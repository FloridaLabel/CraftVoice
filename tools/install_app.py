"""Transactional installation of an existing BeispielApp build. No signing or sudo."""
from pathlib import Path
import os
import plistlib
import shutil
import signal
import subprocess
import sys
import tempfile
from collections.abc import Callable

from project import load_config
CONFIG = load_config()
BUNDLE_ID = CONFIG['bundle_id']
APP_NAME = CONFIG['name']
EXECUTABLE = CONFIG['executable']
FINGERPRINT = 'C357A87EC48947E3C69F9C9925D7EE7FD34A1003'


class InstallError(RuntimeError):
    pass


def ensure_stopped() -> None:
    result = subprocess.run(['/usr/bin/pgrep', '-x', EXECUTABLE], capture_output=True, text=True)
    if result.returncode == 0:
        raise InstallError(f'{APP_NAME} läuft noch. Bitte alle Instanzen beenden und ./install.sh erneut ausführen. Es wird keine laufende App ersetzt.')
    if result.returncode != 1:
        raise InstallError('Laufende Prozesse konnten nicht zuverlässig geprüft werden. Installation abgebrochen.')


def bundle_id(app: Path) -> str:
    try:
        with (app / 'Contents/Info.plist').open('rb') as stream:
            info = plistlib.load(stream)
        return info.get('CFBundleIdentifier', '') if isinstance(info, dict) else ''
    except (OSError, ValueError) as error:
        raise InstallError(f'Bundle-ID von {app} konnte nicht gelesen werden; die App wird nicht ersetzt.') from error


def copy_app(source: Path, destination: Path) -> None:
    subprocess.run(['/usr/bin/ditto', str(source), str(destination)], check=True)


def install(source: Path, destination: Path, verify: Callable[[Path], None],
            stopped: Callable[[], None] = ensure_stopped,
            copy: Callable[[Path, Path], None] = copy_app,
            move: Callable[[Path, Path], None] = os.rename) -> None:
    """The CLI fixes destination to /Applications; tests pass isolated directories."""
    if source.is_symlink() or not source.is_dir():
        raise InstallError('Kein reguläres App-Bundle in dist/. Zuerst ./build.sh ausführen.')
    stopped()
    verify(source)  # Nothing under /Applications is changed until this succeeds.
    parent = destination.parent
    lock = parent / f'.{EXECUTABLE}.install-lock'
    try:
        lock.mkdir(mode=0o700)
    except FileExistsError as error:
        raise InstallError('Eine andere Installation läuft oder eine frühere Installation wurde unterbrochen. Sperrverzeichnis prüfen: ' + str(lock)) from error
    except PermissionError as error:
        raise InstallError('Keine Schreibrechte für ' + str(parent) + '. Es wurden keine Administratorrechte angefordert. Vor einer erneuten Installation die benötigte Berechtigung klären.') from error
    transaction = None
    preserve = False
    try:
        if destination.is_symlink() or (destination.exists() and not destination.is_dir()):
            raise InstallError('Das Installationsziel ist kein reguläres App-Verzeichnis; es wird nicht ersetzt.')
        if destination.exists() and bundle_id(destination) != BUNDLE_ID:
            raise InstallError('Die vorhandene App hat eine andere Bundle-ID; sie wird nicht ersetzt.')
        transaction = Path(tempfile.mkdtemp(prefix=f'.{EXECUTABLE}-install-', dir=parent))
        staged = transaction / 'new.app'
        backup = transaction / 'previous.app'
        copy(source, staged)
        verify(staged)  # Also rejects damaged or changed copies, before replacing anything.
        stopped()
        try:
            if destination.exists():
                move(destination, backup)  # Same filesystem: preserve the exact old bundle.
            stopped()  # Recheck after backup and immediately before publishing.
            move(staged, destination)
            verify(destination)
        except BaseException as error:
            try:
                if destination.exists() and not staged.exists():
                    # Never move a newly launched app, even during recovery.
                    stopped()
                    move(destination, staged)
                if backup.exists():
                    if destination.exists():
                        raise InstallError('Das Ziel wurde zwischenzeitlich verändert; Wiederherstellung kann es nicht sicher ersetzen.')
                    move(backup, destination)
            except BaseException as recovery_error:
                preserve = True
                raise InstallError(f'Installation fehlgeschlagen; automatische Wiederherstellung nicht möglich: {recovery_error}. Sicherung und Installationsdateien bleiben erhalten: {transaction}') from error
            raise InstallError(f'Installation fehlgeschlagen; vorheriger Zustand wiederhergestellt: {error}') from error
    finally:
        if transaction is not None and not preserve:
            try:
                shutil.rmtree(transaction)
            except OSError as error:
                # An installed or restored app is already intact. Retain diagnostics.
                print(f'Hinweis: Temporäre Dateien konnten nicht entfernt werden: {transaction}: {error}')
        try:
            lock.rmdir()
        except OSError as error:
            print(f'Hinweis: Installationssperre konnte nicht entfernt werden: {lock}: {error}', file=sys.stderr)


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    try:
        configured = CONFIG['signing_fingerprint']
        if configured != FINGERPRINT:
            raise InstallError('Die Signierkonfiguration entspricht nicht der freigegebenen Identität Craft Code Signing. Keine Installation.')

        def verify(app: Path) -> None:
            subprocess.run([str(root / 'tools/verify-signature.sh'), str(app), FINGERPRINT], check=True)

        def interrupted(number, _frame):
            raise InstallError(f'Installation durch Signal {number} unterbrochen.')

        for number in (signal.SIGTERM, signal.SIGHUP):
            signal.signal(number, interrupted)
        install(root / 'dist' / (APP_NAME + '.app'), Path('/Applications') / (APP_NAME + '.app'), verify)
        print(f'{APP_NAME} wurde erfolgreich nach /Applications/{APP_NAME}.app installiert.')
        return 0
    except (InstallError, OSError, subprocess.CalledProcessError, KeyboardInterrupt) as error:
        print(f'Installation abgebrochen: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
