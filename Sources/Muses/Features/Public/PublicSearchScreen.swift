import SwiftUI
import MusesDomain
import MusesCatalog

/// Search input is editable independently of the query that produced the visible rows.
struct PublicSearchScreen: View {
    @Bindable var session: PublicYouTubeSession
    @Binding var focusRequested: Bool
    @State private var query = ""
    private var submittedQuery: String { session.submittedSearchQuery }
    private var submittedKind: MusesCatalog.CatalogItem.Kind { session.submittedSearchKind }
    @State private var scope: Scope = .youtube
    @FocusState private var focused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    private enum Scope: String, CaseIterable { case youtube = "YouTube", saved = "On this device" }
    private var usesLocalResults: Bool { session.isSubmittedSearchLocal }
    private var localVideos: [MusesDomain.Track] {
        guard !submittedQuery.isEmpty, submittedKind == .video else { return [] }
        return session.libraryTracks.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(submittedQuery) || $0.displayArtist.localizedCaseInsensitiveContains(submittedQuery)
        }
    }
    private var localPlaylists: [LocalPlaylist] {
        guard !submittedQuery.isEmpty, submittedKind == .playlist else { return [] }
        return session.playlists.filter { $0.name.localizedCaseInsensitiveContains(submittedQuery) }
    }
    private var resultCount: Int { usesLocalResults ? localVideos.count + localPlaylists.count : session.searchItems.count }
    private var loading: Bool { !usesLocalResults && session.searching }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                searchInput
                if typeSize.isAccessibilitySize { accessibleSourcePicker }
                else { sourcePicker.pickerStyle(.segmented) }
                if typeSize.isAccessibilitySize { accessibleKindPicker }
                else { kindPicker.pickerStyle(.segmented) }
                if !submittedQuery.isEmpty && session.searchKind != submittedKind {
                    Text("Search in \(session.searchKind.rawValue.capitalized) when you submit.").font(.footnote).foregroundStyle(.secondary)
                }
                if scope == .saved {
                    Text("Search saved videos and local playlists without an online request.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !session.apiConfigured {
                    PublicNotice(message: "YouTube search is unavailable in this configuration. Search saved items on this device.", symbol: "wifi.slash")
                }
                if let error = session.queueFailureMessage { PublicNotice(message: error, symbol: "exclamationmark.circle") }
                results
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, PublicStyle.inset).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(PublicStyle.background)
        .background(PublicKeyboardDismissal { focused = false })
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Search").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !submittedQuery.isEmpty && query.isEmpty { query = submittedQuery; scope = session.isSubmittedSearchLocal ? .saved : .youtube }
            else if !session.apiConfigured { scope = .saved }
            normalizeDraftKind()
            consumeFocusRequest()
        }
        .onChange(of: focusRequested) { _, _ in consumeFocusRequest() }
        .onChange(of: scope) { _, _ in normalizeDraftKind() }
        .onChange(of: session.apiConfigured) { _, configured in
            if !configured { scope = .saved; normalizeDraftKind() }
        }
    }

    private var accessibleSourcePicker: some View {
        Menu {
            ForEach(Scope.allCases, id: \.self) { value in
                Button(value.rawValue) { scope = value }.disabled(value == .youtube && !session.apiConfigured)
            }
        } label: {
            HStack {
                Text(scope.rawValue).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 18))
            }.frame(minHeight: 44)
        }.accessibilityLabel("Search source").accessibilityValue(scope.rawValue).accessibilityIdentifier("public.searchSource")
    }
    private var accessibleKindPicker: some View {
        Menu {
            Button("Videos") { session.searchKind = .video }
            Button("Playlists") { session.searchKind = .playlist }
            if scope == .youtube && session.apiConfigured { Button("Channels") { session.searchKind = .channel } }
        } label: {
            HStack {
                Text(session.searchKind == .video ? "Videos" : session.searchKind == .playlist ? "Playlists" : "Channels")
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 18))
            }.frame(minHeight: 44)
        }.accessibilityLabel("Search type").accessibilityValue(session.searchKind.rawValue).accessibilityIdentifier("public.searchKind")
    }

    private var sourcePicker: some View {
        Picker("Search source", selection: $scope) {
            ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0).disabled($0 == .youtube && !session.apiConfigured) }
        }.accessibilityIdentifier("public.searchSource")
    }
    private var kindPicker: some View {
        Picker("Search type", selection: $session.searchKind) {
            Text("Videos").tag(MusesCatalog.CatalogItem.Kind.video)
            Text("Playlists").tag(MusesCatalog.CatalogItem.Kind.playlist)
            if scope == .youtube && session.apiConfigured { Text("Channels").tag(MusesCatalog.CatalogItem.Kind.channel) }
        }.accessibilityIdentifier("public.searchKind")
    }

    private var searchInput: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(scope == .saved ? "Search saved items" : "Search YouTube", text: $query)
                .submitLabel(.search).autocorrectionDisabled().focused($focused)
                .onSubmit(submit).frame(minHeight: 44).accessibilityIdentifier("public.search")
            if !query.isEmpty || !submittedQuery.isEmpty {
                Button { query = ""; session.clearSearchResults() } label: { PublicIconActionLabel(title: "Clear search", symbol: "xmark.circle") }
                    .buttonStyle(.plain).accessibilityIdentifier("public.clearSearch")
            }
            Button(action: submit) { PublicIconActionLabel(title: scope == .saved ? "Search saved items" : "Search YouTube", symbol: "magnifyingglass") }
                .buttonStyle(.borderedProminent)
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.searching)
                .accessibilityIdentifier("public.submitSearch")
        }.padding(12).background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private var results: some View {
        if submittedQuery.isEmpty {
            PublicEmptyState(symbol: "magnifyingglass", title: "Find a video or playlist", detail: "Choose a source and type, enter a title or creator, then search.")
                .accessibilityIdentifier("public.searchIdle")
        } else {
            Text("\(resultCount) \(resultCount == 1 ? "result" : "results") for “\(submittedQuery)” · \(submittedKind.rawValue.capitalized)")
                .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("public.searchResultsHeading")
            if loading {
                ProgressView("Searching YouTube").accessibilityIdentifier("public.searchLoading")
            }
            if !usesLocalResults, let error = session.searchError {
                PublicNotice(message: "Couldn’t search YouTube. " + error, symbol: "exclamationmark.circle")
                    .accessibilityIdentifier("public.searchError")
                Button("Retry", systemImage: "arrow.clockwise") {
                    Task {
                        if session.searchPages.items.isEmpty { await session.retrySearch() }
                        else { await session.nextSearchPage() }
                    }
                }
                    .buttonStyle(.bordered).frame(minHeight: 44).disabled(loading)
                    .accessibilityIdentifier(session.searchPages.items.isEmpty ? "public.retrySearch" : "public.retrySearchPage")
            } else if resultCount == 0 && !loading {
                PublicEmptyState(symbol: "magnifyingglass", title: usesLocalResults ? "No saved items match “\(submittedQuery)”" : "No results for “\(submittedQuery)”", detail: "Try another title or creator, or choose a different source.")
                    .accessibilityIdentifier("public.searchEmpty")
                Button("Edit search") { focused = true }.frame(minHeight: 44)
            }
            if usesLocalResults {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(localVideos) { track in
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Saved video · On this device").font(.caption).foregroundStyle(.secondary)
                            PublicCollectionRow(session: session, track: track, category: .videos)
                        }
                    }
                    ForEach(localPlaylists) { playlist in
                        NavigationLink { PublicPlaylistDetail(session: session, playlistID: playlist.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.name).font(.headline)
                                Text("Local playlist · On this device").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 8)
                        }
                    }
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if session.searchItems.contains(where: { $0.source == "local" }) {
                        Text("Saved on this device").font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(session.searchItems.filter { $0.source == "local" }, id: \.rowID) { PublicCatalogRow(session: session, item: $0) }
                    }
                    if session.searchItems.contains(where: { $0.source != "local" }) {
                        Text("YouTube").font(.headline).padding(.top, 12).accessibilityAddTraits(.isHeader)
                        ForEach(session.searchItems.filter { $0.source != "local" }, id: \.rowID) { PublicCatalogRow(session: session, item: $0) }
                    }
                }
                if session.searchError == nil && session.searchPages.nextPageToken != nil {
                    Button("Load next page", systemImage: "arrow.down.circle") { Task { await session.nextSearchPage() } }
                        .frame(minHeight: 44).disabled(loading).accessibilityIdentifier("public.nextSearchPage")
                }
            }
        }
    }

    private func normalizeDraftKind() {
        if (scope == .saved || !session.apiConfigured) && session.searchKind == .channel { session.searchKind = .video }
    }
    private func consumeFocusRequest() {
        if focusRequested { focused = true; focusRequested = false }
    }
    private func submit() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !session.searching else { return }
        focused = false
        if !session.apiConfigured && scope == .youtube { session.searchKind = .video }
        session.clearSearchResults()
        if scope == .youtube && session.apiConfigured {
            Task { await session.search(term) }
        } else { session.searchSaved(term) }
    }
}
