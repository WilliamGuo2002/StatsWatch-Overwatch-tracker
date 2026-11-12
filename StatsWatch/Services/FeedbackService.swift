import Foundation
import UIKit

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case general, bug, feature
    var id: String { rawValue }
}

enum FeedbackService {
    struct DeviceInfo: Encodable {
        let appVersion: String
        let build: String
        let iosVersion: String
        let model: String
        let language: String

        @MainActor static var current: DeviceInfo {
            let info = Bundle.main.infoDictionary
            return DeviceInfo(
                appVersion: info?["CFBundleShortVersionString"] as? String ?? "?",
                build: info?["CFBundleVersion"] as? String ?? "?",
                iosVersion: UIDevice.current.systemVersion,
                model: UIDevice.current.model,
                language: Locale.preferredLanguages.first ?? "unknown"
            )
        }
    }

    private struct Payload: Encodable {
        let category: String
        let message: String
        let contact: String
        let device: DeviceInfo?
    }

    enum SendError: Error {
        case notConfigured, rateLimited, failed
    }

    static func send(category: FeedbackCategory, message: String, contact: String, device: DeviceInfo?) async throws {
        guard BackendConfig.isConfigured, let url = URL(string: BackendConfig.baseURL + "/feedback") else {
            throw SendError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONEncoder().encode(Payload(
            category: category.rawValue,
            message: message,
            contact: contact,
            device: device
        ))
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 429 { throw SendError.rateLimited }
        guard (200...299).contains(status) else { throw SendError.failed }
    }
}
