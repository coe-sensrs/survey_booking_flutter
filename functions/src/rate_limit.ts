/**
 * Server-side rate limiting for authentication operations.
 *
 * State is stored in the Firestore `/auth_rate_limits/` collection, which is
 * locked to Admin SDK writes only — no client can read or write these records.
 *
 * Two strategies are implemented:
 *  - Login (failure-based): counts consecutive failures; resets on success.
 *  - Request (count-based): counts all calls within a window; blocks after limit.
 */

import * as crypto from "crypto";
import * as admin from "firebase-admin";

// ============================================================
// Types
// ============================================================

export interface RateLimitResult {
  blocked: boolean;
  secondsRemaining: number;
}

// ============================================================
// Policies
// ============================================================

interface LoginPolicy {
  /** Maximum consecutive failures allowed within the window before lockout. */
  maxFailures: number;
  /** Duration of the sliding failure-tracking window (ms). */
  windowMs: number;
  /** Duration of the first lockout after hitting maxFailures (ms). */
  lockoutMs: number;
  /** Duration of lockout for repeat offenders (ms). */
  repeatLockoutMs: number;
}

interface RequestPolicy {
  /** Maximum total requests allowed in the window. */
  maxRequests: number;
  /** Window duration (ms). */
  windowMs: number;
  /** Block duration after exceeding maxRequests (ms). */
  blockMs: number;
}

const LOGIN_POLICIES: Record<string, LoginPolicy> = {
    // Standard user accounts: 5 failures -> 15-min lock -> 30-min on repeat.
    login_applicant: {
        maxFailures: 5,
        windowMs: 15 * 60 * 1000,
        lockoutMs: 15 * 60 * 1000,
        repeatLockoutMs: 30 * 60 * 1000,
    },
    // Admin accounts (higher value): 3 failures -> 30-min lock -> 60-min on repeat.
    login_admin: {
        maxFailures: 3,
        windowMs: 15 * 60 * 1000,
        lockoutMs: 30 * 60 * 1000,
        repeatLockoutMs: 60 * 60 * 1000,
    },
};

const REQUEST_POLICIES: Record<string, RequestPolicy> = {
    // Max 3 signup attempts per email per hour.
    signup: {
        maxRequests: 3,
        windowMs: 60 * 60 * 1000,
        blockMs: 60 * 60 * 1000,
    },
    // Max 3 password reset requests per email per hour.
    password_reset: {
        maxRequests: 3,
        windowMs: 60 * 60 * 1000,
        blockMs: 60 * 60 * 1000,
    },
};

// ============================================================
// Helpers
// ============================================================

/** Returns a SHA-256 hex hash of the normalized identifier to avoid storing
 * plaintext PII as Firestore document IDs. */
export function hashIdentifier(identifier: string): string {
    return crypto
        .createHash("sha256")
        .update(identifier.toLowerCase().trim())
        .digest("hex");
}

function docId(action: string, hash: string): string {
    return `${action}_${hash}`;
}

/** Lazy Firestore accessor called at invocation time, not module-load time,
 * to avoid initialization-order issues with admin.initializeApp(). */
function firestoreDb(): FirebaseFirestore.Firestore {
    return admin.firestore();
}

// ============================================================
// Login rate limiting (failure-based)
// ============================================================

/**
 * Checks whether a login identifier is currently blocked.
 * Read-only - does not modify any Firestore state.
 */
export async function checkLoginBlocked(
    identifierHash: string,
    action: string,
): Promise<RateLimitResult> {
    const db = firestoreDb();
    const docRef = db
        .collection("auth_rate_limits")
        .doc(docId(action, identifierHash));
    const doc = await docRef.get();

    if (!doc.exists) return {blocked: false, secondsRemaining: 0};

    const data = doc.data()!;
    const nowMs = Date.now();
    const blockedUntil = data.blockedUntil as admin.firestore.Timestamp | null;

    if (blockedUntil && blockedUntil.toMillis() > nowMs) {
        return {
            blocked: true,
            secondsRemaining: Math.ceil((blockedUntil.toMillis() - nowMs) / 1000),
        };
    }

    return {blocked: false, secondsRemaining: 0};
}

/**
 * Records a failed login attempt, increments the failure counter within the
 * sliding window, and applies a lockout when the threshold is exceeded.
 *
 * @return Whether the identifier is now locked after this failure.
 */
