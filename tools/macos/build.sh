#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
godot="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
app_dir="${MAC_BUILD_DIR:-/tmp/city-explorer-macos}"
app="$app_dir/City Explorer.app"
mkdir -p "$app_dir"
mkdir -p "$root/build/macos"
"$godot" --headless --path "$root" --editor --import --quit
"$godot" --headless --path "$root" --export-release macOS "$app"
# Local installation: ad-hoc signing needs no certificate or Apple credentials.
# Public distribution needs Developer ID signing and notarization instead.
# Remove only Finder/resource-fork metadata from our generated bundle. Leave
# quarantine/security attributes untouched; do not alter system security settings.
python3 - "$app" <<'PYATTR'
import pathlib,subprocess,sys
root=pathlib.Path(sys.argv[1])
for path in [root,*root.rglob('*')]:
    names=subprocess.check_output(['xattr',str(path)],text=True).splitlines()
    for name in ('com.apple.FinderInfo','com.apple.ResourceFork'):
        if name in names: subprocess.run(['xattr','-d',name,str(path)],check=True)
PYATTR
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
python3 "$root/tools/macos/check_bundle.py" "$app"
ditto -c -k --keepParent "$app" "$root/build/macos/CityExplorer-Mac.zip"
printf 'Built %s\n' "$app"
