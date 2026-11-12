import SwiftUI

// MARK: - Smart Coach Section (displayed on profile page)
struct SmartCoachSection: View {
    let viewModel: PlayerViewModel

    private var selectedRole: String? {
        viewModel.selectedRadarRole
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
                Text("Smart Coach")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                if let role = selectedRole {
                    Text(role.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(roleColor(role))
                        .clipShape(Capsule())
                } else {
                    Text("All Roles")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Role Recommendation
            RoleRecommendationCard(viewModel: viewModel, selectedRole: selectedRole)

            // Rank Estimation
            RankEstimationCard(viewModel: viewModel, selectedRole: selectedRole)

            // Hero Pool Analysis
            HeroPoolAnalysisCard(viewModel: viewModel, selectedRole: selectedRole)

            // Coach Tips
            CoachTipsCard(viewModel: viewModel, selectedRole: selectedRole)
        }
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        default: return .gray
        }
    }
}

// MARK: - Role Recommendation
struct RoleRecommendationCard: View {
    let viewModel: PlayerViewModel
    var selectedRole: String? = nil

    private var roleRankings: [(role: String, score: Double, winrate: Double, kda: Double, games: Int)] {
        guard let roles = viewModel.statsSummary?.roles else { return [] }
        return ["tank", "damage", "support"].compactMap { key in
            guard let r = roles[key], (r.gamesPlayed ?? 0) >= 3 else { return nil }
            let wr = r.winrate ?? 0
            let kda = r.kda ?? 0
            let games = r.gamesPlayed ?? 0
            // Weighted score: winrate most important, then KDA, then experience
            let score = wr * 0.6 + min(kda * 10, 30) * 0.25 + min(Double(games), 50) * 0.15
            return (role: key, score: score, winrate: wr, kda: kda, games: games)
        }.sorted { $0.score > $1.score }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundStyle(.green)
                Text("Queue Recommendation")
                    .font(.system(size: 15, weight: .bold))
            }

            if roleRankings.isEmpty {
                Text("Play at least 3 games per role to get recommendations")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(roleRankings.enumerated()), id: \.element.role) { index, r in
                    HStack(spacing: 10) {
                        // Rank badge
                        ZStack {
                            Circle()
                                .fill(index == 0 ? Color.green.opacity(0.15) : Color(.systemGray5))
                                .frame(width: 28, height: 28)
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(index == 0 ? .green : .secondary)
                        }

                        Image(systemName: roleIcon(r.role))
                            .foregroundStyle(roleColor(r.role))
                            .font(.system(size: 13))

                        Text(r.role.capitalized)
                            .font(.system(size: 13, weight: .semibold))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(format: "%.1f%% WR", r.winrate))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(r.winrate >= 50 ? .green : .red)
                            Text("\(r.games) games")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }

                        if r.role == selectedRole {
                            Text("SELECTED")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(roleColor(r.role))
                                .clipShape(Capsule())
                        } else if index == 0 {
                            Text("BEST")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func roleIcon(_ role: String) -> String {
        switch role {
        case "tank": return "shield.fill"
        case "damage": return "bolt.fill"
        case "support": return "cross.fill"
        default: return "circle.fill"
        }
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        default: return .gray
        }
    }
}

// MARK: - Rank Estimation
struct RankEstimationCard: View {
    let viewModel: PlayerViewModel
    var selectedRole: String? = nil

    // Approximate per-10 benchmarks by rank tier — general
    private static let generalBenchmarks: [(rank: String, icon: String, color: Color, elims: Double, deaths: Double, damage: Double, healing: Double)] = [
        ("Bronze",   "circle.fill",       .brown,  8,  9, 3500, 2000),
        ("Silver",   "diamond.fill",      .gray,   11, 8, 4500, 3000),
        ("Gold",     "star.fill",         .yellow,  14, 7, 6000, 4000),
        ("Platinum", "shield.fill",       .cyan,   17, 6.5, 7500, 5000),
        ("Diamond",  "bolt.fill",         .blue,   20, 6, 9000, 6000),
        ("Master",   "crown.fill",        .purple, 23, 5.5, 10500, 7000),
        ("GM",       "star.circle.fill",  .orange, 26, 5, 12000, 8000),
    ]

