/**
 * Shared helpers — Identity Toolkit REST API (Node 22 native fetch)
 */

/**
 * Verifies email/password credentials against the Firebase Identity Toolkit
 * REST API and returns the user's UID. Throws on bad credentials.
 *
 * The Admin SDK has no verifyPassword() method; the REST API is the only
 * supported server-side credential-validation path.
 */
export async function verifyEmailPassword(
    email: string,
    password: string,
    apiKey: string,
): Promise<{ localId: string }> {
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
        error?: { message?: string };
    };

    if (data.error) throw new Error(data.error.message ?? "INVALID_LOGIN_CREDENTIALS");
    if (!data.localId) throw new Error("INVALID_LOGIN_CREDENTIALS");

    return {localId: data.localId};
}

/**
 * Sends a Firebase-branded password reset email via the Identity Toolkit REST API.
 * Silently swallows EMAIL_NOT_FOUND to avoid revealing account existence.
 */
export async function sendPasswordResetEmail(email: string, apiKey: string): Promise<void> {
    const response = await fetch(
        `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${apiKey}`,
        {
            method: "POST",
            headers: {"Content-Type": "application/json"},
            body: JSON.stringify({requestType: "PASSWORD_RESET", email}),
        },
    );

    const data = (await response.json()) as { error?: { message?: string } };
    if (data.error && !(data.error.message ?? "").includes("EMAIL_NOT_FOUND")) {
        throw new Error(data.error.message ?? "Failed to send reset email");
    }
}
