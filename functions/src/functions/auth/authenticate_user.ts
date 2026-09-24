import {onCall, HttpsError} from "firebase-functions/v2/https";
import {db, auth, webApiKey} from "../../lib/admin";
import {verifyEmailPassword} from "../../lib/identity_toolkit";
import {
    hashIdentifier,
    checkLoginBlocked,
    recordLoginFailure,
    resetLoginFailures,
} from "../../lib/rate_limit";

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

        // 7. Ensure custom claims are set on Auth record, mint custom token with role, and reset failure counter.
        await auth.setCustomUserClaims(uid, {role: userRole, is_verified: emailVerified});
        const customToken = await auth.createCustomToken(uid, {role: userRole, is_verified: emailVerified});
        await resetLoginFailures(hash, action);

        return {customToken, role: userRole, emailVerified};
    },
);
