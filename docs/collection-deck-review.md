# Library collection deck review — 2026-09-27

## Scope

`PublicCollectionDeck` replaces the artwork grid with a centered fan. Only the focused index and at most two neighbors on each side are instantiated. Artwork fills the entire card, including its footer; a gradient covers only the lower 58%. A 22-point corner radius and overlaid title, artist and action retain the macOS visual structure. Cards/List controls remain visible above the collection. List rows expose details, play, queue and scoped removal.

Songs are the first-appearance union of local playlist track IDs. Unrelated saved videos are excluded from the Songs count and clear action. Playlist blocks preserve repeated and unavailable occurrences and pass the original occurrence index to `playPlaylist`.

The reference implementation was read without modification from macOS `CollectionSongDeck.swift` and `SongsListView.swift`. The Apple Design skill informed 44-point targets, semantic colors, Dynamic Type reflow, exposed adjacent content, and optional motion. Large text uses stacked presentation controls and full text in the List alternative. Artwork labels remain compact, with full title/artist accessibility labels and a details action.

## Interaction fixes found by simulator testing

- A geometry-container accessibility identifier propagated over the focused card identifier. Removing it preserves the individual focus element and adjustable action.
- A plain SwiftUI button's 44-point layout did not by itself establish a 44-point hit area. Explicit label content shapes now match the control bounds.
- A simultaneous SwiftUI drag both advanced the card and activated its button. Filtering direction only at drag completion also prevented the surrounding page from scrolling. A UIKit pan recognizer now rejects vertical movement before recognition and suppresses the same drag's button activation.
- At maximum accessibility text, a horizontal presentation group widened the entire page. The controls now stack and icon-only controls keep their 44-point targets without oversized glyphs.

## Evidence

The reproducible isolated review project and commands are in `Tests/CollectionDeckReview/README.md`. It uses production components and session/player code with a synthetic local library, separate bundle identifier, and no credentials. It is not a screenshot of the integrated navigation shell.

The iPhone 17e and iPad Pro 11-inch (M5), both iOS 26.5 simulators, cover:

- Cards/List switching; horizontal swipe without playback; previous-card navigation.
- Vertical scrolling beginning over the deck.
- Playlist horizontal swipe followed by previous-arrow navigation, then opening the visible player from an original occurrence.
- Maximum accessibility text, and 44-point control bounds.
- 5,000-song navigation, with a unit-tested maximum five-card projection.
- Exposed-neighbor focus versus center-card activation.

Result: both simulators passed the two component unit cases and all four UI scenarios across the suite run and the targeted neighbor retest. The first iPad neighbor test used a phone-relative point outside the immediate neighbor; deriving the point from the bounded card width fixed that test. The supplemental integrated `PublicLibraryHeroUITests` changes require the root integration run.

Screenshots are kept in XCTest result bundles and locally under `.artifacts/collection-deck/screenshots/{iphone,ipad}`. Synthetic titles and artwork are illustrative; the visible IFrame may report network or embedding errors, so player presentation is tested separately from successful streaming.

This is component and simulator evidence. It does not measure Instruments memory/frame-rate performance, establish manual VoiceOver or Reduce Motion acceptance, or replace integrated app/device playback and release testing. The root integration owns subsequent full-collection playback-context changes.
