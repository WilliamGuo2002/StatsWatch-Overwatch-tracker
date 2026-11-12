import AuthenticationServices
import Foundation
import SwiftUI

enum BattleNetAuth {
    static let callbackScheme = "statswatch"
    static let storageKey = "my_battletag"

    enum AuthError: Error {
        case failed(String)
    }

    static var isConfigured: Bool { BackendConfig.isConfigured }

    /// Returns the signed-in player's BattleTag ("Name#1234").
    static func signIn(using session: WebAuthenticationSession) async throws -> String {
        let state = UUID().uuidString
        guard var components = URLComponents(string: BackendConfig.baseURL + "/login") else {
            throw AuthError.failed("bad_config")
        }
        components.queryItems = [URLQueryItem(name: "state", value: state)]
        guard let loginURL = components.url else { throw AuthError.failed("bad_config") }

        let callback = try await session.authenticate(
            using: loginURL,
            callbackURLScheme: callbackScheme,
            preferredBrowserSession: .ephemeral
        )
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        guard value("state") == state else { throw AuthError.failed("state_mismatch") }
        if let error = value("error") { throw AuthError.failed(error) }
        guard let battleTag = value("battletag"), battleTag.contains("#") else {
            throw AuthError.failed("no_battletag")
        }
        return battleTag
    }

    static func isCancellation(_ error: Error) -> Bool {
        (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
    }
}

// MARK: - Friend links
enum FriendLink {
    static func url(for playerId: String) -> URL? {
        var components = URLComponents()
        components.scheme = BattleNetAuth.callbackScheme
        components.host = "player"
        components.path = "/" + playerId
        return components.url
    }

    /// Extracts a player id ("Name-1234") from statswatch://player/Name-1234.
    static func playerId(from url: URL) -> String? {
        guard url.scheme == BattleNetAuth.callbackScheme, url.host == "player",
              let id = url.pathComponents.dropFirst().first,
              let dash = id.lastIndex(of: "-"),
              dash != id.startIndex,
              !id[id.index(after: dash)...].isEmpty,
              id[id.index(after: dash)...].allSatisfy(\.isNumber) else { return nil }
        return id
    }
}
