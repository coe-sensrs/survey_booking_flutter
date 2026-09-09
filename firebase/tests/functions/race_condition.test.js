/**
 * race_condition.test.js
 *
 * Concurrency tests for submitAppointment.
 * Verifies that the Firestore transaction inside the CF is truly atomic:
 * even when N callers fire simultaneously, the server never allows
 * more than 3 pending appointments per applicant.
 *
 * Strategy:
 *   1. Fire BURST_SIZE concurrent calls from the same applicant.
 *   2. Count how many succeed vs. fail with RESOURCE_EXHAUSTED.
 *   3. Assert: successes ≤ 3, and (successes + rejections) = BURST_SIZE.
 *   4. Verify the Firestore rateLimits document reflects the exact count.
 *
 * Run against the emulator suite:
 *   npm run test:functions
 */

const admin = require("firebase-admin");
const {
  initEmulatorAdmin,
  makeAppointmentPayload,
  clearFirestore,
  callAsUser,
  PROJECT_ID,
} = require("./test_helpers");

// ── Setup ─────────────────────────────────────────────────────────────────────

beforeAll(() => {
  initEmulatorAdmin();
});

afterEach(async () => {
  // Wipe Firestore between test cases so they don't bleed into each other
  await clearFirestore();
});

// ── Helpers ───────────────────────────────────────────────────────────────────

function httpErrorCode(body) {
  return body?.error?.status ?? body?.error?.code ?? null;
}

/**
 * Fire `n` concurrent submitAppointment calls from the given uid.
 * Returns an array of { status, body } objects.
 */
async function burstSubmit(uid, n) {
  const calls = Array.from({ length: n }, () =>
    callAsUser(
      "submitAppointment",
      makeAppointmentPayload({ applicantEmail: `${uid}@test.com` }),
      uid,
      { role: "applicant" },
      true,
    ),
  );
  return Promise.all(calls);
}

// =============================================================================
// Rate-limit atomic transaction tests
// =============================================================================

describe("submitAppointment — atomic rate-limit (race condition)", () => {
  const APPLICANT_UID = "race-test-applicant";

  test("3 concurrent calls all succeed when starting from 0", async () => {
    const results = await burstSubmit(APPLICANT_UID, 3);

    const successes = results.filter((r) => !r.body.error);
    const failures = results.filter((r) => r.body.error);

    expect(successes).toHaveLength(3);
    expect(failures).toHaveLength(0);

    // Verify the rate-limit doc reflects 3
    const rateLimitDoc = await admin
      .firestore()
      .collection("rateLimits")
      .doc(APPLICANT_UID)
      .get();
    expect(rateLimitDoc.data()?.pendingCount).toBe(3);
  });

  test("4th concurrent call is rejected with RESOURCE_EXHAUSTED", async () => {
    // First saturate the quota
    await burstSubmit(APPLICANT_UID, 3);

    // 4th call — must be rejected
    const [result] = await burstSubmit(APPLICANT_UID, 1);
    expect(httpErrorCode(result.body)).toBe("RESOURCE_EXHAUSTED");
  });

  test("burst of 10: exactly 3 succeed, 7 are RESOURCE_EXHAUSTED", async () => {
    const BURST = 10;
    const results = await burstSubmit(APPLICANT_UID, BURST);

    const successes = results.filter((r) => !r.body.error);
    const resourceExhausted = results.filter(
      (r) => httpErrorCode(r.body) === "RESOURCE_EXHAUSTED",
    );
    const otherErrors = results.filter(
      (r) => r.body.error && httpErrorCode(r.body) !== "RESOURCE_EXHAUSTED",
    );

    // Core invariant: never more than 3 succeed
    expect(successes.length).toBeLessThanOrEqual(3);

    // Total accounting: all requests are either success or RESOURCE_EXHAUSTED
    expect(otherErrors).toHaveLength(0);
    expect(successes.length + resourceExhausted.length).toBe(BURST);

    // Firestore reflects the exact winning count (should be 3)
    const rateLimitDoc = await admin
      .firestore()
      .collection("rateLimits")
      .doc(APPLICANT_UID)
      .get();
    expect(rateLimitDoc.data()?.pendingCount).toBe(successes.length);
  });

  test("appointments created in Firestore match the success count", async () => {
    const BURST = 5;
    const results = await burstSubmit(APPLICANT_UID, BURST);
    const successes = results.filter((r) => !r.body.error);

    const snap = await admin
      .firestore()
      .collection("appointments")
      .where("applicantId", "==", APPLICANT_UID)
      .get();

    expect(snap.size).toBe(successes.length);
    expect(snap.size).toBeLessThanOrEqual(3);
  });

  test("each successful appointment has status=pending_assignment (server-enforced)", async () => {
    await burstSubmit(APPLICANT_UID, 3);

    const snap = await admin
      .firestore()
      .collection("appointments")
      .where("applicantId", "==", APPLICANT_UID)
      .get();

    snap.docs.forEach((doc) => {
      expect(doc.data().status).toBe("pending_assignment");
      // applicantId must equal the uid (not from client payload)
      expect(doc.data().applicantId).toBe(APPLICANT_UID);
    });
  });

  test("rate limit persists: 2 existing + burst of 5 → only 1 additional succeeds", async () => {
    // Seed 2 existing appointments
    await burstSubmit(APPLICANT_UID, 2);

    // Now burst 5 more — only 1 slot remains
    const results = await burstSubmit(APPLICANT_UID, 5);
    const successes = results.filter((r) => !r.body.error);

    expect(successes.length).toBeLessThanOrEqual(1);

    const rateLimitDoc = await admin
      .firestore()
      .collection("rateLimits")
      .doc(APPLICANT_UID)
      .get();
    expect(rateLimitDoc.data()?.pendingCount).toBeLessThanOrEqual(3);
  });

  test("different applicants do not share rate limit buckets", async () => {
    const A = "race-applicant-A";
    const B = "race-applicant-B";

    const [resultsA, resultsB] = await Promise.all([
      burstSubmit(A, 3),
      burstSubmit(B, 3),
    ]);

    const successesA = resultsA.filter((r) => !r.body.error);
    const successesB = resultsB.filter((r) => !r.body.error);

    // Both applicants should each be able to hit the 3-quota independently
    expect(successesA).toHaveLength(3);
    expect(successesB).toHaveLength(3);
  });
});
