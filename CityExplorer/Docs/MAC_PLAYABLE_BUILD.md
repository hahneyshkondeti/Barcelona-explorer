# Playable Mac development build

The Unreal version is installed separately at `/Applications/City Explorer Unreal.app`. Double-click it in Applications. It is an Apple Silicon arm64 development build using Unreal Engine 5.8.3 and Xcode 27. The existing `/Applications/City Explorer.app` and Godot checkout remain unchanged.

Controls: W/up for throttle, S/down/space for braking and reverse, A/D or left/right for steering, P/Escape for pause, R for safe recovery, C to reset the camera.

## Validation

The signed staged app was launched outside Unreal Editor using both NullRHI and the native Metal renderer. Both completed the actual Barcelona Chaos simulation with `CITY_EXPLORER_PHYSICS_SUCCESS`. The installed copy is checked separately from its final Applications location. Signature verification uses `codesign --verify --deep --strict`.

A locked Mac prevented the latest visible mouse/menu, wheel-animation and sustained-driving checks. The build is a playable development milestone, not the finished visual-quality upgrade. Terrain and road geometry/materials remain the existing migration baseline. Live Google API behavior, broad collision/camera testing and performance profiling remain pending.

## Packaging

`Tools/package_mac.py` builds the native executable, then cooks and stages a self-contained signed app outside Documents. Unreal's supported `UE_BUILD_FROM_XCODE=1` build path defers app finalization to the subsequent Xcode staging step. This avoids Finder metadata interfering with signing inside Documents. No engine source, signing requirements or security protections are modified.

For this build the verified source was `/private/tmp/CityExplorerStage/Mac/CityExplorer.app`. The additional native archive copy was invalid and is not installed or considered a validated artifact. Installation copies the complete verified staged bundle without Finder metadata; the application folder is renamed to distinguish it from Godot.
