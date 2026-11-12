import Foundation

enum BackendConfig {
    // Base URL of the deployed backend/statswatch-worker, e.g. "https://statswatch-worker.example.workers.dev".
    // In-app feedback and Battle.net sign-in stay unavailable while this is empty.
    static let baseURL = "https://statswatch-worker.statswatch-worker.workers.dev"

    // Turn on only after BNET_CLIENT_ID and BNET_CLIENT_SECRET are set on the worker;
    // otherwise the sign-in button would show and fail.
    static let battleNetSignInEnabled = false

    static var isConfigured: Bool { URL(string: baseURL)?.host != nil }
}
