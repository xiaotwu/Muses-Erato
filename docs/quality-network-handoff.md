# Networking handoff

## Session integration API (ready)

The existing `RequestBudget(searchCallsPerDay:otherUnitsPerDay:)` remains isolated in memory, preserving existing callers and tests. Production should construct **one actor for a stable device-local file** and inject it into every `YouTubeDataCatalog` instance across account/catalog recreation:

```swift
let budget = try RequestBudget(
    searchCallsPerDay: 10,
    otherUnitsPerDay: 100,
    storageURL: applicationSupportURL.appendingPathComponent("device-request-budget.json"),
    timeZone: TimeZone(identifier: "America/Los_Angeles")!
)
```

`storageURL` is the exact argument label (not `storeURL`). The parent directory is created on the first reservation. No UserDefaults domain is used. Tests use the unchanged in-memory initializer or a unique temporary storage URL; fixture sessions must avoid the production URL. Keep this file outside account/library deletion scopes so sign-out, catalog reconstruction or library cleanup does not replenish the device budget. Concurrent actors pointing at one URL are unsupported; share one actor within the process.

Loading corrupt/unreadable existing state throws. Reservations atomically save before publishing successful usage; write failure propagates and prevents transport from spending a request without persisted accounting. Handle initialization failure visibly rather than silently falling back to an empty memory budget. Reservation failure keeps the last successful in-memory state.

`await budget.snapshot(at: Date())` returns `searchUsed`, `otherUsed`, `resetsAt` (Date), and `timeZoneIdentifier`. Use `resetsAt` to explain local recovery time. `reserve(endpoint:at:)` and snapshot date injection support deterministic cross-day tests; time zone injection supports device policy and test isolation. Default day boundary remains Los Angeles, matching existing behavior. Use a stable configured timezone across launches; changing timezone creates a new day identity.

Existing `APIError.quotaExceeded(reason: "localSearchBudget")` / `"localReadBudget"` cases remain compatible. Their localized messages explicitly identify this device's daily limit. Other quota errors identify the shared server project quota. Local counts cannot predict shared Google quota or its reset. `otherUnitsPerDay` continues to count one unit per physical non-search request, including retries; this is a local guardrail, not a Google billing/quota estimator.

## Retry integration

`RetryAfter.delay(in:at:)` parses case-insensitive header names, integer seconds and HTTP date formats. `APIError.classify(_:at:)` gains an optional reference date and preserves its original call shape. A 429 returns `rateLimited(retryAfter:)` with the full delay. Long 429/503 waits return the original response immediately; they never get truncated and retried early. Consumers can read `RetryAfter.delay(in:)` from a 503 if they need its recovery metadata.

`GETCoalescer(transport:retryPolicy:)` accepts optional `HTTPRetryPolicy(maximumAutomaticDelay: 2)`. The default performs at most two retries, honors valid short server waits, and uses exponential equal jitter only when no valid header exists. Search still does not auto-retry. GET merging and cancellation ownership are preserved. An individual cancelled waiter leaves other waiters running; cancelling the last waiter cancels transport/backoff.

## Validation

Completed on 2026-09-29 (host macOS):

- `swift test --package-path Packages/MusesNetworking --scratch-path /tmp/muses-quality-network-build`: **12 tests passed**, zero failures (4 existing + 8 new).
- `swift test --package-path Packages/MusesCatalog --scratch-path /tmp/muses-quality-network-catalog-build`: **28 tests passed**, zero failures; no Catalog source/test changes.

Coverage includes all three HTTP date forms and case-insensitive headers; invalid/past waits; 429/503 long waits returning without sleep or another request; exact short waits; deterministic jitter and retry ceiling; cancellation of the final waiter's backoff; existing individual cancellation with a surviving coalesced waiter; search no retry; one budget reservation per physical retry; persistence reconstruction; DST/local midnight reset and custom timezone; isolated storage; write failure and corrupt storage. Tests inject clocks, random values and recording sleepers so long Retry-After cases do not sleep. The cancellation test cancels a sleeper as soon as it begins (ran in under a millisecond). App-level integration remains the session/coordinator stream's responsibility.

Changes are confined to Packages/MusesNetworking plus this handoff. No UI/session files, commits, PRs, or external settings are changed by this workstream.

## 2026-09-30 live-validation configuration error fix (ready for coordinator rebuild)

New production change is confined to `Packages/MusesNetworking/Sources/MusesNetworking/HTTP.swift`:

- Added `APIError.configuration(APIConfigurationIssue)` with `.appNotAuthorized`, `.serviceDisabled`, `.invalidKey`.
- Decode `error.details` entries typed `type.googleapis.com/google.rpc.ErrorInfo`. Their known reasons override generic legacy `errors[].reason = forbidden`, including the observed `API_KEY_IOS_APP_BLOCKED`.
- Recognize related app/service restrictions, `SERVICE_DISABLED`, `API_KEY_INVALID` / expired / missing key, and legacy `accessNotConfigured`, `keyInvalid`, `ipRefererBlocked`. Unknown reasons retain existing classification. Raw messages never drive classification.
- Localized descriptions explain the specific Google API configuration problem and retain retry / open in YouTube guidance. No key, raw message, project metadata, request URL or bundle value is retained in the new error or displayed.
- Catalog already propagates APIError unchanged. Search error and scoped playback status-check error already consume `localizedDescription`, so no UI/session edits are necessary. Existing Retry/Open YouTube controls are unchanged. Configuration errors do not auto-retry, bypass embedding permission checks or change outgoing client identity.

Added `ConfigurationErrorTests.swift` (3 network tests) and `ConfigurationFailureTests.swift` (2 catalog tests). Coverage uses representative ErrorInfo responses, generic-forbidden override, disabled service / invalid key, unknown-details and raw-message negative cases, existing quota behavior, safe descriptions, propagation through search and embedding-status requests, local discovery preservation, no automatic retry, and unchanged configured iOS bundle identity.

Re-ran the package commands listed above: **MusesNetworking 15 passed; MusesCatalog 30 passed**, zero failures. Coordinator should rebuild/signed-validate the updated app; no claim of live device validation is made by this workstream. No app bundle/restriction/configuration setting was changed.
