import SwiftUI
import MusesDomain
import MusesCatalog

/// Draft filters stay separate from the query and filters that produced visible results.
struct PublicSearchScreen: View {
    @Bindable var session: PublicYouTubeSession
    @Binding var focusRequested: Bool
    let openSettings: () -> Void
    @State private var query = ""
    @FocusState private var focused: Bool
    private var submittedQuery: String { session.submittedSearchQuery }
    private var sourceSummary: String { PublicSearchSource.allCases.filter { session.searchSources.contains($0) }.map(\.rawValue).joined(separator: ", ") }
    private var kindSummary: String { PublicYouTubeSession.searchKindOrder.filter { session.searchKinds.contains($0) }.map(kindTitle).joined(separator: ", ") }
    private var filtersChanged: Bool { session.searchSources != session.submittedSearchSources || session.searchKinds != session.submittedSearchKinds }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                searchInput
                if !submittedQuery.isEmpty && filtersChanged {
                    Text("Search filters changed. Submit to update results.").font(.footnote).foregroundStyle(.secondary)
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
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                filterMenu
                Button(action: openSettings) { PublicIconActionLabel(title: "Settings", symbol: "gearshape") }
            }
        }
        .onAppear {
            if query.isEmpty { query = submittedQuery }
            session.normalizeSearchSelection()
            consumeFocusRequest()
        }
        .onChange(of: focusRequested) { _, _ in consumeFocusRequest() }
        .onChange(of: session.apiConfigured) { _, _ in session.normalizeSearchSelection() }
    }

    private var filterMenu: some View {
        Menu {
            Section("Source") {
                ForEach(PublicSearchSource.allCases, id: \.self) { source in
                    Button { session.toggleSearchSource(source) } label: {
                        Label(source.rawValue, systemImage: session.searchSources.contains(source) ? "checkmark" : "circle")
                    }
                    .accessibilityAddTraits(session.searchSources.contains(source) ? .isSelected : [])
                    .accessibilityIdentifier("public.searchSource." + (source == .youtube ? "youtube" : "saved"))
                    .disabled((source == .youtube && !session.apiConfigured) || (session.searchSources.contains(source) && session.searchSources.count == 1))
                    .accessibilityHint("Keep at least one source selected.")
                    .menuActionDismissBehavior(.disabled)
                }
            }
            Section("Type") {
                ForEach(PublicYouTubeSession.searchKindOrder, id: \.self) { kind in
                    if kind != .channel || (session.searchSources.contains(.youtube) && session.apiConfigured) {
                        Button { session.toggleSearchKind(kind) } label: {
                            Label(kindTitle(kind), systemImage: session.searchKinds.contains(kind) ? "checkmark" : "circle")
                        }
                        .accessibilityAddTraits(session.searchKinds.contains(kind) ? .isSelected : [])
                        .accessibilityIdentifier("public.searchKind." + kind.rawValue)
                        .disabled(session.searchKinds.contains(kind) && session.searchKinds.count == 1)
                        .accessibilityHint("Keep at least one type selected.")
                        .menuActionDismissBehavior(.disabled)
                    }
                }
            }
        } label: { Image(systemName: "slider.horizontal.3").frame(minWidth: 44, minHeight: 44) }
        .accessibilityLabel("Search filters")
        .accessibilityValue(sourceSummary + "; " + kindSummary)
        .accessibilityIdentifier("public.searchFilters")
    }

    private func kindTitle(_ kind: MusesCatalog.CatalogItem.Kind) -> String {
        switch kind { case .video: "Videos"; case .playlist: "Playlists"; case .channel: "Channels" }
    }

    private var searchInput: some View {
        HStack(spacing: 8) {
            HStack(spacing: 12) {
                TextField(session.searchSources == [.saved] ? "Search saved items" : "Search titles or creators", text: $query)
                    .submitLabel(.search).autocorrectionDisabled().focused($focused)
                    .onSubmit(submit).frame(minHeight: 44).accessibilityIdentifier("public.search")
                if !query.isEmpty || !submittedQuery.isEmpty {
                    Button { query = ""; session.clearSearchResults() } label: { PublicIconActionLabel(title: "Clear search", symbol: "xmark.circle") }
                        .buttonStyle(.plain).accessibilityIdentifier("public.clearSearch")
                }
            }.padding(12).background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 14))
            Button(action: submit) {
                Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PublicStyle.background).frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.searching)
            .accessibilityLabel("Search").accessibilityIdentifier("public.submitSearch")
        }
    }

    @ViewBuilder private var results: some View {
        if submittedQuery.isEmpty {
            Text("Enter a title or creator.").font(.subheadline)
                .foregroundStyle(PublicStyle.ink).padding(.top, 8).accessibilityIdentifier("public.searchIdle")
        } else {
            let sources = PublicSearchSource.allCases.filter { session.submittedSearchSources.contains($0) }.map(\.rawValue).joined(separator: " + ")
            let kinds = PublicYouTubeSession.searchKindOrder.filter { session.submittedSearchKinds.contains($0) }.map(kindTitle).joined(separator: " + ")
            (Text("Results for “\(submittedQuery)”").font(.headline)
                + Text("\n\(session.searchResultCount) \(session.searchResultCount == 1 ? "result" : "results") · \(sources) · \(kinds)").font(.subheadline))
                .foregroundStyle(PublicStyle.ink).accessibilityIdentifier("public.searchResultsHeading")
            if session.searchResultCount == 0 && !session.searching && session.searchError == nil {
                PublicEmptyState(symbol: "magnifyingglass", title: "No results for “\(submittedQuery)”", detail: "Try another title or creator, or choose different filters.")
                    .accessibilityIdentifier("public.searchEmpty")
                Button("Edit search") { focused = true }.frame(minHeight: 44)
            }
            if session.submittedSearchSources.contains(.saved) {
                savedResults
            }
            ForEach(session.remoteSearchKinds, id: \.self) { kind in remoteResults(kind) }
        }
    }

    private var savedResults: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            Text("On this device").font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(session.savedSearchVideos) { track in
                VStack(alignment: .leading, spacing: 0) {
                    Text("Saved video · On this device").font(.caption).foregroundStyle(.secondary)
                    PublicCollectionRow(session: session, track: track, category: .videos)
                }
            }
            ForEach(session.savedSearchPlaylists) { playlist in
                NavigationLink { PublicPlaylistDetail(session: session, playlistID: playlist.id) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name).font(.headline)
                        Text("Local playlist · On this device").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 8)
                }
            }
        }
    }

    private func remoteResults(_ kind: MusesCatalog.CatalogItem.Kind) -> some View {
        let pager = session.searchPager(for: kind)
        return LazyVStack(alignment: .leading, spacing: 8) {
            Text("YouTube · " + kindTitle(kind)).font(.headline).accessibilityAddTraits(.isHeader)
            if pager.loading { ProgressView("Searching YouTube").accessibilityIdentifier("public.searchLoading." + kind.rawValue) }
            ForEach(pager.items, id: \.rowID) { PublicCatalogRow(session: session, item: $0) }
            if let error = pager.error {
                PublicNotice(message: "Couldn’t search YouTube \(kindTitle(kind).lowercased()). " + error, symbol: "exclamationmark.circle")
                    .accessibilityIdentifier("public.searchError." + kind.rawValue)
                Button("Retry", systemImage: "arrow.clockwise") { Task { await session.retrySearch(kind: kind) } }
                    .buttonStyle(.bordered).frame(minHeight: 44).disabled(pager.loading)
                    .accessibilityIdentifier(pager.items.isEmpty ? "public.retrySearch." + kind.rawValue : "public.retrySearchPage." + kind.rawValue)
            } else if pager.nextPageToken != nil {
                Button("Load next page", systemImage: "arrow.down.circle") { Task { await session.nextSearchPage(kind: kind) } }
                    .frame(minHeight: 44).disabled(pager.loading).accessibilityIdentifier("public.nextSearchPage." + kind.rawValue)
            }
        }
    }

    private func consumeFocusRequest() {
        if focusRequested { focused = true; focusRequested = false }
    }
    private func submit() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !session.searching else { return }
        focused = false
        Task { await session.search(term) }
    }
}
