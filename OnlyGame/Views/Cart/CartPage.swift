import SwiftUI

struct CartPage: View {
    @EnvironmentObject var storeVM: StoreViewModel
    @EnvironmentObject var authVM: AuthViewModel
    let onCheckout: () -> Void
    let onRemove: (Game) -> Void

    private var cartTotal: Double { storeVM.cartItems.reduce(0.0) { $0 + $1.effectivePrice } }
    private var hasSufficientBalance: Bool {
        authVM.isAdmin || !authVM.isSignedIn || authVM.walletBalance >= cartTotal
    }

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
            VStack(spacing: 12) {
                // Wallet balance row (signed-in non-admin only)
                if authVM.isSignedIn && !authVM.isAdmin {
                    HStack {
                        Label("Wallet Balance", systemImage: "creditcard.fill")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.60))
                        Spacer()
                        Text(String(format: "$%.2f", authVM.walletBalance))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(hasSufficientBalance ? .green : .orange)
                    }
                    if !hasSufficientBalance {
                        Text("Insufficient balance — top up in Profile")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if storeVM.cartSavings > 0 {
                            HStack(spacing: 6) {
                                Text("Total")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.50))
                                Text("You save \(String(format: "$%.2f", storeVM.cartSavings))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        } else {
                            Text("Total")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.50))
                        }
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
                    .disabled(!hasSufficientBalance)
                }
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

            if game.isOnSale, let discounted = game.discountedPriceValue {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(game.price)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.40))
                        .strikethrough(true, color: .white.opacity(0.40))
                    Text(String(format: "$%.2f", discounted))
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            } else {
                Text(game.price)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

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
