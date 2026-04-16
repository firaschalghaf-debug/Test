import SwiftUI

struct KeyStorePage: View {
    @State private var keyInput = ""
    @State private var redeemResult: RedeemResult?

    enum RedeemResult {
        case success(String)
        case invalid
    }

    // Demo keys — in production these would validate against Supabase
    private let validKeys: [String: String] = [
        "NEON-DRIFT-2024":    "Neon Drift",
        "SHADOW-QUEST-ALPHA": "Shadow Quest",
        "PIXEL-PRO-KEY":      "Pixel Arena",
        "STAR-FORGE-BETA":    "Star Forge",
        "MYSTIC-VALE-2024":   "Mystic Vale",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                redeemSection
                howItWorksSection
            }
            .padding(28)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Key Store")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
            Text("Redeem a product key to add a game to your library.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.50))
        }
    }

    // MARK: - Redeem section

    private var redeemSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Redeem a Key")
                .font(.title2.bold())
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.white.opacity(0.40))
                        TextField("e.g. XXXX-XXXX-XXXX", text: $keyInput)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: keyInput) { redeemResult = nil }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))

                    Button(action: handleRedeem) {
                        Text("Redeem")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let result = redeemResult {
                    resultBanner(result)
                }
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    @ViewBuilder
    private func resultBanner(_ result: RedeemResult) -> some View {
        switch result {
        case .success(let gameName):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\"\(gameName)\" added to your library!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))

        case .invalid:
            HStack(spacing: 10) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Invalid or already redeemed key.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - How it works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How It Works")
                .font(.title2.bold())
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                stepRow(number: "1", title: "Get a Key", description: "Purchase or receive a product key from a retailer or promotion.")
                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.leading, 56)
                stepRow(number: "2", title: "Enter the Key", description: "Paste your key into the field above and tap Redeem.")
                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.leading, 56)
                stepRow(number: "3", title: "Play Instantly", description: "Your game appears in your Library — ready to launch.")
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private func stepRow(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.headline.weight(.bold))
                .foregroundStyle(.cyan)
                .frame(width: 28, height: 28)
                .background(Color.cyan.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - Redeem logic

    private func handleRedeem() {
        let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        redeemResult = validKeys[key].map { .success($0) } ?? .invalid
        keyInput = ""
    }
}
