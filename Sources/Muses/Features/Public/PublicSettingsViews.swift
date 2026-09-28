import SwiftUI
import UIKit
import MusesCatalog

struct PublicSettingsView: View {
    let session: PublicYouTubeSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                NavigationLink {
                    PublicAccountSettingsView(session: session)
                } label: {
                    PublicAccountIdentity(session: session)
                }
                .accessibilityIdentifier("settings.account")
            }
            Section {
                NavigationLink { PublicLibraryDataSettingsView(session: session) } label: {
                    Text("Library & data")
                }
                NavigationLink { PublicPlaybackSettingsView(session: session) } label: {
                    Text("Playback")
                }
                NavigationLink {
                    List {
                        NavigationLink { PublicPrivacyView() } label: {
                            Label("Privacy policy", systemImage: "hand.raised")
                        }
                        PublicServiceLinks()
                    }
                    .navigationTitle("Privacy & support")
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Text("Privacy & support")
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: { PublicIconActionLabel(title: "Close settings", symbol: "xmark") }
            }
        }
        .task(id: session.signedIn) {
            if session.signedIn { await session.loadAccountChannel() }
        }
    }

}

private struct PublicAccountSettingsView: View {
    let session: PublicYouTubeSession
    @State private var confirmingRevocation = false

    var body: some View {
        List {
            if session.accountCleanupPending {
                Section {
                    Text("Account cleanup needs attention.").foregroundStyle(.secondary)
                    Button { Task { await session.retryAccountCleanup() } } label: {
                        Label("Retry cleanup", systemImage: "arrow.clockwise")
                    }
                }
            } else if session.signedIn {
                Section {
                    if session.accountChannelPages.loading {
                        ProgressView("Loading channel")
                    }
                    PublicAccountIdentity(session: session)
                    if let channel = session.accountChannelPages.items.first {
                        DisclosureGroup("Channel details") {
                            Text(channel.id).font(.footnote.monospaced()).textSelection(.enabled)
                                .accessibilityIdentifier("account.channelID")
                            Button { UIPasteboard.general.string = channel.id } label: {
                                Label("Copy Channel ID", systemImage: "doc.on.doc")
                            }
                        }
                    }
                    if let error = session.accountChannelPages.error {
                        Text(error).foregroundStyle(.secondary)
                        Button { Task { await session.loadAccountChannel() } } label: {
                            Label("Retry channel", systemImage: "arrow.clockwise")
                        }
                    } else if session.accountChannelPages.loaded && session.accountChannelPages.items.isEmpty {
                        Text("This account has no available YouTube channel.").foregroundStyle(.secondary)
                    }
                } footer: { Text("Read-only YouTube access") }
                PublicAccountCollectionSections(session: session)
                Section("Account management") {
                    Button { Task { await session.signOut(revokeAccess: false) } } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    Button(role: .destructive) { confirmingRevocation = true } label: {
                        Label("Revoke access", systemImage: "lock.slash")
                    }
                }
            } else if session.oauthConfigured {
                Section {
                    Button { Task { await session.signIn() } } label: {
                        Label("Sign in with Google", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            } else {
                Text("Google sign-in is unavailable. Your local library still works.").foregroundStyle(.secondary)
            }
            if let error = session.failureMessage { Section { Text(error).foregroundStyle(.secondary) } }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: session.signedIn) {
            if session.signedIn {
                await session.loadAccountChannel()
                await session.loadAccountCollections()
            }
        }
        .confirmationDialog("Revoke Google access?", isPresented: $confirmingRevocation, titleVisibility: .visible) {
            Button("Revoke access", role: .destructive) { Task { await session.signOut() } }
        } message: {
            Text("Revokes this app’s Google access and removes its local account credentials. Your saved library remains.")
        }
    }
}

private struct PublicLibraryDataSettingsView: View {
    let session: PublicYouTubeSession
    @State private var confirmingDeletion = false
    @State private var confirmingSync = false

    var body: some View {
        List {
            Section {
                Button { confirmingSync = true } label: {
                    Label("Refresh details", systemImage: "arrow.clockwise")
                }.disabled(session.refreshingMetadata)
            }
            Section {
                Button(role: .destructive) { confirmingDeletion = true } label: {
                    Label("Delete local data", systemImage: "trash")
                }
            } footer: {
                Text("Includes notes, bookmarks and retained originals.")
            }
            if let error = session.failureMessage { Text(error).foregroundStyle(.secondary) }
        }
        .navigationTitle("Library & data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sync details from YouTube?", isPresented: $confirmingSync) {
            Button("Cancel", role: .cancel) {}
            Button("Sync details") { Task { await session.refreshSavedMetadata() } }
        } message: { Text("Updates saved titles and metadata from YouTube. Your local playlist membership and notes remain.") }
        .confirmationDialog("Delete local Muses data?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
            Button("Delete local data", role: .destructive) { Task { await session.deleteLocalData() } }
        } message: {
            Text("Deletes local videos, playlists, queue, history, notes, bookmarks, account credentials and retained originals. Restart if cleanup is pending. Your YouTube account and videos are unaffected.")
        }
    }
}

private struct PublicPlaybackSettingsView: View {
    let session: PublicYouTubeSession
    @State private var confirmingNative = false
    var body: some View {
        List {
            Section {
                if session.nativePlaybackAvailable {
                    Button {
                        if !session.nativePlaybackEnabled { confirmingNative = true }
                    } label: {
                        HStack {
                            Label("Background audio", systemImage: "waveform")
                            Spacer()
                            Image(systemName: session.nativePlaybackEnabled ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
                        }
                    }.accessibilityValue(session.nativePlaybackEnabled ? "Selected" : "Not selected")
                        .accessibilityIdentifier("playback.backgroundAudio")
                }
                Button { session.setNativePlayback(false) } label: {
                    HStack {
                        Label("YouTube video player", systemImage: "play.rectangle")
                        Spacer()
                        Image(systemName: session.nativePlaybackEnabled ? "circle" : "checkmark.circle.fill").accessibilityHidden(true)
                    }
                }.accessibilityValue(session.nativePlaybackEnabled ? "Not selected" : "Selected")
                Link(destination: URL(string: "https://music.youtube.com/")!) {
                    Label("YouTube Music website", systemImage: "safari")
                }
            } footer: {
                Text(session.nativePlaybackEnabled ? "Experimental IPA playback supports background audio and lock-screen controls. Some YouTube streams may be unavailable." : "YouTube video playback pauses when the player closes or Muses enters the background.")
            }
        }
        .alert("Enable experimental background playback?", isPresented: $confirmingNative) {
            Button("Cancel", role: .cancel) {}
            Button("Enable background audio") { session.setNativePlayback(true) }
        } message: { Text("This IPA option resolves playable streams directly from YouTube on this device without sending Google credentials. Availability may change. Website playback remains available.") }
        .navigationTitle("Playback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PublicAccountIdentity: View {
    let session: PublicYouTubeSession
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: session.accountChannelPages.items.first?.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFit().foregroundStyle(.secondary)
            }
            .frame(width: 48, height: 48).clipShape(Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.accountChannelPages.items.first?.title ?? "Google account")
                    .font(.headline).foregroundStyle(.primary)
                    .accessibilityIdentifier("account.nickname")
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 6)
    }
    private var status: String {
        if session.accountCleanupPending { return "Cleanup needs attention" }
        if !session.signedIn { return "Sign in with Google" }
        if session.accountChannelPages.loading { return "Loading profile…" }
        if session.accountChannelPages.error != nil { return "Profile unavailable" }
        if session.accountChannelPages.loaded && session.accountChannelPages.items.isEmpty { return "No YouTube profile" }
        return "YouTube account"
    }
}

struct PublicAccountCollectionSections: View {
    let session: PublicYouTubeSession
    var body: some View {
        Section {
            ForEach(session.accountPlaylistPages.items, id: \.rowID) {
                PublicCatalogRow(session: session, item: $0, authorized: true)
            }
            PublicAccountCollectionFooter(page: session.accountPlaylistPages, title: "playlists") {
                await session.loadAccountCollections()
            }
        } header: { PublicAccountCollectionHeader(title: "Playlists", page: session.accountPlaylistPages) }
        Section {
            ForEach(session.subscriptions, id: \.rowID) { PublicCatalogRow(session: session, item: $0) }
            PublicAccountCollectionFooter(page: session.subscriptionPages, title: "subscriptions") {
                await session.loadSubscriptions()
            }
        } header: { PublicAccountCollectionHeader(title: "Subscriptions", page: session.subscriptionPages) }
    }
}

private struct PublicAccountCollectionHeader: View {
    let title: String
    let page: CatalogPager
    @State private var confirming = false
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button { confirming = true } label: {
                PublicIconActionLabel(title: "Clear \(title.lowercased()) display", symbol: "trash")
            }.disabled(page.items.isEmpty && !page.loading)
        }
        .confirmationDialog("Clear \(title.lowercased()) display?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Clear display", role: .destructive) { page.reset() }
        } message: { Text("Only the display on this device is cleared. Your YouTube account is unchanged.") }
    }
}

private struct PublicAccountCollectionFooter: View {
    let page: CatalogPager
    let title: String
    let load: () async -> Void
    var body: some View {
        if page.loading { ProgressView("Loading \(title)") }
        if let error = page.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
        if !page.loading && (!page.loaded || page.error != nil || page.nextPageToken != nil) {
            Button { Task { await load() } } label: {
                Label(page.error != nil ? "Retry" : page.loaded ? "More" : "Load \(title)",
                      systemImage: page.error != nil ? "arrow.clockwise" : "arrow.down")
            }.accessibilityIdentifier("account.load.\(title)")
        }
        if page.loaded && page.items.isEmpty && !page.loading { Text("No \(title)").foregroundStyle(.secondary) }
    }
}
