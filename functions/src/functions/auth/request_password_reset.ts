import {onCall, HttpsError} from "firebase-functions/v2/https";
import {webApiKey} from "../../lib/admin";
import {sendPasswordResetEmail} from "../../lib/identity_toolkit";
import {
    hashIdentifier,
    checkAndIncrementRequests,
} from "../../lib/rate_limit";

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
