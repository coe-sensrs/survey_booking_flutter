import {onCall, HttpsError} from "firebase-functions/v2/https";
import {db, auth, FieldValue, Timestamp} from "../../lib/admin";
import {sendAppointmentNotification} from "../notifications/send_push_notification";
import {NotificationType} from "../notifications/notification_types";

interface XenDetailsData {
    name: string;
    mobile: string;
    email: string;
}

interface LogisticsData {
    coordinatorName: string;
    coordinatorDesignation: string;
    driverName: string;
    driverMobile: string;
    vehicleNumber: string;
    vehicleModel: string;
}

interface KmlFileData {
    storagePath: string;
    originalFileName: string;
    fileType: string;
    sizeBytes: number;
    uploadedAt: string;
}

interface PermissionDocData {
    storagePath: string;
    originalFileName: string;
    fileType: string;
    sizeBytes: number;
    uploadedAt: string;
}

interface SubmitAppointmentData {
    appointmentId?: string;
    applicantName: string;
    applicantOrgName?: string | null;
    applicantEmail: string;
    surveyType: string;
    customSurveyName?: string | null;
    state: string;
    district: string;
    xenDetails: XenDetailsData;
    areaName: string;
    kmlFile: KmlFileData;
    preferredDate: string; // ISO-8601
    logistics: LogisticsData;
    permissionDocuments: PermissionDocData[];
}

/**
 * Server-mediated appointment submission.
 *
 * Security guarantees (vs. direct client Firestore write):
 *  1. Role enforced: only applicants with verified email can call.
 *  2. status is hard-coded server-side to 'pending_assignment' — no client tampering.
 *  3. applicantId is sourced from the verified JWT, not the client payload.
 *  4. The 3-unresolved-appointment quota is checked AND incremented inside a
 *     single atomic Firestore transaction, preventing race-condition bypasses.
 *  5. Initial audit log entry is written within the same transaction.
 */
export const submitAppointment = onCall(
    {
        region: "us-central1",
        cors: true,
        invoker: "public",
        enforceAppCheck: false,
    },
    async (request) => {
        // ── 1. Auth guards ────────────────────────────────────────────────────
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "You must be signed in to submit a booking.");
        }

        const uid = request.auth.uid;
        let role = request.auth.token.role as string | undefined;
        let emailVerified = request.auth.token.email_verified as boolean | undefined;

        if (!role) {
            const userDoc = await db.collection("users").doc(uid).get();
            if (userDoc.exists) {
                role = userDoc.data()?.role as string | undefined;
                if (role) {
                    try {
                        await auth.setCustomUserClaims(uid, {role});
                    } catch {/* ignore claims sync errors */}
                }
            }
        }

        if (role !== "applicant") {
            throw new HttpsError(
                "permission-denied",
                "Only applicants can submit survey booking requests.",
            );
        }

        if (emailVerified === undefined) {
            const isVerifiedClaim = request.auth.token.is_verified as boolean | undefined;
            if (isVerifiedClaim !== undefined) {
                emailVerified = isVerifiedClaim;
            } else {
                try {
                    const authUser = await auth.getUser(uid);
                    emailVerified = authUser.emailVerified;
                } catch {/* ignore */}
            }
        }

        if (!emailVerified) {
            throw new HttpsError(
                "failed-precondition",
                "Please verify your email address before submitting a booking.",
            );
        }

        // ── 2. Payload validation ─────────────────────────────────────────────
        const data = request.data as SubmitAppointmentData;

        if (!data?.surveyType || typeof data.surveyType !== "string") {
            throw new HttpsError("invalid-argument", "surveyType is required.");
        }
        if (!data?.state || !data?.district || !data?.areaName) {
            throw new HttpsError("invalid-argument", "state, district, and areaName are required.");
        }
        if (!data?.xenDetails?.name || !data?.xenDetails?.mobile || !data?.xenDetails?.email) {
            throw new HttpsError("invalid-argument", "XEN details (name, mobile, email) are required.");
        }
        if (!data?.kmlFile?.storagePath) {
            throw new HttpsError("invalid-argument", "KML/KMZ spatial file reference is required.");
        }
        if (!data?.preferredDate) {
            throw new HttpsError("invalid-argument", "preferredDate is required.");
        }
        if (!data?.logistics?.coordinatorName) {
            throw new HttpsError("invalid-argument", "Logistics details are required.");
        }

        // ── 3. Atomic submission transaction ──────────────────────────────────
        const rateLimitRef = db.collection("rateLimits").doc(uid);
        const appointmentRef = (data.appointmentId &&
            typeof data.appointmentId === "string" &&
            data.appointmentId.trim().length > 0) ?
            db.collection("appointments").doc(data.appointmentId.trim()) :
            db.collection("appointments").doc();
        const now = FieldValue.serverTimestamp();

        await db.runTransaction(async (txn) => {
            const rateLimitSnap = await txn.get(rateLimitRef);
            const pendingCount = rateLimitSnap.exists ?
                ((rateLimitSnap.data()?.pendingCount as number) ?? 0) :
                0;

            if (pendingCount >= 3) {
                throw new HttpsError(
                    "resource-exhausted",
                    "You have reached the maximum of 3 unresolved survey requests. " +
                    "Please wait for an existing request to be resolved before submitting a new one.",
                );
            }

            // Write appointment with server-enforced fields
            txn.set(appointmentRef, {
                applicantId: uid,
                applicantName: data.applicantName ?? "",
                applicantOrgName: data.applicantOrgName ?? null,
                applicantEmail: data.applicantEmail ?? "",
                surveyType: data.surveyType,
                customSurveyName: data.customSurveyName ?? null,
                state: data.state,
                district: data.district,
                xenDetails: data.xenDetails,
                areaName: data.areaName,
                kmlFile: {
                    ...data.kmlFile,
                    uploadedAt: data.kmlFile.uploadedAt ? Timestamp.fromDate(new Date(data.kmlFile.uploadedAt)) : now,
                },
                preferredDate: Timestamp.fromDate(new Date(data.preferredDate)),
                confirmedDate: null,
                logistics: data.logistics,
                permissionDocuments: (data.permissionDocuments ?? []).map((doc) => ({
                    ...doc,
                    uploadedAt: doc.uploadedAt ? Timestamp.fromDate(new Date(doc.uploadedAt)) : now,
                })),
                // Server-enforced: clients cannot set these on creation
                status: "pending_assignment",
                assignedReviewerId: null,
                assignedReviewerName: null,
                assignedTaskMemberId: null,
                assignedTaskMemberName: null,
                rejectionReason: null,
                clarificationNote: null,
                clarificationReply: null,
                createdAt: now,
                updatedAt: now,
            });

            // Increment rate limit counter atomically
            txn.set(
                rateLimitRef,
                {pendingCount: pendingCount + 1, lastBookingAt: now},
                {merge: true},
            );

            // Initial audit log entry within the same transaction
            const auditRef = appointmentRef.collection("auditLog").doc();
            txn.set(auditRef, {
                action: "submitted",
                performedBy: uid,
                performedByRole: "applicant",
                applicantId: uid,
                timestamp: now,
                note: "Application submitted by applicant.",
            });
        });

        // ── 4. Notify admins (fire-and-forget — must not block or throw) ────
        await sendAppointmentNotification(
            NotificationType.BOOKING_CREATED,
            {}, // booking_created recipients are resolved via admin role query
            appointmentRef.id,
        );

        return {appointmentId: appointmentRef.id};
    },
);
