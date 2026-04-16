import SwiftUI

struct WishlistSheet: View {
    @EnvironmentObject var storeVM: StoreViewModel
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            if storeVM.wishlistGames.isEmpty {
                emptyState
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(storeVM.wishlistGames.enumerated()), id: \.element.id) { index, game in
                            WishlistRow(
                                game: game,
                                isOwned: storeVM.cloudLibraryIds.contains(game.id),
                                isInCart: storeVM.cartItems.contains(where: { $0.id == game.id }),
                                onAddToCart: { storeVM.addToCart(game) },
                                onRemove: {
                                    if let uid = authVM.userId {
                                        Task { await storeVM.toggleWishlist(game: game, userId: uid) }
                                    }
                                }
                            )
                            if index < storeVM.wishlistGames.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.06))
                                    .padding(.leading, 116)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Wishlist")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            Text("\(storeVM.wishlistGames.count) game\(storeVM.wishlistGames.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.50))
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.28))
                .padding(20)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 22))
            Text("Your wishlist is empty")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Tap the heart on any game to save it here.")
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Wishlist row

private struct WishlistRow: View {
    let game: Game
    let isOwned: Bool
    let isInCart: Bool
    let onAddToCart: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            coverThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(game.genre)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.50))
                if let dev = game.developerName {
                    Text(dev)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                if game.isOnSale, let discounted = game.discountedPriceValue {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(game.price)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.38))
                            .strikethrough(true, color: .white.opacity(0.38))
                        Text(String(format: "$%.2f", discounted))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.green)
                    }
                } else {
                    Text(game.price)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.80))
                }

                Button(isOwned ? "Owned" : (isInCart ? "In Cart" : "Add to Cart")) {
                    if !isOwned && !isInCart { onAddToCart() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(isOwned ? .green : (isInCart ? .gray : .cyan))
                .disabled(isOwned || isInCart)
            }

            Button(action: onRemove) {
                Image(systemName: "heart.slash")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        if let cover = game.coverImage {
            Image(cover)
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [game.color, .black],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 90, height: 54)
                .overlay(
                    Image(systemName: game.imageName)
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.85))
                )
        }
    }
}
