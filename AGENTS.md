# Muses-Erato project guidance

Muses-Erato is the iOS member of Project-Muses. The installed app is Muses.

- Use `../Muses-Polyhymnia` as the product and interaction reference. Current iOS source and explicit user decisions determine implemented capabilities.
- Adapt the macOS library, collection context, queue, artwork and typography to native iPhone/iPad layouts. Public and experimental Native playback have separate source allowlists and acceptance gates; do not infer Public background audio from macOS.
- Keep credentials outside Git and preserve existing library data.
- Run the relevant package/app checks for changes. Build instructions are in docs/repository-guide.md and `.github/workflows/quality.yml`.
- Project-Muses owns GitHub Pages and aggregated releases. Keep native builds, signing, IPA audit and source releases in this repository. The policy builder is a local parity check, not a deployment pipeline.
- Do not add automated-assistant attribution or co-author trailers to commits.

## Shared product baseline

[Project-Muses platform baseline](https://github.com/xiaotwu/Project-Muses/blob/main/docs/platform-baseline.md) records the family direction. Polyhymnia is the core product reference. Explicit user decisions and current source/runtime evidence take precedence over historical port documents. Windows may be rebuilt against that baseline; preserve library data and verify native Windows behavior before claiming parity.
