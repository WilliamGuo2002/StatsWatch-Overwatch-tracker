import SwiftUI

struct SessionTrackerView: View {
    let viewModel: PlayerViewModel
    let playerId: String

    @State private var sessionStart: StatSnapshot?
    @State private var sessionEnd: StatSnapshot?
    @State private var isSessionActive = false
    @State private var isRefreshing = false

    private let storage = LocalStorageService.shared
    private let sessionKey = "sw_active_session"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Session status
                SessionStatusCard(isActive: isSessionActive)

                if !isSessionActive {
                    // Not in session — show start button
                    Button {
                        startSession()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Session")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    Text("Tap before you start playing. When you're done, come back and end the session to see your results.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                } else {
                    // Active session — show current start snapshot + end button
                    if let start = sessionStart {
                        SessionSnapshotCard(title: "Session Start", snapshot: start, color: .blue)
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task { await endSession() }
                        } label: {
                            HStack {
                                if isRefreshing { ProgressView().tint(.white) }
                                Image(systemName: "stop.fill")
                                Text("End Session")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isRefreshing)

                        Button {
                            cancelSession()
                        } label: {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }

                // Session result
                if let start = sessionStart, let end = sessionEnd {
                    SessionResultCard(start: start, end: end)
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Session Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadSessionState() }
    }

    private func startSession() {
        guard let stats = viewModel.statsSummary?.general else { return }
        let snapshot = makeSnapshot(from: stats)
        sessionStart = snapshot
        sessionEnd = nil
        isSessionActive = true
        saveSessionState()
    }

    private func endSession() async {
        isRefreshing = true
        // Re-fetch fresh stats
        do {
            let freshStats = try await OverwatchAPIService.shared.getPlayerStatsSummary(
                playerId: playerId,
                gamemode: viewModel.selectedMode,
                platform: viewModel.selectedPlatform
            )
            if let general = freshStats.general {
                sessionEnd = makeSnapshot(from: general)
            }
        } catch {}
        isSessionActive = false
        clearSessionState()
        isRefreshing = false
    }

    private func cancelSession() {
        isSessionActive = false
        sessionStart = nil
        sessionEnd = nil
        clearSessionState()
    }

    private func makeSnapshot(from stats: GeneralStats) -> StatSnapshot {
        StatSnapshot(
            id: UUID(),
            playerId: playerId,
            date: Date(),
            gamemode: viewModel.selectedMode.rawValue,
            winrate: stats.winrate ?? 0,
            kda: stats.kda ?? 0,
            gamesPlayed: stats.gamesPlayed ?? 0,
            elimsPer10: stats.average?.eliminations ?? 0,
            deathsPer10: stats.average?.deaths ?? 0,
            damagePer10: stats.average?.damage ?? 0,
            healingPer10: stats.average?.healing ?? 0,
            assistsPer10: stats.average?.assists ?? 0
        )
    }

    // Persistence for active session (survives app restart)
    private func saveSessionState() {
        if let data = try? JSONEncoder().encode(sessionStart) {
            UserDefaults.standard.set(data, forKey: "\(sessionKey)_\(playerId)")
        }
    }

    private func loadSessionState() {
        if let data = UserDefaults.standard.data(forKey: "\(sessionKey)_\(playerId)"),
           let snapshot = try? JSONDecoder().decode(StatSnapshot.self, from: data) {
            sessionStart = snapshot
            isSessionActive = true
        }
    }

    private func clearSessionState() {
        UserDefaults.standard.removeObject(forKey: "\(sessionKey)_\(playerId)")
    }
}

// MARK: - Status Card
struct SessionStatusCard: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.green.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Image(systemName: isActive ? "record.circle" : "circle.dotted")
                    .font(.system(size: 20))
                    .foregroundStyle(isActive ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isActive ? "Session Active" : "No Active Session")
                    .font(.system(size: 15, weight: .semibold))
                Text(isActive ? "Go play some games! Come back when you're done." : "Start a session before you play to track your progress.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Snapshot Card
struct SessionSnapshotCard: View {
    let title: String
    let snapshot: StatSnapshot
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(snapshot.date, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                SnapStatItem(label: "Games", value: "\(snapshot.gamesPlayed)")
                SnapStatItem(label: "Win Rate", value: String(format: "%.1f%%", snapshot.winrate))
                SnapStatItem(label: "KDA", value: String(format: "%.2f", snapshot.kda))
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

struct SnapStatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Result
struct SessionResultCard: View {
    let start: StatSnapshot
    let end: StatSnapshot

    private var gamesPlayed: Int { end.gamesPlayed - start.gamesPlayed }
    private var wrDelta: Double { end.winrate - start.winrate }
    private var kdaDelta: Double { end.kda - start.kda }

    // Estimate wins/losses from games and winrate change
    private var estimatedWins: Int {
        if gamesPlayed <= 0 { return 0 }
        // Approximate: use end winrate applied to session games
        let endGames = end.gamesPlayed
        let startGames = start.gamesPlayed
        let endWins = Int(round(Double(endGames) * end.winrate / 100))
        let startWins = Int(round(Double(startGames) * start.winrate / 100))
        return max(0, endWins - startWins)
    }

    private var estimatedLosses: Int {
        max(0, gamesPlayed - estimatedWins)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(.orange)
                Text("Session Result")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }

            if gamesPlayed <= 0 {
                Text("No games detected. The stats haven't changed since session start.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                // Games summary
                HStack(spacing: 0) {
                    ResultBigStat(label: "Games", value: "\(gamesPlayed)", color: .primary)
                    ResultBigStat(label: "Wins", value: "\(estimatedWins)", color: .green)
                    ResultBigStat(label: "Losses", value: "\(estimatedLosses)", color: .red)
                }

                Divider()

                // Deltas
                VStack(spacing: 6) {
                    SessionDeltaRow(label: "Win Rate", before: String(format: "%.1f%%", start.winrate), after: String(format: "%.1f%%", end.winrate), delta: wrDelta, format: "%+.1f%%")
                    SessionDeltaRow(label: "KDA", before: String(format: "%.2f", start.kda), after: String(format: "%.2f", end.kda), delta: kdaDelta, format: "%+.2f")
                    SessionDeltaRow(label: "Elims/10", before: String(format: "%.1f", start.elimsPer10), after: String(format: "%.1f", end.elimsPer10), delta: end.elimsPer10 - start.elimsPer10, format: "%+.1f")
                    SessionDeltaRow(label: "Deaths/10", before: String(format: "%.1f", start.deathsPer10), after: String(format: "%.1f", end.deathsPer10), delta: end.deathsPer10 - start.deathsPer10, format: "%+.1f", lowerIsBetter: true)
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.05), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct ResultBigStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SessionDeltaRow: View {
    let label: String
    let before: String
    let after: String
    let delta: Double
    var format: String = "%+.1f"
    var lowerIsBetter: Bool = false

    private var isGood: Bool {
        lowerIsBetter ? delta < 0 : delta > 0
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(before)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.tertiary)
            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
            Text(after)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Spacer()
            if abs(delta) > 0.01 {
                Text(String(format: format, delta))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isGood ? .green : .red)
            }
        }
    }
}
