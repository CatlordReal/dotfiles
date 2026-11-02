#!/usr/bin/env python3
"""Inspect release artifact metadata and optionally verify its code signature."""
import argparse
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import zipfile


def app_in(root):
    apps = list(root.glob('Products/Applications/*.app')) if root.suffix == '.xcarchive' else [root]
    if len(apps) != 1 or not apps[0].is_dir() or apps[0].suffix != '.app':
        raise ValueError('expected exactly one app')
    return apps[0]


def safe_name(name):
    return isinstance(name, str) and name not in ('', '.', '..') and pathlib.PurePosixPath(name).name == name and '/' not in name and '\\' not in name and not any(c in name for c in '*?[]')


def contained_file(root, path):
    return path.is_file() and path.resolve().is_relative_to(root.resolve())


def inspect(app, args):
    info_path = app / 'Info.plist'
    if not info_path.exists():
        info_path = app / 'Contents/Info.plist'
    if not contained_file(app, info_path):
        raise ValueError('Info.plist escapes app bundle or is missing')
    with info_path.open('rb') as f:
        info = plistlib.load(f)
    failures = []
    for key, expected in [('CFBundleIdentifier', args.bundle), ('CFBundleShortVersionString', args.version), ('CFBundleVersion', args.build)]:
        actual = info.get(key)
        print(f'{key}: {actual!r}')
        if not isinstance(actual, str) or not actual or actual != expected:
            failures.append(f'{key} missing or does not match expected {expected!r}')
    primary = info.get('CFBundleIcons', {}).get('CFBundlePrimaryIcon', {})
    icon_name = primary.get('CFBundleIconName') or info.get('CFBundleIconName')
    icon_files = primary.get('CFBundleIconFiles', [])
    resources = app / 'Contents/Resources' if (app / 'Contents/Resources').is_dir() else app
    if not resources.resolve().is_relative_to(app.resolve()):
        raise ValueError('resources escape app bundle')
    asset_catalog = contained_file(app, resources / 'Assets.car')
    icon_evidence = bool((icon_name or icon_files) and asset_catalog)
    if isinstance(icon_files, list):
        for name in icon_files:
            if safe_name(name):
                icon_evidence |= any(contained_file(app, p) for p in resources.glob(pathlib.Path(name).stem + '*'))
    # macOS bundles commonly use an explicit .icns file.
    mac_icon = info.get('CFBundleIconFile')
    if safe_name(mac_icon):
        icon_path = resources / (mac_icon if pathlib.Path(mac_icon).suffix else mac_icon + '.icns')
        icon_evidence |= contained_file(app, icon_path)
    print(f'Primary icon metadata and resource evidence: {icon_evidence}')
    if not icon_evidence:
        failures.append('primary icon metadata/resource evidence missing')
    if args.metadata_only:
        print('Signature: NOT CHECKED; metadata-only is not signing-ready')
    else:
        result = subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], capture_output=True, text=True)
        print('Signature verification:', 'passed' if result.returncode == 0 else 'failed')
        if result.returncode:
            failures.append('codesign verification failed: ' + result.stderr.strip())
    for failure in failures:
        print('ERROR:', failure, file=sys.stderr)
    print('Scope: metadata/icon evidence and optional signature verification only; review team, profile, entitlements, icon and distribution eligibility separately.')
    return bool(failures)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifact', type=pathlib.Path)
    parser.add_argument('--bundle', required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--build', required=True)
    parser.add_argument('--metadata-only', action='store_true', help='skip signature verification; does not establish signing readiness')
    args = parser.parse_args()
    try:
        if args.artifact.suffix.lower() != '.ipa':
            return inspect(app_in(args.artifact), args)
        with tempfile.TemporaryDirectory(prefix='release-preflight-') as temp, zipfile.ZipFile(args.artifact) as ipa:
            # Reject oversized archives and unsafe members before extraction.
            entries = ipa.infolist()
            if len(entries) > 100000 or sum(e.file_size for e in entries) > 4 * 1024**3 or args.artifact.stat().st_size > 4 * 1024**3:
                raise ValueError('IPA exceeds size or member limit')
            for entry in entries:
                path = pathlib.PurePosixPath(entry.filename)
                if path.is_absolute() or '..' in path.parts or (entry.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError('unsafe IPA entry')
            ipa.extractall(temp)
            apps = list((pathlib.Path(temp) / 'Payload').glob('*.app'))
            if len(apps) != 1:
                raise ValueError('expected exactly one Payload app')
            return inspect(apps[0], args)
    except (OSError, ValueError, plistlib.InvalidFileException, zipfile.BadZipFile) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
