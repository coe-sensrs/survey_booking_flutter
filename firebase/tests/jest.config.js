/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  testTimeout: 30000,
  // Emulator project ID — must match the --project flag passed to
  // `firebase emulators:start`. Does NOT need to be a real Firebase project.
  globals: {
    PROJECT_ID: 'survey-desk-test',
  },
};
