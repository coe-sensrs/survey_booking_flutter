import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";

if (admin.apps.length === 0) {
    admin.initializeApp();
}

export const db = admin.firestore();
export const auth = admin.auth();
export {FieldValue, Timestamp} from "firebase-admin/firestore";

// Secret: Firebase Web API Key (Firebase Console -> Project Settings -> General -> Web API Key).
// Set via: firebase functions:secrets:set AUTH_WEB_API_KEY
export const webApiKey = defineSecret("AUTH_WEB_API_KEY");
export {admin};
