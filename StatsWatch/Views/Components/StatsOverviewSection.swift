import SwiftUI

struct StatsOverviewSection: View {
    let viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Main stats row: Win Rate, KDA, Play Time
            HStack(spacing: 10) {
                StatCard(
                    title: "Win Rate",
                    value: String(format: "%.1f%%", viewModel.overallWinRate),
                    subtitle: "\(viewModel.overallGamesWon)/\(viewModel.overallGamesPlayed)"
                )

                StatCard(
                    title: "KDA",
                    value: String(format: "%.2f", viewModel.overallKDA),
                    subtitle: "\(viewModel.totalEliminations)/\(viewModel.totalDeaths)/\(viewModel.statsSummary?.general?.total?.assists ?? 0)"
                )

                StatCard(
                    title: "Play Time",
                    value: "\(viewModel.totalPlayTimeHours)",
                    valueSuffix: "hrs",
                    subtitle: "\(viewModel.overallGamesPlayed) games"
                )
            }

            // Per 10 min stats row
            HStack(spacing: 10) {
                MiniStatCard(title: "Elims/10min", value: String(format: "%.2f", viewModel.elimsPer10))
                MiniStatCard(title: "Deaths/10min", value: String(format: "%.2f", viewModel.deathsPer10))
                MiniStatCard(title: "Assists/10min", value: String(format: "%.2f", viewModel.assistsPer10))
            }

            // Expandable detailed stats
            if viewModel.showExpandedStats {
                HStack(spacing: 10) {
                    MiniStatCard(title: "Dmg/10min", value: String(format: "%.0f", viewModel.damagePer10))
                    MiniStatCard(title: "Heal/10min", value: String(format: "%.0f", viewModel.healingPer10))
                }

                // Total stats
                HStack(spacing: 10) {
                    MiniStatCard(title: "Total Elims", value: "\(viewModel.totalEliminations)")
                    MiniStatCard(title: "Total Deaths", value: "\(viewModel.totalDeaths)")
                    MiniStatCard(title: "Total Assists", value: "\(viewModel.totalAssists)")
                }

                HStack(spacing: 10) {
                    MiniStatCard(title: "Total Damage", value: formatLargeNumber(viewModel.statsSummary?.general?.total?.damage ?? 0))
                    MiniStatCard(title: "Total Healing", value: formatLargeNumber(viewModel.statsSummary?.general?.total?.healing ?? 0))
                }
            }

            // Expand/Collapse button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.showExpandedStats.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.showExpandedStats ? "Show Less" : "Show More")
                        .font(.system(size: 13))
                    Image(systemName: viewModel.showExpandedStats ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal)
    }

    private func formatLargeNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }
}

// MARK: - Stat Card (Large)
struct StatCard: View {
    let title: String
    let value: String
    var valueSuffix: String? = nil
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                if let suffix = valueSuffix {
                    Text(suffix)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Mini Stat Card
struct MiniStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
