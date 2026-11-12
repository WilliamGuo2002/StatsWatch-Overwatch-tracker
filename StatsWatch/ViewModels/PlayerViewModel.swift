import Foundation
import SwiftUI

@Observable
class PlayerViewModel {
    var searchText = ""
    var searchResults: [PlayerSearchResult] = []
    var isSearching = false
    var searchError: LocalizedStringKey?
    var directLookupPlayerId: String?

    var playerSummary: PlayerSummary?
    var statsSummary: PlayerStatsSummary?
    var careerStats: [String: [CareerStatCategory]]?
    var heroGlobalStats: [HeroGlobalStat] = []
    var heroes: [HeroInfo] = []
    var isLoadingProfile = false
    var profileError: LocalizedStringKey?

    var selectedMode: GameMode = .quickplay
    var selectedPlatform: Platform?
    var isPrivateProfile = false
    private var heroesLocale: String?
    var showExpandedStats = false
    var currentPlayerId: String?

    private let api = OverwatchAPIService.shared

    // MARK: - Search
    func searchPlayers() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearching = true
        searchError = nil
        searchResults = []
        directLookupPlayerId = nil

        // If input contains #, convert to - and try direct lookup
        if query.contains("#") {
            let playerId = query.replacingOccurrences(of: "#", with: "-")
            do {
                let summary = try await api.getPlayerSummary(playerId: playerId)
                directLookupPlayerId = playerId
                let result = PlayerSearchResult(
                    playerId: playerId,
                    name: summary.username,
                    avatar: summary.avatar,
                    namecard: summary.namecard,
                    title: summary.title,
                    careerUrl: nil,
                    blizzardId: nil,
                    lastUpdatedAt: nil,
                    isPublic: true
                )
                searchResults = [result]
                isSearching = false
                return
            } catch {
                // Direct lookup failed, fallback to search
            }
        }

        // Search by name
        let searchName = query.split(separator: "#").first.map(String.init) ?? query
        do {
            let response = try await api.searchPlayers(name: searchName)
            searchResults = response.results
            if response.results.isEmpty {
                searchError = "No players found for \"\(searchName)\""
            }
        } catch {
            searchError = APIError.from(error).message
        }

