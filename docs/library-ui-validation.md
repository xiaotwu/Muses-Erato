# Library layout and interaction validation

Date: 2026-09-27. Contract: [library-ui-contract.md](library-ui-contract.md).

## Integrated changes

The public shell groups related actions, removes duplicate page headings, and uses labels for import, account, policy and support actions. Library has one native title, horizontal categories and compact scoped tools. Songs uses playlist membership union with Cards / List. Playlists are vertical collection blocks with complete lazy horizontal occurrence strips.

The artwork surface follows macOS CollectionDeckCardSurface: full bleed imagery, a gradient over the lower 58%, title/artist/action footer, a 22 pt continuous corner and fan neighbors. Only five cards around the focus are constructed, independent of collection size. The public visible-player boundary remains in effect.

## Evidence and repairs

- Four Persistence successor tests passed, including refreshable remote names, sanitized encoding and explicit handwritten import names. Log: `/tmp/erato-remote-successor.log`.
- Thirty hosted application tests passed after integration, including exact occurrence selection, duplicate order, unavailable slot rejection, explicit Up Next retention, collection replacement, precise Songs clearing and restart. Log: `/tmp/erato-compact-integrated-tests.log`.
- The top-level Queue menu's cancel, clear, current-item preservation and restart UI scenario passed in that run.
- Automatic account paging, original default names, import and restart passed on the integrated phone simulator before the additional card interaction checks.
- The policy consent UI passed after restoring a labeled Continue action. Log: `/tmp/erato-compact-artwork-ui.log`.
- A Search outside-tap test exposed UIKit/SwiftUI focus disagreement. The dismissal bridge now updates both responders and FocusState. The same integrated UI test passed afterward in `/tmp/erato-compact-final-ui.log`.
- A parent accessibility identifier overwrote the focused card's identifier. It was removed; child labels and full 44 pt hit regions were retained.
- Actual card-swipe checks exposed an unwanted playback activation. The directional UIKit pan now rejects vertical gestures and filters the drag release from playback activation; preceding failed runs are not acceptance evidence.

## Final delivery evidence

- Integrated iPhone automatic import, Cards swipe without playback, List switching and restart passed in `/tmp/erato-compact-final-artwork.log` after the gesture repair. Its separate first large-text attempt needed the test to scroll to a virtualized form field; no product behavior was weakened.
- The complete maximum accessibility text-size flow and seven import/collection/scoping hosted tests passed in `/tmp/erato-compact-large-final.log`.
- The complete integrated iPad flow passed in `/tmp/erato-compact-ipad-ui.log`.
- The component harness independently passed horizontal/vertical gestures, adjacent/focused activation, playlist strip swipe and arrows, exact occurrence playback, maximum text size and 5,000-item navigation on iPhone and iPad. See [collection-deck-review.md](collection-deck-review.md); harness screenshots are distinct from integrated Library screenshots.
- The signed final UI Debug build succeeded in `/tmp/erato-device-compact-final.log`, was installed on the paired physical iPhone and successfully launched. The owner confirmed the new functions are correct; layout is accepted as an interim delivery and will be discussed in a later design round.

- The Library deletion/restart, bulk-clear confirmation and normal category/empty-clear scenarios passed in `/tmp/erato-compact-library-regression.log`. Its maximum-text test incorrectly required the entire category button to fit inside the horizontal rail. The test now taps a hittable category and verifies its selected state, consistent with the existing integrated smoke helper. The maximum-text import/category/hero scenario passed afterward in `/tmp/erato-compact-library-large-retest.log`. These four scenarios passed across the initial run and the targeted rerun; the initial suite run itself failed.

## Remaining delivery checks

The owner confirmed functional behavior on the physical iPhone. Further visual layout refinement is deferred at the owner’s request. Manual VoiceOver and Reduce Motion checks remain unverified. Library regression evidence is recorded above. An isolated component harness or a successful build does not substitute for integrated UI or physical-device acceptance.

The earlier distribution IPA represents an older code version. Final distribution packaging and public P6 privacy, authorization, migration-retention and store-review gates remain separate.
