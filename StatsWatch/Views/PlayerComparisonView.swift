import SwiftUI

@Observable
class PlayerComparisonViewModel {
    var player1Tag = ""
    var player2Tag = ""
    var player1Summary: PlayerSummary?
    var player2Summary: PlayerSummary?
    var player1Stats: PlayerStatsSummary?
    var player2Stats: PlayerStatsSummary?
    var isLoading = false
    var errorMessage: LocalizedStringKey?
    var hasCompared = false
    var selectedMode: GameMode = .competitive

    private let api = OverwatchAPIService.shared

    func compare() async {
        let tag1 = player1Tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag2 = player2Tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag1.isEmpty, !tag2.isEmpty else {
            errorMessage = "Please enter both BattleTags"
            return
        }

        let id1 = tag1.replacingOccurrences(of: "#", with: "-")
        let id2 = tag2.replacingOccurrences(of: "#", with: "-")

        isLoading = true
        errorMessage = nil
        hasCompared = false

        do {
            async let s1 = api.getPlayerSummary(playerId: id1)
            async let s2 = api.getPlayerSummary(playerId: id2)
            async let st1 = api.getPlayerStatsSummary(playerId: id1, gamemode: selectedMode)
            async let st2 = api.getPlayerStatsSummary(playerId: id2, gamemode: selectedMode)

            player1Summary = try await s1
            player2Summary = try await s2
            player1Stats = try await st1
            player2Stats = try await st2
            hasCompared = true
        } catch {
            errorMessage = APIError.from(error).message
        }

        isLoading = false
    }
}

