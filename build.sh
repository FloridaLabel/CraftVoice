#!/bin/zsh
set -euo pipefail
here=${0:A:h}
exec python3 "$here/tools/build.py" "$@"
