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
                    storage: UserDefaultsLocalStorage(),
                    emitLocalSessionAsInitialSession: true
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
            .upsert(Row(id: userId, username: username, role: "user"))
            .execute()
    }

    // MARK: - Tags

    /// Returns a map of game UUID → tag name array.
    func fetchGameTags() async throws -> [UUID: [String]] {
        let response = try await client
            .from("game_tags")
            .select("game_id, tags(tag_name)")
            .execute()

        struct TagRow: Decodable { let tagName: String }
        struct Row: Decodable {
            let gameId: UUID
            let tags: TagRow
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let rows = try decoder.decode([Row].self, from: response.data)

        return Dictionary(grouping: rows, by: { $0.gameId })
            .mapValues { $0.map { $0.tags.tagName } }
    }

    // MARK: - Wishlist

    func fetchWishlistGameIds(userId: UUID) async throws -> [UUID] {
        let response = try await client
            .from("wishlists")
            .select("game_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
        struct Row: Decodable { let gameId: UUID }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Row].self, from: response.data).map { $0.gameId }
    }

    func addToWishlist(userId: UUID, gameId: UUID) async throws {
        struct Row: Encodable {
            let userId: UUID; let gameId: UUID
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"; case gameId = "game_id"
            }
        }
        try await client.from("wishlists").insert(Row(userId: userId, gameId: gameId)).execute()
    }

    func removeFromWishlist(userId: UUID, gameId: UUID) async throws {
        try await client
            .from("wishlists")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("game_id", value: gameId.uuidString)
            .execute()
    }

    // MARK: - Friends

    func fetchFriends(userId: UUID) async throws -> [Friend] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Rows where I sent the request
        struct Row1: Decodable { let friendshipId: Int; let userId2: UUID; let status: String }
        let r1 = try await client.from("friends")
            .select("friendship_id, user_id2, status")
            .eq("user_id1", value: userId.uuidString)
            .neq("status", value: "Blocked")
            .execute()
        let sent = try decoder.decode([Row1].self, from: r1.data)

        // Rows where I received the request
        struct Row2: Decodable { let friendshipId: Int; let userId1: UUID; let status: String }
        let r2 = try await client.from("friends")
            .select("friendship_id, user_id1, status")
            .eq("user_id2", value: userId.uuidString)
            .neq("status", value: "Blocked")
            .execute()
        let received = try decoder.decode([Row2].self, from: r2.data)

        // Build map: otherUserId → (friendshipId, status, isSentByMe)
        var map: [UUID: (id: Int, status: String, sentByMe: Bool)] = [:]
        for r in sent     { map[r.userId2] = (r.friendshipId, r.status, true)  }
        for r in received { map[r.userId1] = (r.friendshipId, r.status, false) }
        guard !map.isEmpty else { return [] }

        // Fetch usernames for all other users
        let uuids = map.keys.map { $0.uuidString }
        struct ProfileRow: Decodable { let id: UUID; let username: String }
        let rp = try await client.from("profiles")
            .select("id, username")
            .in("id", values: uuids)
            .execute()
        let profiles = try decoder.decode([ProfileRow].self, from: rp.data)
        let names = Dictionary(profiles.map { ($0.id, $0.username) }, uniquingKeysWith: { a, _ in a })

        return map.compactMap { (uuid, info) -> Friend? in
            guard let username = names[uuid] else { return nil }
            return Friend(id: info.id, userId: uuid, username: username,
                          status: info.status, isSentByMe: info.sentByMe)
        }
    }

    func sendFriendRequest(fromUserId: UUID, toUserId: UUID) async throws {
        struct Row: Encodable {
            let userId1: UUID; let userId2: UUID; let status: String
            enum CodingKeys: String, CodingKey {
                case userId1 = "user_id1"; case userId2 = "user_id2"; case status
            }
        }
        try await client.from("friends")
            .insert(Row(userId1: fromUserId, userId2: toUserId, status: "Pending"))
            .execute()
    }

    func respondToFriendRequest(friendshipId: Int, accept: Bool) async throws {
        if accept {
            try await client.from("friends")
                .update(["status": "Accepted"])
                .eq("friendship_id", value: friendshipId)
                .execute()
        } else {
            try await client.from("friends")
                .delete()
                .eq("friendship_id", value: friendshipId)
                .execute()
        }
    }

    func removeFriend(friendshipId: Int) async throws {
        try await client.from("friends").delete().eq("friendship_id", value: friendshipId).execute()
    }

    func searchProfile(username: String) async throws -> (id: UUID, username: String)? {
        let response = try await client
            .from("profiles")
            .select("id, username")
            .ilike("username", pattern: "%\(username)%")
            .limit(1)
            .execute()
        struct Row: Decodable { let id: UUID; let username: String }
        let rows = try JSONDecoder().decode([Row].self, from: response.data)
        return rows.first.map { ($0.id, $0.username) }
    }

    func fetchPendingFriendsCount(userId: UUID) async throws -> Int {
        let response = try await client
            .from("friends")
            .select("friendship_id")
            .eq("user_id2", value: userId.uuidString)
            .eq("status", value: "Pending")
            .execute()
        struct Row: Decodable { let friendshipId: Int }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Row].self, from: response.data).count
    }

    // MARK: - System requirements

    func fetchSystemRequirements(gameId: UUID) async throws -> SystemRequirements? {
        let response = try await client
            .from("system_requirements")
            .select("min_os, min_cpu, min_ram_gb, min_gpu, min_storage_gb, rec_os, rec_cpu, rec_ram_gb, rec_gpu, rec_storage_gb")
            .eq("game_id", value: gameId.uuidString)
            .limit(1)
            .execute()

        struct Row: Decodable {
            let minOs: String?
            let minCpu: String?
            let minRamGb: Int?
            let minGpu: String?
            let minStorageGb: Int?
            let recOs: String?
            let recCpu: String?
            let recRamGb: Int?
            let recGpu: String?
            let recStorageGb: Int?
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let rows = try decoder.decode([Row].self, from: response.data)
        guard let row = rows.first else { return nil }

        return SystemRequirements(
            minOS: row.minOs, minCPU: row.minCpu, minRAMGB: row.minRamGb,
            minGPU: row.minGpu, minStorageGB: row.minStorageGb,
            recOS: row.recOs, recCPU: row.recCpu, recRAMGB: row.recRamGb,
            recGPU: row.recGpu, recStorageGB: row.recStorageGb
        )
    }

    // MARK: - Reviews

    func fetchReviews(gameId: UUID) async throws -> [Review] {
        let response = try await client
            .from("reviews")
            .select("review_id, user_id, rating, comment, created_at, profiles(username)")
            .eq("game_id", value: gameId.uuidString)
            .order("created_at", ascending: false)
            .execute()

        struct ProfileRow: Decodable { let username: String }
        struct Row: Decodable {
            let reviewId: Int
            let userId: UUID
            let rating: Int
            let comment: String?
            let createdAt: Date
            let profiles: ProfileRow
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmt.date(from: str) { return d }
            fmt.formatOptions = [.withInternetDateTime]
            if let d = fmt.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Cannot parse date: \(str)"
            )
        }

        let rows = try decoder.decode([Row].self, from: response.data)
        return rows.map {
            Review(id: $0.reviewId, userId: $0.userId, username: $0.profiles.username,
                   rating: $0.rating, comment: $0.comment, createdAt: $0.createdAt)
        }
    }

    /// Replaces the user's existing review for a game (delete + insert).
    func submitReview(userId: UUID, gameId: UUID, rating: Int, comment: String?) async throws {
        // Remove any previous review by this user for this game
        try await client
            .from("reviews")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("game_id", value: gameId.uuidString)
            .execute()

        struct Row: Encodable {
            let userId: UUID
            let gameId: UUID
            let rating: Int
            let comment: String?
            enum CodingKeys: String, CodingKey {
                case userId  = "user_id"
                case gameId  = "game_id"
                case rating, comment
            }
        }
        try await client
            .from("reviews")
            .insert(Row(userId: userId, gameId: gameId, rating: rating, comment: comment))
            .execute()
    }

    func deleteReview(userId: UUID, gameId: UUID) async throws {
        try await client
            .from("reviews")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("game_id", value: gameId.uuidString)
            .execute()
    }

    // MARK: - Discounts

    struct DiscountRow: Decodable {
        let gameId: UUID
        let discountPercent: Double
    }

    /// Returns active discounts as a map of game UUID → discount percentage.
    func fetchActiveDiscounts() async throws -> [UUID: Double] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        let response = try await client
            .from("discounts")
            .select("game_id, discount_percent")
            .lte("start_date", value: today)
            .gte("end_date", value: today)
            .execute()

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let rows = try decoder.decode([DiscountRow].self, from: response.data)
        return Dictionary(rows.map { ($0.gameId, $0.discountPercent) },
                          uniquingKeysWith: { a, _ in a })
    }

    // MARK: - Orders

    /// Creates an order + detail rows for the given games. Returns the new order_id.
    @discardableResult
    func createOrder(userId: UUID, games: [Game]) async throws -> Int {
        let total = games.reduce(0.0) { $0 + $1.effectivePrice }

        // 1. Insert order row
        struct OrderRow: Encodable {
            let userId: UUID
            let totalAmount: Double
            let paymentMethod: String
            let status: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case totalAmount = "total_amount"
                case paymentMethod = "payment_method"
                case status
            }
        }
        let orderResponse = try await client
            .from("orders")
            .insert(OrderRow(userId: userId, totalAmount: total,
                             paymentMethod: "WalletBalance", status: "Completed"))
            .select("order_id")
            .single()
            .execute()

        struct OrderIDRow: Decodable { let orderId: Int }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let orderId = try decoder.decode(OrderIDRow.self, from: orderResponse.data).orderId

        // 2. Insert detail rows
        struct DetailRow: Encodable {
            let orderId: Int
            let gameId: UUID
            let quantity: Int
            let unitPrice: Double
            let discountApplied: Double
            enum CodingKeys: String, CodingKey {
                case orderId = "order_id"
                case gameId = "game_id"
                case quantity
                case unitPrice = "unit_price"
                case discountApplied = "discount_applied"
            }
        }
        let details = games.map {
            DetailRow(orderId: orderId, gameId: $0.id, quantity: 1,
                      unitPrice: $0.originalPriceValue,
                      discountApplied: $0.discountPercent ?? 0)
        }
        try await client.from("order_details").insert(details).execute()
        return orderId
    }

    func fetchOrders(userId: UUID) async throws -> [Order] {
        let response = try await client
            .from("orders")
            .select("order_id, order_date, total_amount, payment_method, status, order_details(order_detail_id, game_id, unit_price, discount_applied, subtotal, games(title, genre))")
            .eq("user_id", value: userId.uuidString)
            .order("order_date", ascending: false)
            .execute()

        struct GameRow: Decodable { let title: String; let genre: String }
        struct DetailRow: Decodable {
            let orderDetailId: Int
            let gameId: UUID
            let unitPrice: Double
            let discountApplied: Double
            let subtotal: Double?
            let games: GameRow
        }
        struct OrderRow: Decodable {
            let orderId: Int
            let orderDate: Date
            let totalAmount: Double
            let paymentMethod: String?
            let status: String
            let orderDetails: [DetailRow]
        }

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        dec.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmt.date(from: str) { return d }
            fmt.formatOptions = [.withInternetDateTime]
            if let d = fmt.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Cannot parse date: \(str)"
            )
        }

        let rows = try dec.decode([OrderRow].self, from: response.data)
        return rows.map { row in
            Order(
                id: row.orderId,
                orderDate: row.orderDate,
                totalAmount: row.totalAmount,
                paymentMethod: row.paymentMethod,
                status: row.status,
                items: row.orderDetails.map { d in
                    OrderItem(id: d.orderDetailId, gameId: d.gameId,
                              gameTitle: d.games.title, gameGenre: d.games.genre,
                              unitPrice: d.unitPrice, discountApplied: d.discountApplied,
                              subtotal: d.subtotal ?? d.unitPrice)
                }
            )
        }
    }

    // MARK: - Cart persistence

    func fetchCartGameIds(userId: UUID) async throws -> [UUID] {
        let response = try await client
            .from("cart_items")
            .select("game_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
        struct Row: Decodable { let gameId: UUID }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Row].self, from: response.data).map { $0.gameId }
    }

    func addCartItem(userId: UUID, gameId: UUID) async throws {
        struct Row: Encodable {
            let userId: UUID; let gameId: UUID
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"; case gameId = "game_id"
            }
        }
        try await client.from("cart_items").insert(Row(userId: userId, gameId: gameId)).execute()
    }

    func removeCartItem(userId: UUID, gameId: UUID) async throws {
        try await client
            .from("cart_items")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("game_id", value: gameId.uuidString)
            .execute()
    }

    // MARK: - Wallet

    func fetchWalletBalance(userId: UUID) async throws -> Double {
        let response = try await client
            .from("wallets")
            .select("balance")
            .eq("user_id", value: userId.uuidString)
            .execute()
        struct Row: Decodable { let balance: Double }
        let rows = try JSONDecoder().decode([Row].self, from: response.data)
        return rows.first?.balance ?? 0
    }

    func topUpWallet(userId: UUID, amount: Double) async throws -> Double {
        let current = try await fetchWalletBalance(userId: userId)
        let newBalance = current + amount
        struct Row: Encodable { let balance: Double }
        try await client
            .from("wallets")
            .update(Row(balance: newBalance))
            .eq("user_id", value: userId.uuidString)
            .execute()
        return newBalance
    }

    func deductFromWallet(userId: UUID, amount: Double) async throws -> Double {
        let current = try await fetchWalletBalance(userId: userId)
        guard current >= amount else {
            throw NSError(domain: "Wallet", code: 402,
                          userInfo: [NSLocalizedDescriptionKey: "Insufficient balance"])
        }
        let newBalance = current - amount
        struct Row: Encodable { let balance: Double }
        try await client
            .from("wallets")
            .update(Row(balance: newBalance))
            .eq("user_id", value: userId.uuidString)
            .execute()
        return newBalance
    }

    func clearCart(userId: UUID) async throws {
        try await client
            .from("cart_items")
            .delete()
            .eq("user_id", value: userId.uuidString)
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