struct PlayerComparisonView: View {
    @State private var vm = PlayerComparisonViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Input section
                VStack(spacing: 10) {
                    PlayerTagInput(label: String(localized: "Player 1"), placeholder: "Player 1 BattleTag (Name#1234)", text: $vm.player1Tag, color: .blue)
                    Text("VS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                    PlayerTagInput(label: String(localized: "Player 2"), placeholder: "Player 2 BattleTag (Name#1234)", text: $vm.player2Tag, color: .orange)
                }
                .padding(.horizontal)

                // Mode picker
                Picker("Mode", selection: $vm.selectedMode) {
                    Text("Competitive").tag(GameMode.competitive)
                    Text("Quick Play").tag(GameMode.quickplay)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Compare button
                Button {
                    Task { await vm.compare() }
                } label: {
                    HStack {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        }
                        Text("Compare")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(colors: [.blue, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(vm.player1Tag.isEmpty || vm.player2Tag.isEmpty || vm.isLoading)
                .padding(.horizontal)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                // Results
                if vm.hasCompared {
                    // Player headers
                    PVPHeaderSection(
                        p1: vm.player1Summary,
                        p2: vm.player2Summary,
                        p1Tag: vm.player1Tag,
                        p2Tag: vm.player2Tag
                    )

                    // Overall stats comparison
                    if let s1 = vm.player1Stats?.general, let s2 = vm.player2Stats?.general {
                        PVPStatsSection(title: "Overall", stats1: s1, stats2: s2)
                    }

                    // Role breakdown
                    PVPRoleSection(
                        roles1: vm.player1Stats?.roles,
                        roles2: vm.player2Stats?.roles,
                        p1Name: vm.player1Summary?.username ?? "P1",
                        p2Name: vm.player2Summary?.username ?? "P2"
                    )
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Player vs Player")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PlayerTagInput: View {
    let label: String
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(color)
                        .font(.system(size: 14))
                }
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - PVP Header
struct PVPHeaderSection: View {
    let p1: PlayerSummary?
    let p2: PlayerSummary?
    let p1Tag: String
    let p2Tag: String

    var body: some View {
        HStack(spacing: 0) {
            PVPPlayerCard(summary: p1, tag: p1Tag, color: .blue)
            Text("VS")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            PVPPlayerCard(summary: p2, tag: p2Tag, color: .orange)
        }
        .padding(.horizontal)
    }
}

struct PVPPlayerCard: View {
    let summary: PlayerSummary?
    let tag: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: URL(string: summary?.avatar ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(color.opacity(0.15))
                    .overlay { Image(systemName: "person.fill").foregroundStyle(color) }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 2))

            Text(tag.contains("#") ? tag : formatBattleTag(from: tag.replacingOccurrences(of: "#", with: "-")))
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            if let level = summary?.endorsement?.level {
                Text("Endorsement \(level)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PVP Stats Section
struct PVPStatsSection: View {
    let title: LocalizedStringKey
    let stats1: GeneralStats
    let stats2: GeneralStats

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            VStack(spacing: 4) {
                PVPStatBar(label: "Win Rate", v1: stats1.winrate ?? 0, v2: stats2.winrate ?? 0, format: "%.1f%%", higherIsBetter: true)
                PVPStatBar(label: "KDA", v1: stats1.kda ?? 0, v2: stats2.kda ?? 0, format: "%.2f", higherIsBetter: true)
                PVPStatBar(label: "Games", v1: Double(stats1.gamesPlayed ?? 0), v2: Double(stats2.gamesPlayed ?? 0), format: "%.0f", higherIsBetter: true)
                PVPStatBar(label: "Elims/10", v1: stats1.average?.eliminations ?? 0, v2: stats2.average?.eliminations ?? 0, format: "%.1f", higherIsBetter: true)
                PVPStatBar(label: "Deaths/10", v1: stats1.average?.deaths ?? 0, v2: stats2.average?.deaths ?? 0, format: "%.1f", higherIsBetter: false)
                PVPStatBar(label: "Dmg/10", v1: stats1.average?.damage ?? 0, v2: stats2.average?.damage ?? 0, format: "%.0f", higherIsBetter: true)
                PVPStatBar(label: "Heal/10", v1: stats1.average?.healing ?? 0, v2: stats2.average?.healing ?? 0, format: "%.0f", higherIsBetter: true)
                PVPStatBar(label: "Assists/10", v1: stats1.average?.assists ?? 0, v2: stats2.average?.assists ?? 0, format: "%.1f", higherIsBetter: true)
            }
            .padding(.horizontal)
        }
    }
}

struct PVPStatBar: View {
    let label: String
    let v1: Double
    let v2: Double
    var format: String = "%.1f"
    var higherIsBetter: Bool = true

    private var p1Wins: Bool {
        higherIsBetter ? v1 > v2 : v1 < v2
    }

    var body: some View {
        HStack(spacing: 6) {
            // P1 value
            Text(String(format: format, v1))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(p1Wins && v1 != v2 ? .blue : .primary)
                .frame(width: 55, alignment: .trailing)

            // Bar
            GeometryReader { geo in
                let total = v1 + v2
                let ratio1 = total > 0 ? CGFloat(v1 / total) : 0.5

                HStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue.opacity(p1Wins ? 0.7 : 0.25))
                        .frame(width: geo.size.width * ratio1)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange.opacity(!p1Wins ? 0.7 : 0.25))
                }
            }
            .frame(height: 8)

            // P2 value
            Text(String(format: format, v2))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(!p1Wins && v1 != v2 ? .orange : .primary)
                .frame(width: 55, alignment: .leading)
        }
        .overlay(alignment: .center) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .background(Color(.systemBackground).opacity(0.8))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - PVP Role Section
struct PVPRoleSection: View {
    let roles1: [String: RoleStatEntry]?
    let roles2: [String: RoleStatEntry]?
    let p1Name: String
    let p2Name: String

    private let roleOrder = ["tank", "damage", "support"]

    var body: some View {
        VStack(spacing: 8) {
            Text("Role Breakdown")
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            ForEach(roleOrder, id: \.self) { role in
                let r1 = roles1?[role]
                let r2 = roles2?[role]
                if r1 != nil || r2 != nil {
                    PVPRoleRow(
                        role: role,
                        r1: r1,
                        r2: r2,
                        p1Name: p1Name,
                        p2Name: p2Name
                    )
                }
            }
        }
    }
}

struct PVPRoleRow: View {
    let role: String
    let r1: RoleStatEntry?
    let r2: RoleStatEntry?
    let p1Name: String
    let p2Name: String

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: roleIcon)
                    .foregroundStyle(roleColor)
                    .font(.system(size: 12))
                Text(role.capitalized)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }

            HStack(spacing: 16) {
                // P1
                VStack(spacing: 2) {
                    Text(p1Name)
                        .font(.system(size: 9))
                        .foregroundStyle(.blue)
                    HStack(spacing: 8) {
                        MiniStat(label: "WR", value: String(format: "%.0f%%", r1?.winrate ?? 0))
                        MiniStat(label: "KDA", value: String(format: "%.1f", r1?.kda ?? 0))
                        MiniStat(label: "Games", value: "\(r1?.gamesPlayed ?? 0)")
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 30)

                // P2
                VStack(spacing: 2) {
                    Text(p2Name)
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                    HStack(spacing: 8) {
                        MiniStat(label: "WR", value: String(format: "%.0f%%", r2?.winrate ?? 0))
                        MiniStat(label: "KDA", value: String(format: "%.1f", r2?.kda ?? 0))
                        MiniStat(label: "Games", value: "\(r2?.gamesPlayed ?? 0)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    private var roleIcon: String {
        switch role {
        case "tank": return "shield.fill"
        case "damage": return "bolt.fill"
        case "support": return "cross.fill"
        default: return "circle.fill"
        }
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

struct MiniStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
        }
    }
}
