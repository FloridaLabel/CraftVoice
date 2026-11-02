"""Local developer bundle; explicit ad-hoc signature, no certificate or installation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
from build import bundle_info
from make_icon import build_icon

ROOT = Path(__file__).resolve().parent.parent

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compile-only', action='store_true')
    parser.add_argument('--debug', action='store_true')
    parser.add_argument('--reuse-executable', type=Path, help='Bundle an explicitly selected existing executable without compiling; caller must verify its source revision.')
    args = parser.parse_args()
    config = json.loads((ROOT / 'project.json').read_text())
    mode = 'debug' if args.debug else 'release'
    if args.compile_only and args.reuse_executable:
        parser.error('--compile-only and --reuse-executable are mutually exclusive')
    # New artifacts live in macOS temporary storage, never beside synced sources.
    local = Path(tempfile.gettempdir()).resolve() / 'CraftVoiceDeveloper' / hashlib.sha256(str(ROOT).encode()).hexdigest()[:12]
    local.mkdir(parents=True, exist_ok=True, mode=0o700)
    scratch = local / 'build'
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(local / 'cache/clang'), SWIFTPM_MODULECACHE_OVERRIDE=str(local / 'cache/swift'))
    if args.reuse_executable:
        executable = args.reuse_executable.expanduser().resolve(strict=True)
        if not executable.is_file() or not os.access(executable, os.X_OK):
            parser.error('Selected executable is not an executable regular file')
    else:
        subprocess.run(['swift', 'build', '--package-path', str(ROOT), '--cache-path', str(local / 'cache/swiftpm'), '--scratch-path', str(scratch), '-c', mode], check=True, env=env)
        executable = scratch / mode / config['executable']
    if args.compile_only:
        print(executable)
        return
    subprocess.run(['/usr/bin/lipo', '-verify_arch', 'arm64', str(executable)], check=True)
    output = local / 'bundles'
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.candidate-', dir=output) as temporary:
        work = Path(temporary)
        app = work / (config['name'] + '.app')
        contents = app / 'Contents'
        (contents / 'MacOS').mkdir(parents=True)
        (contents / 'Resources/de.lproj').mkdir(parents=True)
        binary = contents / 'MacOS' / config['executable']
        shutil.copyfile(executable, binary)
        binary.chmod(0o755)
        shutil.copytree(ROOT / 'Resources/ThirdParty', contents / 'Resources/ThirdParty', copy_function=shutil.copyfile)
        build_icon(ROOT / 'Icon/CraftVoice.png', contents / 'Resources', work / 'icon')
        (contents / 'Info.plist').write_bytes(plistlib.dumps(bundle_info(config)))
        # Strip inherited extended metadata only from the new temporary bundle.
        # /usr/bin/xattr works with macOS Python builds lacking os.listxattr.
        subprocess.run(['/usr/bin/xattr', '-cr', str(app)], check=True)
        subprocess.run(['/usr/bin/codesign', '--force', '--sign', '-', str(app)], check=True)
        subprocess.run(['/usr/bin/codesign', '--verify', '--strict', '--verbose=2', str(app)], check=True)
        # Never overwrite an earlier bundle; every completed build gets a new folder.
        destination = Path(tempfile.mkdtemp(prefix='build-', dir=output)) / app.name
        app.rename(destination)
        subprocess.run(['/usr/bin/codesign', '--verify', '--strict', '--verbose=2', str(destination)], check=True)
        print(destination)

if __name__ == '__main__':
    main()
