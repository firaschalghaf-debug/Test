import SwiftUI

struct ProfilePage: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var storeVM: StoreViewModel

    private var accountKey: String {
        storeVM.accountKey(email: authVM.sessionEmail, username: authVM.username)
    }

    private var libraryCount: Int {
        storeVM.libraryGames(isAdmin: authVM.isAdmin, accountKey: accountKey).count
    }

    private var favoriteGenres: [String] {
        storeVM.favoriteGenres(isAdmin: authVM.isAdmin, accountKey: accountKey)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroBanner
                statsRow
                walletCard
                detailsRow
                if let userId = authVM.userId {
                    OrderHistorySection(userId: userId)
                        .padding(.top, 4)
                }
            }
            .padding(28)
        }
    }

    // MARK: - Subviews

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34)
                .fill(LinearGradient(
                    colors: [.purple.opacity(0.36), .blue.opacity(0.26), .black.opacity(0.45)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 34).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .frame(height: 300)

            // Ambient glows
            Circle().fill(Color.cyan.opacity(0.18)).frame(width: 210, height: 210).blur(radius: 24).offset(x: 260, y: -70)
            Circle().fill(Color.purple.opacity(0.18)).frame(width: 190, height: 190).blur(radius: 24).offset(x: 420, y: 40)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 18) {
                    avatarCircle
                    userInfo
                }

                HStack(spacing: 12) {
                    pill("Online", icon: "checkmark.circle.fill", color: .green)
                    pill(authVM.isAdmin ? "Admin Access" : "Player Account",
                         icon: authVM.isAdmin ? "lock.shield.fill" : "gamecontroller.fill",
                         color: authVM.isAdmin ? .cyan : .white.opacity(0.82))
                }
            }
            .padding(28)
        }
    }

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.white.opacity(0.24), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 112, height: 112)
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.white)
        }
    }

    private var userInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(authVM.displayName)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                if authVM.isAdmin {
                    Label("ADMIN", systemImage: "crown.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            Text(authVM.isGuest ? "Browsing as guest — sign in to save your library" : authVM.sessionEmail)
                .font(.title3)
                .foregroundStyle(authVM.isGuest ? .orange.opacity(0.85) : .white.opacity(0.72))
            Text("Level 27 Account • Neon Collection Owner")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.60))
        }
    }

    private func pill(_ label: String, icon: String, color: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
    }

    private var walletCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Wallet", systemImage: "creditcard.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: "$%.2f", authVM.walletBalance))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.cyan)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Top Up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.60))
                HStack(spacing: 10) {
                    ForEach([5.0, 10.0, 25.0, 50.0], id: \.self) { amount in
                        Button {
                            Task { await authVM.topUp(amount: amount) }
                        } label: {
                            Text("+$\(Int(amount))")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(.cyan)
                        .disabled(authVM.isTopping)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var statsRow: some View {
        HStack(spacing: 18) {
            StatCard(title: "Library", value: "\(libraryCount)",                  subtitle: "Owned games",    systemImage: "books.vertical.fill", accent: .cyan)
            StatCard(title: "Cart",    value: "\(storeVM.cartItems.count)",        subtitle: "Items waiting",  systemImage: "cart.fill",           accent: .orange)
            StatCard(title: "Genres",  value: "\(favoriteGenres.count)",           subtitle: "Favorites",      systemImage: "sparkles",            accent: .purple)
        }
    }

    private var detailsRow: some View {
        HStack(alignment: .top, spacing: 18) {
            infoCard
            playerStatusCard
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Overview")
                .font(.title2.bold())
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 12) {
                ProfileInfoRow(title: "Display Name",    value: authVM.displayName)
                ProfileInfoRow(title: "Email",           value: authVM.sessionEmail)
                ProfileInfoRow(title: "Role",            value: authVM.isAdmin ? "Administrator" : "Standard User")
                ProfileInfoRow(title: "Favorite Genres", value: favoriteGenres.joined(separator: ", "))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var playerStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Player Status")
                .font(.title2.bold())
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 14) {
                ProfileInfoRow(title: "Achievement Rank", value: authVM.isAdmin ? "Overseer Tier" : "Gold Tier")
                ProfileInfoRow(title: "Main Genre",       value: favoriteGenres.first ?? "Unknown")
                ProfileInfoRow(title: "Current Mood",     value: "Ready to play")
            }

            Button {
                Task { await authVM.signOut() }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}
