import SwiftUI

enum HeroRecordMetric: String, CaseIterable {
    case timePlayed = "time_played"
    case gamesWon = "games_won"
    case winPercentage = "win_percentage"
    case weaponAccuracy = "weapon_accuracy_best_in_game"
    case eliminationsPerLife = "eliminations_per_life"
    case killStreak = "kill_streak_best"
    case multikill = "multikill_best"
    case eliminations = "eliminations_avg_per_10_min"
    case finalBlows = "final_blows_avg_per_10_min"
    case soloKills = "solo_kills_avg_per_10_min"
    case objectiveKills = "objective_kills_avg_per_10_min"
    case objectiveTime = "objective_time_avg_per_10_min"
    case heroDamage = "hero_damage_done_avg_per_10_min"
    case healing = "healing_done_avg_per_10_min"
    case deaths = "deaths_avg_per_10_min"

    var title: LocalizedStringKey {
        switch self {
        case .timePlayed: return "Time Played"
        case .gamesWon: return "Games Won"
        case .winPercentage: return "Win Rate"
        case .weaponAccuracy: return "Best Accuracy in Game"
        case .eliminationsPerLife: return "Elims per Life"
        case .killStreak: return "Best Kill Streak"
        case .multikill: return "Best Multikill"
        case .eliminations: return "Elims / 10 min"
        case .finalBlows: return "Final Blows / 10 min"
        case .soloKills: return "Solo Kills / 10 min"
        case .objectiveKills: return "Objective Kills / 10 min"
        case .objectiveTime: return "Objective Time / 10 min"
        case .heroDamage: return "Hero Damage / 10 min"
        case .healing: return "Healing / 10 min"
        case .deaths: return "Fewest Deaths / 10 min"
        }
    }

    var icon: String {
        switch self {
        case .timePlayed: return "clock.fill"
        case .gamesWon, .winPercentage: return "trophy.fill"
        case .weaponAccuracy: return "scope"
        case .eliminationsPerLife, .eliminations, .finalBlows, .soloKills: return "flame.fill"
        case .killStreak, .multikill: return "bolt.fill"
        case .objectiveKills, .objectiveTime: return "flag.fill"
        case .heroDamage: return "burst.fill"
        case .healing: return "cross.fill"
        case .deaths: return "heart.fill"
        }
    }

    var lowerIsBetter: Bool { self == .deaths }

    func format(_ value: Double) -> String {
        switch self {
        case .timePlayed:
            return formatTimePlayed(seconds: Int(value))
        case .winPercentage, .weaponAccuracy:
            return String(format: "%.0f%%", value)
        case .gamesWon, .killStreak, .multikill, .heroDamage, .healing:
            return String(format: "%.0f", value)
        case .objectiveTime:
            let seconds = Int(value)
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        default:
            return String(format: "%.2f", value)
        }
    }
}

struct HeroRecordsView: View {
    let viewModel: PlayerViewModel
    let playerId: String
    @State private var metrics: [String: HeroComparisonMetric] = [:]
    @State private var selectedMetric: HeroRecordMetric = .timePlayed
    @State private var isLoading = true
    @State private var errorMessage: LocalizedStringKey?

    private var availableMetrics: [HeroRecordMetric] {
        HeroRecordMetric.allCases.filter { !(values(for: $0).isEmpty) }
    }

    private func values(for metric: HeroRecordMetric) -> [HeroComparisonValue] {
        let list = (metrics[metric.rawValue]?.values ?? []).filter { $0.value > 0 }
        return metric.lowerIsBetter
            ? list.sorted { $0.value < $1.value }
            : list.sorted { $0.value > $1.value }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    Text(viewModel.selectedMode.displayName)
                    if let platform = viewModel.selectedPlatform, !viewModel.availablePlatforms.isEmpty {
                        Text("·")
                        Text(platform.displayName)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                        .padding(.horizontal)
                } else if availableMetrics.isEmpty {
                    Text("No hero records available")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                } else {
                    metricPicker
                    recordList
                }
            }
            .padding(.vertical, 12)
        }
        .navigationTitle("Hero Records")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.ensureHeroesLoaded()
            await load()
        }
    }

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableMetrics, id: \.self) { metric in
                    let isSelected = metric == selectedMetric
                    Button {
                        selectedMetric = metric
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 10))
                            Text(metric.title)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        }
                        .foregroundStyle(isSelected ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? Color.orange : Color.clear)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var recordList: some View {
        let list = values(for: selectedMetric)
        let best = list.map(\.value).max() ?? 1
        return VStack(spacing: 8) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                HeroRecordRow(
                    rank: index + 1,
                    name: viewModel.heroInfo(for: item.hero)?.name ?? item.hero.capitalized,
                    portraitURL: viewModel.heroPortraitURL(for: item.hero),
                    role: viewModel.heroRole(for: item.hero),
                    valueText: selectedMetric.format(item.value),
                    ratio: selectedMetric.lowerIsBetter ? (list.first?.value ?? 0) / max(item.value, 0.01) : item.value / max(best, 0.01)
                )
            }
        }
        .padding(.horizontal)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            metrics = try await OverwatchAPIService.shared.getHeroComparisons(
                playerId: playerId,
                gamemode: viewModel.selectedMode,
                platform: viewModel.selectedPlatform
            )
            if !availableMetrics.contains(selectedMetric), let first = availableMetrics.first {
                selectedMetric = first
            }
        } catch {
            errorMessage = APIError.from(error).message
        }
        isLoading = false
    }
}

struct HeroRecordRow: View {
    let rank: Int
    let name: String
    let portraitURL: URL?
    let role: String
    let valueText: String
    let ratio: Double

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? .orange : .secondary)
                .frame(width: 24)

            AsyncImage(url: portraitURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(roleColor.opacity(0.15))
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())
            .overlay(Circle().stroke(roleColor.opacity(0.3), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 5) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(roleColor.opacity(0.45))
                        .frame(width: geo.size.width * min(1, max(0, ratio)), height: 4)
                }
                .frame(height: 4)
            }

            Text(valueText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var roleColor: Color {
        switch role {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        default: return .gray
        }
    }
}
