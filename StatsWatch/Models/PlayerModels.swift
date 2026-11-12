import Foundation
import SwiftUI

// MARK: - Player Search
struct PlayerSearchResult: Codable, Identifiable {
    var id: String { playerId }
    let playerId: String
    let name: String?
    let avatar: String?
    let namecard: String?
    let title: String?
    let careerUrl: String?
    let blizzardId: String?
    let lastUpdatedAt: Int?
    let isPublic: Bool?

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case name, avatar, namecard, title
        case careerUrl = "career_url"
        case blizzardId = "blizzard_id"
        case lastUpdatedAt = "last_updated_at"
        case isPublic = "is_public"
    }
}

struct PlayerSearchResponse: Codable {
    let total: Int
    let results: [PlayerSearchResult]
}

// MARK: - Player Summary
struct PlayerSummary: Codable {
    let username: String?
    let avatar: String?
    let namecard: String?
    let title: String?
    let endorsement: Endorsement?
    let competitive: CompetitiveRanks?
    let lastUpdatedAt: Int?

    enum CodingKeys: String, CodingKey {
        case username, avatar, namecard, title, endorsement, competitive
        case lastUpdatedAt = "last_updated_at"
    }
}

struct Endorsement: Codable {
    let level: Int?
    let frame: String?
}

struct CompetitiveRanks: Codable {
    let pc: PlatformRanks?
    let console: PlatformRanks?
}

struct PlatformRanks: Codable {
    let season: Int?
    let tank: RankInfo?
    let damage: RankInfo?
    let support: RankInfo?
    let open: RankInfo?

    /// Convert API cumulative season number to the new era season number.
    /// The Feb 2025 major update reset seasons — OW2 Season 14 (API value ~14)
    /// became the new Season 1. Adjust the offset if the API numbering changes.
    var displaySeason: Int? {
        guard let s = season else { return nil }
        let newEraSeason = s - 20  // API 21 → display 1, API 22 → display 2, etc.
        return newEraSeason > 0 ? newEraSeason : s
    }
}

struct RankInfo: Codable {
    let division: String?
    let tier: Int?
    let roleIcon: String?
    let rankIcon: String?
    let tierIcon: String?

    enum CodingKeys: String, CodingKey {
        case division, tier
        case roleIcon = "role_icon"
        case rankIcon = "rank_icon"
        case tierIcon = "tier_icon"
    }
}

// MARK: - Player Stats Summary
struct PlayerStatsSummary: Codable {
    let general: GeneralStats?
    let heroes: [String: HeroStatEntry]?
    let roles: [String: RoleStatEntry]?
}

struct GeneralStats: Codable {
    let gamesPlayed: Int?
    let gamesWon: Int?
    let gamesLost: Int?
    let timePlayed: Int? // seconds
    let winrate: Double?
    let kda: Double?
    let total: StatTotals?
    let average: StatAverages?

    enum CodingKeys: String, CodingKey {
        case gamesPlayed = "games_played"
        case gamesWon = "games_won"
        case gamesLost = "games_lost"
        case timePlayed = "time_played"
        case winrate, kda, total, average
    }
}

struct StatTotals: Codable {
    let eliminations: Int?
    let assists: Int?
    let deaths: Int?
    let damage: Int?
    let healing: Int?
}

struct StatAverages: Codable {
    let eliminations: Double?
    let assists: Double?
    let deaths: Double?
    let damage: Double?
    let healing: Double?
}

struct HeroStatEntry: Codable {
    let gamesPlayed: Int?
    let gamesWon: Int?
    let gamesLost: Int?
    let timePlayed: Int? // seconds
    let winrate: Double?
    let kda: Double?
    let total: StatTotals?
    let average: StatAverages?

    enum CodingKeys: String, CodingKey {
        case gamesPlayed = "games_played"
        case gamesWon = "games_won"
        case gamesLost = "games_lost"
        case timePlayed = "time_played"
        case winrate, kda, total, average
    }

