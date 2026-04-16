import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("OnlyGame")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text("Game platform")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)

            VStack(spacing: 6) {
                ForEach(SidebarTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 28, alignment: .center)

                            Text(tab.rawValue)
                                .font(.system(size: 20, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)

                            Spacer(minLength: 8)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 17)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectedTab == tab ? Color.white.opacity(0.12) : .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(selectedTab == tab ? Color.white.opacity(0.14) : .clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .contentShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.98), .purple.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
