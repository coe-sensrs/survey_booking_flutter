const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const { resolve } = require('path');

const PROJECT_ID = global.PROJECT_ID || 'survey-desk-test';
const RULES_PATH = resolve(__dirname, '../../../firestore.rules');

// ---------------------------------------------------------------------------
// Test users
// ---------------------------------------------------------------------------
const APPLICANT_A = { uid: 'applicant-a', email: 'a@test.com', email_verified: true, role: 'applicant' };
const APPLICANT_B = { uid: 'applicant-b', email: 'b@test.com', email_verified: true, role: 'applicant' };
const ADMIN = { uid: 'admin-1', email: 'admin@test.com', email_verified: true, role: 'admin' };
const COMMITTEE = { uid: 'committee-1', email: 'c@test.com', email_verified: true, role: 'committee' };

function authToken(user) {
  return { uid: user.uid, token: { email: user.email, email_verified: user.email_verified, role: user.role } };
}

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
// users/{uid}
// ---------------------------------------------------------------------------
describe('Firestore rules: users/{uid}', () => {
  // -- Read ------------------------------------------------------------------
  test('unauthenticated read denied', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('users').doc(APPLICANT_A.uid).get());
  });

  test('authenticated user can read own document', async () => {
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
    // Seed data via admin
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc(APPLICANT_A.uid).set({
        fullName: 'Test', email: 'a@test.com', phone: '1234567890', role: 'applicant',
        createdAt: new Date(), updatedAt: new Date(),
      });
    });
    await assertSucceeds(db.collection('users').doc(APPLICANT_A.uid).get());
  });

  test('authenticated user can read another user document', async () => {
    // Per rules: any authenticated user can read profile data
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc(APPLICANT_B.uid).set({
        fullName: 'Other', email: 'b@test.com', phone: '1234567890', role: 'applicant',
        createdAt: new Date(), updatedAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
    await assertSucceeds(db.collection('users').doc(APPLICANT_B.uid).get());
  });

  // -- Self-create -----------------------------------------------------------
  test('applicant can create own user document with valid fields', async () => {
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
    await assertSucceeds(db.collection('users').doc(APPLICANT_A.uid).set({
      fullName: 'Applicant A',
      email: 'a@test.com',
      phone: '1234567890',
      role: 'applicant',
      createdAt: new Date(),
      updatedAt: new Date(),
    }));
  });

  test('applicant cannot create document for another uid', async () => {
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
    await assertFails(db.collection('users').doc(APPLICANT_B.uid).set({
      fullName: 'Fake', email: 'b@test.com', phone: '1234567890', role: 'applicant',
      createdAt: new Date(), updatedAt: new Date(),
    }));
  });

  test('applicant cannot self-create with admin role (privilege escalation)', async () => {
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
    await assertFails(db.collection('users').doc(APPLICANT_A.uid).set({
      fullName: 'Hacker', email: 'a@test.com', phone: '1234567890', role: 'admin',
      createdAt: new Date(), updatedAt: new Date(),
    }));
  });

  test('applicant cannot self-create with committee role', async () => {
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
    await assertFails(db.collection('users').doc(APPLICANT_A.uid).set({
      fullName: 'Hacker', email: 'a@test.com', phone: '1234567890', role: 'committee',
      createdAt: new Date(), updatedAt: new Date(),
    }));
  });

  // -- Self-update: blocked fields -------------------------------------------
  test('user cannot modify own role', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc(APPLICANT_A.uid).set({
        fullName: 'Test', email: 'a@test.com', phone: '1234567890', role: 'applicant',
        createdAt: new Date(), updatedAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
    await assertFails(db.collection('users').doc(APPLICANT_A.uid).update({
      role: 'admin', updatedAt: new Date(),
    }));
  });

  test('user cannot modify own createdAt', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc(APPLICANT_A.uid).set({
        fullName: 'Test', email: 'a@test.com', phone: '1234567890', role: 'applicant',
        createdAt: new Date(), updatedAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
    await assertFails(db.collection('users').doc(APPLICANT_A.uid).update({
      createdAt: new Date(), updatedAt: new Date(),
    }));
  });

  test('user cannot modify own email', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc(APPLICANT_A.uid).set({
        fullName: 'Test', email: 'a@test.com', phone: '1234567890', role: 'applicant',
        createdAt: new Date(), updatedAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
    await assertFails(db.collection('users').doc(APPLICANT_A.uid).update({
      email: 'evil@new.com', updatedAt: new Date(),
    }));
  });

  test('user cannot modify another user profile', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc(APPLICANT_B.uid).set({
        fullName: 'Other', email: 'b@test.com', phone: '1234567890', role: 'applicant',
        createdAt: new Date(), updatedAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
    await assertFails(db.collection('users').doc(APPLICANT_B.uid).update({
      fullName: 'Tampered', updatedAt: new Date(),
    }));
  });

  // -- Self-update: allowed fields -------------------------------------------
  test('user can update own fullName and phone', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc(APPLICANT_A.uid).set({
        fullName: 'Test', email: 'a@test.com', phone: '1234567890', role: 'applicant',
        createdAt: new Date(), updatedAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
    await assertSucceeds(db.collection('users').doc(APPLICANT_A.uid).update({
      fullName: 'Updated Name', phone: '9876543210', updatedAt: new Date(),
    }));
  });

  // -- Admin write -----------------------------------------------------------
  test('admin can write any user document', async () => {
    const db = testEnv.authenticatedContext(ADMIN.uid, authToken(ADMIN).token).firestore();
    await assertSucceeds(db.collection('users').doc('new-user-xyz').set({
      fullName: 'Admin Created', email: 'new@test.com', phone: '1112223333',
      role: 'committee', expertiseTag: 'Geology',
      createdAt: new Date(), updatedAt: new Date(),
    }));
  });

  // -- Claim mismatch tests --------------------------------------------------
  test('CLAIM MISMATCH: token=applicant, Firestore role=admin → NOT admin', async () => {
    // User has applicant claim but Firestore says admin → should NOT get admin access
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc('mismatch-user').set({
        fullName: 'Mismatch', email: 'x@test.com', phone: '1234567890', role: 'admin',
        createdAt: new Date(), updatedAt: new Date(),
      });
    });
    // Auth token says applicant — try admin-only write
    const db = testEnv.authenticatedContext('mismatch-user', {
      email: 'x@test.com', email_verified: true, role: 'applicant',
    }).firestore();
    await assertFails(db.collection('users').doc('some-other-user').set({
      fullName: 'Exploit', email: 'z@test.com', phone: '1234567890',
      role: 'committee', createdAt: new Date(), updatedAt: new Date(),
    }));
  });

  test('CLAIM MISMATCH: token=admin, Firestore role=applicant → still admin', async () => {
    // User has admin claim but Firestore says applicant → should still have admin access
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('users').doc('mismatch-admin').set({
        fullName: 'Admin', email: 'adm@test.com', phone: '1234567890', role: 'applicant',
        createdAt: new Date(), updatedAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext('mismatch-admin', {
      email: 'adm@test.com', email_verified: true, role: 'admin',
    }).firestore();
    await assertSucceeds(db.collection('users').doc('any-user').set({
      fullName: 'Created By Admin', email: 'new@test.com', phone: '1234567890',
      role: 'committee', createdAt: new Date(), updatedAt: new Date(),
    }));
  });
});