    // Role-specific benchmarks
    private static let tankBenchmarks: [(rank: String, icon: String, color: Color, elims: Double, deaths: Double, damage: Double, healing: Double)] = [
        ("Bronze",   "circle.fill",       .brown,  10, 8, 5000, 300),
        ("Silver",   "diamond.fill",      .gray,   13, 7, 6500, 400),
        ("Gold",     "star.fill",         .yellow,  16, 6.5, 8000, 500),
        ("Platinum", "shield.fill",       .cyan,   19, 6, 9500, 600),
        ("Diamond",  "bolt.fill",         .blue,   22, 5.5, 11000, 700),
        ("Master",   "crown.fill",        .purple, 25, 5, 12500, 800),
        ("GM",       "star.circle.fill",  .orange, 28, 4.5, 14000, 1000),
    ]

    private static let damageBenchmarks: [(rank: String, icon: String, color: Color, elims: Double, deaths: Double, damage: Double, healing: Double)] = [
        ("Bronze",   "circle.fill",       .brown,  9,  9, 4000, 100),
        ("Silver",   "diamond.fill",      .gray,   13, 8, 5500, 150),
        ("Gold",     "star.fill",         .yellow,  17, 7, 7000, 200),
        ("Platinum", "shield.fill",       .cyan,   20, 6.5, 8500, 200),
        ("Diamond",  "bolt.fill",         .blue,   23, 6, 10000, 250),
        ("Master",   "crown.fill",        .purple, 26, 5.5, 11500, 300),
        ("GM",       "star.circle.fill",  .orange, 29, 5, 13000, 350),
    ]

    private static let supportBenchmarks: [(rank: String, icon: String, color: Color, elims: Double, deaths: Double, damage: Double, healing: Double)] = [
        ("Bronze",   "circle.fill",       .brown,  5,  8, 2000, 4000),
        ("Silver",   "diamond.fill",      .gray,   7,  7, 2800, 5000),
        ("Gold",     "star.fill",         .yellow,  9,  6.5, 3500, 6000),
        ("Platinum", "shield.fill",       .cyan,   11, 6, 4200, 7000),
        ("Diamond",  "bolt.fill",         .blue,   13, 5.5, 5000, 8000),
        ("Master",   "crown.fill",        .purple, 15, 5, 5800, 9000),
        ("GM",       "star.circle.fill",  .orange, 17, 4.5, 6500, 10000),
    ]

    private var benchmarks: [(rank: String, icon: String, color: Color, elims: Double, deaths: Double, damage: Double, healing: Double)] {
        switch selectedRole {
        case "tank": return Self.tankBenchmarks
        case "damage": return Self.damageBenchmarks
        case "support": return Self.supportBenchmarks
        default: return Self.generalBenchmarks
        }
    }

    private var estimation: (rank: String, icon: String, color: Color, confidence: Double, roleLabel: String?)? {
        let avg: StatAverages?

        if let role = selectedRole, let roleEntry = viewModel.statsSummary?.roles?[role] {
            avg = roleEntry.average
        } else {
            avg = viewModel.statsSummary?.general?.average
        }

        guard let avg = avg else { return nil }
        let elims = avg.eliminations ?? 0
        let deaths = avg.deaths ?? 0
        let damage = avg.damage ?? 0
        let healing = avg.healing ?? 0

        guard elims > 0 || damage > 0 else { return nil }

        var bestIndex = 0
        var bestScore = Double.infinity

        for (i, b) in benchmarks.enumerated() {
            let elimDiff = abs(elims - b.elims) / max(b.elims, 1)
            let deathDiff = abs(deaths - b.deaths) / max(b.deaths, 1)
            let dmgDiff = abs(damage - b.damage) / max(b.damage, 1)
            let healDiff = abs(healing - b.healing) / max(b.healing, 1)
            let score = elimDiff * 0.3 + deathDiff * 0.25 + dmgDiff * 0.25 + healDiff * 0.2
            if score < bestScore {
                bestScore = score
                bestIndex = i
            }
        }

        let confidence = max(0.3, min(1.0, 1.0 - bestScore))
        let b = benchmarks[bestIndex]
        return (rank: b.rank, icon: b.icon, color: b.color, confidence: confidence, roleLabel: selectedRole?.capitalized)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.dots.scatter")
                    .foregroundStyle(.orange)
                Text("Stats-Based Rank Reference")
                    .font(.system(size: 15, weight: .bold))
            }

