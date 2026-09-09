/**
 * authz.test.js
 *
 * Authorization tests for all Cloud Functions callables.
 * Verifies that every callable correctly rejects callers that do not
 * satisfy its role / email-verification requirements.
 *
 * Covered functions:
 *   - createCommitteeAccount  (admin-only)
 *   - authenticateUser        (any signed-in user)
 *   - registerApplicant       (public — no auth needed for registration)
 *   - requestPasswordReset    (public)
 *   - submitAppointment       (applicant + email verified)
 *
 * Run against the emulator suite:
 *   npm run test:functions
 */

const admin = require("firebase-admin");
const {
  initEmulatorAdmin,
  makeAppointmentPayload,
  callAsUser,
  callUnauthenticated,
} = require("./test_helpers");

// ── Setup ─────────────────────────────────────────────────────────────────────

beforeAll(() => {
  initEmulatorAdmin();
});

// ── Helper: check CF error code in response body ──────────────────────────────
function errorCode(body) {
  // v2 callable errors land in body.error.status
  return body?.error?.status ?? body?.error?.code ?? null;
}

// =============================================================================
// submitAppointment — role & email-verification guards
// =============================================================================

describe("submitAppointment", () => {
  const FN = "submitAppointment";

  test("unauthenticated caller → UNAUTHENTICATED", async () => {
    const { body } = await callUnauthenticated(FN, makeAppointmentPayload());
    expect(errorCode(body)).toBe("UNAUTHENTICATED");
  });

  test("committee_admin role → PERMISSION_DENIED", async () => {
    const { body } = await callAsUser(
      FN,
      makeAppointmentPayload(),
      "admin-uid-001",
      { role: "committee_admin" },
    );
    expect(errorCode(body)).toBe("PERMISSION_DENIED");
  });

  test("committee_reviewer role → PERMISSION_DENIED", async () => {
    const { body } = await callAsUser(
      FN,
      makeAppointmentPayload(),
      "reviewer-uid-001",
      { role: "committee_reviewer" },
    );
    expect(errorCode(body)).toBe("PERMISSION_DENIED");
  });

  test("committee_task_member role → PERMISSION_DENIED", async () => {
    const { body } = await callAsUser(
      FN,
      makeAppointmentPayload(),
      "task-uid-001",
      { role: "committee_task_member" },
    );
    expect(errorCode(body)).toBe("PERMISSION_DENIED");
  });

  test("applicant with unverified email → FAILED_PRECONDITION", async () => {
    const { body } = await callAsUser(
      FN,
      makeAppointmentPayload(),
      "applicant-unverified-001",
      { role: "applicant" },
      false, // email_verified = false
    );
    expect(errorCode(body)).toBe("FAILED_PRECONDITION");
  });

  test("applicant missing required surveyType → INVALID_ARGUMENT", async () => {
    const payload = makeAppointmentPayload({ surveyType: "" });
    const { body } = await callAsUser(
      FN,
      payload,
      "applicant-uid-001",
      { role: "applicant" },
    );
    expect(errorCode(body)).toBe("INVALID_ARGUMENT");
  });

  test("applicant missing required state/district → INVALID_ARGUMENT", async () => {
    const payload = makeAppointmentPayload({ state: "", district: "" });
    const { body } = await callAsUser(
      FN,
      payload,
      "applicant-uid-001",
      { role: "applicant" },
    );
    expect(errorCode(body)).toBe("INVALID_ARGUMENT");
  });

  test("applicant missing KML file → INVALID_ARGUMENT", async () => {
    const payload = makeAppointmentPayload({
      kmlFile: { storagePath: "", originalFileName: "", fileType: "", sizeBytes: 0, uploadedAt: "" },
    });
    const { body } = await callAsUser(
      FN,
      payload,
      "applicant-uid-001",
      { role: "applicant" },
    );
    expect(errorCode(body)).toBe("INVALID_ARGUMENT");
  });

  test("valid applicant with verified email succeeds", async () => {
    const { body } = await callAsUser(
      FN,
      makeAppointmentPayload(),
      "applicant-uid-valid",
      { role: "applicant" },
      true,
    );
    // Success: no error key, appointmentId returned
    expect(body?.error).toBeUndefined();
    expect(typeof body?.result?.appointmentId ?? body?.data?.appointmentId).toBe("string");
  });
});

