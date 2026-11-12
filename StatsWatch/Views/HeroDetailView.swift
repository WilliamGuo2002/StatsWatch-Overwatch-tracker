import SwiftUI

struct HeroDetailView: View {
    let hero: HeroWithStats
    let viewModel: PlayerViewModel

    private var heroName: String {
        viewModel.heroInfo(for: hero.key)?.name ?? hero.key.capitalized
    }

    private var heroRole: String {
        viewModel.heroInfo(for: hero.key)?.role ?? HeroRoles.role(for: hero.key)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero header
                HeroDetailHeader(
                    hero: hero,
                    heroName: heroName,
                    heroRole: heroRole,
                    portraitURL: viewModel.heroPortraitURL(for: hero.key)
                )

                // Key stats
                HeroKeyStats(hero: hero)

                // Per-hero radar chart
                VStack(spacing: 8) {
                    Text("Performance Profile")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    RadarChartView(
                        data: heroRadarData,
                        accentColor: roleColor
                    )
                    .frame(height: 250)
                    .padding(.horizontal)
                }

                // Detailed average stats
                HeroAverageStats(hero: hero)

                // Total stats
                HeroTotalStats(hero: hero)

                // Comparison with your overall average
                if let general = viewModel.statsSummary?.general {
                    HeroVsOverallComparison(hero: hero, general: general)
                }

                // Hero-specific and personal best stats from career data
                if let categories = viewModel.careerStatsForHero(hero.key) {
                    HeroCareerHighlights(categories: categories, accentColor: roleColor)
                }

                // Career stats link
                NavigationLink {
                    CareerStatsView(viewModel: viewModel, heroKey: hero.key, heroName: heroName)
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 15))
                            .foregroundStyle(.purple)
                            .frame(width: 24)
                        Text("Detailed Career Stats")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .padding(14)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [roleColor.opacity(0.06), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(heroName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var roleColor: Color {
        switch heroRole {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        default: return .blue
        }
    }

    private var heroRadarData: [PlayerViewModel.RadarDataPoint] {
        let avg = hero.stats.average
        let elims = avg?.eliminations ?? 0
        let assists = avg?.assists ?? 0
        let deaths = avg?.deaths ?? 0
        let damage = avg?.damage ?? 0
        let healing = avg?.healing ?? 0

        let survivability = max(0, 1.0 - (deaths / 15.0))

        return [
            .init(label: "Elims", value: min(1, elims / 25.0)),
            .init(label: "Assists", value: min(1, assists / 15.0)),
            .init(label: "Survival", value: min(1, survivability)),
            .init(label: "Damage", value: min(1, damage / 12000.0)),
            .init(label: "Healing", value: min(1, healing / 8000.0)),
        ]
    }
}

// MARK: - Hero Detail Header
struct HeroDetailHeader: View {
    let hero: HeroWithStats
    let heroName: String
    let heroRole: String
    let portraitURL: URL?

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: portraitURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            .overlay(Circle().stroke(roleColor.opacity(0.3), lineWidth: 2))

            VStack(alignment: .leading, spacing: 6) {
                Text(heroName)
                    .font(.system(size: 24, weight: .bold))

                HStack(spacing: 6) {
                    Image(systemName: roleIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(roleColor)
                    Text(heroRole.capitalized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(roleColor)
                }

                Text("\(hero.stats.gamesPlayed ?? 0) games • \(formatTimePlayed(seconds: hero.stats.timePlayed ?? 0))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var roleIcon: String {
        switch heroRole {
        case "tank": return "shield.fill"
        case "damage": return "bolt.fill"
        case "support": return "cross.fill"
        default: return "circle.fill"
        }
    }

    private var roleColor: Color {
        switch heroRole {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        default: return .blue
        }
    }
}

// MARK: - Key Stats
struct HeroKeyStats: View {
    let hero: HeroWithStats

    var body: some View {
        HStack(spacing: 0) {
            KeyStatItem(
                title: "Win Rate",
                value: String(format: "%.1f%%", hero.stats.winrate ?? 0),
                color: (hero.stats.winrate ?? 0) >= 50 ? .green : .red
            )
            Divider().frame(height: 36)
            KeyStatItem(
                title: "KDA",
                value: String(format: "%.2f", hero.stats.kda ?? 0),
                color: .primary
            )
            Divider().frame(height: 36)
            KeyStatItem(
                title: "W/L",
                value: "\(hero.stats.gamesWon ?? 0)/\(hero.stats.gamesLost ?? 0)",
                color: .primary
            )
        }
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct KeyStatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Average Stats (Per 10 Min)
struct HeroAverageStats: View {
    let hero: HeroWithStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Average Per 10 Min")
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 8) {
                AvgStatCell(label: "Eliminations", value: String(format: "%.1f", hero.stats.average?.eliminations ?? 0))
                AvgStatCell(label: "Assists", value: String(format: "%.1f", hero.stats.average?.assists ?? 0))
                AvgStatCell(label: "Deaths", value: String(format: "%.1f", hero.stats.average?.deaths ?? 0))
                AvgStatCell(label: "Damage", value: String(format: "%.0f", hero.stats.average?.damage ?? 0))
                AvgStatCell(label: "Healing", value: String(format: "%.0f", hero.stats.average?.healing ?? 0))
            }
            .padding(.horizontal)
        }
    }
}

struct AvgStatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Total Stats
struct HeroTotalStats: View {
    let hero: HeroWithStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Totals")
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 8) {
                TotalStatCell(label: "Eliminations", value: "\(hero.stats.total?.eliminations ?? 0)")
                TotalStatCell(label: "Assists", value: "\(hero.stats.total?.assists ?? 0)")
                TotalStatCell(label: "Deaths", value: "\(hero.stats.total?.deaths ?? 0)")
                TotalStatCell(label: "Damage", value: formatLarge(hero.stats.total?.damage ?? 0))
                TotalStatCell(label: "Healing", value: formatLarge(hero.stats.total?.healing ?? 0))
            }
            .padding(.horizontal)
        }
    }

    private func formatLarge(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

struct TotalStatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Hero vs Overall Comparison
struct HeroVsOverallComparison: View {
    let hero: HeroWithStats
    let general: GeneralStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("vs Your Overall Average")
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal)

            VStack(spacing: 6) {
                ComparisonRow(
                    label: "Win Rate",
                    heroValue: hero.stats.winrate ?? 0,
                    overallValue: general.winrate ?? 0,
                    format: "%.1f%%"
                )
                ComparisonRow(
                    label: "KDA",
                    heroValue: hero.stats.kda ?? 0,
                    overallValue: general.kda ?? 0,
                    format: "%.2f"
                )
                ComparisonRow(
                    label: "Elims/10min",
                    heroValue: hero.stats.average?.eliminations ?? 0,
                    overallValue: general.average?.eliminations ?? 0,
                    format: "%.1f"
                )
                ComparisonRow(
                    label: "Deaths/10min",
                    heroValue: hero.stats.average?.deaths ?? 0,
                    overallValue: general.average?.deaths ?? 0,
                    format: "%.1f",
                    lowerIsBetter: true
                )
                ComparisonRow(
                    label: "Dmg/10min",
                    heroValue: hero.stats.average?.damage ?? 0,
                    overallValue: general.average?.damage ?? 0,
                    format: "%.0f"
                )
                ComparisonRow(
                    label: "Heal/10min",
                    heroValue: hero.stats.average?.healing ?? 0,
                    overallValue: general.average?.healing ?? 0,
                    format: "%.0f"
                )
            }
            .padding(.horizontal)
        }
    }
}

