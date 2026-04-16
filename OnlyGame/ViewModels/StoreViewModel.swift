import SwiftUI
import Combine
import Supabase

@MainActor
final class StoreViewModel: ObservableObject {

    // MARK: - Remote data
    @Published var dbGames: [Game] = []
    @Published var isLoadingGames = false
    @Published var gamesLoadError = ""

    // MARK: - Cart
    @Published var cartItems: [Game] = []

    // MARK: - Cloud library (Supabase user_library)
    @Published var cloudLibraryIds: Set<UUID> = []

    // MARK: - Purchase history (guests / offline fallback)
    @Published var purchasedTitlesByAccount: [String: [String]] = [:]

    // MARK: - Admin view-as
    @Published var selectedUserID = 1
    @Published var purchasedTitlesByUser: [Int: [String]] = [:]

    // MARK: - Persistence keys
    private let accountLibraryKey = "savedGamesByAccount"
    private let adminLibraryKey   = "savedGamesByUser"

    // MARK: - Static data

    let users: [UserProfile] = [
        UserProfile(id: 1, name: "Max",  favoriteGenres: ["Racing", "RPG", "Action"],           ownedGameTitles: ["Neon Drift", "Shadow Quest", "Pixel Arena"]),
        UserProfile(id: 2, name: "Alex", favoriteGenres: ["Strategy", "Simulation", "Sci-Fi"],  ownedGameTitles: ["Star Forge", "Kingdom Builder", "Galaxy Frontier"]),
        UserProfile(id: 3, name: "Mina", favoriteGenres: ["Adventure", "Survival", "Stealth"],  ownedGameTitles: ["Mystic Vale", "Ocean Runner", "Night Raid"])
    ]

    let fallbackGames: [Game] = [
        Game(title: "Neon Drift",       genre: "Racing",     price: "$19.99", color: .purple, subtitle: "Arcade racing with futuristic tracks",       imageName: "car.fill"),
        Game(title: "Shadow Quest",     genre: "RPG",        price: "$29.99", color: .blue,   subtitle: "Fantasy combat and dungeon runs",             imageName: "shield.lefthalf.filled"),
        Game(title: "Pixel Arena",      genre: "Action",     price: "$14.99", color: .pink,   subtitle: "Fast arena battles and score chasing",        imageName: "bolt.fill"),
        Game(title: "Star Forge",       genre: "Strategy",   price: "$24.99", color: .indigo, subtitle: "Build fleets and dominate galaxies",          imageName: "sparkles"),
        Game(title: "Mystic Vale",      genre: "Adventure",  price: "$17.99", color: .teal,   subtitle: "Puzzle exploration in a magical world",       imageName: "leaf.fill"),
        Game(title: "Mecha Blitz",      genre: "Shooter",    price: "$34.99", color: .orange, subtitle: "Pilot giant mechs in online battles",         imageName: "cpu.fill"),
        Game(title: "Aether Clash",     genre: "Fighting",   price: "$21.99", color: .red,    subtitle: "Arena duels with elemental powers",           imageName: "flame.fill"),
        Game(title: "Ocean Runner",     genre: "Survival",   price: "$18.99", color: .cyan,   subtitle: "Survive storms and explore deep waters",      imageName: "drop.fill"),
        Game(title: "Night Raid",       genre: "Stealth",    price: "$26.99", color: .mint,   subtitle: "Sneak through enemy zones under moonlight",   imageName: "moon.stars.fill"),
        Game(title: "Kingdom Builder",  genre: "Simulation", price: "$23.99", color: .green,  subtitle: "Grow your town into a thriving empire",       imageName: "building.2.fill"),
        Game(title: "Galaxy Frontier",  genre: "Sci-Fi",     price: "$31.99", color: .blue,   subtitle: "Chart new worlds beyond the outer rim",       imageName: "globe.americas.fill"),
        Game(title: "Turbo Street",     genre: "Arcade",     price: "$12.99", color: .yellow, subtitle: "Quick races and stylish city drifting",       imageName: "speedometer")
    ]

    var activeGames: [Game] { dbGames.isEmpty ? fallbackGames : dbGames }

    var availableGenres: [String] {
        ["All"] + Array(Set(activeGames.map { $0.genre })).sorted()
    }

    // MARK: - User context helpers

    var currentAdminUser: UserProfile {
        users.first { $0.id == selectedUserID } ?? users[0]
    }

    func accountKey(email: String, username: String) -> String {
        let key = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !key.isEmpty { return key }
        let uKey = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return uKey.isEmpty ? "guest" : uKey
    }