export async function recordLoginFailure(
    identifierHash: string,
    action: string,
): Promise<RateLimitResult> {
    const policy = LOGIN_POLICIES[action];
    if (!policy) throw new Error(`Unknown login action: ${action}`);

    const db = firestoreDb();
    const docRef = db
        .collection("auth_rate_limits")
        .doc(docId(action, identifierHash));
    const now = admin.firestore.Timestamp.now();
    const nowMs = Date.now();

    let blocked = false;
    let secondsRemaining = 0;

    await db.runTransaction(async (tx) => {
        const doc = await tx.get(docRef);

        if (!doc.exists) {
            tx.set(docRef, {
                identifierHash,
                action,
                failureCount: 1,
                firstFailureAt: now,
                lastActivityAt: now,
                blockedUntil: null,
                lockoutCount: 0,
            });
            return;
        }

        const data = doc.data()!;
        const firstFailureAt = data.firstFailureAt as admin.firestore.Timestamp;
        const windowExpired =
      firstFailureAt.toMillis() + policy.windowMs < nowMs;

        if (windowExpired) {
            // Sliding window expired - reset counters, treat as first failure.
            tx.update(docRef, {
                failureCount: 1,
                firstFailureAt: now,
                lastActivityAt: now,
                blockedUntil: null,
            });
            return;
        }

        const newCount = (data.failureCount as number) + 1;

        if (newCount >= policy.maxFailures) {
            const isRepeatOffender = (data.lockoutCount as number) > 0;
            const lockoutMs = isRepeatOffender ? policy.repeatLockoutMs : policy.lockoutMs;
            const blockedUntilMs = nowMs + lockoutMs;

            blocked = true;
            secondsRemaining = Math.ceil(lockoutMs / 1000);

            tx.update(docRef, {
                failureCount: newCount,
                lastActivityAt: now,
                blockedUntil: admin.firestore.Timestamp.fromMillis(blockedUntilMs),
                lockoutCount: (data.lockoutCount as number) + 1,
            });
        } else {
            tx.update(docRef, {
                failureCount: newCount,
                lastActivityAt: now,
            });
        }
    });

    return {blocked, secondsRemaining};
}

/**
 * Resets failure counters and clears any active lockout after a successful login.
 * Non-blocking: errors are logged but do not fail the auth operation.
 */
export async function resetLoginFailures(
    identifierHash: string,
    action: string,
): Promise<void> {
    const db = firestoreDb();
    const docRef = db
        .collection("auth_rate_limits")
        .doc(docId(action, identifierHash));
    try {
        await docRef.set(
            {
                failureCount: 0,
                blockedUntil: null,
                lastActivityAt: admin.firestore.Timestamp.now(),
            },
            {merge: true},
        );
    } catch {
        console.warn(
            `[rate_limit] Non-critical: failed to reset login failures for action=${action}`,
        );
    }
}

// ============================================================
// Request rate limiting (count-based: signup & password reset)
// ============================================================

/**
 * Checks whether the identifier is currently blocked AND increments the
 * request counter atomically in a Firestore transaction.
 *
 * All requests (successful or not) count toward the limit.
 * Call this BEFORE executing the operation.
 *
 * @return Whether the request should be blocked.
 */
export async function checkAndIncrementRequests(
    identifierHash: string,
    action: string,
): Promise<RateLimitResult> {
    const policy = REQUEST_POLICIES[action];
    if (!policy) throw new Error(`Unknown request action: ${action}`);

    const db = firestoreDb();
    const docRef = db
        .collection("auth_rate_limits")
        .doc(docId(action, identifierHash));
    const now = admin.firestore.Timestamp.now();
    const nowMs = Date.now();

    let blocked = false;
    let secondsRemaining = 0;

    await db.runTransaction(async (tx) => {
        const doc = await tx.get(docRef);

        if (!doc.exists) {
            // First request - allow and start tracking.
            tx.set(docRef, {
                identifierHash,
                action,
                requestCount: 1,
                windowStart: now,
                lastActivityAt: now,
                blockedUntil: null,
            });
            return;
        }

        const data = doc.data()!;
        const blockedUntil = data.blockedUntil as admin.firestore.Timestamp | null;

        // Check active block first - do not increment when already blocked.
        if (blockedUntil && blockedUntil.toMillis() > nowMs) {
            blocked = true;
            secondsRemaining = Math.ceil((blockedUntil.toMillis() - nowMs) / 1000);
            return;
        }

        const windowStart = data.windowStart as admin.firestore.Timestamp;
        const windowExpired = windowStart.toMillis() + policy.windowMs < nowMs;

        if (windowExpired) {
            // Window expired - reset and allow this request.
            tx.update(docRef, {
                requestCount: 1,
                windowStart: now,
                lastActivityAt: now,
                blockedUntil: null,
            });
            return;
        }

        const newCount = (data.requestCount as number) + 1;

        if (newCount > policy.maxRequests) {
            const blockedUntilMs = nowMs + policy.blockMs;
            blocked = true;
            secondsRemaining = Math.ceil(policy.blockMs / 1000);

            tx.update(docRef, {
                requestCount: newCount,
                lastActivityAt: now,
                blockedUntil: admin.firestore.Timestamp.fromMillis(blockedUntilMs),
            });
        } else {
            tx.update(docRef, {
                requestCount: newCount,
                lastActivityAt: now,
            });
        }
    });

    return {blocked, secondsRemaining};
}
