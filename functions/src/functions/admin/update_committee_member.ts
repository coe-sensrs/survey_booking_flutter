import {onCall, HttpsError} from "firebase-functions/v2/https";
import {db, auth, FieldValue} from "../../lib/admin";

// ─────────────────────────────────────────────────────────────────────────────
// Shared admin guard — mirrors admin_appointment_mutations.ts pattern.
// ─────────────────────────────────────────────────────────────────────────────
async function requireAdmin(
    request: {auth?: {uid: string; token: Record<string, unknown>} | null},
): Promise<void> {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "You must be signed in to perform this action.");
    }

    const callerUid = request.auth.uid;
    const callerDoc = await db.collection("users").doc(callerUid).get();

    if (callerDoc.exists && (callerDoc.data()?.active === false || callerDoc.data()?.isActive === false)) {
        throw new HttpsError("permission-denied", "Your account has been deactivated. Contact your administrator.");
    }

    const tokenRole = request.auth.token.role as string | undefined;
    if (tokenRole === "admin") return;

    if (callerDoc.exists) {
        const docRole = callerDoc.data()?.role as string | undefined;
        if (docRole === "admin") {
            await auth.setCustomUserClaims(callerUid, {role: "admin"});
            return;
        }
    }

    throw new HttpsError("permission-denied", "Only administrators can perform this action.");
}

// ─────────────────────────────────────────────────────────────────────────────
// updateCommitteeMember — Admin updates a committee member's profile
// Accepts: { uid, fullName?, phone?, expertiseTag?, active? }
// At least one optional field must be provided.
// ─────────────────────────────────────────────────────────────────────────────
export const updateCommitteeMember = onCall(
    {region: "us-central1", cors: true, invoker: "public", enforceAppCheck: false},
    async (request) => {
        await requireAdmin(request);

        const {uid, fullName, phone, expertiseTag, active} = request.data as {
            uid: string;
            fullName?: string;
            phone?: string;
            expertiseTag?: string;
            active?: boolean;
        };

        if (!uid) {
            throw new HttpsError("invalid-argument", "uid is required.");
        }

        // Validate that at least one field is being updated
        const hasUpdate =
            fullName !== undefined ||
            phone !== undefined ||
            expertiseTag !== undefined ||
            active !== undefined;

        if (!hasUpdate) {
            throw new HttpsError(
                "invalid-argument",
                "At least one field (fullName, phone, expertiseTag, active) must be provided.",
            );
        }

        // Verify target is actually a committee member
        const targetDoc = await db.collection("users").doc(uid).get();
        if (!targetDoc.exists) {
            throw new HttpsError("not-found", "Committee member not found.");
        }
        if (targetDoc.data()?.role !== "committee") {
            throw new HttpsError("failed-precondition", "Target user is not a committee member.");
        }

        // Validate phone format if provided
        if (phone !== undefined) {
            const phoneDigits = phone.replace(/[^0-9]/g, "");
            if (phoneDigits.length < 10 || phoneDigits.length > 15) {
                throw new HttpsError("invalid-argument", "Please provide a valid 10-digit phone number.");
            }
        }

        // Validate fullName if provided
        if (fullName !== undefined && fullName.trim().length === 0) {
            throw new HttpsError("invalid-argument", "Full name cannot be empty.");
        }

        // Build Firestore update map
        const updates: Record<string, unknown> = {
            updatedAt: FieldValue.serverTimestamp(),
        };
        if (fullName !== undefined) updates["fullName"] = fullName.trim();
        if (phone !== undefined) updates["phone"] = phone.trim();
        if (expertiseTag !== undefined) updates["expertiseTag"] = expertiseTag.trim();
        if (active !== undefined) updates["active"] = active;

        await db.collection("users").doc(uid).update(updates);

        // If fullName changed, sync it to Firebase Auth displayName
        if (fullName !== undefined) {
            try {
                await auth.updateUser(uid, {displayName: fullName.trim()});
            } catch {
                // Non-blocking — Firestore is the source of truth for displayName in this app
            }
        }

        return {success: true};
    },
);
