import SwiftUI

struct PlayStyleCard: View {
    let viewModel: PlayerViewModel

    private var selectedRole: String? {
        viewModel.selectedRadarRole
    }

    private var analysis: PlayStyleAnalysis {
        PlayStyleAnalysis(viewModel: viewModel, selectedRole: selectedRole)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Play Style Profile")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                if let role = selectedRole {
                    Text(role.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(analysis.traitColor)
                        .clipShape(Capsule())
                }
            }

            // Main card
            VStack(spacing: 14) {
                // Style type badge
                Text(analysis.styleType)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: analysis.styleGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text(analysis.styleSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Divider()

                // Trait tags
                FlowLayout(spacing: 8) {
                    ForEach(analysis.traits, id: \.self) { trait in
                        Text(trait)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(analysis.traitColor.opacity(0.12))
                            .foregroundStyle(analysis.traitColor)
                            .clipShape(Capsule())
                    }
                }

                Divider()

                // Key insights
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(analysis.insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                                .padding(.top, 2)
                            Text(insight)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // Signature hero (filtered by role if selected)
                if let topHero = analysis.signatureHero {
                    HStack(spacing: 10) {
                        AsyncImage(url: viewModel.heroPortraitURL(for: topHero.key)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.2))
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedRole != nil ? "Top \(selectedRole!.capitalized) Hero" : "Signature Hero")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(viewModel.heroInfo(for: topHero.key)?.name ?? topHero.key.capitalized)
                                .font(.system(size: 14, weight: .bold))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.0f%%", topHero.stats.winrate ?? 0))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle((topHero.stats.winrate ?? 0) >= 50 ? .green : .red)
                            Text("\(topHero.stats.gamesPlayed ?? 0) games")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }
}

// MARK: - Play Style Analysis Engine
struct PlayStyleAnalysis {
    let viewModel: PlayerViewModel
    var selectedRole: String? = nil

    // Role-specific stat accessors
    private var elims: Double {
        if let role = selectedRole, let r = viewModel.statsSummary?.roles?[role] {
            return r.average?.eliminations ?? 0
        }
        return viewModel.elimsPer10
    }

    private var deaths: Double {
        if let role = selectedRole, let r = viewModel.statsSummary?.roles?[role] {
            return r.average?.deaths ?? 0
        }
        return viewModel.deathsPer10
    }

    private var assists: Double {
        viewModel.assistsPer10(for: selectedRole)
    }

    private var damage: Double {
        if let role = selectedRole, let r = viewModel.statsSummary?.roles?[role] {
            return r.average?.damage ?? 0
        }
        return viewModel.damagePer10
    }

    private var healing: Double {
        if let role = selectedRole, let r = viewModel.statsSummary?.roles?[role] {
            return r.average?.healing ?? 0
        }
        return viewModel.healingPer10
    }

    private var winRate: Double {
        if let role = selectedRole, let r = viewModel.statsSummary?.roles?[role] {
            return r.winrate ?? 0
        }
        return viewModel.overallWinRate
    }

    private var kda: Double {
        if let role = selectedRole, let r = viewModel.statsSummary?.roles?[role] {
            return r.kda ?? 0
        }
        return viewModel.overallKDA
    }

    private var gamesPlayed: Int {
        if let role = selectedRole, let r = viewModel.statsSummary?.roles?[role] {
            return r.gamesPlayed ?? 0
        }
        return viewModel.overallGamesPlayed
    }

    var styleType: String {
        let role = selectedRole ?? dominantRole
        let aggression = aggressionScore

        switch role {
        case "damage":
            if aggression > 0.7 { return "Aggressive Slayer" }
            if elims > 18 { return "Precision Striker" }
            if damage > 8000 { return "Damage Machine" }
            return "Steady Damage Dealer"
        case "tank":
            if aggression > 0.6 { return "Frontline Brawler" }
            if deaths < 4 { return "Unbreakable Wall" }
            if damage > 9000 { return "Battle Tank" }
            return "Protective Guardian"
        case "support":
            if elims > 10 { return "Battle Medic" }
            if healing > 7000 { return "Healing Engine" }
            if healing > 5000 { return "Dedicated Healer" }
            if assists > 8 { return "Enabler" }
            return "Utility Support"
        default:
            if heroPoolSize > 10 { return "Flex Master" }
            return "Versatile Player"
        }
    }

    var styleSubtitle: String {
        let wr = winRate
        let games = gamesPlayed
        let roleLabel = selectedRole?.capitalized

        if let roleLabel = roleLabel {
            if wr >= 55 && games > 50 { return "Dominating as \(roleLabel) — a proven winner" }
            if wr >= 50 { return "Solid \(roleLabel) performance — holding your own" }
            if games < 20 { return "Still building your \(roleLabel) experience" }
            return "Room to grow as \(roleLabel)"
        } else {
            if wr >= 55 && games > 100 { return "A proven winner with a dominant track record" }
            if wr >= 50 { return "Consistent performer who holds their own" }
            if games < 50 { return "Still finding your stride — keep going!" }
            return "Room to grow with dedication"
        }
    }

    var traits: [String] {
        var result: [String] = []

        let role = selectedRole ?? dominantRole

        // Role tag
        if selectedRole != nil {
            result.append("\(role.capitalized) Player")
        } else {
            result.append("\(dominantRole.capitalized) Main")
        }

        // Aggression
        if aggressionScore > 0.65 { result.append("High Aggression") }
        else if aggressionScore < 0.35 { result.append("Passive Playstyle") }

        // Survivability (role-adjusted thresholds)
        let lowDeathThreshold: Double = (role == "tank") ? 4 : (role == "support" ? 4 : 5)
        let highDeathThreshold: Double = (role == "tank") ? 7 : (role == "support" ? 7 : 8)
        if deaths < lowDeathThreshold { result.append("Hard to Kill") }
        else if deaths > highDeathThreshold { result.append("Risk Taker") }

        // Role-specific traits
        switch role {
        case "tank":
            if damage > 8000 { result.append("Damage Tank") }
            if elims > 20 { result.append("Brawler") }
        case "damage":
            if elims > 20 { result.append("Frag Hunter") }
            if damage > 9000 { result.append("DPS Monster") }
        case "support":
            if healing > 6000 { result.append("Heal Bot") }
            if assists > 8 { result.append("Team Player") }
            if damage > 3500 { result.append("DPS Support") }
        default:
            break
        }

        // Hero pool
        if selectedRole == nil {
            if heroPoolSize >= 8 { result.append("Wide Hero Pool") }
            else if heroPoolSize <= 3 { result.append("One-Trick Specialist") }
        } else {
            if roleHeroPoolSize >= 4 { result.append("Versatile \(role.capitalized)") }
            else if roleHeroPoolSize <= 1 { result.append("One-Trick") }
        }

        // Team player (general)
        if selectedRole == nil && assists > 6 { result.append("Team Player") }

        // Impact
        if kda > 3.0 { result.append("High Impact") }

        return result
    }

    var insights: [String] {
        var result: [String] = []

        if let role = selectedRole {
            // Role-specific insights
            let roleName = role == "damage" ? "DPS" : role.capitalized

            // Win rate insight for role
            if winRate >= 55 {
                result.append("Excellent \(roleName) win rate at \(String(format: "%.0f%%", winRate)) — this is one of your strengths")
            } else if winRate < 45 && gamesPlayed > 20 {
                result.append("Your \(roleName) win rate (\(String(format: "%.0f%%", winRate))) needs work — focus on improving fundamentals")
            }

            // Best hero in this role
            let roleHeroes = viewModel.allHeroesSorted.filter {
                HeroRoles.role(for: $0.key) == role && ($0.stats.gamesPlayed ?? 0) >= 5
            }
            if let best = roleHeroes.max(by: { ($0.stats.winrate ?? 0) < ($1.stats.winrate ?? 0) }) {
                let name = viewModel.heroInfo(for: best.key)?.name ?? best.key.capitalized
                result.append("Best \(roleName) hero: \(name) at \(String(format: "%.0f%%", best.stats.winrate ?? 0)) win rate")
            }

            // Role-specific stat insights
            switch role {
            case "tank":
                if damage > 9000 {
                    result.append("Your tank damage (\(String(format: "%.0f", damage))/10min) is excellent — great space creation")
                }
                if deaths > 6 {
                    result.append("Consider playing more conservatively — \(String(format: "%.1f", deaths)) deaths/10min is high for a tank")
                }
            case "damage":
                if elims > 20 {
                    result.append("Strong frag output at \(String(format: "%.1f", elims)) elims/10min")
                }
                if damage < 6000 {
                    result.append("Your DPS output (\(String(format: "%.0f", damage))/10min) could be higher — try to find more value")
                }
            case "support":
                if healing > 6000 {
                    result.append("Great healing output at \(String(format: "%.0f", healing))/10min")
                }
                if damage > 3000 && healing > 4000 {
                    result.append("Good balance between damage and healing — a well-rounded support")
                }
            default: break
            }

            // KDA for role
            if kda >= 3.0 {
                result.append("\(roleName) KDA of \(String(format: "%.1f", kda)) is excellent")
            } else if kda < 1.5 {
                result.append("Your \(roleName) KDA needs improvement — focus on fewer deaths")
            }
        } else {
            // General insights (original)
            if let bestRole = viewModel.roleStats.max(by: { ($0.stats.winrate ?? 0) < ($1.stats.winrate ?? 0) }) {
                let roleName = bestRole.key == "damage" ? "DPS" : bestRole.key.capitalized
                result.append("Your strongest role is \(roleName) at \(String(format: "%.0f%%", bestRole.stats.winrate ?? 0)) win rate")
            }

            if let best = viewModel.allHeroesSorted.filter({ ($0.stats.gamesPlayed ?? 0) >= 5 }).max(by: { ($0.stats.winrate ?? 0) < ($1.stats.winrate ?? 0) }) {
                let name = viewModel.heroInfo(for: best.key)?.name ?? best.key.capitalized
                result.append("Your best hero is \(name) with \(String(format: "%.0f%%", best.stats.winrate ?? 0)) win rate")
            }

            if kda >= 3.0 {
                result.append("Your KDA of \(String(format: "%.1f", kda)) is excellent — you're getting great value per life")
            } else if kda < 1.5 {
                result.append("Try to focus on dying less — your KDA has room for improvement")
            }
        }

        return result
    }

    var signatureHero: HeroWithStats? {
        if let role = selectedRole {
            return viewModel.topHeroes.first { HeroRoles.role(for: $0.key) == role }
        }
        return viewModel.topHeroes.first
    }

    var styleGradient: [Color] {
        let role = selectedRole ?? dominantRole
        switch role {
        case "tank": return [.blue, .cyan]
        case "damage": return [.red, .orange]
        case "support": return [.green, .mint]
        default: return [.purple, .blue]
        }
    }

    var traitColor: Color {
        let role = selectedRole ?? dominantRole
        switch role {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        default: return .purple
        }
    }

    // MARK: - Private Helpers
    private var dominantRole: String {
        viewModel.roleStats
            .max(by: { ($0.stats.gamesPlayed ?? 0) < ($1.stats.gamesPlayed ?? 0) })?
            .key ?? "damage"
    }

    private var aggressionScore: Double {
        // Normalize and combine
        let elimScore = min(1, elims / 25.0)
        let damageScore = min(1, damage / 10000.0)
        let deathPenalty = min(1, deaths / 12.0)

        return (elimScore * 0.4 + damageScore * 0.4 + deathPenalty * 0.2)
    }

    private var heroPoolSize: Int {
        viewModel.allHeroesSorted.filter { ($0.stats.gamesPlayed ?? 0) >= 5 }.count
    }

    private var roleHeroPoolSize: Int {
        guard let role = selectedRole else { return heroPoolSize }
        return viewModel.allHeroesSorted.filter {
            HeroRoles.role(for: $0.key) == role && ($0.stats.gamesPlayed ?? 0) >= 5
        }.count
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
