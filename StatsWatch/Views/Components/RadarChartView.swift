import SwiftUI

struct RadarChartSection: View {
    @Bindable var viewModel: PlayerViewModel

    private let roles: [(key: String?, label: String, icon: String, color: Color)] = [
        (nil, "All", "circle.grid.cross", .blue),
        ("tank", "Tank", "shield.fill", .blue),
        ("damage", "DPS", "bolt.fill", .red),
        ("support", "Support", "cross.fill", .green),
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Role selector tabs
            HStack(spacing: 8) {
                ForEach(roles, id: \.label) { role in
                    let isSelected = viewModel.selectedRadarRole == role.key
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.selectedRadarRole = role.key
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: role.icon)
                                .font(.system(size: 10))
                            Text(role.label)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        }
                        .foregroundStyle(isSelected ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? role.color : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.horizontal)

            // Radar chart
            RadarChartView(
                data: viewModel.radarData(for: viewModel.selectedRadarRole),
                medianData: viewModel.radarMedianData(for: viewModel.selectedRadarRole),
                accentColor: currentRoleColor
            )
            .frame(height: 260)
            .padding(.horizontal)
            .id(viewModel.selectedRadarRole ?? "all") // force redraw on switch

            // Role-specific average stats below chart
            if let avg = currentAverage {
                RoleAverageStatsRow(average: avg, roleKey: viewModel.selectedRadarRole)
                    .padding(.horizontal)
            }

            // Legend
            HStack(spacing: 20) {
                LegendDot(color: currentRoleColor.opacity(0.6), label: "You")
                LegendDot(color: .gray.opacity(0.3), label: "Median")
            }
            .font(.system(size: 12))
        }
        .padding(.vertical, 8)
    }

    private var currentRoleColor: Color {
        switch viewModel.selectedRadarRole {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        default: return .blue
        }
    }

    private var currentAverage: StatAverages? {
        let role = viewModel.selectedRadarRole
        let base = role.flatMap { viewModel.statsSummary?.roles?[$0]?.average } ?? (role == nil ? viewModel.statsSummary?.general?.average : nil)
        guard let base else { return nil }
        return StatAverages(
            eliminations: base.eliminations,
            assists: viewModel.assistsPer10(for: role),
            deaths: base.deaths,
            damage: base.damage,
            healing: base.healing
        )
    }
}

// MARK: - Role Average Stats Row
struct RoleAverageStatsRow: View {
    let average: StatAverages
    let roleKey: String?

    var body: some View {
        HStack(spacing: 8) {
            RoleAvgItem(title: "Elims", value: String(format: "%.1f", average.eliminations ?? 0))
            RoleAvgItem(title: "Assists", value: String(format: "%.1f", average.assists ?? 0))
            RoleAvgItem(title: "Deaths", value: String(format: "%.1f", average.deaths ?? 0))
            RoleAvgItem(title: "Dmg", value: formatShort(average.damage ?? 0))
            RoleAvgItem(title: "Heal", value: formatShort(average.healing ?? 0))
        }
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatShort(_ v: Double) -> String {
        if v >= 1000 {
            return String(format: "%.1fK", v / 1000)
        }
        return String(format: "%.0f", v)
    }
}

struct RoleAvgItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Radar Chart View
struct RadarChartView: View {
    let data: [PlayerViewModel.RadarDataPoint]
    var medianData: [PlayerViewModel.RadarDataPoint]? = nil
    var accentColor: Color = .blue
    let gridLevels = 5

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 40

            ZStack {
                // Grid lines
                ForEach(1...gridLevels, id: \.self) { level in
                    let scale = CGFloat(level) / CGFloat(gridLevels)
                    PolygonShape(sides: data.count, scale: scale)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                }

                // Axis lines
                ForEach(0..<data.count, id: \.self) { i in
                    let angle = angleFor(index: i)
                    let endPoint = pointOnCircle(center: center, radius: radius, angle: angle)

                    Path { path in
                        path.move(to: center)
                        path.addLine(to: endPoint)
                    }
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
                }

                // Median reference polygon (role-specific shape)
                let medianPoints: [CGPoint] = {
                    if let median = medianData, median.count == data.count {
                        return median.enumerated().map { (i, d) in
                            pointOnCircle(center: center, radius: radius * CGFloat(d.value), angle: angleFor(index: i))
                        }
                    } else {
                        return (0..<data.count).map { i in
                            pointOnCircle(center: center, radius: radius * 0.5, angle: angleFor(index: i))
                        }
                    }
                }()
                PolygonPath(points: medianPoints)
                    .fill(Color.gray.opacity(0.06))
                PolygonPath(points: medianPoints)
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                // Data polygon
                let dataPoints = data.enumerated().map { (i, d) in
                    pointOnCircle(center: center, radius: radius * CGFloat(d.value), angle: angleFor(index: i))
                }
                PolygonPath(points: dataPoints)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.2), accentColor.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                PolygonPath(points: dataPoints)
                    .stroke(accentColor.opacity(0.6), lineWidth: 2)

                // Data point dots
                ForEach(0..<dataPoints.count, id: \.self) { i in
                    Circle()
                        .fill(accentColor.opacity(0.7))
                        .frame(width: 6, height: 6)
                        .position(dataPoints[i])
                }

                // Labels
                ForEach(0..<data.count, id: \.self) { i in
                    let angle = angleFor(index: i)
                    let labelPoint = pointOnCircle(center: center, radius: radius + 24, angle: angle)

                    Text(data[i].label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .position(labelPoint)
                }
            }
        }
    }

    private func angleFor(index: Int) -> Double {
        let sliceAngle = 2 * .pi / Double(data.count)
        return sliceAngle * Double(index) - .pi / 2
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }
}

struct PolygonShape: Shape {
    let sides: Int
    let scale: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * scale

        var path = Path()
        for i in 0..<sides {
            let angle = 2 * .pi / Double(sides) * Double(i) - .pi / 2
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct PolygonPath: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
