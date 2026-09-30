# GitHub main consolidation — 2026-09-29

## Branch inventory

GitHub had three branches: main (e25705510e832550a7479444d695bc43c9a6b916), codex/erato-guided-ui (same commit), and feat/bw-laser-ui-normalize (3e0ffa5bac1274b45e8ad64fd12a62cfed997d3d). Both non-main branch heads are ancestors of main. The feature branch has zero unique commits; main contains 100 later commits. No open pull requests exist. No conflicting or missing remote work needs replaying.

After verification, remove the two redundant remote branch references. All their commits remain reachable from main; published beta release tags and assets remain intact. Local worktree branches are preserved because several contain ongoing task state or original uncommitted work. In particular /Users/xiaotwu/Code/Muses-Erato remains on its original branch with its dirty files unchanged.

## Verification

Fresh swift test runs passed for all six local packages: MusesCore 3, MusesDomain 9, MusesQueue 3, MusesCatalog 28, MusesPersistence 40, MusesNetworking 4. Total 87 tests, zero failures. Re-ran audit-distribution-ipa.py for both beta 2 exports: strict codesign/provisioning identity, compiled large icon opacity, test fixture/data exclusion, public endpoint/capability isolation and Native audio/Ad Hoc profile checks passed. Public SHA256 12824088fde6bb90852c03bebf9fbc22ec8c078deab428e3aa85a8cdecc25ba8; Native SHA256 a3f2c472ffccf13d12414b2c8129c64174d0d1cd17a5386a2f401fe610f31435. No application code changes are introduced by this consolidation.

These checks establish repository consolidation and package/artifact integrity, not new device acceptance or platform review approval. TestFlight external review and Google production verification retain their existing gates.
