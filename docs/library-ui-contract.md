# Library UI contract — 2026-09-27

## Product intent

Content should occupy the screen: scan a compact list, browse artwork by swiping, and play within the selected collection. Controls should explain their scope without repeating the page title or describing implementation details.

## Layout

- One native Library title, followed by a horizontal category rail and compact action group. No repeated Your Collection / On this device heading.
- Songs contains the union of playlist membership, deduplicated by stable TrackID in first appearance order. Its Cards / List control remains visible and labeled.
- Cards reproduce the macOS CollectionSongDeck: focused center card, visible fan neighbors, full bleed artwork, lower scrim, title and artist footer, rounded 22 pt corners. Swipe or chevrons change focus; activating the focused card opens playback. A list provides complete, quickly scannable membership.
- Playlists are vertical blocks. Each block has a title, count and a small group of collection actions, immediately followed by a horizontal lazy strip of small hero cards. Repeated occurrences remain separate; unavailable slots remain visible and cannot play.
- Phone layouts keep controls in horizontal groups where they fit; large text may wrap groups without clipping. Tablet layouts use the available content width rather than stretching individual buttons.
- Import and Create share a row. Import, account, synchronization and destructive scope choices use icon plus text where a symbol alone is ambiguous. Familiar play, chevron and overflow actions may be icons, with accessible names and 44 pt targets.

## Behavior and boundaries

- Selecting a playlist occurrence establishes previous/current/remaining collection order, retains duplicates and preserves explicitly queued upcoming entries. Opening the visible player does not bypass its playback controls.
- Clearing Songs targets its membership union, with an explicit confirmation of saved-video and dependent-reference removal. Clearing a playlist removes its entries; deleting a playlist removes the collection. Clear Up Next preserves the current item.
- Account playlist pages and selected playlist contents load automatically with bounded pagination, cancellation and errors. Original names remain in memory and refresh from their source; only actual user edits acquire user-name provenance.
- No change to the public visible-player or background-playback boundary.

## Verification

Inspect phone and tablet screenshots, empty and populated states, horizontal gestures inside vertical scrolling, Cards / List switching, large text, VoiceOver alternatives, destructive scopes, occurrence playback and restart persistence. Physical device acceptance is recorded separately from simulator tests and builds.

## References

The source of the artwork and interaction contract is `Muses/Features/Shared/CollectionSongDeck.swift`, especially CollectionDeckCardSurface. The Apple Design skill references used are Accessibility (Vision and Mobility), Layout (Visual hierarchy and Adaptability), Typography, Color, Designing for iOS, Buttons (Content), Toolbars, Collections, Scroll views and Writing. The user's density and clarity requirements govern the adaptation.
