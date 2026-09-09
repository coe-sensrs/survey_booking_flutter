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
const APPLICANT_UNVERIFIED = { uid: 'applicant-unverified', token: { email: 'uv@test.com', email_verified: false, role: 'applicant' } };
const ADMIN = { uid: 'admin-1', token: { email: 'admin@test.com', email_verified: true, role: 'admin' } };
const COMMITTEE_ASSIGNED = { uid: 'committee-assigned', token: { email: 'ca@test.com', email_verified: true, role: 'committee' } };
const COMMITTEE_UNASSIGNED = { uid: 'committee-other', token: { email: 'co@test.com', email_verified: true, role: 'committee' } };

const APPOINTMENT_ID = 'appt-001';

/** Seed an appointment document via admin bypass. */
async function seedAppointment(testEnv, overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().collection('appointments').doc(APPOINTMENT_ID).set({
      applicantId: APPLICANT_A.uid,
      applicantName: 'Applicant A',
      applicantEmail: 'a@test.com',
      surveyType: 'Cadastral',
      state: 'Punjab',
      district: 'Ludhiana',
      areaName: 'Test Area',
      preferredDate: new Date(),
      status: 'pending_assignment',
      createdAt: new Date(),
      updatedAt: new Date(),
      assignedReviewerId: COMMITTEE_ASSIGNED.uid,
      assignedTaskMemberId: null,
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
// appointments/{appointmentId} — Read access
// ---------------------------------------------------------------------------
describe('Firestore rules: appointments — read access', () => {
  test('unauthenticated read denied', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).get());
  });

  test('applicant reads own appointment', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, APPLICANT_A.token).firestore();
    await assertSucceeds(db.collection('appointments').doc(APPOINTMENT_ID).get());
  });

  test('applicant cannot read another applicant appointment', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(APPLICANT_B.uid, APPLICANT_B.token).firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).get());
  });

  test('admin reads any appointment', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertSucceeds(db.collection('appointments').doc(APPOINTMENT_ID).get());
  });

  test('assigned committee member reads appointment', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(COMMITTEE_ASSIGNED.uid, COMMITTEE_ASSIGNED.token).firestore();
    await assertSucceeds(db.collection('appointments').doc(APPOINTMENT_ID).get());
  });

  test('unassigned committee member cannot read appointment', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(COMMITTEE_UNASSIGNED.uid, COMMITTEE_UNASSIGNED.token).firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).get());
  });

  test('committee A cannot read appointment assigned to committee B', async () => {
    // Appointment assigned to COMMITTEE_ASSIGNED, accessed by COMMITTEE_UNASSIGNED
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(COMMITTEE_UNASSIGNED.uid, COMMITTEE_UNASSIGNED.token).firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).get());
  });

  test('assigned task member (not reviewer) can read appointment', async () => {
    await seedAppointment(testEnv, {
      assignedReviewerId: 'someone-else',
      assignedTaskMemberId: COMMITTEE_ASSIGNED.uid,
    });
    const db = testEnv.authenticatedContext(COMMITTEE_ASSIGNED.uid, COMMITTEE_ASSIGNED.token).firestore();
    await assertSucceeds(db.collection('appointments').doc(APPOINTMENT_ID).get());
  });
});

// ---------------------------------------------------------------------------
// appointments/{appointmentId} — Create
// ---------------------------------------------------------------------------
describe('Firestore rules: appointments — create', () => {
  const validAppointment = {
    applicantId: APPLICANT_A.uid,
    applicantName: 'Applicant A',
    applicantEmail: 'a@test.com',
    surveyType: 'Cadastral',
    state: 'Punjab',
    district: 'Ludhiana',
    areaName: 'Test Area',
    preferredDate: new Date(),
    status: 'pending_assignment',
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  test('verified applicant can create own appointment', async () => {
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, APPLICANT_A.token).firestore();
    await assertSucceeds(db.collection('appointments').doc('new-appt').set(validAppointment));
  });

  test('unverified applicant cannot create appointment', async () => {
    const db = testEnv.authenticatedContext(APPLICANT_UNVERIFIED.uid, APPLICANT_UNVERIFIED.token).firestore();
    await assertFails(db.collection('appointments').doc('new-appt').set({
      ...validAppointment,
      applicantId: APPLICANT_UNVERIFIED.uid,
      applicantEmail: 'uv@test.com',
    }));
  });

  test('applicant cannot create appointment for another user', async () => {
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, APPLICANT_A.token).firestore();
    await assertFails(db.collection('appointments').doc('new-appt').set({
      ...validAppointment,
      applicantId: APPLICANT_B.uid,
    }));
  });

  test('applicant cannot create appointment with non-pending status', async () => {
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, APPLICANT_A.token).firestore();
    await assertFails(db.collection('appointments').doc('new-appt').set({
      ...validAppointment,
      status: 'approved',
    }));
  });

  test('committee cannot create appointment', async () => {
    const db = testEnv.authenticatedContext(COMMITTEE_ASSIGNED.uid, COMMITTEE_ASSIGNED.token).firestore();
    await assertFails(db.collection('appointments').doc('new-appt').set({
      ...validAppointment,
      applicantId: COMMITTEE_ASSIGNED.uid,
    }));
  });

  test('unauthenticated cannot create appointment', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('appointments').doc('new-appt').set(validAppointment));
  });
});

// ---------------------------------------------------------------------------
// appointments/{appointmentId} — Client-side write bypass prevention
// ---------------------------------------------------------------------------
describe('Firestore rules: appointments — bypass prevention', () => {
  test('applicant cannot update status (bypassing Cloud Functions)', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, APPLICANT_A.token).firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).update({
      status: 'approved',
    }));
  });

  test('applicant cannot change assignedReviewerId', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, APPLICANT_A.token).firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).update({
      assignedReviewerId: 'hacker-id',
    }));
  });

  test('applicant cannot change assignedTaskMemberId', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, APPLICANT_A.token).firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).update({
      assignedTaskMemberId: 'hacker-id',
    }));
  });

  test('applicant cannot change appointment ownership', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(APPLICANT_A.uid, APPLICANT_A.token).firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).update({
      applicantId: 'stolen-id',
    }));
  });

  test('committee cannot directly change status', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(COMMITTEE_ASSIGNED.uid, COMMITTEE_ASSIGNED.token).firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).update({
      status: 'approved',
    }));
  });

  test('committee cannot modify arbitrary fields', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(COMMITTEE_ASSIGNED.uid, COMMITTEE_ASSIGNED.token).firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).update({
      areaName: 'Tampered',
    }));
  });

  test('admin cannot update appointments (all updates via Admin SDK)', async () => {
    // Per rules: allow update: if false — even admin client-side updates are blocked
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).update({
      status: 'approved',
    }));
  });

  test('no one can delete appointments', async () => {
    await seedAppointment(testEnv);
    const db = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).firestore();
    await assertFails(db.collection('appointments').doc(APPOINTMENT_ID).delete());
  });
});
