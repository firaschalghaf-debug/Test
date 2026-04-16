import SwiftUI

struct GameDetailPage: View {
    let game: Game
    let isOwned: Bool
    let isInCart: Bool
    let onClose: () -> Void
    let onAddToCart: () -> Void
    let onPlayDemo: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                closeButton

                HStack(alignment: .top, spacing: 28) {
                    coverSection

                    VStack(alignment: .leading, spacing: 18) {
                        Text(game.title)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        statusTags

                        Text(game.price)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)

                        Text(game.subtitle)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(game.description ?? "A premium game experience on the OnlyGame platform. Build your collection and jump into playable demos where available.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)
                        actionButtons
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(32)
            .frame(minWidth: 1040, minHeight: 700, alignment: .topLeading)
        }
    }

    // MARK: - Subviews

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
    }

    private var statusTags: some View {
        HStack(spacing: 10) {
            tag(game.genre, color: .cyan)
            if isOwned  { tag("Owned",   color: .green) }
            if isInCart { tag("In Cart", color: .cyan)  }
        }
    }

    private func tag(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button(isOwned ? "Owned" : (isInCart ? "In Cart" : "Add to Cart")) {
                if !isOwned && !isInCart { onAddToCart() }
            }
            .buttonStyle(.borderedProminent)
            .tint(isOwned ? .green : (isInCart ? .gray : .cyan))
            .disabled(isOwned || isInCart)

            if game.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "crystal run" {
                Button("Play Demo") { onPlayDemo() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
        }
    }

    @ViewBuilder
    private var coverSection: some View {
        if let cover = game.coverImage {
            Image(cover)
                .resizable()
                .scaledToFill()
                .frame(width: 420, height: 520)
                .clipShape(RoundedRectangle(cornerRadius: 28))
        } else {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [game.color, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 420, height: 520)
                .overlay(
                    Image(systemName: game.imageName)
                        .font(.system(size: 84))
                        .foregroundStyle(.white.opacity(0.92))
                )
        }
    }
}
