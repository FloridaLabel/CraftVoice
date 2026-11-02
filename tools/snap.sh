#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
cd "$root"
executable=$(python3 -c 'import json; print(json.load(open("project.json"))["executable"])')
name=$(python3 -c 'import json; print(json.load(open("project.json"))["name"])')
./tools/verify-signature.sh
for mode in light dark; do
    APP_SNAPSHOT="$root/checks/screenshots" APP_APPEARANCE="$mode" "$root/dist/$name.app/Contents/MacOS/$executable"
done
swift -module-cache-path "$root/.cache/swift" tools/check-layout.swift checks/screenshots/*-layout.json
