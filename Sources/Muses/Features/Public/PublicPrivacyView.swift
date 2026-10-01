import SwiftUI

enum PublicPrivacyPolicy {
    static let version = "2026-09-29.1"
    // Consent remains independent from account/library deletion and pending cleanup.
    static let acceptanceKey = "eratoPrivacyAcceptedVersion"
    static var text: String? {
        #if DEBUG
        if isolatedTest {
            switch ProcessInfo.processInfo.environment["MUSES_UI_TEST_POLICY"] {
            case "missing": return nil
            case "empty": return nil
            default: break
            }
        }
        #endif
        guard let url = Bundle.main.url(forResource: "PublicPrivacyPolicy", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
    static var defaults: UserDefaults {
        #if DEBUG
        if isolatedTest, let id = ProcessInfo.processInfo.environment["MUSES_UI_TEST_LIBRARY"] {
            return UserDefaults(suiteName: "muses.privacy.tests.\(id)")!
        }
        #endif
        return .standard
    }
    private static var isolatedTest: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["MUSES_UI_TEST_LIBRARY"].flatMap(UUID.init(uuidString:)) != nil
        #else
        return false
        #endif
    }
    static var fixtureAccepted: Bool {
        #if DEBUG
        return isolatedTest && ProcessInfo.processInfo.environment["MUSES_UI_TEST_PRIVACY"] != "required"
        #else
        return false
        #endif
    }
    static func canEnter(acceptedVersion: String, policy: String?, fixtureAccepted: Bool = false) -> Bool {
        guard let policy, !policy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return acceptedVersion == version || fixtureAccepted
    }
    static var buildDescription: String {
        #if MUSES_NATIVE_PLAYBACK
        return "Experimental Native"
        #else
        return "Public"
        #endif
    }
    static var playbackSummary: String {
        #if MUSES_NATIVE_PLAYBACK
        return "The YouTube player pauses when closed or backgrounded. This experimental build also offers optional background audio in Settings."
        #else
        return "Playback pauses when the player closes or Muses enters the background."
        #endif
    }
}

/// Only a valid policy and versioned consent can construct the content/session closure.
struct PublicPrivacyGate<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage private var acceptedVersion: String
    @State private var showIntroduction = true
    @State private var consentFailure: String?
    let content: () -> Content
    private let policy: () -> String?
    private let fixtureAccepted: Bool
    private let consentStore: UserDefaults

    init(store: UserDefaults = PublicPrivacyPolicy.defaults,
         policy: @escaping () -> String? = { PublicPrivacyPolicy.text },
         fixtureAccepted: Bool = PublicPrivacyPolicy.fixtureAccepted,
         @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.policy = policy
        self.fixtureAccepted = fixtureAccepted
        self.consentStore = store
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["MUSES_UI_TEST_LIBRARY"].flatMap(UUID.init(uuidString:)) != nil,
           let seed = environment["MUSES_UI_TEST_ACCEPTED_POLICY"] {
            store.set(seed, forKey: PublicPrivacyPolicy.acceptanceKey)
        }
        #endif
        _acceptedVersion = AppStorage(wrappedValue: "", PublicPrivacyPolicy.acceptanceKey, store: store)
    }

