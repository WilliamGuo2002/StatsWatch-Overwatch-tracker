import SwiftUI

struct FeedbackTipView: View {
    @Environment(\.openURL) private var openURL
    @State private var composeCategory: FeedbackCategory?

    private let paypalURL = "https://paypal.me/wg1018"
    private let appStoreURL = ""        // TODO: fill in

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App info header
                VStack(spacing: 10) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("StatsWatch")
                        .font(.system(size: 26, weight: .bold))

                    Text("Overwatch Stats Tracker")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    Text(verbatim: "v\(appVersion)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 20)

                // Feedback section
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("Feedback")
                            .font(.system(size: 16, weight: .bold))
                    } icon: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundStyle(.blue)
                    }

                    FeedbackRow(
                        icon: "envelope.fill",
                        title: String(localized: "Contact Developer"),
                        subtitle: String(localized: "Send us a message"),
                        color: .blue
                    ) {
                        composeCategory = .general
                    }

                    FeedbackRow(
                        icon: "ladybug.fill",
                        title: String(localized: "Report a Bug"),
                        subtitle: String(localized: "Help us improve the app"),
                        color: .red
                    ) {
                        composeCategory = .bug
                    }

                    FeedbackRow(
                        icon: "lightbulb.fill",
                        title: String(localized: "Suggest a Feature"),
                        subtitle: String(localized: "We'd love to hear your ideas"),
                        color: .yellow
                    ) {
                        composeCategory = .feature
                    }

                    FeedbackRow(
                        icon: "star.fill",
                        title: String(localized: "Rate on App Store"),
                        subtitle: String(localized: "Your review helps a lot!"),
                        color: .orange
                    ) {
                        if !appStoreURL.isEmpty, let url = URL(string: appStoreURL) {
                            openURL(url)
                        }
                    }
                }
                .padding(.horizontal)

                // Tip / Donate section
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("Support the Developer")
                            .font(.system(size: 16, weight: .bold))
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                    }

                    VStack(spacing: 12) {
                        Text("StatsWatch is a free, ad-free app made with love. If you enjoy it, consider buying me a coffee!")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // PayPal
                        Button {
                            if let url = URL(string: paypalURL) {
                                openURL(url)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text("P")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color(red: 0.0, green: 0.19, blue: 0.54))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Text("Tip via PayPal")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                            }
                            .padding(14)
                            .background(Color(red: 0.0, green: 0.19, blue: 0.54).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                // Legal & Credits
                VStack(spacing: 10) {
                    Divider()
                        .padding(.vertical, 4)

                    VStack(spacing: 6) {
                        Text("Disclaimer")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)

                        Text("This is an unofficial app and is not affiliated with, endorsed by, or connected to Blizzard Entertainment, Inc. Overwatch, the Overwatch logo, and all related heroes, names, images, and assets are trademarks or registered trademarks of Blizzard Entertainment, Inc.")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Player data is retrieved from publicly available profiles via the OverFast API. This app does not collect, store, or share any personal information beyond what is saved locally on your device, except feedback you choose to send.")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)

                    Divider()

                    Text("Data provided by OverFast API")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Text("Made with ❤️ for the Overwatch community")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("About & Support")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $composeCategory) { category in
            NavigationStack {
                FeedbackComposeView(category: category)
            }
        }
    }
}

// MARK: - Feedback Row
struct FeedbackRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
