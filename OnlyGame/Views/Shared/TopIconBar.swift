import SwiftUI

struct TopIconBar: View {
    let isSignedIn: Bool
    let displayName: String
    let isAdmin: Bool
    let walletBalance: Double
    let cartCount: Int
    let wishlistCount: Int
    let pendingFriendsCount: Int

    let onSignIn: () -> Void
    let onCart: () -> Void
    let onWishlist: () -> Void
    let onFriends: () -> Void
    let onProfile: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Spacer()

            // User greeting / sign-in
            if isSignedIn {
                HStack(spacing: 6) {
                    if isAdmin {
                        Label("Admin", systemImage: "crown.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.cyan)
                    } else {
                        Text("Hi, \(displayName)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.trailing, 8)
            } else {
                Button(action: onSignIn) {
                    Text("Sign In")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cyan.opacity(0.80))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }

            // Friends
            if isSignedIn {
                iconButton(
                    systemName: "person.2.fill",
                    badge: pendingFriendsCount,
                    badgeColor: .orange,
                    action: onFriends
                )
            }

            // Wishlist
            if isSignedIn {
                iconButton(
                    systemName: "heart.fill",
                    badge: wishlistCount,
                    badgeColor: .pink,
                    action: onWishlist
                )
            }

            // Cart
            iconButton(
                systemName: "cart.fill",
                badge: cartCount,
                badgeColor: .cyan,
                action: onCart
            )

            // Wallet balance
            if isSignedIn {
                HStack(spacing: 4) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(String(format: "$%.2f", walletBalance))
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.cyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.cyan.opacity(0.12))
                .clipShape(Capsule())
                .padding(.leading, 4)
            }

            // Profile — always rightmost
            if isSignedIn {
                Button(action: onProfile) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.purple.opacity(0.70), .blue.opacity(0.60)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 32, height: 32)
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
    }

    private func iconButton(systemName: String, badge: Int, badgeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(badge > 0 ? 0.12 : 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if badge > 0 {
                    Text("\(min(badge, 99))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(badgeColor)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
