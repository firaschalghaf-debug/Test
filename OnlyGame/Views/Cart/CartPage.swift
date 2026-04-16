import SwiftUI

struct CartPage: View {
    @EnvironmentObject var storeVM: StoreViewModel
    let onCheckout: () -> Void
    let onRemove: (Game) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            if storeVM.cartItems.isEmpty {
                emptyState
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(storeVM.cartItems.enumerated()), id: \.element.id) { index, game in
                            CartItemRow(game: game, onRemove: { onRemove(game) })
                            if index < storeVM.cartItems.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.06))
                                    .padding(.leading, 132)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }

                checkoutBar
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cart")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
            Text("\(storeVM.cartItems.count) item\(storeVM.cartItems.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.50))
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.28))
                .padding(20)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 22))

            Text("Your cart is empty")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Browse the Store and add games to your cart.")
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Checkout bar

    private var checkoutBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.08))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.50))
                    Text(storeVM.cartTotal)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button(action: onCheckout) {
                    HStack(spacing: 8) {
                        Image(systemName: "bag.fill")
                        Text("Checkout")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
    }
}

// MARK: - Cart item row

struct CartItemRow: View {
    let game: Game
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
            }

            Spacer()

            Text(game.price)
                .font(.headline)
                .foregroundStyle(.white)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
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
