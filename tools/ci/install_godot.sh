#!/bin/bash
set -euo pipefail
# Official binaries, pinned to the release's SHA-512 checksums in this repo.
root="$(cd "$(dirname "$0")/../.." && pwd)"
staging="${RUNNER_TEMP:-/tmp}/brisa-godot-ci"
mkdir -p "$staging"
cd "$staging"
assets=(Godot_v4.5-stable_macos.universal.zip)
if [ "${1:-ios}" = ios ]; then assets+=(Godot_v4.5-stable_export_templates.tpz); fi
for asset in "${assets[@]}"; do
  curl --fail --location --retry 3 --output "$asset" "https://github.com/godotengine/godot-builds/releases/download/4.5-stable/$asset"
  expected=$(awk -v name="$asset" '$2 == name {print $1}' "$root/tools/ci/godot.sha512")
  test -n "$expected"
  printf '%s  %s\n' "$expected" "$asset" | shasum -a 512 -c -
done
unzip -q -o Godot_v4.5-stable_macos.universal.zip
if [ "${1:-ios}" = ios ]; then
mkdir -p "$HOME/Library/Application Support/Godot/export_templates/4.5.stable"
unzip -p Godot_v4.5-stable_export_templates.tpz templates/ios.zip > "$HOME/Library/Application Support/Godot/export_templates/4.5.stable/ios.zip"
fi
printf '%s\n' "$staging/Godot.app/Contents/MacOS" >> "$GITHUB_PATH"
