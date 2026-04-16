import SwiftUI

struct GameDetailPage: View {
    let game: Game
    let isOwned: Bool
    let isInCart: Bool
    let isWishlisted: Bool
    let onClose: () -> Void
    let onAddToCart: () -> Void
    let onPlayDemo: () -> Void
    let onToggleWishlist: (() -> Void)?

    @EnvironmentObject var authVM: AuthViewModel

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

                        priceSection

                        Text(game.subtitle)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(game.description ?? "A premium game experience on the OnlyGame platform. Build your collection and jump into playable demos where available.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)

                        gameMetadata

                        Spacer(minLength: 8)
                        actionButtons
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                    .background(Color.white.opacity(0.10))

                SystemRequirementsSection(gameId: game.id)

                Divider()
                    .background(Color.white.opacity(0.10))

                ReviewsSection(game: game, isOwned: isOwned)
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
        FlowLayout(spacing: 8) {
            tag(game.genre, color: .cyan)
            ForEach(game.tags, id: \.self) { t in
                tag(t, color: .white.opacity(0.55))
            }
            if game.isOnSale, let pct = game.discountPercent {
                tag("-\(Int(pct))% SALE", color: .green)
            }
            if isOwned  { tag("Owned",   color: .green) }
            if isInCart { tag("In Cart", color: .cyan)  }
        }
    }

    @ViewBuilder
    private var priceSection: some View {
        if game.isOnSale, let discounted = game.discountedPriceValue {
            VStack(alignment: .leading, spacing: 4) {
                Text(game.price)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .strikethrough(true, color: .white.opacity(0.45))
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(String(format: "$%.2f", discounted))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.green)
                    if let pct = game.discountPercent {
                        Text("Save \(Int(pct))%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green.opacity(0.80))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        } else {
            Text(game.price)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
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

    @ViewBuilder
    private var gameMetadata: some View {
        let hasDev  = game.developerName != nil
        let hasPub  = game.publisherName != nil
        let hasDate = game.releaseDate != nil
        if hasDev || hasPub || hasDate {
            VStack(alignment: .leading, spacing: 8) {
                if let dev = game.developerName {
                    metaRow(icon: "hammer.fill", label: "Developer", value: dev)
                }
                if let pub = game.publisherName {
                    metaRow(icon: "building.2.fill", label: "Publisher", value: pub)
                }
                if let raw = game.releaseDate {
                    metaRow(icon: "calendar", label: "Released", value: formattedDate(raw))
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func formattedDate(_ raw: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: raw) else { return raw }
        df.dateFormat = "MMM d, yyyy"
        return df.string(from: date)
    }

    private func metaRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 16)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
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

            if let toggle = onToggleWishlist, !isOwned {
                Button(action: toggle) {
                    Label(isWishlisted ? "Wishlisted" : "Wishlist",
                          systemImage: isWishlisted ? "heart.fill" : "heart")
                        .foregroundStyle(isWishlisted ? Color.pink : Color.white)
                }
                .buttonStyle(.bordered)
                .tint(isWishlisted ? .pink : .white)
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