    var timePlayedHours: Double {
        Double(timePlayed ?? 0) / 3600.0
    }
}

struct RoleStatEntry: Codable {
    let gamesPlayed: Int?
    let gamesWon: Int?
    let gamesLost: Int?
    let timePlayed: Int? // seconds
    let winrate: Double?
    let kda: Double?
    let total: StatTotals?
    let average: StatAverages?

    enum CodingKeys: String, CodingKey {
        case gamesPlayed = "games_played"
        case gamesWon = "games_won"
        case gamesLost = "games_lost"
        case timePlayed = "time_played"
        case winrate, kda, total, average
    }

    var killDeathRatio: Double? { Self.ratio(total?.eliminations, total?.deaths) }

    // Zero deaths is treated as one so a deathless role still shows its raw count.
    private static func ratio(_ numerator: Int?, _ deaths: Int?) -> Double? {
        guard let numerator, let deaths else { return nil }
        return Double(numerator) / Double(max(deaths, 1))
    }
}

// MARK: - Hero Info
struct HeroInfo: Codable, Identifiable {
    var id: String { key }
    let key: String
    let name: String
    let portrait: String?
    let role: String?
    let subrole: String?
}

// MARK: - Platform
enum Platform: String, CaseIterable {
    case pc
    case console

    var displayName: LocalizedStringKey {
        switch self {
        case .pc: return "PC"
        case .console: return "Console"
        }
    }
}

// MARK: - Game Mode
enum GameMode: String, CaseIterable {
    case quickplay = "quickplay"
    case competitive = "competitive"

    var displayName: LocalizedStringKey {
        switch self {
        case .quickplay: return "Quick Play"
        case .competitive: return "Competitive"
        }
    }
}

// MARK: - Hero Role Mapping
struct HeroRoles {
    static let tank: Set<String> = [
        "dva", "doomfist", "junker-queen", "mauga", "orisa",
        "ramattra", "reinhardt", "roadhog", "sigma", "winston",
        "wrecking-ball", "zarya", "hazard"
    ]

    static let damage: Set<String> = [
        "ashe", "bastion", "cassidy", "echo", "genji", "hanzo",
        "junkrat", "mei", "pharah", "reaper", "sojourn", "soldier-76",
        "sombra", "symmetra", "torbjorn", "tracer", "widowmaker",
        "venture", "freja", "vendetta", "emre"
    ]

    static let support: Set<String> = [
        "ana", "baptiste", "brigitte", "illari", "juno",
        "kiriko", "lifeweaver", "lucio", "mercy", "moira",
        "zenyatta"
    ]

    static func role(for hero: String) -> String {
        let key = hero.lowercased()
        if tank.contains(key) { return "tank" }
        if damage.contains(key) { return "damage" }
        if support.contains(key) { return "support" }
        return "damage"
    }
}

// MARK: - Display Helpers
struct HeroWithStats: Identifiable {
    var id: String { key }
    let key: String
    let stats: HeroStatEntry
}

struct RoleWithStats: Identifiable {
    var id: String { key }
    let key: String
    let stats: RoleStatEntry
}

/// Convert playerId (Name-1234) back to BattleTag display format (Name#1234)
func formatBattleTag(from playerId: String) -> String {
    // Find the last "-" which separates name from number
    if let lastDash = playerId.lastIndex(of: "-") {
        let name = String(playerId[playerId.startIndex..<lastDash])
        let number = String(playerId[playerId.index(after: lastDash)...])
        // Only format as BattleTag if the part after dash is numeric
        if number.allSatisfy(\.isNumber) && !number.isEmpty {
            return "\(name)#\(number)"
        }
    }
    return playerId
}

func formatTimePlayed(seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}

func formatTimePlayedShort(seconds: Int) -> String {
    let hours = seconds / 3600
    if hours > 0 {
        return "\(hours)h"
    }
    let minutes = (seconds % 3600) / 60
    return "\(minutes)m"
}

