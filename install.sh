#!/bin/zsh
set -euo pipefail
here=${0:A:h}
if (( $# )); then
    [[ "$1" == --help && $# == 1 ]] || { echo 'Aufruf: ./install.sh' >&2; exit 2; }
    echo 'Installiert die geprüfte App nach /Applications. Baut und signiert nichts; kein sudo.'
    exit 0
fi
exec python3 "$here/tools/install_app.py"
