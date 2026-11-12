import WidgetKit
import SwiftUI

// MARK: - Shared Data
struct WidgetPlayerData: Codable {
    let name: String
    let winrate: Double
    let kda: Double
    let gamesPlayed: Int
    let rank: String?
    let updatedAt: Date
}

// MARK: - Timeline Provider
struct StatsWatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsWatchEntry {
        StatsWatchEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsWatchEntry) -> Void) {
        let data = loadWidgetData() ?? .placeholder
        completion(StatsWatchEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsWatchEntry>) -> Void) {
        let data = loadWidgetData() ?? .placeholder
        let entry = StatsWatchEntry(date: Date(), data: data)
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadWidgetData() -> WidgetPlayerData? {
        let defaults = UserDefaults(suiteName: "group.WilliamGuo.StatsWatch")
        guard let data = defaults?.data(forKey: "widget_player_data") else { return nil }
        return try? JSONDecoder().decode(WidgetPlayerData.self, from: data)
    }
}

// MARK: - Entry
struct StatsWatchEntry: TimelineEntry {
    let date: Date
    let data: WidgetPlayerData
}

extension WidgetPlayerData {
    static let placeholder = WidgetPlayerData(
        name: "Player#1234",
        winrate: 52.3,
        kda: 3.15,
        gamesPlayed: 142,
        rank: "Gold",
        updatedAt: Date()
    )
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let entry: StatsWatchEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text("StatsWatch")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            Text(entry.data.name)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(1)

            if let rank = entry.data.rank {
                Text(rank)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.cyan)
            }

            Spacer()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "%.1f%%", entry.data.winrate))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(entry.data.winrate >= 50 ? .green : .red)
                    Text("Win Rate")
                        .font(.system(size: 7))
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "%.2f", entry.data.kda))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("KDA")
                        .font(.system(size: 7))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: StatsWatchEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("StatsWatch")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                Text(entry.data.name)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)

                if let rank = entry.data.rank {
                    Text(rank)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.cyan)
                }

                Spacer()

                Text(entry.data.updatedAt, style: .relative)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(spacing: 10) {
                WidgetStatItem(
                    label: "Win Rate",
                    value: String(format: "%.1f%%", entry.data.winrate),
                    color: entry.data.winrate >= 50 ? .green : .red
                )
                WidgetStatItem(
                    label: "KDA",
                    value: String(format: "%.2f", entry.data.kda),
                    color: .primary
                )
                WidgetStatItem(
                    label: "Games",
                    value: "\(entry.data.gamesPlayed)",
                    color: .blue
                )
            }
        }
        .padding(14)
    }
}

struct WidgetStatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}

struct StatsWatchWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatsWatchEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration
struct StatsWatchWidget: Widget {
    let kind: String = "StatsWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsWatchProvider()) { entry in
            StatsWatchWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("StatsWatch")
        .description("View your Overwatch stats at a glance")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle
@main
struct StatsWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsWatchWidget()
    }
}
