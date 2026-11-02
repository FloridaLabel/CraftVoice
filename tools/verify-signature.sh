#!/bin/zsh
set -euo pipefail
here=${0:A:h}
exec python3 "$here/verify_signature.py" "$@"
