#!/usr/bin/env python3
"""One diagnostic process; capture only CraftVoice's active live windows, no permissions requested."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
app = root / 'dist/CraftVoice.app'
folder = root / 'checks/redesign-final-screenshots'
folder.mkdir(parents=True, exist_ok=True)
subprocess.run([str(root / 'tools/verify-signature.sh'), str(app)], cwd=root, check=True)
subprocess.run(['swiftc', '-module-cache-path', str(root / '.cache/swift'), str(root / 'tools/activate-design-preview.swift'), '-o', str(root / 'checks/activate-design-preview')], cwd=root, check=True)
logPath = folder / 'matrix.log'
logPath.unlink(missing_ok=True)
# Remove only the known generated files; never accept screenshots from an old run.
for mode in ('dark', 'light'):
    for state in ('empty', 'recording', 'transcribing', 'completed', 'inserted', 'unverified', 'error', 'long', 'gallery'):
        for suffix in ('.png', '-layout.json'):
            (folder / f'dictation-{state}-{mode}{suffix}').unlink(missing_ok=True)
    for tab in ('controls', 'privacy', 'appearance'):
        (folder / f'settings-{tab}-{mode}.png').unlink(missing_ok=True)
process = subprocess.Popen(['/usr/bin/open', '-n', '-W', '--stdout', str(logPath), '--stderr', str(logPath), '--env', f'APP_SNAPSHOT={folder}', '--env', 'APP_SNAPSHOT_MATRIX=1', str(app)], cwd=root)
activator = subprocess.Popen([str(root / 'checks/activate-design-preview'), str(app)], cwd=root)
try:
    if process.wait(timeout=60) != 0: raise SystemExit('FAIL launching preview')
finally:
    activator.terminate(); activator.wait(timeout=5)
log = logPath.read_text()
if 'MATRIX SNAPSHOT PASS' not in log or 'FAIL' in log or 'active=false' in log or 'key=false' in log:
    raise SystemExit('FAIL active live-window matrix: ' + log)
for mode in ('dark', 'light'):
    for state in ('empty', 'recording', 'transcribing', 'completed', 'inserted', 'unverified', 'error', 'long', 'gallery'):
        assert (folder / f'dictation-{state}-{mode}.png').is_file()
    for tab in ('controls', 'privacy', 'appearance'):
        assert (folder / f'settings-{tab}-{mode}.png').is_file()
paths = [str(p) for p in folder.glob('dictation-*-layout.json') if 'gallery' not in p.name]
subprocess.run(['swift', '-module-cache-path', str(root / '.cache/swift'), str(root / 'tools/check-layout.swift'), *paths], check=True, cwd=root)
# Relative areas alone can pass even when the whole page exceeds its window.
for name in paths:
    data = json.loads(Path(name).read_text())
    assert len([p for p in data['probes'] if p['kind'] == 'probe']) >= 4, name
    for probe in data['probes']:
        assert probe['x'] >= -0.5 and probe['y'] >= -0.5, (name, probe['name'], 'negative origin')
        assert probe['x'] + probe['width'] <= data['window']['width'] + 0.5, (name, probe['name'], 'horizontal overflow')
        assert probe['y'] + probe['height'] <= data['window']['height'] + 0.5, (name, probe['name'], 'vertical overflow')
print('PASS 18 active dictation/gallery screenshots + 6 active settings screenshots; 16 layouts inside window bounds')
