import SwiftUI

struct StorePage: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var storeVM: StoreViewModel

    @Binding var featuredIndex: Int
    let onOpenCart: () -> Void
    let onOpenGame: (Game) -> Void
    let onSignIn: () -> Void
    let onOpenFeaturedBanner: (FeaturedBanner) -> Void

    @State private var searchText = ""
    @State private var selectedGenreFilter = "All"

    private let columns = [GridItem(.adaptive(minimum: 270), spacing: 22)]

    // MARK: - Computed

    private var accountKey: String {
        storeVM.accountKey(email: authVM.sessionEmail, username: authVM.username)
    }

    private var ownedTitles: [String] {
        storeVM.ownedTitles(isAdmin: authVM.isAdmin, accountKey: accountKey)
    }

    private var favoriteGenres: [String] {
        storeVM.favoriteGenres(isAdmin: authVM.isAdmin, accountKey: accountKey)
    }

    private var allPersonalized: [Game] {
        storeVM.personalizedGames(favoriteGenres: favoriteGenres, ownedTitles: ownedTitles)
    }

    private var filteredGames: [Game] {
        storeVM.filteredGames(from: allPersonalized, genre: selectedGenreFilter, search: searchText)
    }

    // Top-5 personalized games get a "For You" badge in the grid
    private var recommendedTitles: Set<String> {
        Set(allPersonalized.prefix(5).map { $0.title })
    }

    private var featuredBanners: [FeaturedBanner] {
        storeVM.featuredBanners(favoriteGenres: favoriteGenres)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topBar
                searchBar
                FeaturedBannerCarousel(
                    banners: featuredBanners,
                    featuredIndex: $featuredIndex,
                    onOpenBanner: onOpenFeaturedBanner
                )
                GenreFilterRow(genres: storeVM.availableGenres, selectedGenre: $selectedGenreFilter)
                browseHeader
                gamesGrid
            }
            .padding(26)
        }
    }

    // MARK: - Top bar (brand + status + cart collapsed into one row)

    private var topBar: some View {
        HStack(spacing: 14) {
            Text("OnlyGame")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 6) {
                Circle()
                    .fill(storeVM.dbGames.isEmpty ? Color.orange : .green)
                    .frame(width: 7, height: 7)
                Text(storeVM.dbGames.isEmpty ? "Local data" : "Supabase")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.50))
                if storeVM.isLoadingGames {
                    ProgressView().controlSize(.mini)
                }
            }

            if !storeVM.gamesLoadError.isEmpty {
                Text(storeVM.gamesLoadError)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.90))
                    .lineLimit(1)
            }

            Spacer()

            if authVM.isAdmin {
                HStack(spacing: 8) {
                    Text("Viewing as")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.60))
                    Picker("", selection: $storeVM.selectedUserID) {
                        ForEach(storeVM.users) { user in
                            Text(user.name).tag(user.id)
                        }
                    }
                    .pickerStyle(.menu)
                    Text("Admin")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(Capsule())
                }
            } else if authVM.isSignedIn {
                Text("Hi, \(authVM.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.60))
            } else {
                Button(action: onSignIn) {
                    Text("Sign In")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.cyan.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Button(action: onOpenCart) {
                HStack(spacing: 6) {
                    Image(systemName: "cart.fill")
                    if storeVM.cartItems.count > 0 {
                        Text("\(storeVM.cartItems.count)")
                            .font(.caption.weight(.bold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(storeVM.cartItems.isEmpty
                    ? Color.white.opacity(0.08)
                    : Color.cyan.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.55))
            TextField("Search games, genres, or features", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.40))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Browse header

    private var browseHeader: some View {
        HStack {
            Text("Browse")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Spacer()
            Text("\(filteredGames.count) game\(filteredGames.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Games grid

    private var gamesGrid: some View {
        LazyVGrid(columns: columns, spacing: 22) {
            ForEach(filteredGames) { game in
                GameCard(
                    game: game,
                    isInCart: storeVM.cartItems.contains(where: { $0.title == game.title }),
                    isOwned: ownedTitles.contains(game.title),
                    isRecommended: recommendedTitles.contains(game.title),
                    onOpen: { onOpenGame(game) },
                    onAddToCart: { storeVM.addToCart(game) }
                )
            }
        }
    }
}
