import SwiftUI

struct LibraryPage: View {
    @EnvironmentObject var storeVM: StoreViewModel
    @EnvironmentObject var authVM: AuthViewModel
    let onPlay: (Game) -> Void

    @State private var searchText     = ""
    @State private var selectedGenre  = "All"

    private var games: [Game] {
        let key = storeVM.accountKey(email: authVM.sessionEmail, username: authVM.username)
        return storeVM.libraryGames(isAdmin: authVM.isAdmin, accountKey: key)
    }

    private var genres: [String] {
        ["All"] + Array(Set(games.map { $0.genre })).sorted()
    }

    private var filteredGames: [Game] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return games.filter { game in
            let matchesGenre  = selectedGenre == "All" || game.genre == selectedGenre
            let matchesSearch = query.isEmpty ||
                game.title.localizedCaseInsensitiveContains(query) ||
                game.genre.localizedCaseInsensitiveContains(query)
            return matchesGenre && matchesSearch
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                if !games.isEmpty {
                    searchBar
                    genreFilterRow
                }
                contentSection
            }
            .padding(28)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Library")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(games.count) game\(games.count == 1 ? "" : "s") owned")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.50))
            }
            Spacer()
        }
    }

    // MARK: - Genre filter

    private var genreFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(genres, id: \.self) { genre in
                    let isSelected = selectedGenre == genre
                    Button { selectedGenre = genre } label: {
                        Text(genre)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .black : .white.opacity(0.70))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.cyan : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.45))
            TextField("Search your library", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        if games.isEmpty {
            emptyState
        } else if filteredGames.isEmpty {
            noResultsState
        } else {
            VStack(spacing: 0) {
                ForEach(Array(filteredGames.enumerated()), id: \.element.id) { index, game in
                    LibraryGameRow(game: game, onPlay: { onPlay(game) })
                    if index < filteredGames.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 132)
                    }
                }
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 48))
                .foregroundStyle(.cyan)
                .padding(20)
                .background(Color.cyan.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 22))

            Text("Your library is empty")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Head to the Store, add games to your cart, and checkout — they'll appear here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.60))
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var noResultsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.35))
            Text("No games match \"\(searchText)\"")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Library game row

struct LibraryGameRow: View {
    let game: Game
    let onPlay: () -> Void

    private var isPlayable: Bool {
        game.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "crystal run"
    }

    var body: some View {
        HStack(spacing: 16) {
            coverThumbnail

            VStack(alignment: .leading, spacing: 5) {
                Text(game.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(game.genre)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.50))

                    if isPlayable {
                        Text("Demo available")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.cyan.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if isPlayable {
                Button(action: onPlay) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.caption.weight(.bold))
                        Text("Play")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            } else {
                Text("No Demo")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.28))
                    .frame(minWidth: 80, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        if let cover = game.coverImage {
            Image(cover)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(
                    colors: [game.color, .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 100, height: 58)
                .overlay(
                    Image(systemName: game.imageName)
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.90))
                )
        }
    }
}