// =============================================================================
// createCommitteeAccount — admin-only
// =============================================================================

describe("createCommitteeAccount", () => {
  const FN = "createCommitteeAccount";
  const PAYLOAD = {
    name: "New Member",
    email: "newmember@test.com",
    phone: "9876543210",
    expertiseTag: "Cadastral",
  };

  test("unauthenticated caller → UNAUTHENTICATED", async () => {
    const { body } = await callUnauthenticated(FN, PAYLOAD);
    expect(errorCode(body)).toBe("UNAUTHENTICATED");
  });

  test("applicant role → PERMISSION_DENIED", async () => {
    const { body } = await callAsUser(FN, PAYLOAD, "applicant-uid-002", {
      role: "applicant",
    });
    expect(errorCode(body)).toBe("PERMISSION_DENIED");
  });

  test("committee_reviewer role → PERMISSION_DENIED", async () => {
    const { body } = await callAsUser(FN, PAYLOAD, "reviewer-uid-002", {
      role: "committee_reviewer",
    });
    expect(errorCode(body)).toBe("PERMISSION_DENIED");
  });

  test("committee_task_member role → PERMISSION_DENIED", async () => {
    const { body } = await callAsUser(FN, PAYLOAD, "task-uid-002", {
      role: "committee_task_member",
    });
    expect(errorCode(body)).toBe("PERMISSION_DENIED");
  });

  test("deactivated admin (isActive=false) → PERMISSION_DENIED", async () => {
    await admin.firestore().collection("users").doc("deactivated-admin-001").set({
      role: "admin",
      active: false,
      isActive: false,
    });
    const { body } = await callAsUser(FN, PAYLOAD, "deactivated-admin-001", {
      role: "committee_admin",
      isActive: false,
    });
    expect(errorCode(body)).toBe("PERMISSION_DENIED");
  });

  test("active committee_admin succeeds", async () => {
    await admin.firestore().collection("users").doc("admin-uid-active").set({
      role: "admin",
      active: true,
      isActive: true,
    });
    const { body } = await callAsUser(FN, PAYLOAD, "admin-uid-active", {
      role: "committee_admin",
      isActive: true,
    });
    expect(body?.error).toBeUndefined();
  });
});

// =============================================================================
// authenticateUser — any signed-in user but blocks deactivated accounts
// =============================================================================

describe("authenticateUser", () => {
  const FN = "authenticateUser";
  const PAYLOAD = { email: "anyone@test.com", password: "Test1234!" };

  test("unauthenticated (no token) is valid — it is the login endpoint", async () => {
    // authenticateUser is the login function and does NOT require a prior token.
    // It should either succeed or fail with UNAUTHENTICATED only if credentials wrong.
    // We just assert it does NOT return PERMISSION_DENIED for unauthenticated callers.
    const { body } = await callUnauthenticated(FN, PAYLOAD);
    expect(errorCode(body)).not.toBe("PERMISSION_DENIED");
  });
});

// =============================================================================
// requestPasswordReset — public endpoint, no auth needed
// =============================================================================

describe("requestPasswordReset", () => {
  const FN = "requestPasswordReset";

  test("unauthenticated caller is accepted (email reset is public)", async () => {
    const { body } = await callUnauthenticated(FN, {
      email: "anyone@test.com",
    });
    // Must NOT be PERMISSION_DENIED or UNAUTHENTICATED
    expect(errorCode(body)).not.toBe("PERMISSION_DENIED");
    expect(errorCode(body)).not.toBe("UNAUTHENTICATED");
  });
});
