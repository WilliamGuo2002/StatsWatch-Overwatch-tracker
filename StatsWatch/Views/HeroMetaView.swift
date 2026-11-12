import SwiftUI

struct HeroMetaView: View {
    let viewModel: PlayerViewModel
    @State private var heroStats: [HeroGlobalStat] = []
    @State private var maps: [MapInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: LocalizedStringKey?
    @State private var selectedRole: String? = nil
    @State private var sortBy: MetaSortOption = .pickrate
    @State private var selectedGamemode: GameMode = .competitive
    @State private var region: MetaRegion = .preferred
    @State private var division: CompetitiveDivision? = nil
    @State private var mapKey: String? = nil

    enum MetaSortOption: CaseIterable {
        case pickrate, winrate, banrate

        var title: LocalizedStringKey {
            switch self {
            case .pickrate: return "Pick Rate"
            case .winrate: return "Win Rate"
            case .banrate: return "Ban Rate"
            }
        }
    }

    private let api = OverwatchAPIService.shared
    private static let standardMapModes: Set<String> = ["assault", "clash", "control", "escort", "flashpoint", "hybrid", "push"]

    private var hasBanrates: Bool {
        heroStats.contains { ($0.banrate ?? 0) > 0 }
    }

    private var sortOptions: [MetaSortOption] {
        hasBanrates ? MetaSortOption.allCases : [.pickrate, .winrate]
    }

    private var filterKey: String {
        "\(selectedGamemode.rawValue)-\(region.rawValue)-\(division?.rawValue ?? "")-\(mapKey ?? "")"
    }

    private var selectedMapName: String? {
        mapKey.flatMap { key in maps.first { $0.key == key }?.name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Gamemode toggle
                HStack(spacing: 0) {
                    ForEach(GameMode.allCases, id: \.self) { mode in
                        Button {
                            selectedGamemode = mode
                        } label: {
                            Text(mode.displayName)
                                .font(.system(size: 13, weight: selectedGamemode == mode ? .bold : .medium))
                                .foregroundStyle(selectedGamemode == mode ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedGamemode == mode ? Color.blue : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(3)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

                // Region / rank / map filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(MetaRegion.allCases, id: \.self) { option in
                                Button { region = option } label: { Text(option.displayName) }
                            }
                        } label: {
                            MetaFilterLabel(icon: "globe") { Text(region.displayName) }
                        }

                        if selectedGamemode == .competitive {
                            Menu {
                                Button { division = nil } label: { Text("All Ranks") }
                                ForEach(CompetitiveDivision.allCases, id: \.self) { option in
                                    Button { division = option } label: { Text(option.displayName) }
                                }
                            } label: {
                                MetaFilterLabel(icon: "rosette") {
                                    if let division { Text(division.displayName) } else { Text("All Ranks") }
                                }
                            }
                        }

                        Menu {
                            Button { mapKey = nil } label: { Text("All Maps") }
                            ForEach(maps) { map in
                                Button { mapKey = map.key } label: { Text(verbatim: map.name) }
                            }
                        } label: {
                            MetaFilterLabel(icon: "map") {
                                if let selectedMapName { Text(verbatim: selectedMapName) } else { Text("All Maps") }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Role filter
                HStack(spacing: 8) {
                    RoleFilterChip(label: "All", icon: "circle.grid.cross", isSelected: selectedRole == nil) {
                        selectedRole = nil
                    }
                    RoleFilterChip(label: "Tank", icon: "shield.fill", isSelected: selectedRole == "tank", color: .blue) {
                        selectedRole = "tank"
                    }
                    RoleFilterChip(label: "DPS", icon: "bolt.fill", isSelected: selectedRole == "damage", color: .red) {
                        selectedRole = "damage"
                    }
                    RoleFilterChip(label: "Support", icon: "cross.fill", isSelected: selectedRole == "support", color: .green) {
                        selectedRole = "support"
                    }
                }
                .padding(.horizontal)

                // Sort toggle
                HStack {
                    Text("Sort by")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Picker("Sort", selection: $sortBy) {
                        ForEach(sortOptions, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                } else {
                    // Stats list
                    let filtered = filteredAndSorted
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, stat in
                        MetaHeroRow(
                            rank: index + 1,
                            stat: stat,
                            heroInfo: viewModel.heroInfo(for: stat.hero),
                            role: viewModel.heroRole(for: stat.hero),
                            portraitURL: viewModel.heroPortraitURL(for: stat.hero),
                            maxPickrate: filtered.compactMap(\.pickrate).max() ?? 1,
                            maxBanrate: filtered.compactMap(\.banrate).max() ?? 1,
                            showBanrate: hasBanrates,
                            sortBy: sortBy
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Hero Meta")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.ensureHeroesLoaded()
            if maps.isEmpty, let all = try? await api.getMaps() {
                maps = all
                    .filter { !Self.standardMapModes.isDisjoint(with: $0.gamemodes ?? []) }
                    .sorted { $0.name < $1.name }
            }
        }
        .task(id: filterKey) {
            await loadStats()
        }
        .onChange(of: hasBanrates) {
            if !hasBanrates && sortBy == .banrate { sortBy = .pickrate }
        }
    }

    private var filteredAndSorted: [HeroGlobalStat] {
        var list = heroStats
        if let role = selectedRole {
            list = list.filter { viewModel.heroRole(for: $0.hero) == role }
        }
        switch sortBy {
        case .pickrate:
            list.sort { ($0.pickrate ?? 0) > ($1.pickrate ?? 0) }
        case .winrate:
            list.sort { ($0.winrate ?? 0) > ($1.winrate ?? 0) }
        case .banrate:
            list.sort { ($0.banrate ?? 0) > ($1.banrate ?? 0) }
        }
        return list
    }

    private func loadStats() async {
        isLoading = true
        errorMessage = nil
        do {
            heroStats = try await api.getHeroGlobalStats(
                gamemode: selectedGamemode,
                region: region,
                division: division?.rawValue,
                map: mapKey
            )
        } catch is CancellationError {
            return
        } catch {
            errorMessage = APIError.from(error).message
        }
        isLoading = false
    }
}

enum CompetitiveDivision: String, CaseIterable {
    case bronze, silver, gold, platinum, emerald, diamond, master, grandmaster

    var displayName: LocalizedStringKey {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .emerald: return "Emerald"
        case .diamond: return "Diamond"
        case .master: return "Master"
        case .grandmaster: return "Grandmaster"
        }
    }
}

struct MetaFilterLabel<Title: View>: View {
    let icon: String
    @ViewBuilder let title: () -> Title

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            title()
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }
}

struct RoleFilterChip: View {
    let label: LocalizedStringKey
    let icon: String
    var isSelected: Bool
    var color: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? color : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct MetaHeroRow: View {
    let rank: Int
    let stat: HeroGlobalStat
    let heroInfo: HeroInfo?
    let role: String
    let portraitURL: URL?
    let maxPickrate: Double
    let maxBanrate: Double
    let showBanrate: Bool
    let sortBy: HeroMetaView.MetaSortOption

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            // Portrait
            AsyncImage(url: portraitURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(roleColor.opacity(0.15))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(roleColor)
                            .font(.system(size: 14))
                    }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(Circle().stroke(roleColor.opacity(0.3), lineWidth: 1.5))

            // Name + role
            VStack(alignment: .leading, spacing: 3) {
                Text(heroInfo?.name ?? stat.hero.capitalized)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(roleName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Bar + stats
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    // Pick rate
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.1f%%", stat.pickrate ?? 0))
                            .font(.system(size: 13, weight: sortBy == .pickrate ? .bold : .medium, design: .rounded))
                            .foregroundStyle(sortBy == .pickrate ? .primary : .secondary)
                        Text("Pick")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }

                    // Win rate
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.1f%%", stat.winrate ?? 0))
                            .font(.system(size: 13, weight: sortBy == .winrate ? .bold : .medium, design: .rounded))
                            .foregroundStyle(winrateColor)
                        Text("Win")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }

                    if showBanrate {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(format: "%.1f%%", stat.banrate ?? 0))
                                .font(.system(size: 13, weight: sortBy == .banrate ? .bold : .medium, design: .rounded))
                                .foregroundStyle(sortBy == .banrate ? Color.purple : Color.secondary)
                            Text("Ban")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Bar
                GeometryReader { geo in
                    let ratio: CGFloat = switch sortBy {
                    case .pickrate: CGFloat((stat.pickrate ?? 0) / max(maxPickrate, 0.01))
                    case .winrate: CGFloat((stat.winrate ?? 0) / 100)
                    case .banrate: CGFloat((stat.banrate ?? 0) / max(maxBanrate, 0.01))
                    }
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor.opacity(0.4))
                        .frame(width: geo.size.width * min(1, ratio), height: 4)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(width: 120, height: 4)
            }
            .fixedSize()
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

    private var winrateColor: Color {
        let wr = stat.winrate ?? 0
        if wr >= 52 { return .green }
        if wr >= 48 { return .primary }
        return .red
    }

    private var roleName: LocalizedStringKey {
        switch role {
        case "tank": return "Tank"
        case "damage": return "DPS"
        case "support": return "Support"
        default: return LocalizedStringKey(role.capitalized)
        }
    }

    private var barColor: Color {
        switch sortBy {
        case .pickrate: return roleColor
        case .winrate: return winrateColor
        case .banrate: return .purple
        }
    }
}
