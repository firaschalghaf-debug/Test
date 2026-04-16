import SwiftUI
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Session state (set only after successful auth)
    @Published var sessionEmail: String = ""
    @Published var username:     String = ""
    @Published var userId:       UUID?  = nil
    @Published var role:         String = "user"

    // MARK: - UI state
    @Published var isLoading    = false
    @Published var errorMessage = ""

    // MARK: - Derived

    var displayName: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let prefix = sessionEmail.split(separator: "@").first { return String(prefix) }
        return "Player"
    }

    /// True only after a successful Supabase sign-in.
    var isSignedIn: Bool {
        !sessionEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isGuest: Bool { !isSignedIn }
    var isAdmin: Bool { role == "admin" }

    // MARK: - Session restore

    func restoreSession() async {
        guard SupabaseManager.shared.currentUserUUID != nil else { return }
        await fetchProfile()
    }

    // MARK: - Auth actions

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        do {
            try await SupabaseManager.shared.signIn(email: email, password: password)
            await fetchProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String, username: String) async {
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        do {
            try await SupabaseManager.shared.signUp(email: email, password: password)
            let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                _ = try? await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(data: ["display_name": .string(name)])
                )
            }
            if let uuid = SupabaseManager.shared.currentUserUUID {
                await SupabaseManager.shared.createProfileIfNeeded(userId: uuid, username: name)
            }
            await fetchProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        try? await SupabaseManager.shared.signOut()
        sessionEmail = ""
        username     = ""
        userId       = nil
        role         = "user"
        errorMessage = ""
    }

    // MARK: - Private

    private func fetchProfile() async {
        guard let uuid = SupabaseManager.shared.currentUserUUID else { return }
        userId = uuid

        if let userEmail = SupabaseManager.shared.client.auth.currentUser?.email {
            sessionEmail = userEmail
        }

        do {
            let profile = try await SupabaseManager.shared.fetchProfile(userId: uuid)
            role = profile.role
            if !profile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                username = profile.username
            }
        } catch {
            role = "user"
        }
    }
}
