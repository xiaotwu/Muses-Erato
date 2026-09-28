import SwiftUI
import UIKit

struct PublicSettingsView: View {
    let session: PublicYouTubeSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                NavigationLink {
                    PublicAccountSettingsView(session: session)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        if session.signedIn, let channel = session.accountChannelPages.items.first {
                            Text(channel.id).font(.subheadline.monospaced()).textSelection(.enabled)
                            Text(channel.title).font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Google account")
                            Text(accountStatus).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("settings.account")
            }
            Section {
                NavigationLink { PublicLibraryDataSettingsView(session: session) } label: {
                    Label("Library & local data", systemImage: "externaldrive")
                }
                NavigationLink { PublicPlaybackSettingsView() } label: {
                    Label("Playback", systemImage: "play.circle")
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
                    Label("Privacy & support", systemImage: "hand.raised")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: { PublicIconActionLabel(title: "Done", symbol: "checkmark") }
            }
        }
        .task(id: session.signedIn) {
            if session.signedIn { await session.loadAccountChannel() }
        }
    }

    private var accountStatus: String {
        if session.accountCleanupPending { return "Cleanup needs attention" }
        if session.signedIn {
            if session.accountChannelPages.loading { return "Loading channel…" }
            if session.accountChannelPages.error != nil { return "Channel unavailable" }
            return session.accountChannelPages.loaded ? "No YouTube channel" : "Signed in"
        }
        return "Not signed in"
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
                    ForEach(session.accountChannelPages.items, id: \.rowID) { channel in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(channel.title).font(.headline)
                            HStack {
                                Text(channel.id)
                                    .font(.subheadline.monospaced())
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("account.channelID")
                                Spacer(minLength: 8)
                                Button { UIPasteboard.general.string = channel.id } label: {
                                    PublicIconActionLabel(title: "Copy Channel ID", symbol: "doc.on.doc")
                                }.buttonStyle(.borderless)
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
                    NavigationLink { PublicYouTubeAccountCatalog(session: session) } label: {
                        Label("Account playlists & collections", systemImage: "music.note.list")
                    }.accessibilityLabel("Account & YouTube collections")
                } footer: { Text("Read-only YouTube access") }
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
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: session.signedIn) {
            if session.signedIn { await session.loadAccountChannel() }
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

    var body: some View {
        List {
            Section {
                Button { Task { await session.refreshSavedMetadata() } } label: {
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
        .confirmationDialog("Delete local Muses data?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
            Button("Delete local data", role: .destructive) { Task { await session.deleteLocalData() } }
        } message: {
            Text("Deletes local videos, playlists, queue, history, notes, bookmarks, account credentials and retained originals. Restart if cleanup is pending. Your YouTube account and videos are unaffected.")
        }
    }
}

private struct PublicPlaybackSettingsView: View {
    var body: some View {
        List {
            Section {
                Label("YouTube video player", systemImage: "play.rectangle")
                Link(destination: URL(string: "https://music.youtube.com/")!) {
                    Label("YouTube Music website", systemImage: "safari")
                }
            } footer: {
                Text("Current in-app playback pauses when the player closes or Muses enters the background.")
            }
        }
        .navigationTitle("Playback")
        .navigationBarTitleDisplayMode(.inline)
    }
}
