import SwiftUI

struct RecentSummarySection: View {
    let viewModel: PlayerViewModel
    let playerId: String
    @State private var period: SummaryPeriod = .today

    enum SummaryPeriod: CaseIterable {
        case today, week

        var title: LocalizedStringKey {
            switch self {
            case .today: return "Today"
            case .week: return "This Week"
            }
        }
    }

    private let storage = LocalStorageService.shared

    private var periodStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch period {
        case .today: return today
        case .week: return calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? today
        }
    }

    // Latest snapshot before the period; for the week view, fall back to the earliest one inside it.
    private var baseline: StatSnapshot? {
        let snapshots = storage.getSnapshots(for: playerId, gamemode: viewModel.selectedMode.rawValue)
        if let before = snapshots.first(where: { $0.date < periodStart }) { return before }
        return period == .week ? snapshots.last(where: { $0.date >= periodStart }) : nil
    }

    private var rankBaseline: RankSnapshot? {
        let snapshots = storage.getRankSnapshots(for: playerId)
        if let before = snapshots.last(where: { $0.date < periodStart }) { return before }
        return period == .week ? snapshots.first(where: { $0.date >= periodStart }) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Summary")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Picker("Period", selection: $period) {
                    ForEach(SummaryPeriod.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            if let base = baseline, let general = viewModel.statsSummary?.general {
                summaryContent(base: base, general: general)
            } else {
                Text("Your summary appears once a snapshot from before this period exists. Stats are saved each time you open this profile.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func summaryContent(base: StatSnapshot, general: GeneralStats) -> some View {
        let games = max(0, (general.gamesPlayed ?? 0) - base.gamesPlayed)
        let wins = min(games, max(0, (general.gamesWon ?? 0) - base.derivedGamesWon))
        let kdaDelta = (general.kda ?? 0) - base.kda

        Text("Compared with \(base.date, format: .dateTime.month().day().hour().minute())")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

        if games == 0 {
            Text("No new games since then")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 10) {
                SummaryStatCell(title: "Games", value: "\(games)", color: .primary)
                SummaryStatCell(title: "W-L", value: "\(wins)-\(games - wins)", color: .primary)
                SummaryStatCell(
                    title: "Win Rate",
                    value: String(format: "%.0f%%", Double(wins) / Double(games) * 100),
                    color: wins * 2 >= games ? .green : .red
                )
                SummaryStatCell(
                    title: "KDA",
                    value: String(format: "%+.2f", kdaDelta),
                    color: kdaDelta >= 0 ? .green : .red
                )
            }
        }

        let changes = rankChanges
        if !changes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(changes, id: \.role) { change in
                    RankChangeRow(role: change.role, from: change.from, to: change.to)
                }
            }
            .padding(.top, 2)
        }
    }

    private var rankChanges: [(role: String, from: Int, to: Int)] {
        guard let base = rankBaseline, let current = viewModel.displayedRanks else { return [] }
        let now = RankScore.scores(for: current)
        return RankScore.roles.compactMap { role in
            guard let from = base.scores[role], let to = now[role] else { return nil }
            return (role, from, to)
        }
    }
}

struct SummaryStatCell: View {
    let title: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct RankChangeRow: View {
    let role: String
    let from: Int
    let to: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: RoleStyle.icon(role))
                .font(.system(size: 11))
                .foregroundStyle(RoleStyle.color(role))
                .frame(width: 16)
            Text(RoleStyle.name(role))
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(RankScore.localizedLabel(forScore: from))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(RankScore.localizedLabel(forScore: to))
                .font(.system(size: 12, weight: .semibold))
            if to != from {
                Text(to > from ? "▲\(to - from)" : "▼\(from - to)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(to > from ? .green : .red)
            }
        }
    }
}

enum RoleStyle {
    static func icon(_ role: String) -> String {
        switch role {
        case "tank": return "shield.fill"
        case "damage": return "bolt.fill"
        case "support": return "cross.fill"
        case "open": return "person.3.fill"
        default: return "circle.fill"
        }
    }

    static func color(_ role: String) -> Color {
        switch role {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        case "open": return .purple
        default: return .gray
        }
    }

    static func name(_ role: String) -> LocalizedStringKey {
        switch role {
        case "tank": return "Tank"
        case "damage": return "DPS"
        case "support": return "Support"
        case "open": return "Open 6v6"
        default: return LocalizedStringKey(role.capitalized)
        }
    }
}

extension RankScore {
    static func localizedLabel(forScore score: Int) -> LocalizedStringKey {
        "\(Text(LocalizedStringKey(divisionName(forScore: score)))) \(5 - score % 5)"
    }
}
