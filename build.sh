#!/bin/zsh
set -euo pipefail
here=${0:A:h}
if [[ "${1:-}" == --local-signed ]]; then
    shift
    exec python3 "$here/tools/build.py" "$@"
fi
exec python3 "$here/tools/developer_build.py" "$@"
