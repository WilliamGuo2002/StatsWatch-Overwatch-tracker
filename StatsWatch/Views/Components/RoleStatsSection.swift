import SwiftUI

struct RoleStatsSection: View {
    let viewModel: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Role Stats")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.roleStats) { role in
                        RoleCard(role: role, assistDeathRatio: viewModel.roleAssistDeathRatio(for: role.key))
                            .frame(width: roleCardWidth)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var roleCardWidth: CGFloat {
        let count = viewModel.roleStats.count
        if count <= 3 {
            // Fit all cards on screen with spacing
            return (UIScreen.main.bounds.width - 32 - CGFloat(count - 1) * 10) / CGFloat(count)
        }
        // Show partial next card to hint scrolling
        return (UIScreen.main.bounds.width - 32 - 20) / 3.3
    }
}

struct RoleCard: View {
    let role: RoleWithStats
    let assistDeathRatio: Double?

    var body: some View {
        VStack(spacing: 8) {
            // Role header
            HStack(spacing: 6) {
                Image(systemName: roleIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)

                Text(roleDisplayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(roleColor)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 10,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 10
            ))

            VStack(spacing: 6) {
                RoleStatRow(label: "Games", value: "\(role.stats.gamesPlayed ?? 0)")
                RoleStatRow(label: "WR", value: String(format: "%.1f%%", role.stats.winrate ?? 0))
                RoleStatRow(label: "KDA", value: String(format: "%.2f", role.stats.kda ?? 0))
                switch role.key {
                case "tank", "damage":
                    RoleStatRow(label: "KD", value: formatRatio(role.stats.killDeathRatio))
                case "support":
                    RoleStatRow(label: "AD", value: formatRatio(assistDeathRatio))
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(roleColor.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatRatio(_ value: Double?) -> String {
        value.map { String(format: "%.2f", $0) } ?? "-"
    }

    private var roleDisplayName: String {
        switch role.key {
        case "tank": return "Tank"
        case "damage": return "DPS"
        case "support": return "Support"
        case "open": return "Open 6v6"
        default: return role.key.capitalized
        }
    }

    private var roleIcon: String {
        switch role.key {
        case "tank": return "shield.fill"
        case "damage": return "bolt.fill"
        case "support": return "cross.fill"
        case "open": return "person.3.fill"
        default: return "circle.fill"
        }
    }

    private var roleColor: Color {
        switch role.key {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        case "open": return .purple
        default: return .gray
        }
    }
}

struct RoleStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
    }
}