        isSearching = false
    }

    // MARK: - Load Player Profile
    func loadPlayerProfile(playerId: String) async {
        currentPlayerId = playerId
        isLoadingProfile = true
        profileError = nil
        playerSummary = nil
        statsSummary = nil
        careerStats = nil
        showExpandedStats = false
        selectedPlatform = nil
        isPrivateProfile = false

        async let heroesTask: () = ensureHeroesLoaded()
        async let globalStatsTask: () = loadHeroGlobalStats()

        await loadSummary(playerId: playerId)
        selectedPlatform = defaultPlatform

        async let statsTask: () = loadStats(playerId: playerId)
        async let careerTask: () = loadCareerStats(playerId: playerId)
        await statsTask
        await careerTask
        await heroesTask
        await globalStatsTask
        if playerSummary != nil, statsSummary?.general == nil {
            isPrivateProfile = await api.isProfilePrivate(playerId: playerId, summary: playerSummary)
        }
        recordSnapshots(playerId: playerId)

        isLoadingProfile = false
    }

    private func loadSummary(playerId: String) async {
        do {
            playerSummary = try await api.getPlayerSummary(playerId: playerId)
        } catch {
            profileError = APIError.from(error).message
        }
    }

    // MARK: - Platform
    var availablePlatforms: [Platform] {
        let ranks = playerSummary?.competitive
        return ranks?.pc != nil && ranks?.console != nil ? Platform.allCases : []
    }

    var displayedRanks: PlatformRanks? {
        let ranks = playerSummary?.competitive
        return selectedPlatform == .console ? ranks?.console : (ranks?.pc ?? ranks?.console)
    }

    private var defaultPlatform: Platform? {
        let ranks = playerSummary?.competitive
        if ranks?.pc != nil { return .pc }
        if ranks?.console != nil { return .console }
        return nil
    }

    func switchPlatform(_ platform: Platform) async {
        guard platform != selectedPlatform, let playerId = currentPlayerId else { return }
        selectedPlatform = platform
        await reloadStats(playerId: playerId)
    }

    // MARK: - Switch Game Mode
    func switchMode(_ mode: GameMode) async {
        guard mode != selectedMode, let playerId = currentPlayerId else { return }
        selectedMode = mode
        await reloadStats(playerId: playerId)
    }

    private func reloadStats(playerId: String) async {
        showExpandedStats = false
        statsSummary = nil
        careerStats = nil

        async let statsTask: () = loadStats(playerId: playerId)
        async let careerTask: () = loadCareerStats(playerId: playerId)
        await statsTask
        await careerTask
        recordSnapshots(playerId: playerId)
    }

    private func recordSnapshots(playerId: String) {
        guard currentPlayerId == playerId else { return }
        let storage = LocalStorageService.shared
        if let ranks = displayedRanks {
            storage.saveRankSnapshot(RankSnapshot(
                playerId: playerId,
                date: Date(),
                season: ranks.season,
                scores: RankScore.scores(for: ranks)
            ))
        }
        guard let general = statsSummary?.general else { return }
        storage.addSnapshot(StatSnapshot(
            id: UUID(),
            playerId: playerId,
            date: Date(),
            gamemode: selectedMode.rawValue,
            winrate: general.winrate ?? 0,
            kda: general.kda ?? 0,
            gamesPlayed: general.gamesPlayed ?? 0,
            elimsPer10: general.average?.eliminations ?? 0,
            deathsPer10: general.average?.deaths ?? 0,
            damagePer10: general.average?.damage ?? 0,
            healingPer10: general.average?.healing ?? 0,
            assistsPer10: assistsPer10,
            gamesWon: general.gamesWon
        ))
    }

    private func loadStats(playerId: String) async {
        do {
            statsSummary = try await api.getPlayerStatsSummary(
                playerId: playerId,
                gamemode: selectedMode,
                platform: selectedPlatform
            )
        } catch {
            if profileError == nil {
                profileError = APIError.from(error).message
            }
        }
    }

    private func loadCareerStats(playerId: String) async {
        do {
            careerStats = try await api.getPlayerCareerStats(playerId: playerId, gamemode: selectedMode, platform: selectedPlatform)
        } catch {
            // Non-critical, career stats are supplementary
        }
    }

    private func loadHeroGlobalStats() async {
        guard heroGlobalStats.isEmpty else { return }
        do {
            heroGlobalStats = try await api.getHeroGlobalStats(region: .preferred)
        } catch {
            // Non-critical
        }
    }

    func heroGlobalWinrate(for heroKey: String) -> Double? {
        heroGlobalStats.first { $0.hero == heroKey }?.winrate
    }

    func heroGlobalPickrate(for heroKey: String) -> Double? {
        heroGlobalStats.first { $0.hero == heroKey }?.pickrate
    }

    func careerStatsForHero(_ heroKey: String) -> [CareerStatCategory]? {
        careerStats?[heroKey]
    }

    func careerStatsAllHeroes() -> [CareerStatCategory]? {
        careerStats?["all-heroes"]
    }

    func ensureHeroesLoaded() async {
        let locale = APILocale.current
        guard heroes.isEmpty || heroesLocale != locale else { return }
        do {
            heroes = try await api.getHeroes(locale: locale)
            heroesLocale = locale
        } catch {
            // Non-critical
        }
    }

    func heroRole(for key: String) -> String {
        heroInfo(for: key)?.role ?? HeroRoles.role(for: key)
    }

    // Uses career stats because the summary endpoint only counts offensive assists.
    func roleAssistDeathRatio(for role: String) -> Double? {
        if let totals = careerTotals(for: role), totals.isReliable {
            guard totals.assists > 0 || totals.deaths > 0 else { return nil }
            return totals.assists / max(totals.deaths, 1)
        }
        guard let total = statsSummary?.roles?[role]?.total,
              let assists = total.assists, let deaths = total.deaths else { return nil }
        return Double(assists) / Double(max(deaths, 1))
    }

    private func careerValue(_ categories: [CareerStatCategory], category: String, key: String) -> Double? {
        categories.first { $0.category == category }?
            .stats?.first { $0.key == key }?
            .value?.doubleValue
    }

    // MARK: - Computed: General Stats
    var overallWinRate: Double {
        statsSummary?.general?.winrate ?? 0
    }

    var overallGamesPlayed: Int {
        statsSummary?.general?.gamesPlayed ?? 0
    }

    var overallGamesWon: Int {
        statsSummary?.general?.gamesWon ?? 0
    }

    var overallKDA: Double {
        statsSummary?.general?.kda ?? 0
    }

    var totalEliminations: Int {
        statsSummary?.general?.total?.eliminations ?? 0
    }

    var totalDeaths: Int {
        statsSummary?.general?.total?.deaths ?? 0
    }

    var totalAssists: Int {
        if let totals = careerTotals(for: nil), totals.isReliable { return Int(totals.assists) }
        return statsSummary?.general?.total?.assists ?? 0
    }

    var totalPlayTimeSeconds: Int {
        statsSummary?.general?.timePlayed ?? 0
    }

    var totalPlayTimeHours: Int {
        totalPlayTimeSeconds / 3600
    }

    // Per 10min stats (from average field)
    var elimsPer10: Double { statsSummary?.general?.average?.eliminations ?? 0 }
    var deathsPer10: Double { statsSummary?.general?.average?.deaths ?? 0 }
    var assistsPer10: Double { assistsPer10(for: nil) }

    // The summary endpoint only counts offensive assists; career stats carry the full total.
    func assistsPer10(for role: String?) -> Double {
        if let totals = careerTotals(for: role), totals.isReliable, totals.seconds > 0 {
            return totals.assists / totals.seconds * 600
        }
        if let role, let entry = statsSummary?.roles?[role] {
            return entry.average?.assists ?? 0
        }
        return statsSummary?.general?.average?.assists ?? 0
    }

    private func withCareerAssists(_ key: String, _ stats: HeroStatEntry) -> HeroStatEntry {
        guard let categories = careerStats?[key],
              let assists = careerValue(categories, category: "assists", key: "assists"),
              assists >= careerValue(categories, category: "assists", key: "offensive_assists") ?? 0 else { return stats }
        let seconds = Double(stats.timePlayed ?? 0)
        let per10 = seconds > 0 ? assists / seconds * 600 : stats.average?.assists
        return HeroStatEntry(
            gamesPlayed: stats.gamesPlayed,
            gamesWon: stats.gamesWon,
            gamesLost: stats.gamesLost,
            timePlayed: stats.timePlayed,
            winrate: stats.winrate,
            kda: stats.kda,
            total: stats.total.map {
                StatTotals(eliminations: $0.eliminations, assists: Int(assists), deaths: $0.deaths, damage: $0.damage, healing: $0.healing)
            },
            average: stats.average.map {
                StatAverages(eliminations: $0.eliminations, assists: per10, deaths: $0.deaths, damage: $0.damage, healing: $0.healing)
            }
        )
    }

    // Blizzard's newer "assists" stat does not cover older play time. When it is smaller than the
    // legacy offensive-assist count it is incomplete, so callers fall back to the summary numbers.
    private struct CareerAssistTotals {
        var assists = 0.0
        var offensive = 0.0
        var deaths = 0.0
        var seconds = 0.0
        var isReliable: Bool { assists >= offensive }
    }

    private func careerTotals(for role: String?) -> CareerAssistTotals? {
        guard let careerStats else { return nil }
        func add(_ categories: [CareerStatCategory], to totals: inout CareerAssistTotals) {
            totals.assists += careerValue(categories, category: "assists", key: "assists") ?? 0
            totals.offensive += careerValue(categories, category: "assists", key: "offensive_assists") ?? 0
            totals.deaths += careerValue(categories, category: "combat", key: "deaths") ?? 0
            totals.seconds += careerValue(categories, category: "game", key: "time_played") ?? 0
        }
        var totals = CareerAssistTotals()
        if role == nil, let all = careerStats["all-heroes"] {
            add(all, to: &totals)
            return totals
        }
        for (hero, categories) in careerStats where hero != "all-heroes" && (role == nil || heroRole(for: hero) == role) {
            add(categories, to: &totals)
        }
        return totals
    }
    var damagePer10: Double { statsSummary?.general?.average?.damage ?? 0 }
    var healingPer10: Double { statsSummary?.general?.average?.healing ?? 0 }

    // MARK: - Computed: Top Heroes
    var topHeroes: [HeroWithStats] {
        guard let heroDict = statsSummary?.heroes else { return [] }
        return heroDict
            .map { HeroWithStats(key: $0.key, stats: withCareerAssists($0.key, $0.value)) }
            .sorted { $0.stats.timePlayedHours > $1.stats.timePlayedHours }
            .prefix(3)
            .map { $0 }
    }

    var allHeroesSorted: [HeroWithStats] {
        guard let heroDict = statsSummary?.heroes else { return [] }
        return heroDict
            .map { HeroWithStats(key: $0.key, stats: withCareerAssists($0.key, $0.value)) }
            .sorted { $0.stats.timePlayedHours > $1.stats.timePlayedHours }
    }

    func heroInfo(for key: String) -> HeroInfo? {
        heroes.first { $0.key == key }
    }

    func heroPortraitURL(for key: String) -> URL? {
        if let info = heroInfo(for: key), let portrait = info.portrait {
            return URL(string: portrait)
        }
        return nil
    }

    // MARK: - Computed: Role Stats
    var roleStats: [RoleWithStats] {
        guard let roleDict = statsSummary?.roles else { return [] }
        let order = ["tank", "damage", "support", "open"]
        return roleDict
            .map { RoleWithStats(key: $0.key, stats: $0.value) }
            .sorted { a, b in
                let ia = order.firstIndex(of: a.key) ?? 99
                let ib = order.firstIndex(of: b.key) ?? 99
                return ia < ib
            }
    }

    // MARK: - Radar Chart Data
    var selectedRadarRole: String? = nil // nil = all, "tank", "damage", "support"

    struct RadarDataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double // 0-1 normalized
    }

    // Role-specific benchmarks (approximate community medians per 10 min)
    // These represent typical Gold-Platinum level averages
    private static let roleBenchmarks: [String?: (elims: Double, assists: Double, deaths: Double, damage: Double, healing: Double)] = [
        nil:        (elims: 14.0, assists: 4.0,  deaths: 6.5, damage: 6000,  healing: 2500),
        "tank":     (elims: 16.0, assists: 3.0,  deaths: 5.5, damage: 8000,  healing: 500),
        "damage":   (elims: 18.0, assists: 1.0,  deaths: 7.0, damage: 8500,  healing: 200),
        "support":  (elims: 10.0, assists: 7.0,  deaths: 6.0, damage: 3500,  healing: 6000),
    ]

    // Max scale values per role (top-tier performance ceiling)
    private static let roleMaxValues: [String?: (elims: Double, assists: Double, deaths: Double, damage: Double, healing: Double)] = [
        nil:        (elims: 28.0, assists: 15.0, deaths: 15.0, damage: 12000, healing: 8000),
        "tank":     (elims: 28.0, assists: 10.0, deaths: 15.0, damage: 14000, healing: 3000),
        "damage":   (elims: 30.0, assists: 6.0,  deaths: 15.0, damage: 14000, healing: 2000),
        "support":  (elims: 18.0, assists: 15.0, deaths: 15.0, damage: 6000,  healing: 10000),
    ]

    func radarData(for role: String?) -> [RadarDataPoint] {
        let avg: StatAverages?
        let deaths: Double

        if let role = role, let roleEntry = statsSummary?.roles?[role] {
            avg = roleEntry.average
            deaths = roleEntry.average?.deaths ?? 0
        } else {
            avg = statsSummary?.general?.average
            deaths = deathsPer10
        }

        let elims = avg?.eliminations ?? 0
        let assists = assistsPer10(for: role)
        let damage = avg?.damage ?? 0
        let healing = avg?.healing ?? 0

        let maxVals = Self.roleMaxValues[role] ?? Self.roleMaxValues[nil]!
        let survivability = max(0, 1.0 - (deaths / maxVals.deaths))

        return [
            RadarDataPoint(label: "Elims", value: min(1, elims / maxVals.elims)),
            RadarDataPoint(label: "Assists", value: min(1, assists / maxVals.assists)),
            RadarDataPoint(label: "Survival", value: min(1, survivability)),
            RadarDataPoint(label: "Damage", value: min(1, damage / maxVals.damage)),
            RadarDataPoint(label: "Healing", value: min(1, healing / maxVals.healing)),
        ]
    }

    func radarMedianData(for role: String?) -> [RadarDataPoint] {
        let bench = Self.roleBenchmarks[role] ?? Self.roleBenchmarks[nil]!
        let maxVals = Self.roleMaxValues[role] ?? Self.roleMaxValues[nil]!
        let medianSurvival = max(0, 1.0 - (bench.deaths / maxVals.deaths))

        return [
            RadarDataPoint(label: "Elims", value: min(1, bench.elims / maxVals.elims)),
            RadarDataPoint(label: "Assists", value: min(1, bench.assists / maxVals.assists)),
            RadarDataPoint(label: "Survival", value: min(1, medianSurvival)),
            RadarDataPoint(label: "Damage", value: min(1, bench.damage / maxVals.damage)),
            RadarDataPoint(label: "Healing", value: min(1, bench.healing / maxVals.healing)),
        ]
    }
}
