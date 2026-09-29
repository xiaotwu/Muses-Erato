#!/usr/bin/env python3
"""Verify an exported public App Store or experimental Ad Hoc IPA locally; never upload it."""
import argparse
import hashlib
import json
import pathlib
import plistlib
import subprocess
import stat
import tempfile
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('ipa', type=pathlib.Path)
parser.add_argument('--team', required=True)
parser.add_argument('--variant', choices=['public', 'native'], default='public')
parser.add_argument('--bundle-id', default='com.xiaotwu.muses.erato')
args = parser.parse_args()
ipa = args.ipa.resolve(strict=True)

def run(command):
    return subprocess.run(command, capture_output=True, check=True)

with zipfile.ZipFile(ipa) as archive:
    for entry in archive.infolist():
        path = pathlib.PurePosixPath(entry.filename)
        if path.is_absolute() or '..' in path.parts:
            raise SystemExit('FAIL: unsafe archive member path')
        if stat.S_ISLNK(entry.external_attr >> 16):
            target = pathlib.PurePosixPath(archive.read(entry).decode('utf-8'))
            if target.is_absolute() or '..' in target.parts:
                raise SystemExit('FAIL: unsafe archive symlink')
with tempfile.TemporaryDirectory(prefix='erato-distribution-audit-') as temporary:
    run(['ditto', '-x', '-k', str(ipa), temporary])
    apps = list((pathlib.Path(temporary) / 'Payload').glob('*.app'))
    if len(apps) != 1:
        raise SystemExit('FAIL: expected one app in Payload')
    app = apps[0]
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != args.bundle_id or 'iPhoneOS' not in info.get('CFBundleSupportedPlatforms', []):
        raise SystemExit('FAIL: unexpected bundle or platform')
    run(['codesign', '--verify', '--deep', '--strict', str(app)])
    entitlements = plistlib.loads(run(['codesign', '-d', '--entitlements', ':-', str(app)]).stdout)
    profile = plistlib.loads(run(['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')]).stdout)
    identifier = f'{args.team}.{args.bundle_id}'
    if entitlements.get('application-identifier') != identifier or entitlements.get('get-task-allow') is not False:
        raise SystemExit('FAIL: wrong identity or development signing')
    if profile.get('ProvisionsAllDevices') or profile['Entitlements'].get('get-task-allow') is not False:
        raise SystemExit('FAIL: unexpected enterprise or development profile')
    if args.variant == 'public' and profile.get('ProvisionedDevices'):
        raise SystemExit('FAIL: profile is not for App Store distribution')
    if args.variant == 'native' and not profile.get('ProvisionedDevices'):
        raise SystemExit('FAIL: native download requires registered-device Ad Hoc signing')
    if args.team not in profile.get('TeamIdentifier', []) or profile['Entitlements'].get('application-identifier') != identifier:
        raise SystemExit('FAIL: provisioning identity mismatch')
    asset_info = json.loads(run(['xcrun', 'assetutil', '--info', str(app / 'Assets.car')]).stdout)
    icons = [asset for asset in asset_info if asset.get('AssetType') == 'Icon Image'
             and asset.get('PixelWidth') == 1024 and asset.get('PixelHeight') == 1024]
    if not icons or any(asset.get('Opaque') is not True for asset in icons):
        raise SystemExit('FAIL: large app icon is missing or contains transparency')
    print('Large app icon is opaque in the compiled asset catalog.')
    binary_text = run(['strings', '-a', str(app / info['CFBundleExecutable'])]).stdout.decode(errors='replace')
    for marker in ('MUSES_UI_TEST_LIBRARY', 'MUSES_UI_TEST_CATALOG', 'Fixture first video', 'MusesUITests/'):
        if marker in binary_text:
            raise SystemExit('FAIL: binary contains test fixture marker: ' + marker)
    if any(path.suffix in ('.sqlite', '.xcresult', '.db') for path in app.rglob('*')):
        raise SystemExit('FAIL: app bundles generated test or runtime data')
    if args.variant == 'public':
        audit = run(['python3', str(pathlib.Path(__file__).with_name('audit-public-artifact.py')), str(app)])
        print(audit.stdout.decode())
    else:
        if info.get('UIBackgroundModes') != ['audio']:
            raise SystemExit('FAIL: native audio background declaration missing or expanded')
        if 'YouTubeKit' not in binary_text:
            raise SystemExit('FAIL: native resolver not linked')
        if not (app / 'PublicPrivacyPolicy.md').is_file() or not (app / 'PrivacyInfo.xcprivacy').is_file():
            raise SystemExit('FAIL: privacy documents missing')
        print('Native Ad Hoc signature, profile, background declaration and fixture exclusion passed.')
    print(json.dumps({'ipaSHA256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
                      'bundleID': args.bundle_id, 'version': info.get('CFBundleShortVersionString'),
                      'build': info.get('CFBundleVersion'), 'variant': args.variant, 'registeredDeviceCount': len(profile.get('ProvisionedDevices', [])),
                      'distributionExportVerified': True,
                      'uploaded': False}, indent=2))
