"""Compile, bundle, sign and verify; never installs or changes keychain settings."""
import argparse
from contextlib import contextmanager
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import time
from project import ROOT, load_config
from make_icon import build_icon


def run(args, **kwargs):
    subprocess.run(args, check=True, cwd=ROOT, **kwargs)


@contextmanager
def candidate_directory(dist):
    folder = Path(tempfile.mkdtemp(prefix='.build-', dir=dist))
    try:
        yield folder
    except BaseException:
        if (folder / 'previous.app').exists():
            print('Vorherige Build-Ausgabe bleibt zur Wiederherstellung erhalten: ' + str(folder))
        else:
            shutil.rmtree(folder)
        raise
    else:
        shutil.rmtree(folder)


def bundle_info(config):
    return dict(CFBundleIdentifier=config['bundle_id'], CFBundleName=config['name'], CFBundleDisplayName=config['name'],
                    CFBundleExecutable=config['executable'], CFBundlePackageType='APPL', CFBundleShortVersionString='0.1.0',
                    CFBundleVersion=str(time.time_ns()), CFBundleDevelopmentRegion='de', CFBundleLocalizations=['de'],
                    LSMinimumSystemVersion='26.0', NSHighResolutionCapable=True, NSPrincipalClass='NSApplication',
                    LSUIElement=True, CFBundleIconFile="AppIcon.icns",
                    NSMicrophoneUsageDescription='CraftVoice nimmt deine Stimme auf, um deutsche Diktate ausschließlich auf diesem Mac zu erkennen.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument('--compile-only', action='store_true', help='Nur Swift kompilieren; keine .app, keine Signierung oder Installation')
    mode_group.add_argument('--check-signing', action='store_true', help='Nur vorhandene Signieridentität prüfen')
    parser.add_argument('--debug', action='store_true')
    args = parser.parse_args()
    config = load_config()
    if not args.compile_only:
        result = subprocess.run(['/usr/bin/security', 'find-identity', '-v', '-p', 'codesigning'], capture_output=True, text=True, check=True)
        pattern = r'\b' + config['signing_fingerprint'] + r'\s+"Craft Code Signing"'
        if not re.search(pattern, result.stdout):
            raise RuntimeError('Craft Code Signing mit dem festgelegten Fingerabdruck ist nicht verfügbar. Kein Ad-hoc-Fallback. Im normalen Terminal prüfen.')
    if args.check_signing:
        print('Signieridentität bestätigt: ' + config['signing_fingerprint'])
        return
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(ROOT / '.cache/clang'), SWIFTPM_MODULECACHE_OVERRIDE=str(ROOT / '.cache/swift'))
    mode = 'debug' if args.debug else 'release'
    run(['swift', 'build', '-debug-info-format', 'none', '--disable-sandbox', '--cache-path', str(ROOT / '.cache'), '--scratch-path', str(ROOT / '.build'), '-c', mode], env=env)
    if args.compile_only:
        print('Nur kompiliert. Es wurde keine signierte App erstellt oder installiert.')
        return
    dist = ROOT / 'dist'; dist.mkdir(exist_ok=True)
    # Keep any previous verified build until the candidate passes every check.
    with candidate_directory(dist) as temp:
        app = Path(temp) / (config['name'] + '.app')
        contents = app / 'Contents'; (contents / 'MacOS').mkdir(parents=True)
        (contents / 'Resources/de.lproj').mkdir(parents=True)
        shutil.copy2(ROOT / '.build' / mode / config['executable'], contents / 'MacOS' / config['executable'])
        if (ROOT / 'Resources/ThirdParty').is_dir():
            shutil.copytree(ROOT / 'Resources/ThirdParty', contents / 'Resources/ThirdParty')
        build_icon(ROOT / "Icon/CraftVoice.png", contents / "Resources", temp / "icon-build")
        info = bundle_info(config)
        (contents / 'Info.plist').write_bytes(plistlib.dumps(info))
        run(['/usr/bin/codesign', '--force', '--sign', config['signing_fingerprint'], str(app)])
        run([str(ROOT / 'tools/verify-signature.sh'), str(app), config['signing_fingerprint']])
        destination = dist / (config['name'] + '.app')
        backup = Path(temp) / 'previous.app'
        if destination.exists(): destination.rename(backup)
        try:
            app.rename(destination)
        except BaseException:
            if backup.exists(): backup.rename(destination)
            raise
    print('Gebaut und geprüft: ' + str(destination))


if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit('Build abgebrochen: ' + str(error))
