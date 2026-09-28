#!/usr/bin/env python3
"""Generate an isolated UI review project; never edit the shared Xcode project or app source."""
import plistlib
import json
import pathlib
import subprocess
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / '.artifacts/collection-deck'
OUT.mkdir(parents=True, exist_ok=True)
subprocess.run(['xcodegen','dump','--spec',str(ROOT/'project.yml'),'--type','json','--file',str(OUT/'base.json')], check=True)
spec=json.loads((OUT/'base.json').read_text())
for package in spec['packages'].values():
    if 'path' in package: package['path']=str(ROOT/package['path'])
app=spec['targets']['Muses']
for source in app['sources']: source['path']=str(ROOT/source['path'])
# Exact production session and player; only entry-point/visibility adapters differ in the test build.
session=(ROOT/'Sources/Muses/App/PublicYouTubeApp.swift').read_text().replace('@main\nstruct PublicAppLauncher', 'struct PublicAppLauncher')
(OUT/'PublicYouTubeApp.swift').write_text(session)
player=(ROOT/'Sources/Muses/Features/Public/PublicRootView.swift').read_text().replace('private struct PublicPlayerView:', 'struct PublicPlayerView:')
(OUT/'PublicRootView.swift').write_text(player)
for source in app['sources']:
    if source['path'].endswith('/App/PublicYouTubeApp.swift'): source['path']=str(OUT/'PublicYouTubeApp.swift')
    if source['path'].endswith('/Public/PublicRootView.swift'): source['path']=str(OUT/'PublicRootView.swift')
for path in ['Sources/Muses/Features/Public/PublicCollectionDeck.swift', 'Tests/CollectionDeckReview/Harness.swift']:
    absolute=str(ROOT/path)
    if not any(source['path']==absolute for source in app['sources']): app['sources'].append({'path':absolute})
info=plistlib.loads((ROOT/'Sources/Muses/Resources/Info.plist').read_bytes())
info['CFBundleIdentifier']='com.xiaotwu.muses.deck-review'
(OUT/'Info.plist').write_bytes(plistlib.dumps(info))
app['settings']['base']['INFOPLIST_FILE']=str(OUT/'Info.plist')
app['settings']['base']['PRODUCT_BUNDLE_IDENTIFIER']='com.xiaotwu.muses.deck-review'
for name,path in [('MusesTests','DeckUnitTests.swift'),('MusesPublicUITests','DeckUITests.swift')]:
    spec['targets'][name]['sources']=[{'path':str(ROOT/'Tests/CollectionDeckReview'/path)}]
(OUT/'project.json').write_text(json.dumps(spec,indent=2))
subprocess.run(['xcodegen','generate','--spec',str(OUT/'project.json'),'--project',str(OUT)],check=True)
