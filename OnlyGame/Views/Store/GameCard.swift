import SwiftUI

struct GameCard: View {
    let game: Game
    let isInCart: Bool
    let isOwned: Bool
    let isRecommended: Bool
    let onOpen: () -> Void
    let onAddToCart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverThumbnail
                .overlay(alignment: .topLeading) { forYouBadge }
                .overlay(alignment: .topTrailing)  { statusBadge }
                .onTapGesture { onOpen() }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(game.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(game.price)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.80))
                }

                HStack {
                    Text(game.genre)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())

                    Spacer()

                    Button(isOwned ? "Owned" : (isInCart ? "In Cart" : "Add to Cart")) {
                        if !isInCart && !isOwned { onAddToCart() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(isOwned ? .green : (isInCart ? .gray : .cyan))
                    .disabled(isInCart || isOwned)
                }
            }
            .padding(14)
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Cover

    @ViewBuilder
    private var coverThumbnail: some View {
        if let cover = game.coverImage {
            Image(cover)
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .clipped()
        } else {
            Rectangle()
                .fill(LinearGradient(
                    colors: [game.color, .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 180)
                .overlay(
                    Image(systemName: game.imageName)
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.85))
                )
        }
    }

    // MARK: - Badges

    @ViewBuilder
    private var forYouBadge: some View {
        if isRecommended && !isOwned {
            Text("For You")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(10)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isOwned {
            overlayBadge("Owned", color: .green)
        } else if isInCart {
            overlayBadge("In Cart", color: .cyan)
        }
    }

    private func overlayBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.50))
            .clipShape(Capsule())
            .padding(10)
    }
}
