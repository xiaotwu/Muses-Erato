# Local Google and device configuration

Google Cloud API keys are project credentials. There is no separate credential type named
“YouTube Data API key”: enable YouTube Data API v3 in the same project and use an API key
with appropriate restrictions for the chosen client. iOS OAuth is a separate credential
type, with a matching app Bundle ID and reverse-client-ID callback scheme. See Google's
[Data API setup](https://developers.google.com/youtube/v3/getting-started).

The public app supports guest metadata/search with an API key and account-backed reads
with OAuth. Both consume the associated project's API quota; using OAuth does not avoid
quota. Known video links play in the official visible IFrame without Data API credentials.

Create an owner-local build configuration, outside Git:

```sh
python3 scripts/configure-local-google.py \
  --oauth-plist /path/to/downloaded-ios-client.plist \
  --api-key-file /path/to/api-key.txt \
  --development-team APPLE_TEAM_ID
```

The default output is `~/.config/muses-erato/Local.xcconfig`, mode 0600. It is not copied
into the repository. The script prints only the output path and validation failures.
Pass that file to Xcode without putting credential values in shell arguments:

```sh
xcodebuild -project Muses.xcodeproj -scheme Muses \
  -xcconfig "$HOME/.config/muses-erato/Local.xcconfig" \
  -destination 'platform=iOS,id=DEVICE_UDID' -allowProvisioningUpdates build
```

On 2026-09-27, the owner-supplied iOS OAuth plist matched `com.xiaotwu.muses.erato`.
Google sign-in and OAuth-backed search succeeded on a physical iPhone. The separately
supplied API key returned HTTP 200 and one item from a `videos.list` test for the official
IFrame demonstration video; this consumes one metadata request. Keys, tokens and raw
private responses are not recorded in this repository. Cloud quota/restriction settings
and consent verification still need review before public release.

## Restriction acceptance, 2026-09-27

Three owner-key `videos.list(part=id)` requests were made for the same official sample:
correct `X-Ios-Bundle-Identifier`, wrong bundle identity and no identity. All returned
HTTP 200 with one item. This does **not** prove iOS restriction enforcement and fails
the intended negative acceptance cases. The owner was asked to configure application
restrictions for `com.xiaotwu.muses.erato` and an API restriction to YouTube Data API v3.
Retest after Cloud propagation: correct identity must work and wrong/missing identity
must fail. No key value or request URL is recorded. Three metadata requests were used.
