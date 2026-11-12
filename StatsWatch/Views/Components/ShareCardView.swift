import SwiftUI

struct ShareCardView: View {
    let viewModel: PlayerViewModel
    let playerId: String
    @State private var shareImage: UIImage?
    @State private var isSharing = false
    @State private var avatarImage: UIImage?
    @State private var rankIcons: [String: UIImage] = [:] // key: "tank"/"damage"/"support"/"open"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Preview
                ShareCardContent(
                    viewModel: viewModel,
                    avatarImage: avatarImage,
                    rankIcons: rankIcons
                )
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Share button
                Button {
                    let renderer = ImageRenderer(content:
                        ShareCardContent(
                            viewModel: viewModel,
                            avatarImage: avatarImage,
                            rankIcons: rankIcons
                        )
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 400)
                    )
                    renderer.scale = 3
                    if let image = renderer.uiImage {
                        shareImage = image
                        isSharing = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Stats Card")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Share Card")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isSharing) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
        .task {
            // Pre-download avatar
            if let urlStr = viewModel.playerSummary?.avatar, let url = URL(string: urlStr) {
                avatarImage = await downloadImage(url: url)
            }
            // Pre-download rank icons
            if let ranks = viewModel.displayedRanks {
                let roleRanks: [(String, RankInfo?)] = [
                    ("tank", ranks.tank),
                    ("damage", ranks.damage),
                    ("support", ranks.support),
                    ("open", ranks.open),
                ]
                for (key, rank) in roleRanks {
                    if let iconURL = rank?.rankIcon, let url = URL(string: iconURL) {
                        if let img = await downloadImage(url: url) {
                            rankIcons[key] = img
                        }
                    }
                }
            }
        }
    }

    private func downloadImage(url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Card Content (rendered to image)
struct ShareCardContent: View {
    let viewModel: PlayerViewModel
    var avatarImage: UIImage? = nil
    var rankIcons: [String: UIImage] = [:]

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack(spacing: 12) {
                // Avatar — use pre-downloaded UIImage for ImageRenderer
                if let avatar = avatarImage {
                    Image(uiImage: avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.currentPlayerId.map { formatBattleTag(from: $0) } ?? viewModel.playerSummary?.username ?? "Player")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        Text(viewModel.selectedMode == .competitive ? "Competitive" : "Quick Play")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                        if let season = viewModel.displayedRanks?.displaySeason {
                            Text("S\(season)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("StatsWatch")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("OW Tracker")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Divider().background(Color.white.opacity(0.2))

            // Competitive ranks (only in competitive mode)
            if viewModel.selectedMode == .competitive, let ranks = viewModel.displayedRanks {
                ShareRanksSection(ranks: ranks, rankIcons: rankIcons)
                Divider().background(Color.white.opacity(0.2))
            }

            // Main stats
            HStack(spacing: 0) {
                ShareStatItem(label: "Win Rate", value: String(format: "%.1f%%", viewModel.overallWinRate), color: .green)
                ShareStatItem(label: "KDA", value: String(format: "%.2f", viewModel.overallKDA), color: .cyan)
                ShareStatItem(label: "Games", value: "\(viewModel.overallGamesPlayed)", color: .orange)
                ShareStatItem(label: "Hours", value: "\(viewModel.totalPlayTimeHours)", color: .purple)
            }

            Divider().background(Color.white.opacity(0.2))

            // Per 10min
            HStack(spacing: 0) {
                ShareMiniStat(label: "Elims/10", value: String(format: "%.1f", viewModel.elimsPer10))
                ShareMiniStat(label: "Deaths/10", value: String(format: "%.1f", viewModel.deathsPer10))
                ShareMiniStat(label: "Dmg/10", value: formatShort(viewModel.damagePer10))
                ShareMiniStat(label: "Heal/10", value: formatShort(viewModel.healingPer10))
            }

            // Top heroes
            if !viewModel.topHeroes.isEmpty {
                Divider().background(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 6) {
                    Text("TOP HEROES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))

                    HStack(spacing: 8) {
                        ForEach(viewModel.topHeroes.prefix(3)) { hero in
                            let name = viewModel.heroInfo(for: hero.key)?.name ?? hero.key.capitalized
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(roleColor(for: hero.key).opacity(0.5))
                                    .frame(width: 24, height: 24)
                                    .overlay {
                                        Image(systemName: roleIcon(for: hero.key))
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white)
                                    }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(name)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(String(format: "%.0f%%", hero.stats.winrate ?? 0))
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func formatShort(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fK", v / 1000) }
        return String(format: "%.0f", v)
    }

    private func roleColor(for key: String) -> Color {
        switch HeroRoles.role(for: key) {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        default: return .gray
        }
    }

    private func roleIcon(for key: String) -> String {
        switch HeroRoles.role(for: key) {
        case "tank": return "shield.fill"
        case "damage": return "bolt.fill"
        case "support": return "cross.fill"
        default: return "circle.fill"
        }
    }
}

// MARK: - Competitive Ranks in Share Card
struct ShareRanksSection: View {
    let ranks: PlatformRanks
    var rankIcons: [String: UIImage] = [:]

    private var allRoles: [(key: String, label: String, icon: String, rank: RankInfo?, color: Color)] {
        [
            ("tank", "Tank", "shield.fill", ranks.tank, .blue),
            ("damage", "DPS", "bolt.fill", ranks.damage, .red),
            ("support", "Support", "cross.fill", ranks.support, .green),
            ("open", "6v6", "person.3.fill", ranks.open, .purple),
        ]
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("COMPETITIVE RANKS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                if let season = ranks.displaySeason {
                    Text("Season \(season)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 6) {
                ForEach(allRoles.filter { $0.rank != nil }, id: \.key) { role in
                    ShareRankItem(
                        label: role.label,
                        icon: role.icon,
                        rank: role.rank!,
                        color: role.color,
                        rankIconImage: rankIcons[role.key]
                    )
                }
            }
        }
    }
}

struct ShareRankItem: View {
    let label: String
    let icon: String
    let rank: RankInfo
    let color: Color
    var rankIconImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 4) {
            // Role icon
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)

            // Rank icon (pre-downloaded)
            if let img = rankIconImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            } else {
                // Fallback: text-based rank display
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(rankShortText)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(color)
                    }
            }

            // Division + tier text
            Text(rankDisplayText)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)

            Text(label)
                .font(.system(size: 7))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private var rankDisplayText: String {
        let div = rank.division?.capitalized ?? "?"
        if let tier = rank.tier {
            return "\(div) \(tier)"
        }
        return div
    }

    private var rankShortText: String {
        guard let div = rank.division else { return "?" }
        switch div {
        case "bronze": return "B"
        case "silver": return "S"
        case "gold": return "G"
        case "platinum": return "P"
        case "diamond": return "D"
        case "master": return "M"
        case "grandmaster": return "GM"
        case "ultimate": return "U"
        default: return String(div.prefix(1)).uppercased()
        }
    }
}

struct ShareStatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShareMiniStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - UIKit Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
