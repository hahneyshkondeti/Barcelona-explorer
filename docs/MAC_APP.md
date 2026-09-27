# City Explorer for Mac

Development branch: `codex/mac-first`. Standalone Godot 4.5 app, universal Apple Silicon + Intel executable, macOS 12+ export target. Tested locally on Apple M2 Pro; Intel and other macOS versions are untested. Uses the desktop Forward+ renderer and existing offline city. No Godot installation is needed to play the exported app.

## Build

Install Godot 4.5 and its official macOS export template. From the repository:

```sh
bash tools/macos/build.sh
```

Use `GODOT_BIN=/path/to/Godot` to override the editor location. Output: `/tmp/city-explorer-macos/City Explorer.app` (override its directory with `MAC_BUILD_DIR`) and `build/macos/CityExplorer-Mac.zip`. The app is built outside the iCloud-synced Documents folder to prevent Finder metadata from breaking code signing. The build verifies metadata, universal architecture and local signature. The `Mac application` GitHub workflow builds the same ZIP on branch pushes and tests the packaged app outside the checkout.

The app is ad-hoc signed for local use. Public friction-free distribution needs Developer ID signing and notarization; this is not an App Store submission. No Apple account credentials are used or stored.

## Play

Open `/Applications/City Explorer.app`, or search **City Explorer** in Spotlight. WASD/arrows drive, brake held at rest reverses, R recovers the car, C resets the camera, P/Escape pauses. Onscreen driving controls and map/address search remain available. The native window can enter fullscreen using its green window button; Command-Q quits.

Local saves remain under `~/Library/Application Support/Godot/app_userdata/City Explorer/`, shared with the editor version. Avoid running two copies while driving, because both write the same save. Earlier Brisa saves are migrated when no City Explorer save exists.

This packages the current game. Real building scans and weekly downloadable asset updates remain future work described in `REAL_BUILDINGS_RESEARCH.md`.

## Icon

`assets/city-explorer-icon.png` is the exact user-supplied image `ChatGPT Image 28 Sept 2026, 01_18_00.png`, selected on 2026-09-28. The artwork is unchanged; Godot generates the required macOS icon sizes during export. It replaces the previous generated icon.