struct ComparisonRow: View {
    let label: String
    let heroValue: Double
    let overallValue: Double
    var format: String = "%.1f"
    var lowerIsBetter: Bool = false

    private var diff: Double { heroValue - overallValue }
    private var isBetter: Bool { lowerIsBetter ? diff < 0 : diff > 0 }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Text(String(format: format, heroValue))
                .font(.system(size: 13, weight: .bold, design: .rounded))

            if diff != 0 {
                let absDiff = abs(diff)
                HStack(spacing: 2) {
                    Image(systemName: isBetter ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8))
                    Text(String(format: format, absDiff))
                        .font(.system(size: 10))
                }
                .foregroundStyle(isBetter ? .green : .red)
                .frame(width: 65, alignment: .trailing)
            } else {
                Text("—")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 65, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct HeroCareerHighlights: View {
    let categories: [CareerStatCategory]
    let accentColor: Color

    private func stats(_ category: String) -> [CareerStat] {
        (categories.first { $0.category == category }?.stats ?? [])
            .filter { ($0.value?.doubleValue ?? 0) > 0 }
    }

    var body: some View {
        VStack(spacing: 14) {
            let specific = stats("hero_specific")
            if !specific.isEmpty {
                HighlightGrid(title: "Hero Specific", icon: "sparkles", color: accentColor, stats: specific)
            }
            let best = stats("best")
            if !best.isEmpty {
                HighlightGrid(title: "Personal Bests", icon: "medal.fill", color: .orange, stats: best)
            }
        }
    }
}

struct HighlightGrid: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    let stats: [CareerStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(stats) { stat in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedValue(stat))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                        Text(stat.label ?? stat.key ?? "")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal)
        }
    }

    private func formattedValue(_ stat: CareerStat) -> String {
        let key = stat.key ?? ""
        let value = stat.value?.doubleValue ?? 0
        if key.contains("time") {
            return formatTimePlayed(seconds: Int(value))
        }
        if key.contains("accuracy") || key.contains("percentage") {
            return String(format: "%.0f%%", value)
        }
        return stat.value?.displayString ?? "-"
    }
}