            if let est = estimation {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(est.color.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: est.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(est.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("~\(est.rank)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(est.color)
                            if let roleLabel = est.roleLabel {
                                Text(roleLabel)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(est.color.opacity(0.7))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(est.roleLabel != nil ? "Rough reference from \(est.roleLabel!) per-10min stats" : "Rough reference from per-10min stats")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        // Confidence bar
                        HStack(spacing: 4) {
                            Text("Confidence")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(.systemGray5))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(est.color.opacity(0.6))
                                        .frame(width: geo.size.width * CGFloat(est.confidence))
                                }
                            }
                            .frame(width: 60, height: 4)
                            Text(String(format: "%.0f%%", est.confidence * 100))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Disclaimer
                Text("⚠️ Only based on elims/deaths/damage/healing averages. Real rank also depends on accuracy, positioning, ult economy, team play and more.")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Not enough stat data for estimation")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Hero Pool Analysis
struct HeroPoolAnalysisCard: View {
    let viewModel: PlayerViewModel
    var selectedRole: String? = nil

    private struct PoolAnalysis {
        let totalHeroes: Int
        let tankCount: Int
        let damageCount: Int
        let supportCount: Int
        let missingSubroles: [String]
        let diversityScore: Double // 0-100
        let oneHeroTrick: String? // if >60% time on one hero
        let roleLabel: String?
    }

    private var analysis: PoolAnalysis? {
        guard let heroes = viewModel.statsSummary?.heroes, !heroes.isEmpty else { return nil }

        // Only count heroes with meaningful playtime (>= 2 games)
        let meaningful = heroes.filter { ($0.value.gamesPlayed ?? 0) >= 2 }

        // If a role is selected, filter to that role only
        if let role = selectedRole {
            let roleHeroes = meaningful.filter { HeroRoles.role(for: $0.key) == role }
            let heroCount = roleHeroes.count
            var missing: [String] = []

            // Role-specific subrole checks
            switch role {
            case "tank":
                let hasShield = roleHeroes.keys.contains(where: { ["reinhardt", "sigma", "ramattra", "orisa"].contains($0) })
                let hasDive = roleHeroes.keys.contains(where: { ["winston", "dva", "wrecking-ball", "doomfist"].contains($0) })
                if !hasShield { missing.append("Shield Tank") }
                if !hasDive { missing.append("Dive Tank") }
            case "damage":
                let hasHitscan = roleHeroes.keys.contains(where: { ["soldier-76", "cassidy", "ashe", "widowmaker", "sojourn"].contains($0) })
                let hasProjectile = roleHeroes.keys.contains(where: { ["pharah", "junkrat", "hanzo", "genji", "echo"].contains($0) })
                let hasFlanker = roleHeroes.keys.contains(where: { ["tracer", "genji", "sombra", "reaper"].contains($0) })
                if !hasHitscan { missing.append("Hitscan") }
                if !hasProjectile { missing.append("Projectile") }
                if !hasFlanker { missing.append("Flanker") }
            case "support":
                let hasMainHeal = roleHeroes.keys.contains(where: { ["ana", "baptiste", "moira", "kiriko"].contains($0) })
                let hasFlexHeal = roleHeroes.keys.contains(where: { ["lucio", "mercy", "zenyatta", "brigitte"].contains($0) })
                if !hasMainHeal { missing.append("Main Healer") }
                if !hasFlexHeal { missing.append("Flex Support") }
            default: break
            }

            // Diversity for single role
            let maxExpected: Double = role == "damage" ? 5 : (role == "support" ? 4 : 3)
            let diversity = min(Double(heroCount), maxExpected) / maxExpected * 100

            // One-trick within role
            let totalTime = roleHeroes.values.reduce(0) { $0 + ($1.timePlayed ?? 0) }
            let topHero = roleHeroes.max { ($0.value.timePlayed ?? 0) < ($1.value.timePlayed ?? 0) }
            var otp: String? = nil
            if let top = topHero, totalTime > 0 {
                let ratio = Double(top.value.timePlayed ?? 0) / Double(totalTime)
                if ratio > 0.6 {
                    otp = viewModel.heroInfo(for: top.key)?.name ?? top.key.capitalized
                }
            }

            return PoolAnalysis(
                totalHeroes: heroCount,
                tankCount: role == "tank" ? heroCount : 0,
                damageCount: role == "damage" ? heroCount : 0,
                supportCount: role == "support" ? heroCount : 0,
                missingSubroles: missing,
                diversityScore: diversity,
                oneHeroTrick: otp,
                roleLabel: role.capitalized
            )
        }

        // All roles analysis (original logic)
        let tanks = meaningful.filter { HeroRoles.role(for: $0.key) == "tank" }
        let dps = meaningful.filter { HeroRoles.role(for: $0.key) == "damage" }
        let supports = meaningful.filter { HeroRoles.role(for: $0.key) == "support" }

        // Check for missing subroles
        var missing: [String] = []
        if tanks.isEmpty { missing.append("Tank") }
        if dps.isEmpty { missing.append("DPS") }
        if supports.isEmpty { missing.append("Support") }

        // Check sub-categories
        let hasShieldTank = tanks.keys.contains(where: { ["reinhardt", "sigma", "ramattra", "orisa"].contains($0) })
        let hasDiveTank = tanks.keys.contains(where: { ["winston", "dva", "wrecking-ball", "doomfist"].contains($0) })
        let hasHitscan = dps.keys.contains(where: { ["soldier-76", "cassidy", "ashe", "widowmaker", "sojourn"].contains($0) })
        let hasProjectile = dps.keys.contains(where: { ["pharah", "junkrat", "hanzo", "genji", "echo"].contains($0) })
        let hasMainHeal = supports.keys.contains(where: { ["ana", "baptiste", "moira", "kiriko"].contains($0) })
        let hasFlexHeal = supports.keys.contains(where: { ["lucio", "mercy", "zenyatta", "brigitte"].contains($0) })

        if !tanks.isEmpty && !hasShieldTank { missing.append("Shield Tank") }
        if !tanks.isEmpty && !hasDiveTank { missing.append("Dive Tank") }
        if !dps.isEmpty && !hasHitscan { missing.append("Hitscan DPS") }
        if !dps.isEmpty && !hasProjectile { missing.append("Projectile DPS") }
        if !supports.isEmpty && !hasMainHeal { missing.append("Main Healer") }
        if !supports.isEmpty && !hasFlexHeal { missing.append("Flex Support") }

        // Diversity score
        let heroCount = meaningful.count
        let tankBalance: Double = min(Double(tanks.count), 3) / 3 * 0.33
        let dpsBalance: Double = min(Double(dps.count), 5) / 5 * 0.33
        let supportBalance: Double = min(Double(supports.count), 4) / 4 * 0.34
        let roleBalance = tankBalance + dpsBalance + supportBalance
        let diversity = (min(Double(heroCount), 12) / 12 * 0.5 + roleBalance * 0.5) * 100

        // One-trick check
        let totalTime = heroes.values.reduce(0) { $0 + ($1.timePlayed ?? 0) }
        let topHero = heroes.max { ($0.value.timePlayed ?? 0) < ($1.value.timePlayed ?? 0) }
        var otp: String? = nil
        if let top = topHero, totalTime > 0 {
            let ratio = Double(top.value.timePlayed ?? 0) / Double(totalTime)
            if ratio > 0.6 {
                otp = viewModel.heroInfo(for: top.key)?.name ?? top.key.capitalized
            }
        }

        return PoolAnalysis(
            totalHeroes: heroCount,
            tankCount: tanks.count,
            damageCount: dps.count,
            supportCount: supports.count,
            missingSubroles: missing,
            diversityScore: diversity,
            oneHeroTrick: otp,
            roleLabel: nil
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(.cyan)
                Text("Hero Pool Analysis")
                    .font(.system(size: 15, weight: .bold))
            }

            if let a = analysis {
                // Diversity score
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 4)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: CGFloat(a.diversityScore / 100))
                            .stroke(diversityColor(a.diversityScore), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        Text(String(format: "%.0f", a.diversityScore))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Diversity: \(diversityLabel(a.diversityScore))")
                            .font(.system(size: 13, weight: .semibold))
                        if let roleLabel = a.roleLabel {
                            Text("\(a.totalHeroes) \(roleLabel) heroes played")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(a.totalHeroes) heroes (\(a.tankCount)T / \(a.damageCount)D / \(a.supportCount)S)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // One-trick warning
                if let otp = a.oneHeroTrick {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 11))
                        Text("One-trick alert: >60% playtime on **\(otp)**")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    }
                }

                // Missing subroles
                if !a.missingSubroles.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gaps in hero pool:")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        FlowLayoutCompact {
                            ForEach(a.missingSubroles, id: \.self) { sub in
                                Text(sub)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            } else {
                Text("Not enough data to analyze hero pool")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func diversityColor(_ score: Double) -> Color {
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }

    private func diversityLabel(_ score: Double) -> String {
        if score >= 70 { return "Versatile" }
        if score >= 40 { return "Moderate" }
        return "Narrow"
    }
}

// Simple flow layout for compact tag display
struct FlowLayoutCompact: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, width: proposal.width ?? 300)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, pos) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxWidth = max(maxWidth, x)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Coach Tips
struct CoachTipsCard: View {
    let viewModel: PlayerViewModel
    var selectedRole: String? = nil

    private var tips: [(icon: String, color: Color, text: String)] {
        var result: [(icon: String, color: Color, text: String)] = []

        let wr: Double
        let kda: Double
        let deaths: Double
        let elims: Double
        let damage: Double
        let healing: Double
        let assists: Double
        let roleName: String

        if let role = selectedRole, let roleEntry = viewModel.statsSummary?.roles?[role] {
            // Use role-specific stats
            wr = roleEntry.winrate ?? 0
            kda = roleEntry.kda ?? 0
            deaths = roleEntry.average?.deaths ?? 0
            elims = roleEntry.average?.eliminations ?? 0
            damage = roleEntry.average?.damage ?? 0
            healing = roleEntry.average?.healing ?? 0
            assists = viewModel.assistsPer10(for: role)
            roleName = role.capitalized
        } else if let general = viewModel.statsSummary?.general {
            // Use general stats
            wr = general.winrate ?? 0
            kda = general.kda ?? 0
            deaths = general.average?.deaths ?? 0
            elims = general.average?.eliminations ?? 0
            damage = general.average?.damage ?? 0
            healing = general.average?.healing ?? 0
            assists = viewModel.assistsPer10
            roleName = "Overall"
        } else {
            return []
        }

        // Role-specific thresholds
        let highDeathThreshold: Double
        let lowDeathThreshold: Double
        switch selectedRole {
        case "tank": highDeathThreshold = 7; lowDeathThreshold = 3.5
        case "damage": highDeathThreshold = 9; lowDeathThreshold = 4
        case "support": highDeathThreshold = 7; lowDeathThreshold = 3
        default: highDeathThreshold = 8; lowDeathThreshold = 4
        }

        // Death analysis
        if deaths > highDeathThreshold {
            result.append(("exclamationmark.triangle.fill", .red,
                "[\(roleName)] Deaths (\(String(format: "%.1f", deaths))/10min) are high. Focus on positioning and using cover more effectively."))
        } else if deaths < lowDeathThreshold {
            result.append(("checkmark.circle.fill", .green,
                "[\(roleName)] Excellent survival rate (\(String(format: "%.1f", deaths))/10min). Your positioning is strong."))
        }

        // Win rate analysis
        if wr < 45 {
            result.append(("arrow.down.circle.fill", .red,
                "[\(roleName)] Win rate is below average (\(String(format: "%.1f%%", wr))). Consider focusing on your best heroes in this role."))
        } else if wr >= 55 {
            result.append(("flame.fill", .orange,
                "[\(roleName)] Strong win rate of \(String(format: "%.1f%%", wr))! You're performing well."))
        }

        // KDA analysis
        if kda < 2.0 {
            result.append(("target", .orange,
                "[\(roleName)] KDA of \(String(format: "%.2f", kda)) could improve. Try to trade more efficiently."))
        } else if kda >= 4.0 {
            result.append(("star.fill", .yellow,
                "[\(roleName)] Outstanding KDA of \(String(format: "%.2f", kda)). Your fight impact is excellent."))
        }

        // Role-specific tips
        switch selectedRole {
        case "tank":
            if damage < 6000 {
                result.append(("shield.fill", .blue,
                    "[Tank] Your damage output (\(String(format: "%.0f", damage))/10min) is low. Tanks need to create space through damage pressure."))
            }
            if deaths > 6 && elims < 15 {
                result.append(("exclamationmark.shield.fill", .orange,
                    "[Tank] High deaths with low elims — you may be overextending. Play with your team and time engagements better."))
            }
        case "damage":
            if damage < 5000 {
                result.append(("bolt.fill", .red,
                    "[DPS] Damage output (\(String(format: "%.0f", damage))/10min) is below average. Focus on consistent damage and target priority."))
            }
            if elims < 12 {
                result.append(("scope", .orange,
                    "[DPS] Eliminations (\(String(format: "%.1f", elims))/10min) could be higher. Look for picks on out-of-position enemies."))
            }
        case "support":
            if healing < 5000 {
                result.append(("cross.fill", .blue,
                    "[Support] Healing output (\(String(format: "%.0f", healing))/10min) is low. Prioritize keeping your team alive."))
            }
            if damage > 4000 && healing < 5000 {
                result.append(("bolt.fill", .orange,
                    "[Support] High damage but low healing — balance your playstyle. Heal first, damage in safe windows."))
            }
            if assists > 8 {
                result.append(("hand.thumbsup.fill", .green,
                    "[Support] Great assist count (\(String(format: "%.1f", assists))/10min)! You're enabling your team well."))
            }
        default:
            // General tips (no role selected)
            if damage > 5000 && healing < 1000 {
                result.append(("bolt.fill", .red,
                    "Very aggressive style (high damage, low healing). If you're Support, try to balance healing and damage output."))
            }
            if healing > 5000 && damage < 2000 {
                result.append(("cross.fill", .blue,
                    "You're heal-focused. Consider adding some damage during safe moments to help finish low-HP targets."))
            }
            if assists < 2 && elims > 10 {
                result.append(("person.2.fill", .purple,
                    "Low assists (\(String(format: "%.1f", assists))/10min) despite good elims. Try to play more with your team."))
            }
        }

        // Hero pool advice for selected role
        if let heroes = viewModel.statsSummary?.heroes {
            let roleHeroes: [String: HeroStatEntry]
            if let role = selectedRole {
                roleHeroes = heroes.filter { HeroRoles.role(for: $0.key) == role && ($0.value.gamesPlayed ?? 0) >= 5 }
            } else {
                roleHeroes = heroes.filter { ($0.value.gamesPlayed ?? 0) >= 5 }
            }
            if roleHeroes.count < 2 {
                let roleText = selectedRole?.capitalized ?? "total"
                result.append(("person.3.sequence.fill", .cyan,
                    "You have \(roleHeroes.count) \(roleText) hero(es) with 5+ games. Expanding your pool gives you more flexibility."))
            }
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Personalized Tips")
                    .font(.system(size: 15, weight: .bold))
            }

            if tips.isEmpty {
                Text("Play more games to get personalized coaching tips")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: tip.icon)
                            .foregroundStyle(tip.color)
                            .font(.system(size: 12))
                            .frame(width: 16, alignment: .center)
                            .padding(.top, 2)

                        Text(tip.text)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
