import SwiftUI
import WidgetKit

struct PlayerProfileView: View {
    @Bindable var viewModel: PlayerViewModel
    let playerId: String
    @State private var isFavorite = false
    @State private var showFriendLink = false
    private let storage = LocalStorageService.shared

    var body: some View {
        ZStack {
            // Background gradient matching the Chinese app style
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.08),
                    Color.purple.opacity(0.04),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if viewModel.isLoadingProfile {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading profile...")
                        .foregroundStyle(.secondary)
                }
            } else if let error = viewModel.profileError, viewModel.playerSummary == nil {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await viewModel.loadPlayerProfile(playerId: playerId) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Player Header
                        PlayerHeaderSection(viewModel: viewModel, playerId: playerId)

                        // Competitive Ranks Detail
                        if let ranks = viewModel.displayedRanks {
                            CompetitiveRanksSection(ranks: ranks)
                        }

                        // Platform Tabs
                        if !viewModel.availablePlatforms.isEmpty {
                            PlatformTabsView(viewModel: viewModel)
                        }

                        // Game Mode Tabs
                        GameModeTabsView(viewModel: viewModel)

                        if viewModel.isPrivateProfile {
                            PrivateProfileNotice()
                        } else if let stats = viewModel.statsSummary, stats.general == nil {
                            Text("No stats for this game mode yet")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 20)
                        }

