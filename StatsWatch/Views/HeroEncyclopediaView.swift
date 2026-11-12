import SwiftUI

// MARK: - Hero List (Encyclopedia Entry)
struct HeroEncyclopediaListView: View {
    let viewModel: PlayerViewModel
    @State private var selectedRole: String? = nil
    @State private var searchText = ""
    @State private var isLoading = true

    private let api = OverwatchAPIService.shared

    private var allHeroes: [HeroInfo] { viewModel.heroes }

    private var filteredHeroes: [HeroInfo] {
        var list = allHeroes
        if let role = selectedRole {
            list = list.filter { $0.role == role }
        }
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return list.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search heroes...", text: $searchText)
                        .font(.system(size: 14))
                }
                .padding(10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

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

                if isLoading && allHeroes.isEmpty {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    // Hero grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ], spacing: 10) {
                        ForEach(filteredHeroes) { hero in
                            NavigationLink {
                                HeroEncyclopediaDetailView(heroKey: hero.key, heroInfo: hero, viewModel: viewModel)
                            } label: {
                                EncyclopediaHeroCard(hero: hero)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Hero Encyclopedia")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.ensureHeroesLoaded()
            if viewModel.heroGlobalStats.isEmpty {
                do {
                    viewModel.heroGlobalStats = try await api.getHeroGlobalStats(region: .preferred)
                } catch {}
            }
            isLoading = false
        }
    }
}

struct EncyclopediaHeroCard: View {
    let hero: HeroInfo

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: URL(string: hero.portrait ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(roleColor.opacity(0.1))
                    .overlay {
                        Image(systemName: roleIcon)
                            .font(.system(size: 24))
                            .foregroundStyle(roleColor.opacity(0.4))
                    }
            }
            .frame(height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 4) {
                Image(systemName: roleIcon)
                    .font(.system(size: 8))
                    .foregroundStyle(roleColor)
                Text(hero.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .padding(6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var roleIcon: String {
        switch hero.role {
        case "tank": return "shield.fill"
        case "damage": return "bolt.fill"
        case "support": return "cross.fill"
        default: return "circle.fill"
        }
    }

    private var roleColor: Color {
        switch hero.role {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        default: return .gray
        }
    }
}

// MARK: - Hero Encyclopedia Detail
struct HeroEncyclopediaDetailView: View {
    let heroKey: String
    let heroInfo: HeroInfo
    let viewModel: PlayerViewModel
    @State private var heroDetail: HeroDetail?
    @State private var isLoading = true
    @State private var errorMessage: LocalizedStringKey?

    private let api = OverwatchAPIService.shared

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading hero data...")
                    .padding(.top, 60)
            } else if let detail = heroDetail {
                VStack(spacing: 16) {
                    // Header
                    HeroEncyclopediaHeader(hero: heroInfo, detail: detail)

                    // Hitpoints
                    if let hp = detail.hitpoints {
                        HitpointsSection(hitpoints: hp)
                    }

                    // Global stats
                    if let wr = viewModel.heroGlobalWinrate(for: heroKey),
                       let pr = viewModel.heroGlobalPickrate(for: heroKey) {
                        HStack(spacing: 12) {
                            GlobalStatBadge(title: "Global Win Rate", value: String(format: "%.1f%%", wr), color: wr >= 50 ? .green : .red)
                            GlobalStatBadge(title: "Global Pick Rate", value: String(format: "%.1f%%", pr), color: .blue)
                        }
                        .padding(.horizontal)
                    }

                    // Abilities
                    if let abilities = detail.abilities, !abilities.isEmpty {
                        AbilitiesSection(abilities: abilities)
                    }

                    // Perks
                    if let perks = detail.perks, !(perks.minor ?? []).isEmpty || !(perks.major ?? []).isEmpty {
                        PerksSection(perks: perks)
                    }

                    // Stadium Powers
                    if let powers = detail.stadiumPowers, !powers.isEmpty {
                        StadiumPowersSection(powers: powers)
                    }

                    // Story
                    if let story = detail.story?.summary, !story.isEmpty {
                        StorySection(summary: story, detail: detail)
                    }
                }
                .padding(.bottom, 20)
            } else {
                // Error or no data fallback
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text("Failed to load hero details")
                        .font(.system(size: 15, weight: .semibold))
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button("Retry") {
                        Task { await loadDetail() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 60)
                .padding(.horizontal, 30)
            }
        }
        .navigationTitle(heroInfo.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            heroDetail = try await api.getHeroDetail(heroKey: heroKey, locale: APILocale.current)
        } catch {
            errorMessage = APIError.from(error).message
        }
        isLoading = false
    }
}

struct HeroEncyclopediaHeader: View {
    let hero: HeroInfo
    let detail: HeroDetail

    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: hero.portrait ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.15))
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(roleColor.opacity(0.3), lineWidth: 3))

