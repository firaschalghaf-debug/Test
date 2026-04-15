import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let rawURL = "https://jlzykysgiuumtdcqggzg.supabase.co"
        let key = "sb_publishable_of-tbPuORPtSx2_ro5_8Zg_wPirqGPv"

        
        let urlString = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard var components = URLComponents(string: urlString) else {
            fatalError("❌ Invalid Supabase URL string: \(urlString)")
        }

        if components.scheme == nil {
            components.scheme = "https"
        }

        guard let url = components.url,
              let scheme = url.scheme,
              let host = url.host,
              !scheme.isEmpty,
              !host.isEmpty else {
            fatalError("❌ Supabase URL is missing scheme or host: \(urlString)")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
    }

    // MARK: - Auth

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password
        )
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(
            email: email,
            password: password
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    var currentUserID: String? {
        client.auth.currentUser?.id.uuidString
    }
}