                        // Stats Overview
                        if viewModel.statsSummary?.general != nil {
                            StatsOverviewSection(viewModel: viewModel)

                            RecentSummarySection(viewModel: viewModel, playerId: playerId)

                            // Role Stats
                            if !viewModel.roleStats.isEmpty {
                                RoleStatsSection(viewModel: viewModel)
                            }

                            // Radar Chart
                            RadarChartSection(viewModel: viewModel)

                            // Play Style Analysis
                            PlayStyleCard(viewModel: viewModel)

                            // Top Heroes
                            if !viewModel.topHeroes.isEmpty {
                                TopHeroesSection(viewModel: viewModel)
                            }

                            // Hero Tier List
                            if viewModel.allHeroesSorted.count >= 3 {
                                HeroTierListSection(viewModel: viewModel)
                            }

                            // Smart Coach
                            SmartCoachSection(viewModel: viewModel)

                            // Action links
                            VStack(spacing: 8) {
                                ProfileNavLink(icon: "arrow.triangle.swap", title: "Hero Comparison", color: .blue) {
                                    HeroComparisonView(viewModel: viewModel)
                                }
                                ProfileNavLink(icon: "trophy.fill", title: "Hero Records", color: .yellow) {
                                    HeroRecordsView(viewModel: viewModel, playerId: playerId)
                                }
                                ProfileNavLink(icon: "list.bullet.rectangle", title: "Full Career Stats", color: .purple) {
                                    CareerStatsView(viewModel: viewModel, heroKey: nil, heroName: "Overall")
                                }
                                ProfileNavLink(icon: "chart.bar.fill", title: "Hero Meta Analysis", color: .orange) {
                                    HeroMetaView(viewModel: viewModel)
                                }
                                ProfileNavLink(icon: "timer", title: "Session Tracker", color: .red) {
                                    SessionTrackerView(viewModel: viewModel, playerId: playerId)
                                }
                                ProfileNavLink(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking", color: .green) {
                                    ProgressTrackingView(viewModel: viewModel, playerId: playerId)
                                }
                                ProfileNavLink(icon: "book.fill", title: "Hero Encyclopedia", color: .cyan) {
                                    HeroEncyclopediaListView(viewModel: viewModel)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFriendLink) {
            FriendLinkSheet(playerId: playerId, avatar: viewModel.playerSummary?.avatar)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showFriendLink = true
                    } label: {
                        Image(systemName: "qrcode")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        ShareCardView(viewModel: viewModel, playerId: playerId)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        if isFavorite {
                            storage.removeFavorite(playerId: playerId)
                        } else {
                            storage.addFavorite(FavoritePlayer(
                                playerId: playerId,
                                name: formatBattleTag(from: playerId),
                                avatar: viewModel.playerSummary?.avatar,
                                addedAt: Date()
                            ))
                        }
                        isFavorite.toggle()
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundStyle(isFavorite ? .orange : .secondary)
                    }
                }
            }
        }
        .task {
            isFavorite = storage.isFavorite(playerId: playerId)
            await viewModel.loadPlayerProfile(playerId: playerId)
            // Record search history & save snapshot
            if let summary = viewModel.playerSummary {
                storage.addHistory(SearchHistoryItem(
                    playerId: playerId,
                    name: formatBattleTag(from: playerId),
                    avatar: summary.avatar,
                    searchedAt: Date()
                ))
            }
            // Write widget data
            if let summary = viewModel.playerSummary, let stats = viewModel.statsSummary {
                let ranks = viewModel.displayedRanks
                let rank = ranks?.damage?.division ?? ranks?.support?.division ?? ranks?.tank?.division
                let widgetData = WidgetPlayerData(
                    name: formatBattleTag(from: playerId),
                    winrate: stats.general?.winrate ?? 0,
                    kda: stats.general?.kda ?? 0,
                    gamesPlayed: stats.general?.gamesPlayed ?? 0,
                    rank: rank,
                    updatedAt: Date()
                )
                if let data = try? JSONEncoder().encode(widgetData) {
                    UserDefaults(suiteName: "group.com.wgstudio.statswatch.k7q2")?.set(data, forKey: "widget_player_data")
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }
}

// MARK: - Player Header
struct PlayerHeaderSection: View {
    let viewModel: PlayerViewModel
    let playerId: String

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            AsyncImage(url: URL(string: viewModel.playerSummary?.avatar ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(formatBattleTag(from: playerId))
                    .font(.system(size: 22, weight: .bold))

                HStack(spacing: 8) {
                    if let level = viewModel.playerSummary?.endorsement?.level {
                        EndorsementBadge(level: level)
                    }

                    if let title = viewModel.playerSummary?.title {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Competitive ranks
            if let ranks = viewModel.displayedRanks {
                CompactRanksView(ranks: ranks)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct EndorsementBadge: View {
    let level: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 24, height: 24)

            Text("\(level)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

struct CompactRanksView: View {
    let ranks: PlatformRanks

    var body: some View {
        VStack(spacing: 3) {
            if let tank = ranks.tank {
                RankBadge(rank: tank, roleName: "Tank")
            }
            if let damage = ranks.damage {
                RankBadge(rank: damage, roleName: "DPS")
            }
            if let support = ranks.support {
                RankBadge(rank: support, roleName: "Sup")
            }
            if let open = ranks.open {
                RankBadge(rank: open, roleName: "6v6")
            }
        }
    }
}

struct RankBadge: View {
    let rank: RankInfo
    let roleName: String

    var body: some View {
        HStack(spacing: 4) {
            if let iconURL = rank.rankIcon {
                AsyncImage(url: URL(string: iconURL)) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    EmptyView()
                }
                .frame(width: 20, height: 20)
            }

            Text(roleName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Competitive Ranks Section
struct CompetitiveRanksSection: View {
    let ranks: PlatformRanks

    private var allRanks: [(label: String, icon: String, rank: RankInfo?, color: Color)] {
        [
            ("Tank", "shield.fill", ranks.tank, .blue),
            ("DPS", "bolt.fill", ranks.damage, .red),
            ("Support", "cross.fill", ranks.support, .green),
            ("Open 6v6", "person.3.fill", ranks.open, .purple),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Competitive Ranks")
                    .font(.system(size: 18, weight: .bold))

                Spacer()

                if let season = ranks.displaySeason {
                    Text("Season \(season)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)

            HStack(spacing: 8) {
                ForEach(allRanks, id: \.label) { item in
                    RankDetailCard(
                        label: item.label,
                        icon: item.icon,
                        rank: item.rank,
                        color: item.color
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct RankDetailCard: View {
    let label: String
    let icon: String
    let rank: RankInfo?
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            // Role icon header
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)

            if let rank = rank {
                // Rank icon
                if let iconURL = rank.rankIcon {
                    AsyncImage(url: URL(string: iconURL)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 36, height: 36)
                }

                // Tier icon
                if let tierURL = rank.tierIcon {
                    AsyncImage(url: URL(string: tierURL)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        EmptyView()
                    }
                    .frame(width: 16, height: 16)
                }

                // Division text
                Text(rankDisplayText(rank))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Image(systemName: "minus")
                    .font(.system(size: 20))
                    .foregroundStyle(.quaternary)
                    .frame(height: 36)

                Text("Unranked")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func rankDisplayText(_ rank: RankInfo) -> String {
        let div = rank.division?.capitalized ?? ""
        if let tier = rank.tier {
            return "\(div) \(tier)"
        }
        return div
    }
}

struct ProfileNavLink<Destination: View>: View {
    let icon: String
    let title: LocalizedStringKey
    let color: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Game Mode Tabs
struct GameModeTabsView: View {
    @Bindable var viewModel: PlayerViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(GameMode.allCases, id: \.self) { mode in
                Button {
                    Task { await viewModel.switchMode(mode) }
                } label: {
                    Text(mode.displayName)
                        .font(.system(size: 14, weight: viewModel.selectedMode == mode ? .bold : .medium))
                        .foregroundStyle(viewModel.selectedMode == mode ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.selectedMode == mode
                                ? AnyShapeStyle(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Color.clear)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(3)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

struct PlatformTabsView: View {
    @Bindable var viewModel: PlayerViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.availablePlatforms, id: \.self) { platform in
                let isSelected = viewModel.selectedPlatform == platform
                Button {
                    Task { await viewModel.switchPlatform(platform) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: platform == .pc ? "desktopcomputer" : "gamecontroller.fill")
                            .font(.system(size: 12))
                        Text(platform.displayName)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    }
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.indigo : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(3)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

struct PrivateProfileNotice: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("This profile is private")
                .font(.system(size: 16, weight: .semibold))
            Text("The player has hidden their career profile in Overwatch, so their stats can't be viewed.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
