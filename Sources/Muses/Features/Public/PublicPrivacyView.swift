import SwiftUI

enum PublicPrivacyPolicy {
    static let version = "2026-09-27.1"
    // Keep this non-account policy version separate from inherited library settings.
    // Resetting it during an asynchronous wipe would remove the session's pending-cleanup UI.
    static let acceptanceKey = "eratoPrivacyAcceptedVersion"
    static var text: String? {
        guard let url = Bundle.main.url(forResource: "PublicPrivacyPolicy", withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
    static var defaults: UserDefaults {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["MUSES_UI_TEST_LIBRARY"], UUID(uuidString: id) != nil {
            return UserDefaults(suiteName: "muses.privacy.tests.\(id)")!
        }
        #endif
        return .standard
    }
    static var fixtureAccepted: Bool {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        return environment["MUSES_UI_TEST_LIBRARY"].flatMap(UUID.init(uuidString:)) != nil
            && environment["MUSES_UI_TEST_PRIVACY"] != "required"
        #else
        return false
        #endif
    }
}

/// Construct the app session only after policy agreement; no account refresh or artwork before it.
struct PublicPrivacyGate<Content: View>: View {
    @AppStorage private var acceptedVersion: String
    @State private var agrees = false
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
        _acceptedVersion = AppStorage(wrappedValue: "", PublicPrivacyPolicy.acceptanceKey, store: PublicPrivacyPolicy.defaults)
    }

    var body: some View {
        if acceptedVersion == PublicPrivacyPolicy.version || PublicPrivacyPolicy.fixtureAccepted {
            content()
        } else {
            NavigationStack {
                PublicPrivacyView()
                    .safeAreaInset(edge: .bottom) {
                        VStack(spacing: 12) {
                            Button { agrees.toggle() } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: agrees ? "checkmark.square.fill" : "square")
                                    Text("I agree to the privacy policy and YouTube terms")
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(agrees ? "Agreed" : "Not agreed")
                                .accessibilityIdentifier("privacy.agreement")
                            Button {
                                acceptedVersion = PublicPrivacyPolicy.version
                            } label: {
                                Label("Agree and continue", systemImage: "checkmark")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderedProminent)
                            .disabled(!agrees || PublicPrivacyPolicy.text == nil)
                            .accessibilityIdentifier("privacy.continue")
                        }
                        .padding()
                        .background(.regularMaterial)
                    }
            }
        }
    }
}

struct PublicPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(PublicPrivacyPolicy.text ?? "Privacy policy unavailable. Please contact support before continuing.")
                    .font(.body)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("privacy.policy")
                PublicServiceLinks()
            }
            .frame(maxWidth: 750, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
