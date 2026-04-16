import SwiftUI

// Root — always shows the main app. Sign-in is a sheet, not a gate.
struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var storeVM: StoreViewModel

    var body: some View {
        MainAppView()
            .task {
                storeVM.loadSavedLibraries()
                await authVM.restoreSession()   // re-hydrate saved login
                await storeVM.fetchGames()
            }
    }
}

// MARK: - Main app shell

private struct MainAppView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var storeVM: StoreViewModel

    @State private var selectedTab: SidebarTab?   = .store
    @State private var featuredIndex              = 0
    @State private var isCartPresented            = false
    @State private var isAuthSheetPresented       = false
    @State private var selectedStoreGame: Game?   = nil
    @State private var selectedPlayableGame: Game? = nil

    private var accountKey: String {
        storeVM.accountKey(email: authVM.sessionEmail, username: authVM.username)
    }

    private var ownedTitles: [String] {
        storeVM.ownedTitles(isAdmin: authVM.isAdmin, accountKey: accountKey)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
                .frame(minWidth: 260, idealWidth: 280, maxWidth: 300)
        } detail: {
            ZStack {
                appBackground.ignoresSafeArea()
                tabContent
            }
        }
        .sheet(isPresented: $isCartPresented)      { cartSheet }
        .sheet(item: $selectedStoreGame)           { gameDetailSheet(for: $0) }
        .sheet(item: $selectedPlayableGame)        { gamePlayerSheet(for: $0) }
        .sheet(isPresented: $isAuthSheetPresented) { authSheet }
        // Dismiss auth sheet automatically after sign-in
        .onChange(of: authVM.isSignedIn) {
            if authVM.isSignedIn { isAuthSheetPresented = false }
        }
        .task {
            if let userId = authVM.userId {
                await storeVM.fetchUserLibrary(userId: userId)
            }
        }
        .onChange(of: authVM.userId) {
            if let userId = authVM.userId {
                Task { await storeVM.fetchUserLibrary(userId: userId) }
            } else {
                storeVM.cloudLibraryIds = []
            }
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab ?? .store {
        case .store:
            StorePage(
                featuredIndex: $featuredIndex,
                onOpenCart:    { isCartPresented = true },
                onOpenGame:    { selectedStoreGame = $0 },
                onSignIn:      { isAuthSheetPresented = true },
                onOpenFeaturedBanner: { banner in
                    if let match = storeVM.activeGames.first(where: { $0.title == banner.title }) {
                        selectedStoreGame = match
                    }
                }
            )

        case .library:
            if authVM.isSignedIn {
                LibraryPage(onPlay: { game in
                    let key = game.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if key == "crystal run" { selectedPlayableGame = game }
                })
            } else {
                SignInRequiredView(
                    icon: "books.vertical.fill",
                    message: "Sign in to see your library",
                    onSignIn: { isAuthSheetPresented = true }
                )
            }

        case .achievements:
            if authVM.isSignedIn {
                AchievementsPage()
            } else {
                SignInRequiredView(
                    icon: "trophy.fill",
                    message: "Sign in to track achievements",
                    onSignIn: { isAuthSheetPresented = true }
                )
            }

        case .keyStore:
            KeyStorePage()

        case .profile:
            if authVM.isSignedIn {
                ProfilePage()
            } else {
                SignInRequiredView(
                    icon: "person.crop.circle.fill",
                    message: "Sign in to view your profile",
                    onSignIn: { isAuthSheetPresented = true }
                )
            }
        }
    }

    // MARK: - Sheets

    private var authSheet: some View {
        sheetContainer {
            AuthView()
        }
    }

    private var cartSheet: some View {
        sheetContainer {
            VStack(spacing: 0) {
                sheetCloseButton { isCartPresented = false }
                CartPage(
                    onCheckout: {
                        guard authVM.isSignedIn else {
                            // Not signed in — close cart, show sign-in sheet
                            isCartPresented = false
                            isAuthSheetPresented = true
                            return
                        }
                        Task {
                            await storeVM.checkout(
                                isAdmin: authVM.isAdmin,
                                accountKey: accountKey,
                                userId: authVM.userId
                            )
                            isCartPresented = false
                            selectedTab = .library
                        }
                    },
                    onRemove: { storeVM.removeFromCart($0) }
                )
            }
        }
    }

    private func gameDetailSheet(for game: Game) -> some View {
        sheetContainer {
            GameDetailPage(
                game: game,
                isOwned: ownedTitles.contains(game.title),
                isInCart: storeVM.cartItems.contains(where: { $0.title == game.title }),
                onClose: { selectedStoreGame = nil },
                onAddToCart: { storeVM.addToCart(game) },
                onPlayDemo: {
                    selectedStoreGame = nil
                    selectedPlayableGame = game
                }
            )
            .frame(minWidth: 1100, minHeight: 760)
            .padding(20)
        }
    }

    private func gamePlayerSheet(for game: Game) -> some View {
        sheetContainer {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.title).font(.title2.bold()).foregroundStyle(.white)
                        Text("Playable demo").foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    sheetCloseButton { selectedPlayableGame = nil }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                CrystalRunnerView()
                    .frame(minWidth: 900, minHeight: 650)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .frame(minWidth: 960, minHeight: 760)
        }
    }

    // MARK: - Helpers

    private var appBackground: some View {
        LinearGradient(
            colors: [.black, .purple.opacity(0.9), .blue.opacity(0.8)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private func sheetContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            appBackground.ignoresSafeArea()
            content()
        }
        .interactiveDismissDisabled(false)
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
    }

    private func sheetCloseButton(action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(action: action) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(StoreViewModel())
}
