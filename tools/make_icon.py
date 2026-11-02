"""Package the unchanged supplied PNG as a classic macOS ICNS. No styling/cropping."""
import hashlib
from pathlib import Path
import shutil
import struct
import subprocess


def png_size(path):
    with Path(path).open('rb') as stream: header = stream.read(24)
    if len(header) != 24 or header[:8] != b'\x89PNG\r\n\x1a\n' or header[12:16] != b'IHDR':
        raise ValueError('App-Icon ist keine gültige PNG-Datei.')
    width, height = struct.unpack('>II', header[16:24])
    if width == 0 or width != height: raise ValueError('App-Icon muss quadratisch sein.')
    return width, height


def build_icon(source, resources, work):
    source = Path(source); resources = Path(resources); work = Path(work)
    png_size(source)
    original = hashlib.sha256(source.read_bytes()).hexdigest()
    iconset = work / 'AppIcon.iconset'; iconset.mkdir(parents=True, exist_ok=True)
    resources.mkdir(parents=True, exist_ok=True)
    for base in [16, 32, 128, 256, 512]:
        for scale in [1, 2]:
            pixels = base * scale
            name = 'icon_' + str(base) + 'x' + str(base) + ('@2x' if scale == 2 else '') + '.png'
            subprocess.run(['/usr/bin/sips', '--resampleHeightWidth', str(pixels), str(pixels),
                str(source), '--out', str(iconset / name)], check=True, stdout=subprocess.DEVNULL)
    output = resources / 'AppIcon.icns'
    subprocess.run(['/usr/bin/iconutil', '--convert', 'icns', str(iconset), '--output', str(output)], check=True)
    data = output.read_bytes()
    if len(data) < 8 or data[:4] != b'icns' or struct.unpack('>I', data[4:8])[0] != len(data):
        raise ValueError('AppIcon.icns wurde nicht vollständig erzeugt.')
    shutil.copy2(source, resources / 'CraftVoice.png')
    if hashlib.sha256(source.read_bytes()).hexdigest() != original or hashlib.sha256((resources/'CraftVoice.png').read_bytes()).hexdigest() != original:
        raise RuntimeError('Die PNG-Quelldatei wurde verändert.')
    print('App-Icon verpackt; PNG unverändert: ' + original)
