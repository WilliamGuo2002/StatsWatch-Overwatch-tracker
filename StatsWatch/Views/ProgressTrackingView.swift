import SwiftUI
import Charts

struct ProgressTrackingView: View {
    let viewModel: PlayerViewModel
    let playerId: String
    @State private var snapshots: [StatSnapshot] = []
    @State private var rankSnapshots: [RankSnapshot] = []
    @State private var selectedMetric: ProgressMetric = .winrate

    enum ProgressMetric: String, CaseIterable {
        case winrate = "Win Rate"
        case kda = "KDA"
        case elimsPer10 = "Elims/10"
        case deathsPer10 = "Deaths/10"
        case damagePer10 = "Dmg/10"
        case healingPer10 = "Heal/10"
    }

    private let storage = LocalStorageService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !rankSnapshots.isEmpty {
                    RankHistorySection(snapshots: rankSnapshots)
                }

                if snapshots.count < 2 {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundStyle(.quaternary)
                        Text("Not enough data yet")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Stats are saved each time you view this profile. Come back later to see your progress!")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 60)
                    .padding(.horizontal, 30)
                } else {
                    // Metric picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ProgressMetric.allCases, id: \.self) { metric in
                                Button {
                                    selectedMetric = metric
                                } label: {
                                    Text(metric.rawValue)
                                        .font(.system(size: 12, weight: selectedMetric == metric ? .bold : .medium))
                                        .foregroundStyle(selectedMetric == metric ? .white : .primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(selectedMetric == metric ? Color.blue : Color.clear)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Chart
                    ProgressChartView(
                        snapshots: snapshots,
                        metric: selectedMetric
                    )
                    .frame(height: 200)
                    .padding(.horizontal)

                    // Current vs first snapshot comparison
                    if let first = snapshots.last, let latest = snapshots.first {
                        ProgressComparisonCard(first: first, latest: latest)
                            .padding(.horizontal)
                    }

                    // Snapshot history
                    VStack(alignment: .leading, spacing: 8) {
                        Text("History")
                            .font(.system(size: 16, weight: .bold))
                            .padding(.horizontal)

                        ForEach(snapshots) { snapshot in
                            SnapshotRow(snapshot: snapshot)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Progress Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            snapshots = storage.getSnapshots(for: playerId, gamemode: viewModel.selectedMode.rawValue)
            rankSnapshots = storage.getRankSnapshots(for: playerId)
        }
    }
}

// MARK: - Progress Chart
struct ProgressChartView: View {
    let snapshots: [StatSnapshot]
    let metric: ProgressTrackingView.ProgressMetric

    private var values: [Double] {
        snapshots.reversed().map { value(for: $0) }
    }

    private func value(for s: StatSnapshot) -> Double {
        switch metric {
        case .winrate: return s.winrate
        case .kda: return s.kda
        case .elimsPer10: return s.elimsPer10
        case .deathsPer10: return s.deathsPer10
        case .damagePer10: return s.damagePer10
        case .healingPer10: return s.healingPer10
        }
    }

    var body: some View {
        GeometryReader { geo in
            let vals = values
            guard vals.count >= 2 else { return AnyView(EmptyView()) }

            let minV = (vals.min() ?? 0) * 0.9
            let maxV = max((vals.max() ?? 1) * 1.1, minV + 1)
            let range = maxV - minV
            let stepX = geo.size.width / CGFloat(vals.count - 1)

            return AnyView(
                ZStack {
                    // Grid lines
                    ForEach(0..<4) { i in
                        let y = geo.size.height * CGFloat(i) / 3
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                    }

                    // Line
                    Path { path in
                        for (i, val) in vals.enumerated() {
                            let x = stepX * CGFloat(i)
                            let y = geo.size.height * (1 - CGFloat((val - minV) / range))
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)

                    // Fill
                    Path { path in
                        for (i, val) in vals.enumerated() {
                            let x = stepX * CGFloat(i)
                            let y = geo.size.height * (1 - CGFloat((val - minV) / range))
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: stepX * CGFloat(vals.count - 1), y: geo.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Dots
                    ForEach(0..<vals.count, id: \.self) { i in
                        let x = stepX * CGFloat(i)
                        let y = geo.size.height * (1 - CGFloat((vals[i] - minV) / range))
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                    }

                    // Min/Max labels
                    Text(formatValue(maxV))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .position(x: 20, y: 8)
                    Text(formatValue(minV))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .position(x: 20, y: geo.size.height - 8)
                }
            )
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatValue(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.0f", v) }
        if v == v.rounded() { return String(format: "%.0f", v) }
        return String(format: "%.1f", v)
    }
}

// MARK: - Comparison Card
struct ProgressComparisonCard: View {
    let first: StatSnapshot
    let latest: StatSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Progress Since First Record")
                .font(.system(size: 14, weight: .bold))

            HStack(spacing: 8) {
                ProgressDelta(label: "Win Rate", oldVal: first.winrate, newVal: latest.winrate, format: "%.1f%%")
                ProgressDelta(label: "KDA", oldVal: first.kda, newVal: latest.kda, format: "%.2f")
                ProgressDelta(label: "Elims", oldVal: first.elimsPer10, newVal: latest.elimsPer10, format: "%.1f")
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ProgressDelta: View {
    let label: String
    let oldVal: Double
    let newVal: Double
    var format: String = "%.1f"

    private var diff: Double { newVal - oldVal }

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(String(format: format, newVal))
                .font(.system(size: 14, weight: .bold, design: .rounded))
            if abs(diff) > 0.01 {
                HStack(spacing: 2) {
                    Image(systemName: diff > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8))
                    Text(String(format: format, abs(diff)))
                        .font(.system(size: 9))
                }
                .foregroundStyle(diff > 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Snapshot Row
struct SnapshotRow: View {
    let snapshot: StatSnapshot

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.date, style: .date)
                    .font(.system(size: 12, weight: .medium))
                Text(snapshot.gamemode.capitalized)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text(String(format: "%.1f%%", snapshot.winrate))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text("WR")
                        .font(.system(size: 7))
                        .foregroundStyle(.tertiary)
                }
                VStack(spacing: 1) {
                    Text(String(format: "%.2f", snapshot.kda))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text("KDA")
                        .font(.system(size: 7))
                        .foregroundStyle(.tertiary)
                }
                VStack(spacing: 1) {
                    Text("\(snapshot.gamesPlayed)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text("Games")
                        .font(.system(size: 7))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Rank History
struct RankHistorySection: View {
    let snapshots: [RankSnapshot]

    private var activeRoles: [String] {
        RankScore.roles.filter { role in snapshots.contains { $0.scores[role] != nil } }
    }

    private var scoreRange: ClosedRange<Int> {
        let all = snapshots.flatMap { $0.scores.values }
        let low = ((all.min() ?? 0) / 5) * 5
        let high = min(45, ((all.max() ?? 44) / 5) * 5 + 5)
        return low...max(high, low + 5)
    }

    private var bandEdges: [Int] {
        Array(stride(from: scoreRange.lowerBound, through: scoreRange.upperBound, by: 5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "rosette")
                    .foregroundStyle(.orange)
                Text("Rank History")
                    .font(.system(size: 16, weight: .bold))
            }

            if snapshots.count >= 2 {
                Chart {
                    ForEach(activeRoles, id: \.self) { role in
                        ForEach(snapshots.filter { $0.scores[role] != nil }) { snapshot in
                            LineMark(
                                x: .value("Date", snapshot.date, unit: .day),
                                y: .value("Rank", snapshot.scores[role] ?? 0),
                                series: .value("Role", role)
                            )
                            .foregroundStyle(RoleStyle.color(role))
                            PointMark(
                                x: .value("Date", snapshot.date, unit: .day),
                                y: .value("Rank", snapshot.scores[role] ?? 0)
                            )
                            .foregroundStyle(RoleStyle.color(role))
                            .symbolSize(24)
                        }
                    }
                }
                .chartYScale(domain: scoreRange)
                .chartYAxis {
                    AxisMarks(values: bandEdges) { _ in
                        AxisGridLine()
                    }
                    // Labels sit in the middle of each division band.
                    AxisMarks(values: bandEdges.dropLast().map { Double($0) + 2.5 }) { value in
                        AxisValueLabel {
                            if let score = value.as(Double.self) {
                                Text(LocalizedStringKey(RankScore.divisionName(forScore: Int(score))))
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 180)
            } else {
                Text("Rank history builds up as you check this profile on different days.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if let latest = snapshots.last {
                HStack(spacing: 12) {
                    ForEach(activeRoles, id: \.self) { role in
                        if let score = latest.scores[role] {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(RoleStyle.color(role))
                                    .frame(width: 7, height: 7)
                                Text(RoleStyle.name(role))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(RankScore.localizedLabel(forScore: score))
                                    .font(.system(size: 10, weight: .semibold))
                            }
                        }
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
