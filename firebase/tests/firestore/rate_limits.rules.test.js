const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const { resolve } = require('path');

const PROJECT_ID = global.PROJECT_ID || 'survey-desk-test';
const RULES_PATH = resolve(__dirname, '../../../firestore.rules');

// ---------------------------------------------------------------------------
// Test users
// ---------------------------------------------------------------------------
const APPLICANT = { uid: 'applicant-a', token: { email: 'a@test.com', email_verified: true, role: 'applicant' } };
const ADMIN = { uid: 'admin-1', token: { email: 'admin@test.com', email_verified: true, role: 'admin' } };
const COMMITTEE = { uid: 'committee-1', token: { email: 'c@test.com', email_verified: true, role: 'committee' } };

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// ---------------------------------------------------------------------------
// rateLimits/{applicantId}
// ---------------------------------------------------------------------------
describe('Firestore rules: rateLimits', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('rateLimits').doc(APPLICANT.uid).set({
        pendingCount: 2,
        lastSubmittedAt: new Date(),
      });
    });
  });

  test('applicant can read own rate limit', async () => {
    const db = testEnv.authenticatedContext(APPLICANT.uid, APPLICANT.token).firestore();
    await assertSucceeds(db.collection('rateLimits').doc(APPLICANT.uid).get());
  });

  test('admin can read any rate limit', async () => {
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertSucceeds(db.collection('rateLimits').doc(APPLICANT.uid).get());
  });

  test('committee cannot read rate limits', async () => {
    const db = testEnv.authenticatedContext(COMMITTEE.uid, COMMITTEE.token).firestore();
    await assertFails(db.collection('rateLimits').doc(APPLICANT.uid).get());
  });

  test('unauthenticated cannot read rate limits', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('rateLimits').doc(APPLICANT.uid).get());
  });

  test('applicant cannot write own rate limit (bypass prevention)', async () => {
    const db = testEnv.authenticatedContext(APPLICANT.uid, APPLICANT.token).firestore();
    await assertFails(db.collection('rateLimits').doc(APPLICANT.uid).update({
      pendingCount: 0,
    }));
  });

  test('admin cannot write rate limits from client', async () => {
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertFails(db.collection('rateLimits').doc(APPLICANT.uid).update({
      pendingCount: 0,
    }));
  });

  test('applicant cannot delete rate limit document', async () => {
    const db = testEnv.authenticatedContext(APPLICANT.uid, APPLICANT.token).firestore();
    await assertFails(db.collection('rateLimits').doc(APPLICANT.uid).delete());
  });
});

// ---------------------------------------------------------------------------
// auth_rate_limits/{docId} — Zero client access
// ---------------------------------------------------------------------------
describe('Firestore rules: auth_rate_limits', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('auth_rate_limits').doc('login_test123').set({
        failureCount: 3,
        lastFailedAt: new Date(),
        lockoutUntil: new Date(),
      });
    });
  });

  test('applicant cannot read auth_rate_limits', async () => {
    const db = testEnv.authenticatedContext(APPLICANT.uid, APPLICANT.token).firestore();
    await assertFails(db.collection('auth_rate_limits').doc('login_test123').get());
  });

  test('admin cannot read auth_rate_limits', async () => {
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertFails(db.collection('auth_rate_limits').doc('login_test123').get());
  });

  test('committee cannot read auth_rate_limits', async () => {
    const db = testEnv.authenticatedContext(COMMITTEE.uid, COMMITTEE.token).firestore();
    await assertFails(db.collection('auth_rate_limits').doc('login_test123').get());
  });

  test('unauthenticated cannot read auth_rate_limits', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('auth_rate_limits').doc('login_test123').get());
  });

  test('no one can write auth_rate_limits', async () => {
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertFails(db.collection('auth_rate_limits').doc('login_test123').update({
      failureCount: 0,
    }));
  });

  test('no one can create auth_rate_limits', async () => {
    const db = testEnv.authenticatedContext(APPLICANT.uid, APPLICANT.token).firestore();
    await assertFails(db.collection('auth_rate_limits').doc('new-entry').set({
      failureCount: 0,
      lastFailedAt: new Date(),
    }));
  });

  test('no one can delete auth_rate_limits', async () => {
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertFails(db.collection('auth_rate_limits').doc('login_test123').delete());
  });
});
