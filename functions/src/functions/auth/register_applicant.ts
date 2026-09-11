import {onCall, HttpsError} from "firebase-functions/v2/https";
import {db, auth, FieldValue} from "../../lib/admin";
import {
    hashIdentifier,
    checkAndIncrementRequests,
} from "../../lib/rate_limit";

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
                createdAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp(),
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

            const err = error as { code?: string; message?: string };
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
