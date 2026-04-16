import SwiftUI

// MARK: - Achievement model

struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let rarity: Rarity
    let isUnlocked: Bool
    let gameName: String

    enum Rarity: String, CaseIterable {
        case common    = "Common"
        case rare      = "Rare"
        case epic      = "Epic"
        case legendary = "Legendary"

        var color: Color {
            switch self {
            case .common:    return .white.opacity(0.70)
            case .rare:      return .blue
            case .epic:      return .purple
            case .legendary: return .yellow
            }
        }

        var badgeIcon: String {
            switch self {
            case .common:    return "circle.fill"
            case .rare:      return "diamond.fill"
            case .epic:      return "hexagon.fill"
            case .legendary: return "crown.fill"
            }
        }
    }
}

// MARK: - Page

struct AchievementsPage: View {
    @EnvironmentObject var storeVM: StoreViewModel
    @EnvironmentObject var authVM: AuthViewModel

    private var accountKey: String {
        storeVM.accountKey(email: authVM.sessionEmail, username: authVM.username)
    }

    private var ownedGames: [Game] {
        storeVM.libraryGames(isAdmin: authVM.isAdmin, accountKey: accountKey)
    }

    private var allAchievements: [Achievement] {
        generateAchievements(for: ownedGames)
    }

    private var unlocked: [Achievement] { allAchievements.filter { $0.isUnlocked } }

    @State private var collapsedGames: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                if allAchievements.isEmpty {
                    emptyState
                } else {
                    progressSection
                    ForEach(ownedGames, id: \.id) { game in
                        let gameAchievements = allAchievements.filter { $0.gameName == game.title }
                        let isExpanded = !collapsedGames.contains(game.id)
                        GameAchievementsSection(
                            game: game,
                            achievements: gameAchievements,
                            isExpanded: isExpanded,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if collapsedGames.contains(game.id) {
                                        collapsedGames.remove(game.id)
                                    } else {
                                        collapsedGames.insert(game.id)
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .padding(28)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Achievements")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
            Text("\(unlocked.count) of \(allAchievements.count) completed across \(ownedGames.count) game\(ownedGames.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.50))
        }
    }

    // MARK: - Overall progress card

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Overall Progress")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(allAchievements.isEmpty ? "0%" : "\(Int(Double(unlocked.count) / Double(allAchievements.count) * 100))%")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.cyan)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.10))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: allAchievements.isEmpty ? 0 : geo.size.width * CGFloat(unlocked.count) / CGFloat(allAchievements.count))
                }
                .frame(height: 10)
            }
            .frame(height: 10)

            HStack(spacing: 18) {
                ForEach(Achievement.Rarity.allCases, id: \.rawValue) { rarity in
                    let count = unlocked.filter { $0.rarity == rarity }.count
                    HStack(spacing: 5) {
                        Image(systemName: rarity.badgeIcon)
                            .font(.caption)
                            .foregroundStyle(rarity.color)
                        Text("\(count) \(rarity.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.60))
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow.opacity(0.70))
                .padding(20)
                .background(Color.yellow.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 22))
            Text("No achievements yet")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Own games from the Store to start earning achievements.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.60))
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Achievement generation (deterministic)

    private func generateAchievements(for games: [Game]) -> [Achievement] {
        games.flatMap { game -> [Achievement] in
            let dedicatedUnlocked = game.genre.count % 2 == 0
            return [
                Achievement(title: "First Steps",      description: "Start \(game.title) for the first time.",     icon: "flag.fill",           rarity: .common,    isUnlocked: true,              gameName: game.title),
                Achievement(title: "Getting the Hang", description: "Play \(game.title) for 30 minutes.",          icon: "clock.fill",          rarity: .common,    isUnlocked: true,              gameName: game.title),
                Achievement(title: "Dedicated",        description: "Accumulate 5 hours in \(game.title).",        icon: "star.fill",           rarity: .rare,      isUnlocked: dedicatedUnlocked, gameName: game.title),
                Achievement(title: "Genre Master",     description: "Complete the main story in \(game.title).",   icon: "checkmark.seal.fill", rarity: .epic,      isUnlocked: false,             gameName: game.title),
                Achievement(title: "Legend",           description: "Unlock every secret in \(game.title).",       icon: "crown.fill",          rarity: .legendary, isUnlocked: false,             gameName: game.title),
            ]
        }
    }
}

// MARK: - Per-game section

struct GameAchievementsSection: View {
    let game: Game
    let achievements: [Achievement]
    let isExpanded: Bool
    let onToggle: () -> Void

    private var unlockedCount: Int { achievements.filter { $0.isUnlocked }.count }
    private var progress: Double { achievements.isEmpty ? 0 : Double(unlockedCount) / Double(achievements.count) }

    var body: some View {
        VStack(spacing: 0) {
            // Game header — tap to collapse/expand
            Button {
                onToggle()
            } label: {
                HStack(spacing: 14) {
                    coverThumbnail
                    VStack(alignment: .leading, spacing: 5) {
                        Text(game.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        HStack(spacing: 10) {
                            Text("\(unlockedCount)/\(achievements.count) completed")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.50))
                            miniProgressBar
                        }
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.40))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.08))

                VStack(spacing: 0) {
                    ForEach(Array(achievements.enumerated()), id: \.element.id) { index, achievement in
                        AchievementRow(achievement: achievement)
                        if index < achievements.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.leading, 74)
                        }
                    }
                }
            }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        if let cover = game.coverImage {
            Image(cover)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [game.color, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 72, height: 42)
                .overlay(
                    Image(systemName: "gamecontroller.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.40))
                )
        }
    }

    private var miniProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(width: 80, height: 5)
    }
}

// MARK: - Row

struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 14) {
            iconView

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(achievement.isUnlocked ? .white : .white.opacity(0.35))
                    .lineLimit(1)
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(achievement.isUnlocked ? 0.52 : 0.25))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: achievement.rarity.badgeIcon)
                        .font(.caption2.weight(.bold))
                    Text(achievement.rarity.rawValue)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(achievement.isUnlocked ? achievement.rarity.color : .white.opacity(0.22))

                if achievement.isUnlocked {
                    Text("Completed")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green.opacity(0.85))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(achievement.isUnlocked
                    ? achievement.rarity.color.opacity(0.15)
                    : Color.white.opacity(0.05))
                .frame(width: 44, height: 44)
            Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(achievement.isUnlocked ? achievement.rarity.color : .white.opacity(0.22))
        }
    }
}
