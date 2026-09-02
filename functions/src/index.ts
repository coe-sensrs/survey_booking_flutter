import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

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