            Text(hero.name)
                .font(.system(size: 24, weight: .bold))

            if let desc = detail.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 16) {
                if let role = detail.role {
                    InfoChip(icon: roleIcon, text: role.capitalized, color: roleColor)
                }
                if let subrole = detail.subrole ?? hero.subrole {
                    InfoChip(icon: "tag.fill", text: subrole.capitalized, color: .teal)
                }
                if let location = detail.location {
                    InfoChip(icon: "mappin", text: location, color: .orange)
                }
                if let age = detail.age {
                    InfoChip(icon: "person", text: "\(age)", color: .purple)
                }
            }
        }
        .padding()
    }

    private var roleIcon: String {
        switch hero.role {
        case "tank": return "shield.fill"
        case "damage": return "bolt.fill"
        case "support": return "cross.fill"
        default: return "circle.fill"
        }
    }

    private var roleColor: Color {
        switch hero.role {
        case "tank": return .blue
        case "damage": return .red
        case "support": return .green
        default: return .gray
        }
    }
}

struct InfoChip: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct HitpointsSection: View {
    let hitpoints: HeroHitpoints

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hitpoints")
                .font(.system(size: 15, weight: .bold))
                .padding(.horizontal)

            HStack(spacing: 10) {
                if let health = hitpoints.health, health > 0 {
                    HPBar(label: "Health", value: health, maxValue: hitpoints.total ?? 600, color: .green)
                }
                if let armor = hitpoints.armor, armor > 0 {
                    HPBar(label: "Armor", value: armor, maxValue: hitpoints.total ?? 600, color: .orange)
                }
                if let shields = hitpoints.shields, shields > 0 {
                    HPBar(label: "Shields", value: shields, maxValue: hitpoints.total ?? 600, color: .cyan)
                }
            }
            .padding(.horizontal)

            if let total = hitpoints.total {
                Text("Total: \(total) HP")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct HPBar: View {
    let label: String
    let value: Int
    let maxValue: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.3))
                    .frame(width: geo.size.width * CGFloat(value) / CGFloat(max(maxValue, 1)))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GlobalStatBadge: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AbilitiesSection: View {
    let abilities: [HeroAbility]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Abilities")
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal)

            ForEach(abilities) { ability in
                AbilityRow(ability: ability)
            }
        }
    }
}

struct AbilityRow: View {
    let ability: HeroAbility
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    if let icon = ability.icon, let url = URL(string: icon) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.cyan.opacity(0.1))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.cyan)
                            }
                    }

                    Text(ability.name ?? "Ability")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }

            if isExpanded, let desc = ability.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

struct StorySection: View {
    let summary: String
    let detail: HeroDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundStyle(.purple)
                Text("Backstory")
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                if let birthday = detail.birthday {
                    HStack(spacing: 4) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("Birthday: \(birthday)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(summary)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
            .padding(14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

struct PerksSection: View {
    let perks: HeroPerks

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .foregroundStyle(.yellow)
                Text("Perks")
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.horizontal)

            if let minor = perks.minor, !minor.isEmpty {
                PerkGroup(title: "Minor Perks", powers: minor, color: .teal)
            }
            if let major = perks.major, !major.isEmpty {
                PerkGroup(title: "Major Perks", powers: major, color: .orange)
            }
        }
    }
}

struct PerkGroup: View {
    let title: LocalizedStringKey
    let powers: [HeroPower]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal)
            ForEach(powers) { power in
                HeroPowerRow(power: power, color: color)
            }
        }
    }
}

struct StadiumPowersSection: View {
    let powers: [HeroPower]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "building.columns.fill")
                        .foregroundStyle(.purple)
                    Text("Stadium Powers")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("\(powers.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            if isExpanded {
                ForEach(powers) { power in
                    HeroPowerRow(power: power, color: .purple)
                }
            }
        }
    }
}

struct HeroPowerRow: View {
    let power: HeroPower
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: power.icon ?? "")) { image in
                image.resizable().scaledToFit().padding(4)
            } placeholder: {
                Color.clear
            }
            .frame(width: 36, height: 36)
            .background(color.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(power.name ?? "")
                    .font(.system(size: 13, weight: .semibold))
                if let description = power.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}
