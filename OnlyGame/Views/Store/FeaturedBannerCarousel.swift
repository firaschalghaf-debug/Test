import SwiftUI
import Combine

struct FeaturedBannerCarousel: View {
    let banners: [FeaturedBanner]
    @Binding var featuredIndex: Int
    let onOpenBanner: (FeaturedBanner) -> Void

    private let autoScrollTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        if !banners.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    ForEach(Array(banners.enumerated()), id: \.offset) { index, banner in
                        if index == featuredIndex {
                            FeaturedBannerCard(banner: banner, onOpen: { onOpenBanner(banner) })
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing),
                                    removal:   .move(edge: .leading)
                                ))
                        }
                    }
                }
                .clipped()

                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(Array(banners.enumerated()), id: \.offset) { index, _ in
                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) { featuredIndex = index }
                        } label: {
                            Capsule()
                                .fill(index == featuredIndex ? Color.white : Color.white.opacity(0.25))
                                .frame(width: index == featuredIndex ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.25), value: featuredIndex)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 280)
            .onReceive(autoScrollTimer) { _ in
                withAnimation(.easeInOut(duration: 0.8)) {
                    featuredIndex = (featuredIndex + 1) % banners.count
                }
            }
        }
    }
}

// MARK: - Individual banner card

struct FeaturedBannerCard: View {
    let banner: FeaturedBanner
    let onOpen: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30)
                .fill(LinearGradient(colors: banner.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.14), lineWidth: 1))

            if let cover = banner.coverImage {
                HStack(spacing: 0) {
                    Spacer()
                    Image(cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 360, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .padding(.trailing, 22)
                        .padding(.vertical, 20)
                        .opacity(0.96)
                }
            } else {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 220, height: 220)
                    .blur(radius: 12)
                    .offset(x: 220, y: -10)
                Image(systemName: banner.imageName)
                    .font(.system(size: 110))
                    .foregroundStyle(.white.opacity(0.22))
                    .offset(x: 215, y: 10)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Featured Game")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.86))
                Text(banner.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                Text(banner.subtitle)
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: 420, alignment: .leading)
                Button(banner.buttonTitle) { onOpen() }
                    .buttonStyle(.borderedProminent)
                    .tint(.black.opacity(0.35))
            }
            .padding(26)
        }
        .contentShape(RoundedRectangle(cornerRadius: 30))
        .onTapGesture { onOpen() }
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 12)
    }
}
