# MusesCore

Shared domain + network-facing models for Muses (macOS) and Muses-Erato (iOS).

## Scope

This package intentionally stays UIKit/AppKit free:

- catalog identity helpers
- home recommendation mode
- Innertube browse / search id constants

Platform adapters (OAuth on iOS, browser-helper cookies on macOS, SwiftUI shells) stay in each app target.

## Adoption

- Erato links this package locally via XcodeGen `packages`.
- macOS `xiaotwu/Muses` can add the same package path (or a published tag) when ready to converge.
