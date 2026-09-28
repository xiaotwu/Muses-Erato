# Collection deck component review

This isolated app compiles the production deck, playlist block, session and visible player. It seeds a temporary SwiftData library with nine synthetic songs, a duplicate occurrence and an unavailable occurrence. A second fixture has 5,000 songs. Titles are synthetic; public YouTube thumbnails illustrate the artwork surface. No Google credentials or catalog request are needed.

Generate without modifying the production project:

```sh
python3 Tests/CollectionDeckReview/prepare.py
xcodebuild test -project .artifacts/collection-deck/Muses.xcodeproj \
  -scheme Muses -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UUID' \
  -derivedDataPath .artifacts/collection-deck/derived CODE_SIGNING_ALLOWED=NO
```

The generator removes only the production launcher annotation and exposes the existing player type in generated copies. The generated app uses its own bundle identifier. It reads the current checkout, so regenerate after changing the session or root view. All generated files live in ignored `.artifacts/collection-deck`.

Unit tests cover the bounded five-card projection, directional threshold and exact playlist-union Songs scope. UI tests exercise horizontal focus without playback, previous-card navigation, Cards/List switching, vertical scrolling started on the card, playlist scrolling followed by arrow navigation and occurrence playback, large accessibility text, 44-point targets, 5,000-song switching, and exposed-neighbor versus center activation.

Screenshots are retained as XCTest attachments. Tests also print `DECK_SCREENSHOT:` with their simulator temporary directory so images can be inspected before result-bundle finalization. The supplemental tests do not replace the integrated public app tests, real VoiceOver testing, or device playback verification.
