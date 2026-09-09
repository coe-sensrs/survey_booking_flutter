/**
 * test_helpers.js
 *
 * Shared utilities for Cloud Functions integration tests.
 * Tests call the emulated HTTPS Callable endpoints directly via the
 * Firebase Admin SDK so they can forge custom auth tokens with arbitrary
 * custom claims — no real Firebase project required.
 */

const admin = require("firebase-admin");

const PROJECT_ID = process.env.GCLOUD_PROJECT || global.PROJECT_ID || "survey-desk-test";

// ── Emulator addresses ────────────────────────────────────────────────────────
const EMULATOR_HOST = "127.0.0.1";
const AUTH_PORT = 9099;
const FIRESTORE_PORT = 8080;
const FUNCTIONS_PORT = 5001;

/**
 * Initialise the Admin SDK against the local emulator suite.
 * Call once per test file (before-all hook).
 */
function initEmulatorAdmin() {
  // Guard: don't double-init if a previous test file already called this
  if (admin.apps.length === 0) {
    // Route Auth and Firestore to emulators
    process.env.FIREBASE_AUTH_EMULATOR_HOST = `${EMULATOR_HOST}:${AUTH_PORT}`;
    process.env.FIRESTORE_EMULATOR_HOST = `${EMULATOR_HOST}:${FIRESTORE_PORT}`;
    process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST = `${EMULATOR_HOST}:${FUNCTIONS_PORT}`;

    admin.initializeApp({ projectId: PROJECT_ID });
  }
  return admin;
}

/**
 * Minimal valid appointment payload that passes the CF's validation guards.
 */
function makeAppointmentPayload(overrides = {}) {
  return {
    applicantName: "Test Applicant",
    applicantOrgName: "Test Org",
    applicantEmail: "applicant@test.com",
    surveyType: "topographic",
    customSurveyName: null,
    state: "Maharashtra",
    district: "Pune",
    xenDetails: {
      name: "XEN Name",
      mobile: "9876543210",
      email: "xen@pwd.gov.in",
    },
    areaName: "Test Area",
    kmlFile: {
      storagePath: "uploads/test/area.kml",
      originalFileName: "area.kml",
      fileType: "kml",
      sizeBytes: 1024,
      uploadedAt: new Date().toISOString(),
    },
    preferredDate: new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString(),
    logistics: {
      coordinatorName: "Coord Name",
      coordinatorDesignation: "Assistant Engineer",
      driverName: "Driver Name",
      driverMobile: "9123456789",
      vehicleNumber: "MH12AB1234",
      vehicleModel: "Mahindra Scorpio",
    },
    permissionDocuments: [],
    ...overrides,
  };
}

/**
 * Wipe all Firestore data in the emulator between tests.
 */
async function clearFirestore() {
  const url = `http://${EMULATOR_HOST}:${FIRESTORE_PORT}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
  const res = await fetch(url, { method: "DELETE" });
  if (!res.ok) {
    throw new Error(`Failed to clear Firestore emulator: ${res.status} ${await res.text()}`);
  }
}

/**
 * Build the URL for an emulated HTTPS Callable function.
 * Format: http://127.0.0.1:{port}/{projectId}/us-central1/{fnName}
 */
function callableUrl(fnName) {
  return `http://${EMULATOR_HOST}:${FUNCTIONS_PORT}/${PROJECT_ID}/us-central1/${fnName}`;
}

const tokenCache = new Map();
const pendingTokenPromises = new Map();

/**
 * Ensures user exists, sets custom claims, and exchanges custom token
 * for a real Firebase ID token via the Auth emulator.
 */
async function getIdTokenForUser(uid, claims = {}, verified = true) {
  const cacheKey = `${uid}:${JSON.stringify(claims)}:${verified}`;
  if (tokenCache.has(cacheKey)) {
    return tokenCache.get(cacheKey);
  }
  if (pendingTokenPromises.has(cacheKey)) {
    return pendingTokenPromises.get(cacheKey);
  }

  const promise = (async () => {
    try {
      await admin.auth().getUser(uid);
      await admin.auth().updateUser(uid, { emailVerified: verified });
    } catch {
      try {
        await admin.auth().createUser({
          uid,
          email: `${uid}@test.com`,
          emailVerified: verified,
        });
      } catch {
        // If created in parallel, update instead
        await admin.auth().updateUser(uid, { emailVerified: verified });
      }
    }

    // Set custom claims so they appear top-level in the issued ID token
    await admin.auth().setCustomUserClaims(uid, claims);

    // Mint a custom token and exchange it with the Auth emulator for an ID token
    const customToken = await admin.auth().createCustomToken(uid);
    const resp = await fetch(
      `http://${EMULATOR_HOST}:${AUTH_PORT}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=test`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token: customToken, returnSecureToken: true }),
      }
    );
    const data = await resp.json();
    if (!data.idToken) {
      throw new Error(`Failed to obtain ID token for ${uid}: ${JSON.stringify(data)}`);
    }
    tokenCache.set(cacheKey, data.idToken);
    pendingTokenPromises.delete(cacheKey);
    return data.idToken;
  })();

  pendingTokenPromises.set(cacheKey, promise);
  return promise;
}

/**
 * Make a raw POST request to a v2 Callable Function endpoint.
 * Forges the Authorization header with an authentic ID token
 * so the CF sees a verified uid + custom claims at root level.
 *
 * @param {string}  fnName   - The exported function name (e.g. 'submitAppointment')
 * @param {object}  data     - The request payload
 * @param {string}  uid      - The uid to impersonate (token subject)
 * @param {object}  claims   - Custom claims to embed (e.g. { role: 'applicant' })
 * @param {boolean} verified - email_verified claim value (default: true)
 */
async function callAsUser(fnName, data, uid, claims = {}, verified = true) {
  const idToken = await getIdTokenForUser(uid, claims, verified);

  const url = callableUrl(fnName);
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({ data }),
  });

  const json = await response.json();
  return { status: response.status, body: json };
}

/**
 * Make an unauthenticated POST to a Callable Function.
 */
async function callUnauthenticated(fnName, data) {
  const url = callableUrl(fnName);
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ data }),
  });
  const json = await response.json();
  return { status: response.status, body: json };
}

module.exports = {
  initEmulatorAdmin,
  makeAppointmentPayload,
  clearFirestore,
  callAsUser,
  callUnauthenticated,
  PROJECT_ID,
};
