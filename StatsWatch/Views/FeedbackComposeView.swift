import SwiftUI

struct FeedbackComposeView: View {
    @State var category: FeedbackCategory
    @State private var message = ""
    @State private var contact = ""
    @State private var includeDeviceInfo = true
    @State private var isSending = false
    @State private var showSent = false
    @State private var errorMessage: LocalizedStringKey?
    @Environment(\.dismiss) private var dismiss

    private let device = FeedbackService.DeviceInfo.current

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                Picker("Category", selection: $category) {
                    ForEach(FeedbackCategory.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                ZStack(alignment: .topLeading) {
                    if message.isEmpty {
                        Text(category.placeholder)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $message)
                        .frame(minHeight: 180)
                }
            } footer: {
                Text(verbatim: "\(trimmedMessage.count)/4000")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Section {
                TextField("Your email (optional)", text: $contact)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Only used if you'd like a reply.")
            }

            Section {
                Toggle("Include device info", isOn: $includeDeviceInfo)
            } footer: {
                Text(verbatim: "StatsWatch \(device.appVersion) (\(device.build)) · iOS \(device.iosVersion) · \(device.model) · \(device.language)")
            }
        }
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isSending {
                    ProgressView()
                } else {
                    Button("Send") { Task { await send() } }
                        .disabled(trimmedMessage.count < 5)
                }
            }
        }
        .interactiveDismissDisabled(isSending || !trimmedMessage.isEmpty)
        .alert("Thanks for your feedback!", isPresented: $showSent) {
            Button("OK") { dismiss() }
        }
        .alert(
            "Couldn't send feedback",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        do {
            try await FeedbackService.send(
                category: category,
                message: String(trimmedMessage.prefix(4000)),
                contact: contact.trimmingCharacters(in: .whitespacesAndNewlines),
                device: includeDeviceInfo ? device : nil
            )
            showSent = true
        } catch FeedbackService.SendError.notConfigured {
            errorMessage = "Feedback is temporarily unavailable. Please try again later."
        } catch FeedbackService.SendError.rateLimited {
            errorMessage = "Too many requests. Please wait a moment and try again."
        } catch {
            errorMessage = "Please check your connection and try again. Your message has been kept."
        }
    }
}

extension FeedbackCategory {
    var title: LocalizedStringKey {
        switch self {
        case .general: return "General"
        case .bug: return "Bug"
        case .feature: return "Feature"
        }
    }

    var placeholder: LocalizedStringKey {
        switch self {
        case .general: return "Tell us what you think about StatsWatch…"
        case .bug: return "What happened, and what did you expect? Steps to reproduce help a lot."
        case .feature: return "Describe your idea and how it would help players."
        }
    }
}
