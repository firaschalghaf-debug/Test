import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        guard let url = URL(string: AppConfig.supabaseURL) else {
            fatalError("Invalid Supabase URL: \(AppConfig.supabaseURL)")
        }
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: AppConfig.supabaseKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    storage: UserDefaultsLocalStorage()
                )
            )
        )
    }

    // MARK: - Auth

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    var currentUserID: String? {
        client.auth.currentUser?.id.uuidString
    }

    var currentUserUUID: UUID? {
        client.auth.currentUser?.id
    }

    // MARK: - Profile

    struct ProfileRow: Decodable {
        let username: String
        let role: String
    }

    /// Fetches username + role for the given user. Throws if no row found.
    func fetchProfile(userId: UUID) async throws -> ProfileRow {
        let response = try await client
            .from("profiles")
            .select("username, role")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
        return try JSONDecoder().decode(ProfileRow.self, from: response.data)
    }

    /// Inserts a profile row. Safe to call on sign-up as a belt-and-suspenders
    /// alongside the database trigger.
    func createProfileIfNeeded(userId: UUID, username: String) async {
        struct Row: Encodable {
            let id: UUID
            let username: String
            let role: String
        }
        _ = try? await client
            .from("profiles")
            .insert(Row(id: userId, username: username, role: "user"))
            .execute()
    }

    // MARK: - User library

    /// Returns the game UUIDs owned by this user.
    func fetchLibraryGameIds(userId: UUID) async throws -> [UUID] {
        let response = try await client
            .from("user_library")
            .select("game_id")
            .eq("user_id", value: userId.uuidString)
            .execute()

        struct Row: Decodable { let gameId: UUID }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Row].self, from: response.data).map { $0.gameId }
    }

    /// Bulk-inserts game IDs into this user's library.
    func addGamesToLibrary(userId: UUID, gameIds: [UUID]) async throws {
        guard !gameIds.isEmpty else { return }
        struct Row: Encodable {
            let userId: UUID
            let gameId: UUID
            // Use explicit keys so Encodable maps to snake_case column names
            enum CodingKeys: String, CodingKey {
                case userId  = "user_id"
                case gameId  = "game_id"
            }
        }
        let rows = gameIds.map { Row(userId: userId, gameId: $0) }
        try await client.from("user_library").insert(rows).execute()
    }
}

// MARK: - UserDefaults session storage (no keychain = no macOS password prompts)

final class UserDefaultsLocalStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws {
        UserDefaults.standard.set(value, forKey: key)
    }

    func retrieve(key: String) throws -> Data? {
        UserDefaults.standard.data(forKey: key)
    }

    func remove(key: String) throws {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
