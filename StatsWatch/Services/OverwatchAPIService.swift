import Foundation
import SwiftUI

actor OverwatchAPIService {
    static let shared = OverwatchAPIService()
    private let baseURL = "https://overfast-api.tekrop.fr"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search Players
    func searchPlayers(name: String) async throws -> PlayerSearchResponse {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let url = URL(string: "\(baseURL)/players?name=\(encoded)&limit=20")!
        return try await fetch(url: url)
    }

    // MARK: - Player Summary
    func getPlayerSummary(playerId: String) async throws -> PlayerSummary {
        let url = URL(string: "\(baseURL)/players/\(playerId)/summary")!
        return try await fetch(url: url)
    }

    // MARK: - Player Stats Summary
    func getPlayerStatsSummary(playerId: String, gamemode: GameMode = .quickplay, platform: Platform? = nil) async throws -> PlayerStatsSummary {
        let url = makeURL("/players/\(playerId)/stats/summary", [
            "gamemode": gamemode.rawValue,
            "platform": platform?.rawValue,
        ])
        return try await fetch(url: url)
    }

    // MARK: - Privacy
    // Search results carry an is_public flag; fall back to "summary loads but no stats in any mode".
    func isProfilePrivate(playerId: String, summary: PlayerSummary?) async -> Bool {
        let name = playerId.split(separator: "-").dropLast().joined(separator: "-")
        if let results = try? await searchPlayers(name: name.isEmpty ? playerId : name).results,
           let match = results.first(where: { $0.playerId == playerId || ($0.avatar != nil && $0.avatar == summary?.avatar) }),
           let isPublic = match.isPublic {
            return !isPublic
        }
        let allModes: PlayerStatsSummary? = try? await fetch(url: makeURL("/players/\(playerId)/stats/summary", [:]))
        return allModes?.general == nil
    }

    // MARK: - Heroes List
    func getHeroes(locale: String) async throws -> [HeroInfo] {
        try await fetch(url: makeURL("/heroes", ["locale": locale]))
    }

    // MARK: - Hero Detail
    func getHeroDetail(heroKey: String, locale: String) async throws -> HeroDetail {
        try await fetch(url: makeURL("/heroes/\(heroKey)", ["locale": locale]))
    }

    // MARK: - Hero Global Stats
    func getHeroGlobalStats(
        platform: Platform = .pc,
        gamemode: GameMode = .competitive,
        region: MetaRegion,
        division: String? = nil,
        map: String? = nil
    ) async throws -> [HeroGlobalStat] {
        let url = makeURL("/heroes/stats", [
            "platform": platform.rawValue,
            "gamemode": gamemode.rawValue,
            "region": region.rawValue,
            "competitive_division": gamemode == .competitive ? division : nil,
            "map": map,
        ])
        return try await fetch(url: url)
    }

    // MARK: - Player Career Stats
    func getPlayerCareerStats(playerId: String, gamemode: GameMode = .competitive, platform: Platform? = nil) async throws -> [String: [CareerStatCategory]] {
        let url = makeURL("/players/\(playerId)/stats", [
            "gamemode": gamemode.rawValue,
            "platform": platform?.rawValue,
        ])
        return try await fetch(url: url)
    }

    // MARK: - Hero Comparisons
    func getHeroComparisons(playerId: String, gamemode: GameMode, platform: Platform?) async throws -> [String: HeroComparisonMetric] {
        let url = makeURL("/players/\(playerId)", [
            "gamemode": gamemode.rawValue,
            "platform": platform?.rawValue,
        ])
        let response: PlayerFullResponse = try await fetch(url: url)
        let platformStats = platform == .console
            ? response.stats?.console
            : (response.stats?.pc ?? response.stats?.console)
        let modeStats = gamemode == .competitive ? platformStats?.competitive : platformStats?.quickplay
        return modeStats?.heroesComparisons ?? [:]
    }

    // MARK: - Maps
    func getMaps() async throws -> [MapInfo] {
        let url = URL(string: "\(baseURL)/maps")!
        return try await fetch(url: url)
    }

    // MARK: - Gamemodes
    func getGamemodes() async throws -> [GamemodeInfo] {
        let url = URL(string: "\(baseURL)/gamemodes")!
        return try await fetch(url: url)
    }

    private func makeURL(_ path: String, _ query: [String: String?]) -> URL {
        var components = URLComponents(string: baseURL + path)!
        let items = query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
        components.queryItems = items.isEmpty ? nil : items.sorted { $0.name < $1.name }
        return components.url!
    }

    // MARK: - Generic Fetch
    private func fetch<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw APIError.playerNotFound
            }
            if httpResponse.statusCode == 429 {
                throw APIError.rateLimited
            }
            throw APIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
}

enum APIError: Error {
    case invalidResponse
    case playerNotFound
    case rateLimited
    case serverError(Int)
    case decodingError(String)
    case network

    static func from(_ error: Error) -> APIError {
        (error as? APIError) ?? .network
    }

    var message: LocalizedStringKey {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .playerNotFound:
            return "Player not found. Check the BattleTag and try again."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .decodingError:
            return "Failed to load data. Please try again later."
        case .network:
            return "Network error. Please check your connection and try again."
        }
    }
}