    var body: some View {
        if PublicPrivacyPolicy.canEnter(acceptedVersion: acceptedVersion, policy: policy(),
                                       fixtureAccepted: fixtureAccepted) {
            content()
        } else {
            VStack(spacing: 24) {
                Image(systemName: "play.rectangle.on.rectangle").font(.largeTitle).foregroundStyle(PublicStyle.gold)
                Text("Welcome to Muses").font(.largeTitle.bold()).multilineTextAlignment(.center)
                    .accessibilityIdentifier("privacy.gateTitle")
                Text("Review how Muses uses your data before getting started.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button { showIntroduction = true } label: {
                    PublicTextActionLabel(title: "Continue setup", symbol: "arrow.right")
                }
                .modifier(PublicPrivacyPrimaryAction())
                .accessibilityIdentifier("privacy.reopen")
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .sheet(isPresented: $showIntroduction) {
                NavigationStack {
                    PublicPrivacyIntroduction(updatedPolicy: !acceptedVersion.isEmpty, failure: consentFailure) {
                        // Recheck availability at the action boundary, including saved/fixture paths.
                        guard let policy = policy(), !policy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        consentStore.set(PublicPrivacyPolicy.version, forKey: PublicPrivacyPolicy.acceptanceKey)
                        guard consentStore.string(forKey: PublicPrivacyPolicy.acceptanceKey) == PublicPrivacyPolicy.version else {
                            consentFailure = "Could not save your agreement. Try again."
                            return
                        }
                        consentFailure = nil
                        acceptedVersion = PublicPrivacyPolicy.version
                        showIntroduction = false
                    }
                }
                .tint(PublicStyle.gold)
                .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.fraction(0.78), .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct PublicPrivacyIntroduction: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @State private var agrees = false
    let updatedPolicy: Bool
    let failure: String?
    let accept: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Organize videos. Keep your notes.")
                    .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("privacy.introductionTitle")
                VStack(alignment: .leading, spacing: 12) {
                    point("Organize videos & playlists", symbol: "square.stack", detail: nil)
                    point("Keep notes & time bookmarks", symbol: "note.text", detail: nil)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "play.rectangle").foregroundStyle(PublicStyle.gold).frame(width: 28).accessibilityHidden(true)
                        Text(PublicPrivacyPolicy.playbackSummary).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text("Search, artwork and playback connect to Google. Sign-in is optional.")
                    .font(.subheadline).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    NavigationLink { PublicPrivacyView() } label: {
                        PublicTextActionLabel(title: "Read full privacy policy", symbol: "hand.raised")
                    }.accessibilityIdentifier("privacy.readPolicy")
                    PublicPolicyLinks()
                }
                if PublicPrivacyPolicy.text == nil { PublicMissingPolicyNotice() }
                if let failure { Text(failure).foregroundStyle(.secondary).accessibilityIdentifier("privacy.saveFailure") }
                if dynamicTypeSize.isAccessibilitySize { consentControls }

            }
            .frame(maxWidth: 650, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !dynamicTypeSize.isAccessibilitySize {
                consentControls
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .systemBackground))
            }
        }
        .navigationTitle(updatedPolicy ? "Review updated policy" : "Welcome")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var consentControls: some View {
        VStack(alignment: .leading, spacing: 8) {
                Button { agrees.toggle() } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: agrees ? "checkmark.square.fill" : "square")
                        Text("I agree to the privacy policy and YouTube terms").multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(agrees ? "Agreed" : "Not agreed")
                .accessibilityIdentifier("privacy.agreement")
                Button {
                    guard agrees, PublicPrivacyPolicy.text != nil else { return }
                    accept()
                } label: {
                    Text("Continue").frame(maxWidth: .infinity, minHeight: 44)
                }
                .modifier(PublicPrivacyPrimaryAction())
                .disabled(!agrees || PublicPrivacyPolicy.text == nil)
                .accessibilityIdentifier("privacy.continue")
                Button("Not now") { dismiss() }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("privacy.notNow")
        }
        .frame(maxWidth: 650)
        .frame(maxWidth: .infinity)
    }

    private func point(_ title: String, symbol: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(PublicStyle.gold).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                if let detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
            }
        }
    }
}

private struct PublicPrivacyPrimaryAction: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if #available(iOS 26, *), !reduceTransparency {
            content.buttonStyle(.glassProminent).tint(PublicStyle.gold)
        } else {
            content.buttonStyle(.borderedProminent).tint(PublicStyle.gold)
        }
    }
}

struct PublicPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let text = PublicPrivacyPolicy.text {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(text.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                            if paragraph.hasPrefix("# ") {
                                Text(String(paragraph.dropFirst(2))).font(.title.bold()).accessibilityAddTraits(.isHeader)
                            } else if paragraph.hasPrefix("## ") {
                                Text(String(paragraph.dropFirst(3))).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                            } else {
                                Text(paragraph).font(.body).textSelection(.enabled)
                            }
                        }
                    }.accessibilityIdentifier("privacy.policy")
                } else { PublicMissingPolicyNotice() }
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

private struct PublicMissingPolicyNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy policy unavailable").font(.headline).accessibilityAddTraits(.isHeader)
            Text("The complete policy could not be loaded. Setup cannot continue. Please contact support.")
            Link("Contact support", destination: URL(string: "https://github.com/xiaotwu/Muses-Erato/issues")!)
                .frame(minHeight: 44)
        }.accessibilityIdentifier("privacy.unavailable")
    }
}