    func ownedTitles(isAdmin: Bool, accountKey: String) -> [String] {
        if isAdmin {
            return currentAdminUser.ownedGameTitles
                + (purchasedTitlesByUser[selectedUserID] ?? [])
        }
        // Use cloud library when available
        if !cloudLibraryIds.isEmpty {
            return activeGames.filter { cloudLibraryIds.contains($0.id) }.map { $0.title }
        }
        return purchasedTitlesByAccount[accountKey] ?? []
    }

    func libraryGames(isAdmin: Bool, accountKey: String) -> [Game] {
        if isAdmin {
            let owned = Set(ownedTitles(isAdmin: true, accountKey: accountKey))
            return activeGames.filter { owned.contains($0.title) }
        }
        // Use cloud library when available
        if !cloudLibraryIds.isEmpty {
            return activeGames.filter { cloudLibraryIds.contains($0.id) }
        }
        let owned = Set(purchasedTitlesByAccount[accountKey] ?? [])
        return activeGames.filter { owned.contains($0.title) }
    }

    // MARK: - Cloud library fetch

    func fetchUserLibrary(userId: UUID) async {
        do {
            let ids = try await SupabaseManager.shared.fetchLibraryGameIds(userId: userId)
            cloudLibraryIds = Set(ids)
        } catch {
            // Network failed — local fallback remains active
        }
    }

    func favoriteGenres(isAdmin: Bool, accountKey: String) -> [String] {
        if isAdmin { return currentAdminUser.favoriteGenres }
        let owned = purchasedTitlesByAccount[accountKey] ?? []
        let genres = activeGames.filter { owned.contains($0.title) }.map { $0.genre }
        let unique = Array(NSOrderedSet(array: genres)) as? [String] ?? []
        return unique.isEmpty ? ["Action", "Adventure", "RPG"] : unique
    }

    // MARK: - Store sorting & filtering

    func personalizedGames(favoriteGenres genres: [String], ownedTitles owned: [String]) -> [Game] {
        let genreSet = Set(genres)
        let ownedSet = Set(owned)

        let recommended = activeGames.filter {
            genreSet.contains($0.genre) && !ownedSet.contains($0.title)
        }
        let recommendedTitles = Set(recommended.map { $0.title })

        let other = activeGames.filter {
            !ownedSet.contains($0.title) && !recommendedTitles.contains($0.title)
        }

        let ownedGames = activeGames.filter { ownedSet.contains($0.title) }

        return recommended + other + ownedGames
    }

    func filteredGames(from games: [Game], genre: String, search: String) -> [Game] {
        let byGenre = genre == "All" ? games : games.filter { $0.genre == genre }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return byGenre }
        return byGenre.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.genre.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    func featuredBanners(favoriteGenres genres: [String]) -> [FeaturedBanner] {
        let genreSet = Set(genres)
        var selected: [Game] = []

        if let crystal = activeGames.first(where: { $0.title.lowercased() == "crystal run" }) {
            selected.append(crystal)
        }
        for game in activeGames where genreSet.contains(game.genre) {
            if selected.count >= 3 { break }
            if !selected.contains(where: { $0.title == game.title }) {
                selected.append(game)
            }
        }

        if selected.isEmpty { return defaultFeaturedBanners }

        return selected.map {
            FeaturedBanner(
                title: $0.title,
                subtitle: $0.subtitle,
                buttonTitle: "View Game",
                colors: [$0.color, .blue],
                imageName: $0.imageName,
                coverImage: $0.coverImage
            )
        }
    }

    private let defaultFeaturedBanners: [FeaturedBanner] = [
        FeaturedBanner(title: "Cyber Rush",     subtitle: "Fast-paced action and neon city battles.",                       buttonTitle: "View Game",    colors: [.purple, .blue],  imageName: "bolt.fill",              coverImage: nil),
        FeaturedBanner(title: "Dungeon Realms", subtitle: "Explore dungeons, collect loot, and unlock rare achievements.", buttonTitle: "Explore Now",  colors: [.pink, .indigo],  imageName: "shield.lefthalf.filled", coverImage: nil),
        FeaturedBanner(title: "Skyline Racers", subtitle: "Compete in futuristic races with dynamic rewards.",              buttonTitle: "Start Racing", colors: [.blue, .cyan],    imageName: "car.fill",               coverImage: nil)
    ]

    // MARK: - Cart

    func addToCart(_ game: Game) {
        guard !cartItems.contains(where: { $0.title == game.title }) else { return }
        cartItems.append(game)
    }

    func removeFromCart(_ game: Game) {
        cartItems.removeAll { $0.title == game.title }
    }

    var cartTotal: String {
        let total = cartItems.reduce(0.0) { sum, game in
            sum + (Double(game.price.replacingOccurrences(of: "$", with: "")) ?? 0)
        }
        return String(format: "$%.2f", total)
    }

