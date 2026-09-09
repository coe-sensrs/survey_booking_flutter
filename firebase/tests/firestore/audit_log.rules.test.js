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
const APPLICANT_A = { uid: 'applicant-a', token: { email: 'a@test.com', email_verified: true, role: 'applicant' } };
const APPLICANT_B = { uid: 'applicant-b', token: { email: 'b@test.com', email_verified: true, role: 'applicant' } };
const ADMIN = { uid: 'admin-1', token: { email: 'admin@test.com', email_verified: true, role: 'admin' } };
const COMMITTEE_ASSIGNED = { uid: 'committee-assigned', token: { email: 'ca@test.com', email_verified: true, role: 'committee' } };
const COMMITTEE_UNASSIGNED = { uid: 'committee-other', token: { email: 'co@test.com', email_verified: true, role: 'committee' } };

const APPOINTMENT_ID = 'appt-001';
const AUDIT_LOG_ID = 'log-001';

/** Seeds an appointment with an audit log entry. */
async function seedWithAuditLog(testEnv, overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.collection('appointments').doc(APPOINTMENT_ID).set({
      applicantId: APPLICANT_A.uid,
      applicantName: 'Applicant A',
      applicantEmail: 'a@test.com',
      surveyType: 'Cadastral',
      state: 'Punjab',
      district: 'Ludhiana',
      areaName: 'Test Area',
      preferredDate: new Date(),
      status: 'under_review',
      createdAt: new Date(),
      updatedAt: new Date(),
      assignedReviewerId: COMMITTEE_ASSIGNED.uid,
      assignedTaskMemberId: null,
    });
    await db.collection('appointments').doc(APPOINTMENT_ID)
      .collection('auditLog').doc(AUDIT_LOG_ID).set({
        action: 'status_changed',
        performedBy: ADMIN.uid,
        applicantId: APPLICANT_A.uid,
        timestamp: new Date(),
        details: 'Assigned to committee',
        ...overrides,
      });
  });
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
// appointments/{appointmentId}/auditLog/{logId} — per-appointment subcollection
// ---------------------------------------------------------------------------
describe('Firestore rules: auditLog subcollection', () => {
  test('unauthenticated read denied', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      db.collection('appointments').doc(APPOINTMENT_ID)
        .collection('auditLog').doc(AUDIT_LOG_ID).get()
    );
  });

  test('admin can read any audit log', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertSucceeds(
      db.collection('appointments').doc(APPOINTMENT_ID)
        .collection('auditLog').doc(AUDIT_LOG_ID).get()
    );
  });

  test('applicant can read own appointment audit log', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, APPLICANT_A.token).firestore();
    await assertSucceeds(
      db.collection('appointments').doc(APPOINTMENT_ID)
        .collection('auditLog').doc(AUDIT_LOG_ID).get()
    );
  });

  test('applicant cannot read another applicant audit log', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.authenticatedContext(APPLICANT_B.uid, APPLICANT_B.token).firestore();
    await assertFails(
      db.collection('appointments').doc(APPOINTMENT_ID)
        .collection('auditLog').doc(AUDIT_LOG_ID).get()
    );
  });

  test('assigned committee member can read audit log', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.authenticatedContext(COMMITTEE_ASSIGNED.uid, COMMITTEE_ASSIGNED.token).firestore();
    await assertSucceeds(
      db.collection('appointments').doc(APPOINTMENT_ID)
        .collection('auditLog').doc(AUDIT_LOG_ID).get()
    );
  });

  test('unassigned committee member cannot read audit log', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.authenticatedContext(COMMITTEE_UNASSIGNED.uid, COMMITTEE_UNASSIGNED.token).firestore();
    await assertFails(
      db.collection('appointments').doc(APPOINTMENT_ID)
        .collection('auditLog').doc(AUDIT_LOG_ID).get()
    );
  });

  // -- Write (always denied — Cloud Functions only) -------------------------
  test('client cannot create audit log entry (forging)', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertFails(
      db.collection('appointments').doc(APPOINTMENT_ID)
        .collection('auditLog').doc('forged-log').set({
          action: 'forged_action',
          performedBy: ADMIN.uid,
          applicantId: APPLICANT_A.uid,
          timestamp: new Date(),
        })
    );
  });

  test('client cannot modify existing audit log entry', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertFails(
      db.collection('appointments').doc(APPOINTMENT_ID)
        .collection('auditLog').doc(AUDIT_LOG_ID).update({
          action: 'tampered',
        })
    );
  });

  test('client cannot delete audit log entry', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertFails(
      db.collection('appointments').doc(APPOINTMENT_ID)
        .collection('auditLog').doc(AUDIT_LOG_ID).delete()
    );
  });
});

// ---------------------------------------------------------------------------
// collectionGroup query — Home screen Recent Activity feed
// ---------------------------------------------------------------------------
describe('Firestore rules: auditLog collectionGroup', () => {
  test('admin can query collectionGroup auditLog', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertSucceeds(
      db.collectionGroup('auditLog')
        .where('applicantId', '==', APPLICANT_A.uid)
        .get()
    );
  });

  test('applicant can query own auditLog via collectionGroup', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, APPLICANT_A.token).firestore();
    await assertSucceeds(
      db.collectionGroup('auditLog')
        .where('applicantId', '==', APPLICANT_A.uid)
        .get()
    );
  });

  test('unauthenticated collectionGroup query denied', async () => {
    await seedWithAuditLog(testEnv);
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      db.collectionGroup('auditLog')
        .where('applicantId', '==', APPLICANT_A.uid)
        .get()
    );
  });

  test('committee member cannot use collectionGroup auditLog', async () => {
    // Committee excluded from collectionGroup per rules
    await seedWithAuditLog(testEnv);
    const db = testEnv.authenticatedContext(COMMITTEE_ASSIGNED.uid, COMMITTEE_ASSIGNED.token).firestore();
    // Committee queries collectionGroup for a different applicant — should fail
    await assertFails(
      db.collectionGroup('auditLog')
        .where('applicantId', '==', APPLICANT_B.uid)
        .get()
    );
  });
});
