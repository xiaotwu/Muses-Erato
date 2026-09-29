#if DEBUG
import Foundation
import SwiftUI
import MusesDomain

struct PublicMusicHomeCard: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let thumbnailURL: URL?
    let videoID: String?
    let destination: URL
}
struct PublicMusicHomeSection: Identifiable, Sendable {
    let id: String
    let title: String
    let cards: [PublicMusicHomeCard]
}

struct PublicMusicHomeSnapshot: Sendable {
    let sections: [PublicMusicHomeSection]
    let authenticated: Bool
    let continuation: String?
    init(sections: [PublicMusicHomeSection], authenticated: Bool, continuation: String? = nil) {
        self.sections = sections; self.authenticated = authenticated; self.continuation = continuation
    }
}

/// Browse-only adaptation of macOS FEmusic_home. OAuth is sent only to the
/// first-party Music endpoint; browser cookies and playback URLs are never read.
actor PublicMusicHomeService {
    private let session: URLSession
    private var version = "1.20240617.01.00"
    private var bootstrapped = false
    private var visitorData: String?
    private var contextGeneration = UUID()
    func resetVisitorContext() { contextGeneration = UUID(); visitorData = nil }
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }
    func fetch(accessToken: String? = nil, continuation: String? = nil) async throws -> PublicMusicHomeSnapshot {
        let contextTicket = contextGeneration
        if !bootstrapped {
            let (html, response) = try await session.data(from: URL(string: "https://music.youtube.com/")!)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), html.count <= 8_000_000 else { throw URLError(.badServerResponse) }
            let text = String(decoding: html, as: UTF8.self)
            let regex = try NSRegularExpression(pattern: #"\"INNERTUBE_CLIENT_VERSION\"\s*:\s*\"([^\"]+)\""#)
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) { version = String(text[range]) }
            bootstrapped = true
        }
        var request = URLRequest(url: URL(string: "https://music.youtube.com/youtubei/v1/browse?prettyPrint=false")!)
        request.httpMethod = "POST"
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        var client: [String: Any] = ["clientName": "WEB_REMIX", "clientVersion": version, "hl": "en", "gl": "US"]
        if let visitorData { client["visitorData"] = visitorData }
        var body: [String: Any] = ["context": ["client": client]]
        if let continuation { body["continuation"] = continuation } else { body["browseId"] = "FEmusic_home" }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count <= 8_000_000,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw URLError(.badServerResponse) }
        guard contextTicket == contextGeneration else { throw CancellationError() }
        if let visitor = (json["responseContext"] as? [String: Any])?["visitorData"] as? String { visitorData = visitor }
        let sections = Self.parse(json)
        guard continuation != nil || !sections.isEmpty else { throw URLError(.cannotParseResponse) }
        return PublicMusicHomeSnapshot(sections: sections, authenticated: accessToken != nil && Self.confirmsSignedIn(json), continuation: Self.pageContinuation(json))
    }
    /// Only page-level continuations, never the next page of one horizontal carousel.
    nonisolated static func pageContinuation(_ json: [String: Any]) -> String? {
        var token: String?
        walk(json) { node in
            guard token == nil, let section = (node["sectionListRenderer"] ?? node["sectionListContinuation"]) as? [String: Any] else { return }
            walk(section["continuations"] ?? []) { value in
                if token == nil, let next = value["nextContinuationData"] as? [String: Any] { token = next["continuation"] as? String }
            }
        }
        return token
    }
    nonisolated static func confirmsSignedIn(_ json: [String: Any]) -> Bool {
        var confirmed = false
        walk(json["responseContext"] ?? [:]) { value in
            if value["key"] as? String == "logged_in", value["value"] as? String == "1" { confirmed = true }
        }
        return confirmed
    }
    /// Keeps server shelf titles/order; normalizes only presentation metadata and
    /// real video/playlist/browse endpoints, without inventing Music identities.
    nonisolated static func parse(_ json: [String: Any]) -> [PublicMusicHomeSection] {
        var result: [PublicMusicHomeSection] = []
        var seen = Set<String>()
        walk(json) { node in
            guard let shelf = node["musicCarouselShelfRenderer"] as? [String: Any],
                  let contents = shelf["contents"] as? [[String: Any]] else { return }
            let header = (shelf["header"] as? [String: Any])?["musicCarouselShelfBasicHeaderRenderer"] as? [String: Any]
            let title = text(header?["title"]) ?? "YouTube Music"
            var cards: [PublicMusicHomeCard] = []
            var ids = Set<String>()
            for item in contents {
                guard let renderer = (item["musicTwoRowItemRenderer"] ?? item["musicResponsiveListItemRenderer"]) as? [String: Any] else { continue }
                let columns = renderer["flexColumns"] as? [[String: Any]] ?? []
                let first = columns.first?["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                guard let label = text(renderer["title"]) ?? text(first?["text"]), !label.isEmpty else { continue }
                // Prefer the main navigation endpoint over a thumbnail's play overlay.
                let endpoint = renderer["navigationEndpoint"] ?? renderer["playlistItemData"] ?? renderer["thumbnailOverlay"] ?? renderer["overlay"]
                var video: String?, playlist: String?, browse: String?, thumb: URL?
                walk(endpoint ?? [:]) { value in
                    if video == nil { video = value["videoId"] as? String }
                    if playlist == nil { playlist = value["playlistId"] as? String }
                    if browse == nil { browse = value["browseId"] as? String }
                }
                walk(renderer["thumbnailRenderer"] ?? renderer["thumbnail"] ?? [:]) { value in
                    if let thumbnails = value["thumbnails"] as? [[String: Any]], let url = thumbnails.last?["url"] as? String,
                       let parsed = URL(string: url), parsed.scheme == "https" { thumb = parsed }
                }
                let validVideo = video.flatMap { (try? VideoID($0))?.rawValue }
                let id: String, path: String, query: URLQueryItem?
                if let playlist { id = "playlist:" + playlist; path = "/playlist"; query = URLQueryItem(name: "list", value: playlist) }
                else if let validVideo { id = "video:" + validVideo; path = "/watch"; query = URLQueryItem(name: "v", value: validVideo) }
                else if let browse { id = "browse:" + browse; path = "/browse/" + browse; query = nil }
                else { continue }
                guard ids.insert(id).inserted else { continue }
                var url = URLComponents(string: "https://music.youtube.com")!
                url.path = path; if let query { url.queryItems = [query] }
                guard let destination = url.url else { continue }
                cards.append(PublicMusicHomeCard(id: id, title: label, subtitle: text(renderer["subtitle"]), thumbnailURL: thumb,
                    videoID: playlist == nil ? validVideo : nil, destination: destination))
            }
            guard !cards.isEmpty, seen.insert(title).inserted else { return }
            result.append(PublicMusicHomeSection(id: title, title: title, cards: cards))
        }
        return result
    }
    nonisolated private static func text(_ value: Any?) -> String? {
        guard let dict = value as? [String: Any] else { return value as? String }
        if let simple = dict["simpleText"] as? String { return simple }
        return (dict["runs"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined()
    }
    nonisolated private static func walk(_ value: Any, visit: ([String: Any]) -> Void) {
        if let dict = value as? [String: Any] {
            visit(dict)
            for key in dict.keys.sorted() { if let value = dict[key] { walk(value, visit: visit) } }
        } else if let array = value as? [Any] { for value in array { walk(value, visit: visit) } }
    }
}

@MainActor @Observable final class PublicMusicHomeModel {
    private(set) var sections: [PublicMusicHomeSection] = []
    private(set) var loading = false
    private(set) var error: String?
    private var updatedAt: Date?
    private(set) var personalized = false
    private(set) var accountNotice: String?
    private(set) var nextPage: String?
    private(set) var loadingMore = false
    private(set) var moreError: String?
    private var scope: UInt64?
    private var generation = UUID()
    private let service = PublicMusicHomeService()
    func isCurrent(scope requestedScope: UInt64) -> Bool { scope == requestedScope }
    func load(session: PublicYouTubeSession, refresh: Bool = false) async {
        let requestedScope = session.musicHomeScope
        if scope != requestedScope {
            scope = requestedScope; generation = UUID(); loading = false; sections = []; updatedAt = nil; personalized = false; accountNotice = nil; nextPage = nil; loadingMore = false; moreError = nil
            await service.resetVisitorContext()
        }
        guard scope == requestedScope, session.musicHomeScope == requestedScope else { return }
        guard !loading, refresh || updatedAt == nil || Date().timeIntervalSince(updatedAt!) > 300 else { return }
        if refresh { generation = UUID(); loadingMore = false; nextPage = nil; moreError = nil }
        let requestGeneration = generation
        loading = true; error = nil
        defer { if generation == requestGeneration { loading = false } }
        do {
            #if DEBUG
            if ProcessInfo.processInfo.environment["MUSES_UI_TEST_LIBRARY"] != nil,
               ProcessInfo.processInfo.environment["MUSES_UI_TEST_CATALOG"] == "fixtures" {
                sections = [.init(id: "fixture", title: "Music for you", cards: [.init(id: "video:abcdefghijk", title: "Fixture Music recommendation", subtitle: nil, thumbnailURL: nil, videoID: "abcdefghijk", destination: URL(string: "https://music.youtube.com/watch?v=abcdefghijk")!)])]
                personalized = session.signedIn; updatedAt = Date(); return
            }
            #endif
            let value: PublicMusicHomeSnapshot
            let notice: String?
            if session.signedIn {
                do {
                    value = try await session.readMusicHome(using: service)
                    notice = value.authenticated ? nil : "Your recommendations need a YouTube Music web session."
                } catch is CancellationError { throw CancellationError() }
                catch {
                    notice = "Your recommendations are unavailable. Open the YouTube Music website."
                    value = try await service.fetch()
                }
            } else { value = try await service.fetch(); notice = nil }
            try Task.checkCancellation()
            guard requestGeneration == generation, requestedScope == session.musicHomeScope, requestedScope == scope else { return }
            accountNotice = notice
            personalized = value.authenticated
            sections = value.sections; nextPage = value.continuation; updatedAt = Date(); moreError = nil
            #if DEBUG
            print("[MusicHome] authenticated=\(value.authenticated) shelves=\(value.sections.count)")
            #endif
        } catch is CancellationError { }
        catch { if generation == requestGeneration { self.error = "Could not load YouTube Music." } }
    }
    func loadMore(session: PublicYouTubeSession) async {
        guard let token = nextPage, !loading, !loadingMore, scope == session.musicHomeScope else { return }
        let requestGeneration = generation
        let requestScope = session.musicHomeScope
        loadingMore = true; moreError = nil
        defer { if generation == requestGeneration { loadingMore = false } }
        do {
            let value = personalized ? try await session.readMusicHome(using: service, continuation: token) : try await service.fetch(continuation: token)
            try Task.checkCancellation()
            guard requestGeneration == generation, scope == requestScope, session.musicHomeScope == requestScope else { return }
            for section in value.sections {
                if let index = sections.firstIndex(where: { $0.id == section.id }) {
                    var seen = Set(sections[index].cards.map(\.id))
                    sections[index] = PublicMusicHomeSection(id: section.id, title: section.title,
                        cards: sections[index].cards + section.cards.filter { seen.insert($0.id).inserted })
                } else { sections.append(section) }
            }
            nextPage = value.continuation == token ? nil : value.continuation
        } catch is CancellationError { }
        catch { if generation == requestGeneration { moreError = "Could not load more recommendations." } }
    }

}

struct PublicMusicHomeShelves: View {
    let session: PublicYouTubeSession
    let model: PublicMusicHomeModel
    var featuredOnly: Bool? = nil
    private var visibleSections: [PublicMusicHomeSection] {
        guard model.isCurrent(scope: session.musicHomeScope) else { return [] }
        if featuredOnly == true { return Array(model.sections.prefix(1)) }
        if featuredOnly == false { return Array(model.sections.dropFirst()) }
        return model.sections
    }
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if featuredOnly != false {
                HStack {
                    Text("YouTube Music").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Link(destination: URL(string: "https://music.youtube.com/")!) {
                        Label("Website", systemImage: "safari").labelStyle(.iconOnly).font(.body).frame(width: 44, height: 44)
                            .accessibilityLabel("Open YouTube Music website")
                    }
                }
                Text(model.isCurrent(scope: session.musicHomeScope) && model.personalized ? "Your recommendations" : "Public recommendations").font(.caption).foregroundStyle(.secondary)
                if model.isCurrent(scope: session.musicHomeScope), let notice = model.accountNotice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
                if !model.isCurrent(scope: session.musicHomeScope) || model.loading && model.sections.isEmpty { ProgressView("Loading YouTube Music") }
                if model.isCurrent(scope: session.musicHomeScope), let error = model.error {
                    HStack {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                        Button { Task { await model.load(session: session, refresh: true) } } label: { Label("Retry", systemImage: "arrow.clockwise") }
                            .frame(minHeight: 44)
                    }
                }
            }
            ForEach(visibleSections) { section in
                let featured = section.id == model.sections.first?.id
                VStack(alignment: .leading, spacing: 8) {
                    PublicHomeHeading(title: section.title)
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(section.cards) { card in
                                Button {
                                    if let id = card.videoID, let video = try? VideoID(id) { session.open(video, title: card.title, metadataFetchedAt: Date(), artist: card.subtitle) }
                                    else if let playlist = URLComponents(url: card.destination, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "list" })?.value, !playlist.hasPrefix("RD") {
                                        session.catalogRoute = .playlist(playlist)
                                    } else { openURL(card.destination) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        AsyncImage(url: card.thumbnailURL) { image in image.resizable().scaledToFill() } placeholder: {
                                            Rectangle().fill(.quaternary).overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
                                        }.frame(width: featured ? 218 : 148, height: featured ? 260 : 148)
                                            .clipShape(RoundedRectangle(cornerRadius: featured ? 22 : 16))
                                        Text(card.title).font(.subheadline.weight(.semibold)).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                                        if let subtitle = card.subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(typeSize.isAccessibilitySize ? nil : 2) }
                                    }.frame(width: featured ? 218 : 148, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityIdentifier("home.music.\(card.id)")
                            }
                        }
                    }.scrollIndicators(.hidden)
                }
            }
            if featuredOnly != true {
                if let error = model.moreError { Text(error).font(.footnote).foregroundStyle(.secondary) }
                if model.loadingMore { ProgressView("Loading recommendations") }
                if model.nextPage != nil {
                    Button(model.moreError == nil ? "More recommendations" : "Retry", systemImage: "arrow.down") { Task { await model.loadMore(session: session) } }
                        .frame(minHeight: 44).accessibilityIdentifier("home.music.more")
                }
            }
        }.accessibilityIdentifier("home.musicShelves")
    }
}

#endif
