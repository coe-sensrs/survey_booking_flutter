import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {
    hashIdentifier,
    checkLoginBlocked,
    recordLoginFailure,
    resetLoginFailures,
    checkAndIncrementRequests,
} from "./rate_limit";

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

// Secret: Firebase Web API Key (Firebase Console -> Project Settings -> General -> Web API Key).
// Set via: firebase functions:secrets:set AUTH_WEB_API_KEY
const webApiKey = defineSecret("AUTH_WEB_API_KEY");

// ============================================================
// Shared helpers — Identity Toolkit REST API (Node 22 native fetch)
// ============================================================

/** Verifies email/password credentials against the Firebase Identity Toolkit
 * REST API and returns the user's UID. Throws on bad credentials.
 *
 * The Admin SDK has no verifyPassword() method; the REST API is the only
 * supported server-side credential-validation path. */
async function verifyEmailPassword(
    email: string,
    password: string,
    apiKey: string,
): Promise<{localId: string}> {
    const response = await fetch(
        `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
        {
            method: "POST",
            headers: {"Content-Type": "application/json"},
            body: JSON.stringify({email, password, returnSecureToken: false}),
        },
    );

    const data = (await response.json()) as {
    localId?: string;
    error?: {message?: string};
  };

    if (data.error) throw new Error(data.error.message ?? "INVALID_LOGIN_CREDENTIALS");
    if (!data.localId) throw new Error("INVALID_LOGIN_CREDENTIALS");
    return {localId: data.localId};
}

/** Sends a Firebase-branded password reset email via the Identity Toolkit REST API.
 * Silently swallows EMAIL_NOT_FOUND to avoid revealing account existence. */
async function sendPasswordResetEmail(email: string, apiKey: string): Promise<void> {
    const response = await fetch(
        `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${apiKey}`,
        {
            method: "POST",
            headers: {"Content-Type": "application/json"},
            body: JSON.stringify({requestType: "PASSWORD_RESET", email}),
        },
    );

    const data = (await response.json()) as {error?: {message?: string}};
    if (data.error && !(data.error.message ?? "").includes("EMAIL_NOT_FOUND")) {
        throw new Error(data.error.message ?? "Failed to send reset email");
    }
}

// ============================================================
// Cloud Function: createCommitteeAccount (existing — unchanged)
// ============================================================

interface CreateCommitteeData {
    name: string;
    email: string;
    phone: string;
    expertiseTag: string;
}

/**
 * Cloud Function to provision a new Committee Member account.
 * Only callable by authenticated Admin users.
 */
export const createCommitteeAccount = onCall(
    {
        region: "us-central1",
        cors: true,
        invoker: "public",
        enforceAppCheck: false,
    },
    async (request) => {
        console.log("Auth:", request.auth ? "yes" : "no");
        // 1. Authentication Check
        if (!request.auth) {
            throw new HttpsError(
                "unauthenticated",
                "You must be authenticated to perform this action.",
            );
        }

        const callerUid = request.auth.uid;

        // 2. Authorization Check (Admin verification)
        let isAdmin = request.auth.token.role === "admin";

        if (!isAdmin) {
            // Fallback: Verify admin role from Firestore
            const callerDoc = await db.collection("users").doc(callerUid).get();
            if (callerDoc.exists && callerDoc.data()?.role === "admin") {
                isAdmin = true;
                // Optionally backfill the custom claim
                await auth.setCustomUserClaims(callerUid, {role: "admin"});
            }
        }

        if (!isAdmin) {
            throw new HttpsError(
                "permission-denied",
                "Only administrators are authorized to add committee members.",
            );
        }

        // 3. Input Validation
        const data = request.data as CreateCommitteeData;
        const name = data?.name?.trim();
        const email = data?.email?.trim().toLowerCase();
        const phone = data?.phone?.trim();
        const expertiseTag = data?.expertiseTag?.trim();

        if (!name || !email || !phone || !expertiseTag) {
            throw new HttpsError(
                "invalid-argument",
                "Name, email, phone number, and expertise tag are required.",
            );
        }

        // Basic email format check
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            throw new HttpsError(
                "invalid-argument",
                "Please provide a valid email address.",
            );
        }

        // Phone number check (10 to 15 digits)
        const phoneDigits = phone.replace(/[^0-9]/g, "");
        if (phoneDigits.length < 10 || phoneDigits.length > 15) {
            throw new HttpsError(
                "invalid-argument",
                "Please provide a valid 10-digit phone number.",
            );
        }

        // 4. Generate Temporary Password
        const tempPassword = `Temp@${Math.random().toString(36).slice(-8)}!1`;

        let newUid: string | null = null;

        try {
            // 5. Create Firebase Auth User
            const userRecord = await auth.createUser({
                email: email,
                displayName: name,
                password: tempPassword,
                emailVerified: true, // Committee members are pre-verified
            });

            newUid = userRecord.uid;

            // 6. Set Custom Claim
            await auth.setCustomUserClaims(newUid, {
                role: "committee",
            });

            // 7. Create Firestore User Document
            await db.collection("users").doc(newUid).set({
                uid: newUid,
                role: "committee",
                fullName: name,
                email: email,
                phone: phone,
                expertiseTag: expertiseTag,
                active: true,
                photoUrl: null,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // 8. Generate Password Reset Link for convenient first login
            let passwordResetLink: string | null = null;
            try {
                passwordResetLink = await auth.generatePasswordResetLink(email);
            } catch {
                // Non-blocking if reset link generation fails
            }

            return {
                success: true,
                uid: newUid,
                email: email,
                tempPassword: tempPassword,
                resetLink: passwordResetLink,
                message: "Committee member account created successfully.",
            };
        } catch (error: unknown) {
            // Clean up orphaned Auth user if Firestore creation fails
            if (newUid) {
                try {
                    const doc = await db.collection("users").doc(newUid).get();
                    if (!doc.exists) {
                        await auth.deleteUser(newUid);
                    }
                } catch {
                    // Ignore cleanup errors
                }
            }

            const err = error as { code?: string; message?: string };
            if (err.code === "auth/email-already-exists") {
                throw new HttpsError(
                    "already-exists",
                    "An account with this email address already exists.",
                );
            }

            if (error instanceof HttpsError) {
                throw error;
            }

            throw new HttpsError(
                "internal",
                err.message || "Failed to create committee member account.",
            );
        }
    },
);

// ============================================================
// Cloud Function: authenticateUser
// Verifies credentials server-side, enforces rate limiting, returns custom token.
// ============================================================

interface AuthenticateUserData {
  email: string;
  password: string;
  /** Server-enforced role check. Pass "admin" for the admin login portal. */
  requiredRole?: string;
}

export const authenticateUser = onCall(
    {
        region: "us-central1",
        cors: true,
        invoker: "public",
        enforceAppCheck: false,
        secrets: [webApiKey],
    },
    async (request) => {
        const data = request.data as AuthenticateUserData;
        const email = data?.email?.trim().toLowerCase();
        const password = data?.password;
        const requiredRole = data?.requiredRole;

        if (!email || !password) {
            throw new HttpsError("invalid-argument", "Email and password are required.");
        }

        const action = requiredRole === "admin" ? "login_admin" : "login_applicant";
        const hash = hashIdentifier(email);

        // 1. Pre-flight block check (read-only, no Firestore write).
        const blockStatus = await checkLoginBlocked(hash, action);
        if (blockStatus.blocked) {
            throw new HttpsError(
                "resource-exhausted",
                `Too many failed attempts. Please try again in ${blockStatus.secondsRemaining} seconds.`,
                {secondsRemaining: blockStatus.secondsRemaining},
            );
        }

        // 2. Verify credentials via Identity Toolkit REST API.
        let uid: string;
        try {
            const result = await verifyEmailPassword(email, password, webApiKey.value());
            uid = result.localId;
        } catch (error: unknown) {
            const failResult = await recordLoginFailure(hash, action);

            if (failResult.blocked) {
                throw new HttpsError(
                    "resource-exhausted",
                    `Too many failed attempts. Account locked for ${failResult.secondsRemaining} seconds.`,
                    {secondsRemaining: failResult.secondsRemaining},
                );
            }

            const msg = (error as Error).message ?? "";
            if (msg.includes("USER_DISABLED")) {
                throw new HttpsError("permission-denied", "Your account has been disabled.");
            }

            throw new HttpsError("unauthenticated", "Invalid email or password.");
        }

        // 3. Load Firestore profile.
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) {
            await recordLoginFailure(hash, action);
            throw new HttpsError("not-found", "User profile not found. Please contact support.");
        }

        const userData = userDoc.data()!;
        const userRole = userData.role as string;

        // 4. Server-enforced role check.
        if (requiredRole) {
            const roleAllowed =
        userRole === requiredRole ||
        (requiredRole === "applicant" && userRole === "committee");

            if (!roleAllowed) {
                await recordLoginFailure(hash, action);
                throw new HttpsError(
                    "permission-denied",
                    requiredRole === "admin" ?
                        "Unauthorized access. This login is for administrators only." :
                        "Invalid role for this login.",
                );
            }
        }

        // 5. Account active check.
        if (userData.active === false) {
            throw new HttpsError(
                "permission-denied",
                "Your account has been deactivated. Please contact your administrator.",
            );
        }

        // 6. Email verification status (applicants only; committee & admin are pre-verified).
        let emailVerified = true;
        if (userRole === "applicant") {
            const authUser = await auth.getUser(uid);
            emailVerified = authUser.emailVerified;
        }

        // 7. Mint custom token and reset failure counter.
        const customToken = await auth.createCustomToken(uid);
        await resetLoginFailures(hash, action);

        return {customToken, role: userRole, emailVerified};
    },
);

// ============================================================
// Cloud Function: registerApplicant
// Server-side account creation with rate limiting.
// ============================================================

interface RegisterApplicantData {
  fullName: string;
  email: string;
  phone: string;
  password: string;
  orgName?: string;
}

export const registerApplicant = onCall(
    {
        region: "us-central1",
        cors: true,
        invoker: "public",
        enforceAppCheck: false,
    },
    async (request) => {
        const data = request.data as RegisterApplicantData;
        const fullName = data?.fullName?.trim();
        const email = data?.email?.trim().toLowerCase();
        const phone = data?.phone?.trim();
        const password = data?.password;
        const orgName = data?.orgName?.trim() || null;

        if (!fullName || !email || !phone || !password) {
            throw new HttpsError(
                "invalid-argument",
                "Full name, email, phone number, and password are required.",
            );
        }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
            throw new HttpsError("invalid-argument", "Please provide a valid email address.");
        }
        const phoneDigits = phone.replace(/[^0-9]/g, "");
        if (phoneDigits.length < 10 || phoneDigits.length > 15) {
            throw new HttpsError("invalid-argument", "Please provide a valid 10-digit phone number.");
        }
        if (password.length < 8) {
            throw new HttpsError("invalid-argument", "Password must be at least 8 characters.");
        }

        // Rate limit: max 3 signups per email per hour.
        const hash = hashIdentifier(email);
        const limitResult = await checkAndIncrementRequests(hash, "signup");
        if (limitResult.blocked) {
            throw new HttpsError(
                "resource-exhausted",
                `Too many signup attempts. Please try again in ${limitResult.secondsRemaining} seconds.`,
                {secondsRemaining: limitResult.secondsRemaining},
            );
        }

        let newUid: string | null = null;

        try {
            const userRecord = await auth.createUser({
                email,
                password,
                displayName: fullName,
                emailVerified: false,
            });
            newUid = userRecord.uid;

            await auth.setCustomUserClaims(newUid, {role: "applicant"});

            await db.collection("users").doc(newUid).set({
                uid: newUid,
                role: "applicant",
                fullName,
                email,
                phone,
                orgName: orgName || null,
                active: true,
                photoUrl: null,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Mint custom token so client can sign in and trigger sendEmailVerification().
            const customToken = await auth.createCustomToken(newUid);
            return {success: true, customToken, email};
        } catch (error: unknown) {
            if (newUid) {
                try {
                    const userDoc = await db.collection("users").doc(newUid).get();
                    if (!userDoc.exists) await auth.deleteUser(newUid);
                } catch {/* ignore cleanup errors */}
            }

            if (error instanceof HttpsError) throw error;

            const err = error as {code?: string; message?: string};
            if (err.code === "auth/email-already-exists" || err.code === "auth/email-already-in-use") {
                throw new HttpsError(
                    "already-exists",
                    "An account with this email already exists. " +
            "If you haven't verified your email yet, log in to resend the verification link.",
                );
            }
            if (err.code === "auth/weak-password") {
                throw new HttpsError("invalid-argument", "The password provided is too weak.");
            }

            throw new HttpsError("internal", "Account creation failed. Please try again.");
        }
    },
);

// ============================================================
// Cloud Function: requestPasswordReset
// Server-side password reset email with rate limiting (3 per hour per email).
// ============================================================

interface PasswordResetData {
  email: string;
}

export const requestPasswordReset = onCall(
    {
        region: "us-central1",
        cors: true,
        invoker: "public",
        enforceAppCheck: false,
        secrets: [webApiKey],
    },
    async (request) => {
        const data = request.data as PasswordResetData;
        const email = data?.email?.trim().toLowerCase();

        if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
            throw new HttpsError("invalid-argument", "A valid email address is required.");
        }

        // Rate limit: max 3 reset requests per email per hour.
        const hash = hashIdentifier(email);
        const limitResult = await checkAndIncrementRequests(hash, "password_reset");
        if (limitResult.blocked) {
            throw new HttpsError(
                "resource-exhausted",
                `Too many password reset requests. Please try again in ${limitResult.secondsRemaining} seconds.`,
                {secondsRemaining: limitResult.secondsRemaining},
            );
        }

        // Fire-and-forget: errors are swallowed to avoid revealing account existence.
        try {
            await sendPasswordResetEmail(email, webApiKey.value());
        } catch (e) {
            console.warn("[requestPasswordReset] Failed to dispatch reset email:", e);
        }

        return {
            success: true,
            message: "If an account exists with this email, a password reset link has been sent.",
        };
    },
);
