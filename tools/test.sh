#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
cd "$root"
mkdir -p checks
export CLANG_MODULE_CACHE_PATH="$root/.cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$root/.cache/swift"
swift test --disable-sandbox --cache-path "$root/.cache" --scratch-path "$root/.build"
PYTHONDONTWRITEBYTECODE=1 python3 tools/test-install.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/test-verification.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/test-config.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/test-model-provision.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/test-icon.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/test-diagnostic-comparison.py
./tools/grid-lint.sh
