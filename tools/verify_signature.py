"""Verify existing bundle without rebuilding, resigning, or exporting private keys."""
import argparse
import hashlib
from pathlib import Path
import plistlib
import subprocess
import tempfile
from project import ROOT, load_config


def verify(app, expected):
    config = load_config()
    if expected != config['signing_fingerprint']:
        raise ValueError('Nicht freigegebener Zertifikatsfingerabdruck.')
    subprocess.run(['/usr/bin/codesign', '--verify', '--strict', '--verbose=2', '-R=identifier "' + config['bundle_id'] + '"', str(app)], check=True)
    with (app / 'Contents/Info.plist').open('rb') as stream: info = plistlib.load(stream)
    if info.get('CFBundleIdentifier') != config['bundle_id'] or info.get('CFBundleExecutable') != config['executable']:
        raise ValueError('Bundle-ID oder Programmname weicht von project.json ab.')
    checks = ROOT / 'checks'; checks.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='cert-', dir=checks) as directory:
        prefix = str(Path(directory) / 'certificate-')
        subprocess.run(['/usr/bin/codesign', '--display', '--extract-certificates=' + prefix, str(app)], check=True)
        cert = Path(prefix + '0')
        if not cert.is_file(): raise ValueError('Kein Signierzertifikat exportiert; Prüfung abgebrochen.')
        fingerprint = hashlib.sha1(cert.read_bytes()).hexdigest().upper()
        if fingerprint != expected: raise ValueError('Falscher Zertifikatsfingerabdruck: ' + fingerprint)
    result = subprocess.run(['/usr/bin/codesign', '-d', '-r-', str(app)], capture_output=True, text=True, check=True)
    (checks / 'signing-requirement.txt').write_text(result.stdout + result.stderr)
    print('Signatur, Fingerabdruck und Bundle-ID bestätigt: ' + config['bundle_id'])


if __name__ == '__main__':
    try:
        config = load_config()
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument('app', nargs='?', default=str(ROOT / 'dist' / (config['name'] + '.app')))
        parser.add_argument('fingerprint', nargs='?', default=config['signing_fingerprint'])
        args = parser.parse_args()
        verify(Path(args.app), args.fingerprint.upper())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit('Signaturprüfung fehlgeschlagen: ' + str(error))