// MARK: - Hero Detail (from /heroes/{hero_key})
struct HeroDetail: Codable {
    let name: String?
    let description: String?
    let role: String?
    let location: String?
    let birthday: String?
    let age: Int?
    let hitpoints: HeroHitpoints?
    let abilities: [HeroAbility]?
    let story: HeroStory?
    let subrole: String?
    let perks: HeroPerks?
    let stadiumPowers: [HeroPower]?

    enum CodingKeys: String, CodingKey {
        case name, description, role, location, birthday, age, hitpoints, abilities, story, subrole, perks
        case stadiumPowers = "stadium_powers"
    }
}

struct HeroPerks: Codable {
    let minor: [HeroPower]?
    let major: [HeroPower]?
}

struct HeroPower: Codable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let description: String?
    let icon: String?
}

struct HeroHitpoints: Codable {
    let armor: Int?
    let shields: Int?
    let health: Int?
    let total: Int?
}

struct HeroAbility: Codable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let description: String?
    let icon: String?
    let video: HeroAbilityVideo?
}

struct HeroAbilityVideo: Codable {
    let thumbnail: String?
    let link: HeroAbilityVideoLink?
}

struct HeroAbilityVideoLink: Codable {
    let mp4: String?
    let webm: String?
}

struct HeroStory: Codable {
    let summary: String?
    let media: HeroStoryMedia?
}

struct HeroStoryMedia: Codable {
    let type: String?
    let link: String?
}

// MARK: - Hero Global Stats (from /heroes/stats)
struct HeroGlobalStat: Codable, Identifiable {
    var id: String { hero }
    let hero: String
    let pickrate: Double?
    let winrate: Double?
    let banrate: Double?
}

// MARK: - Hero Comparisons (from /players/{id})
struct PlayerFullResponse: Codable {
    let stats: PlayerPlatformStats?
}

struct PlayerPlatformStats: Codable {
    let pc: PlayerModeStats?
    let console: PlayerModeStats?
}

struct PlayerModeStats: Codable {
    let quickplay: PlayerGamemodeStats?
    let competitive: PlayerGamemodeStats?
}

struct PlayerGamemodeStats: Codable {
    let heroesComparisons: [String: HeroComparisonMetric]?

    enum CodingKeys: String, CodingKey {
        case heroesComparisons = "heroes_comparisons"
    }
}

struct HeroComparisonMetric: Codable {
    let label: String?
    let values: [HeroComparisonValue]?
}

struct HeroComparisonValue: Codable, Identifiable {
    var id: String { hero }
    let hero: String
    let value: Double
}

// MARK: - Career Stats (from /players/{id}/stats/career)
struct CareerStatCategory: Codable, Identifiable {
    var id: String { category ?? UUID().uuidString }
    let category: String?
    let label: String?
    let stats: [CareerStat]?
}

struct CareerStat: Codable, Identifiable {
    var id: String { key ?? UUID().uuidString }
    let key: String?
    let label: String?
    let value: AnyCodableValue?
}

