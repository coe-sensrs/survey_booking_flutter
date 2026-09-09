const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const { resolve } = require('path');

const PROJECT_ID = global.PROJECT_ID || 'survey-desk-test';
const STORAGE_RULES_PATH = resolve(__dirname, '../../../storage.rules');
const FIRESTORE_RULES_PATH = resolve(__dirname, '../../../firestore.rules');

// ---------------------------------------------------------------------------
// Test users
// ---------------------------------------------------------------------------
const USER_A = { uid: 'user-a', token: { email: 'a@test.com', email_verified: true, role: 'applicant' } };
const USER_B = { uid: 'user-b', token: { email: 'b@test.com', email_verified: true, role: 'applicant' } };
const ADMIN = { uid: 'admin-1', token: { email: 'admin@test.com', email_verified: true, role: 'admin' } };

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(FIRESTORE_RULES_PATH, 'utf8'),
    },
    storage: {
      rules: readFileSync(STORAGE_RULES_PATH, 'utf8'),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

// ---------------------------------------------------------------------------
// Profile photos — users/{uid}/profile/{fileName}
// ---------------------------------------------------------------------------
describe('Storage rules: profile photos', () => {
  const photoPath = (uid) => `users/${uid}/profile/avatar.jpg`;

  async function seedPhoto(uid) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const ref = ctx.storage().ref(photoPath(uid));
      await ref.put(new Uint8Array(2048), { contentType: 'image/jpeg' });
    });
  }

  // -- Read ------------------------------------------------------------------
  test('authenticated user can read own profile photo', async () => {
    await seedPhoto(USER_A.uid);
    const ref = testEnv.authenticatedContext(USER_A.uid, USER_A.token).storage().ref(photoPath(USER_A.uid));
    await assertSucceeds(ref.getDownloadURL());
  });

  test('authenticated user can read another user profile photo', async () => {
    // TRD: "readable by anyone in the app" (profile photos aren't sensitive)
    await seedPhoto(USER_B.uid);
    const ref = testEnv.authenticatedContext(USER_A.uid, USER_A.token).storage().ref(photoPath(USER_B.uid));
    await assertSucceeds(ref.getDownloadURL());
  });

  test('unauthenticated cannot read profile photo', async () => {
    await seedPhoto(USER_A.uid);
    const ref = testEnv.unauthenticatedContext().storage().ref(photoPath(USER_A.uid));
    await assertFails(ref.getDownloadURL());
  });

  test('admin can read any profile photo', async () => {
    await seedPhoto(USER_A.uid);
    const ref = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).storage().ref(photoPath(USER_A.uid));
    await assertSucceeds(ref.getDownloadURL());
  });

  // -- Write -----------------------------------------------------------------
  test('user can upload own profile photo (image, under 5MB)', async () => {
    const ref = testEnv.authenticatedContext(USER_A.uid, USER_A.token).storage().ref(photoPath(USER_A.uid));
    await assertSucceeds(ref.put(new Uint8Array(2048), { contentType: 'image/jpeg' }));
  });

  test('user cannot upload to another user profile path', async () => {
    const ref = testEnv.authenticatedContext(USER_A.uid, USER_A.token).storage().ref(photoPath(USER_B.uid));
    await assertFails(ref.put(new Uint8Array(2048), { contentType: 'image/jpeg' }));
  });

  test('admin can upload to any user profile path', async () => {
    const ref = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).storage().ref(photoPath(USER_A.uid));
    await assertSucceeds(ref.put(new Uint8Array(2048), { contentType: 'image/jpeg' }));
  });

  test('upload rejected for non-image content type', async () => {
    const ref = testEnv.authenticatedContext(USER_A.uid, USER_A.token).storage().ref(photoPath(USER_A.uid));
    await assertFails(ref.put(new Uint8Array(2048), { contentType: 'application/pdf' }));
  });

  test('upload rejected for oversized image (>5MB)', async () => {
    const ref = testEnv.authenticatedContext(USER_A.uid, USER_A.token).storage().ref(photoPath(USER_A.uid));
    await assertFails(ref.put(new Uint8Array(6 * 1024 * 1024), { contentType: 'image/jpeg' }));
  });

  // -- Delete ----------------------------------------------------------------
  test('user can delete own profile photo', async () => {
    await seedPhoto(USER_A.uid);
    const ref = testEnv.authenticatedContext(USER_A.uid, USER_A.token).storage().ref(photoPath(USER_A.uid));
    await assertSucceeds(ref.delete());
  });

  test('user cannot delete another user profile photo', async () => {
    await seedPhoto(USER_B.uid);
    const ref = testEnv.authenticatedContext(USER_A.uid, USER_A.token).storage().ref(photoPath(USER_B.uid));
    await assertFails(ref.delete());
  });

  test('admin can delete any profile photo', async () => {
    await seedPhoto(USER_A.uid);
    const ref = testEnv.authenticatedContext(ADMIN.uid, ADMIN.token).storage().ref(photoPath(USER_A.uid));
    await assertSucceeds(ref.delete());
  });
});