    func checkout(isAdmin: Bool, accountKey: String, userId: UUID? = nil) async {
        guard !cartItems.isEmpty else { return }

        if let userId, !isAdmin {
            // Authenticated user — write to Supabase user_library
            let gameIds = cartItems.map { $0.id }
            do {
                try await SupabaseManager.shared.addGamesToLibrary(userId: userId, gameIds: gameIds)
                cloudLibraryIds.formUnion(gameIds)
            } catch {
                // Supabase write failed — fall back to local so the user still sees their games
                let titles  = cartItems.map { $0.title }
                let existing = purchasedTitlesByAccount[accountKey] ?? []
                purchasedTitlesByAccount[accountKey] = Array(Set(existing + titles)).sorted()
                saveAccountLibraries()
            }
        } else if isAdmin {
            let titles   = cartItems.map { $0.title }
            let existing = purchasedTitlesByUser[selectedUserID] ?? []
            purchasedTitlesByUser[selectedUserID] = Array(Set(existing + titles)).sorted()
            saveAdminLibraries()
        } else {
            // Guest
            let titles   = cartItems.map { $0.title }
            let existing = purchasedTitlesByAccount[accountKey] ?? []
            purchasedTitlesByAccount[accountKey] = Array(Set(existing + titles)).sorted()
            saveAccountLibraries()
        }
        cartItems.removeAll()
    }

    // MARK: - Persistence

    func loadSavedLibraries() {
        if let saved = UserDefaults.standard.dictionary(forKey: accountLibraryKey) as? [String: [String]] {
            purchasedTitlesByAccount = saved
        }
        if let saved = UserDefaults.standard.dictionary(forKey: adminLibraryKey) as? [String: [String]] {
            purchasedTitlesByUser = saved.reduce(into: [:]) { dict, pair in
                if let key = Int(pair.key), key != 0 { dict[key] = pair.value }
            }
        }
    }

    private func saveAccountLibraries() {
        UserDefaults.standard.set(purchasedTitlesByAccount, forKey: accountLibraryKey)
    }

    private func saveAdminLibraries() {
        let encoded = Dictionary(uniqueKeysWithValues: purchasedTitlesByUser.map { (String($0.key), $0.value) })
        UserDefaults.standard.set(encoded, forKey: adminLibraryKey)
    }

    // MARK: - Remote fetch

    func fetchGames() async {
        isLoadingGames = true
        gamesLoadError = ""
        do {
            let response = try await SupabaseManager.shared.client
                .from("games").select().execute()
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let rows = try decoder.decode([SupabaseGameRow].self, from: response.data)
            var seen = Set<String>()
            dbGames = rows.compactMap { row -> Game? in
                let key = row.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard seen.insert(key).inserted else { return nil }
                return Game(
                    id: row.id,
                    title: row.title,
                    genre: row.genre,
                    price: row.price,
                    color: color(for: row.genre),
                    subtitle: row.description ?? subtitle(for: row.genre),
                    imageName: row.image ?? "gamecontroller.fill",
                    coverImage: key == "crystal run" ? "crystal_run_cover" : nil,
                    description: row.description,
                    coverImageUrl: row.coverImageUrl
                )
            }
        } catch {
            gamesLoadError = error.localizedDescription
        }
        isLoadingGames = false
    }

    // MARK: - Genre helpers

    func color(for genre: String) -> Color {
        switch genre.lowercased() {
        case "racing":     return .purple
        case "rpg":        return .blue
        case "action":     return .pink
        case "strategy":   return .indigo
        case "adventure":  return .teal
        case "shooter":    return .orange
        case "fighting":   return .red
        case "survival":   return .cyan
        case "stealth":    return .mint
        case "simulation": return .green
        case "sci-fi":     return .blue
        case "arcade":     return .yellow
        default:           return .gray
        }
    }

    func subtitle(for genre: String) -> String {
        switch genre.lowercased() {
        case "racing":     return "High-speed races and competitive events"
        case "rpg":        return "Quests, progression, and character growth"
        case "action":     return "Fast-paced combat and exciting challenges"
        case "strategy":   return "Plan carefully and outsmart your rivals"
        case "adventure":  return "Explore worlds and uncover secrets"
        case "shooter":    return "Precision combat and intense firefights"
        case "fighting":   return "Duel opponents with skill and timing"
        case "survival":   return "Manage danger, resources, and exploration"
        case "stealth":    return "Stay hidden and strike at the right moment"
        case "simulation": return "Build, manage, and grow your systems"
        case "sci-fi":     return "Travel beyond the ordinary into future worlds"
        case "arcade":     return "Quick sessions with stylish action"
        default:           return "Discover a new experience in this genre"
        }
    }
}