// Flexible value that can be Int, Double, or String
enum AnyCodableValue: Codable {
    case int(Int)
    case double(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else {
            self = .int(0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }

    var displayString: String {
        switch self {
        case .int(let v): return "\(v)"
        case .double(let v):
            if v == v.rounded() { return "\(Int(v))" }
            return String(format: "%.2f", v)
        case .string(let v): return v
        }
    }

    var doubleValue: Double {
        switch self {
        case .int(let v): return Double(v)
        case .double(let v): return v
        case .string(let v): return Double(v) ?? 0
        }
    }
}

// MARK: - Map Info (from /maps)
struct MapInfo: Codable, Identifiable {
    var id: String { key }
    let key: String
    let name: String
    let screenshot: String?
    let gamemodes: [String]?
    let location: String?
    let countryCode: String?

    enum CodingKeys: String, CodingKey {
        case key, name, screenshot, gamemodes, location
        case countryCode = "country_code"
    }
}

// MARK: - Gamemode Info (from /gamemodes)
struct GamemodeInfo: Codable, Identifiable {
    var id: String { key }
    let key: String
    let name: String
    let icon: String?
    let description: String?
    let screenshot: String?
}

// MARK: - Local Persistence Models
struct FavoritePlayer: Codable, Identifiable {
    var id: String { playerId }
    let playerId: String
    let name: String
    let avatar: String?
    let addedAt: Date
}

struct SearchHistoryItem: Codable, Identifiable {
    var id: String { playerId }
    let playerId: String
    let name: String
    let avatar: String?
    let searchedAt: Date
}

// MARK: - Widget Data (shared with Widget Extension via App Group)
struct WidgetPlayerData: Codable {
    let name: String
    let winrate: Double
    let kda: Double
    let gamesPlayed: Int
    let rank: String?
    let updatedAt: Date
}

struct StatSnapshot: Codable, Identifiable {
    let id: UUID
    let playerId: String
    let date: Date
    let gamemode: String
    let winrate: Double
    let kda: Double
    let gamesPlayed: Int
    let elimsPer10: Double
    let deathsPer10: Double
    let damagePer10: Double
    let healingPer10: Double
    let assistsPer10: Double
    var gamesWon: Int? = nil

    var derivedGamesWon: Int {
        gamesWon ?? Int((winrate / 100 * Double(gamesPlayed)).rounded())
    }
}

// MARK: - Rank Snapshot
struct RankSnapshot: Codable, Identifiable {
    var id: String { "\(playerId)-\(date.timeIntervalSince1970)" }
    let playerId: String
    let date: Date
    let season: Int?
    let scores: [String: Int]
}

enum RankScore {
    static let roles = ["tank", "damage", "support", "open"]
    private static let divisions = ["bronze", "silver", "gold", "platinum", "emerald", "diamond", "master", "grandmaster", "ultimate"]

    // Bronze 5 = 0, each tier +1, Champion 1 = 44.
    static func score(_ rank: RankInfo?) -> Int? {
        guard let division = rank?.division?.lowercased(),
              let index = divisions.firstIndex(of: division),
              let tier = rank?.tier, (1...5).contains(tier) else { return nil }
        return index * 5 + (5 - tier)
    }

    static func scores(for ranks: PlatformRanks?) -> [String: Int] {
        var result: [String: Int] = [:]
        result["tank"] = score(ranks?.tank)
        result["damage"] = score(ranks?.damage)
        result["support"] = score(ranks?.support)
        result["open"] = score(ranks?.open)
        return result
    }

    static func divisionName(forScore score: Int) -> String {
        let division = divisions[min(max(score / 5, 0), divisions.count - 1)]
        return division == "ultimate" ? "Champion" : division.capitalized
    }

    static func label(forScore score: Int) -> String {
        "\(divisionName(forScore: score)) \(5 - score % 5)"
    }
}

// MARK: - Hero Meta Region
enum MetaRegion: String, CaseIterable {
    case americas
    case europe
    case asia

    var displayName: LocalizedStringKey {
        switch self {
        case .americas: return "Americas"
        case .europe: return "Europe"
        case .asia: return "Asia"
        }
    }

    static var preferred: MetaRegion {
        ["ja-jp", "ko-kr", "zh-tw"].contains(APILocale.current) ? .asia : .americas
    }
}

// MARK: - API Locale
enum APILocale {
    // OverFast has no Simplified Chinese, so zh-Hans falls back to Traditional.
    static var current: String {
        let stored = UserDefaults.standard.string(forKey: "app_language") ?? ""
        let language = stored.isEmpty ? (Bundle.main.preferredLocalizations.first ?? "en") : stored
        switch language.prefix(2) {
        case "ja": return "ja-jp"
        case "ko": return "ko-kr"
        case "es": return "es-es"
        case "zh": return "zh-tw"
        default: return "en-us"
        }
    }
}
