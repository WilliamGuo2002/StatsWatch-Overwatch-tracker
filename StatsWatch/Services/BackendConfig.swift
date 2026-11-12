import Foundation

enum BackendConfig {
    // Base URL of the deployed backend/statswatch-worker, e.g. "https://statswatch-worker.example.workers.dev".
    // Battle.net sign-in and in-app feedback stay unavailable while this is empty.
    static let baseURL = ""

    static var isConfigured: Bool { URL(string: baseURL)?.host != nil }
}
