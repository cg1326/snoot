import Foundation
import Supabase
import AuthenticationServices
import CryptoKit
import Observation

@Observable
final class AuthService: NSObject {

    // MARK: - State
    var currentUser: SupabaseUser?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = false
    var errorMessage: String?

    // MARK: - Private
    private var client: SupabaseClient { SupabaseService.shared.client }
    private var nonceCleartext = ""

    // MARK: - Init
    override init() {
        super.init()
        Task { await restoreSession() }
    }

    // MARK: - Session restore
    @MainActor
    func restoreSession() async {
        do {
            let session = try await client.auth.session
            await fetchOrCreateUserProfile(id: session.user.id.uuidString, email: session.user.email ?? "")
        } catch {
            currentUser = nil
        }
    }

    // MARK: - Sign up
    @MainActor
    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(displayName)]
            )
            await fetchOrCreateUserProfile(id: response.user.id.uuidString, email: email, displayName: displayName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign in
    @MainActor
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            await fetchOrCreateUserProfile(id: session.user.id.uuidString, email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Apple Sign In
    func handleAppleSignIn(authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleIDCredential.identityToken,
              let token = String(data: tokenData, encoding: .utf8)
        else { return }

        // Apple provides the full name only on the very first authorization.
        let displayName: String? = {
            let name = appleIDCredential.fullName
            let parts = [name?.givenName, name?.familyName].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }()

        await MainActor.run { isLoading = true }

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: token,
                    nonce: nonceCleartext
                )
            )
            await fetchOrCreateUserProfile(id: session.user.id.uuidString, email: session.user.email ?? "", displayName: displayName)
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }

        await MainActor.run { isLoading = false }
    }

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        nonceCleartext = nonce
        return sha256(nonce)
    }

    // MARK: - Sign out
    @MainActor
    func signOut() async {
        try? await client.auth.signOut()
        currentUser = nil
    }

    // MARK: - Update display name
    @MainActor
    func updateDisplayName(_ name: String) async {
        guard let uid = currentUser?.id else { return }
        do {
            struct Update: Encodable { let displayName: String; enum CodingKeys: String, CodingKey { case displayName = "display_name" } }
            try await SupabaseService.shared.client
                .from("users")
                .update(Update(displayName: name))
                .eq("id", value: uid)
                .execute()
            currentUser?.displayName = name
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Device token
    func saveDeviceToken(_ token: String) async {
        guard let uid = currentUser?.id else {
            // Not signed in yet — cache and save on next sign-in
            UserDefaults.standard.set(token, forKey: "pendingDeviceToken")
            return
        }
        await persistDeviceToken(token, userId: uid)
    }

    private func persistDeviceToken(_ token: String, userId: String) async {
        struct Update: Encodable {
            let deviceToken: String
            enum CodingKeys: String, CodingKey { case deviceToken = "device_token" }
        }
        try? await SupabaseService.shared.client
            .from("users")
            .update(Update(deviceToken: token))
            .eq("id", value: userId)
            .execute()
        UserDefaults.standard.removeObject(forKey: "pendingDeviceToken")
    }

    // MARK: - Change password
    @MainActor
    func updatePassword(_ newPassword: String) async {
        do {
            try await client.auth.update(user: UserAttributes(password: newPassword))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete account
    @MainActor
    func deleteAccount() async {
        // Delete all user-owned data before signing out. The auth.users record
        // is deleted server-side via a Postgres trigger (on_user_deleted) that
        // cascades when the users row is removed. The client cannot call
        // auth.admin.deleteUser() directly — that requires the service-role key.
        if let userId = currentUser?.id {
            let client = SupabaseService.shared.client
            // Remove this user's membership rows on other people's dogs.
            try? await client.from("dog_owners").delete().eq("user_id", value: userId).execute()
            // Remove any pending invitations addressed to this user's email.
            if let email = currentUser?.email {
                try? await client.from("dog_owners").delete().eq("invited_email", value: email).execute()
            }
            // Cascade-delete all dogs (and their care profiles / medications via FK cascade).
            try? await client.from("dogs").delete().eq("owner_id", value: userId).execute()
            // Delete the public users row; the DB trigger fires auth.admin.deleteUser().
            try? await client.from("users").delete().eq("id", value: userId).execute()
        }
        await signOut()
    }

    // MARK: - Helpers
    @MainActor
    private func fetchOrCreateUserProfile(id: String, email: String, displayName: String? = nil) async {
        // Try to fetch existing row
        if let user = try? await SupabaseService.shared.client
            .from("users")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value as SupabaseUser {
            currentUser = user
            if let pending = UserDefaults.standard.string(forKey: "pendingDeviceToken") {
                await persistDeviceToken(pending, userId: id)
            }
            return
        }

        // Row not found — the DB trigger may not have fired. Upsert it now.
        struct UserUpsert: Encodable {
            let id: String
            let email: String
            let displayName: String?
            enum CodingKeys: String, CodingKey {
                case id, email
                case displayName = "display_name"
            }
        }
        do {
            let user: SupabaseUser = try await SupabaseService.shared.client
                .from("users")
                .upsert(UserUpsert(id: id, email: email, displayName: displayName), onConflict: "id")
                .select()
                .single()
                .execute()
                .value
            currentUser = user
        } catch {
            errorMessage = "Signed in but couldn't load profile: \(error.localizedDescription)"
            currentUser = nil
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var rnd: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &rnd)
                return rnd
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
