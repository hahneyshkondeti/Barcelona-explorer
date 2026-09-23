# Real-map verification — 2026-09-23

Godot 4.5 stable (`876b29033`), macOS on Apple M2 Pro; Compatibility renderer (OpenGL 4.1 Metal). **27 gameplay checks and 10 map/import/refresh checks passed.** This is desktop validation; no iOS build or device performance benchmark is claimed.

## Gameplay

`tests/smoke.gd` loads the actual imported scene and steps physics. It tests visible controls/minimap, acceleration, braking, reverse, both steering directions, mapped wall collision, camera obstruction, the snapshot boundary, ground stability, pause, keyboard input, simultaneous touch input and release, directed map routing and its alignment with road segments.

The end-to-end test drives the real car from the mapped start along Carrer de Mallorca to the Sagrada Família arrival point using a steering/throttle controller. It does not teleport to complete arrival. It verifies the discovery card, continue exploring, offline street-name search, provenance dates, nonmutating place filtering, selected-place routing, save restoration, settings, safe-road recovery and malformed-save fallback. Test saves are isolated from the player save. Headless audio generation is disabled; audio settings are still tested.

The controller test validates the first trip, not every intersection, turn restriction or possible collision. Physical iPhone multitouch, audio output and interruptions remain untested. Directions respect one-way tags, but imported turn-restriction relations and live traffic restrictions are not implemented.

## Data and refresh

`tests/check_map.py` validates real street names, per-place geographic projection, finite building rings/heights, connected routing nodes/edges, honest partial-address counts, presence of one-way data, projection scale, rejection of a truncated refresh, acceptance of unchanged geometry and reproducibility from the included source extract.

The refresh workflow was exercised end to end: download a staged snapshot, validate it, rebuild from staged source during promotion, apply it, then validate the resulting runtime database. The counts remained unchanged. It is developer-run, not an automatic weekly job or in-app update channel. Network errors preserve the active map. The update script uses system curl with normal TLS verification because this Mac's standalone Python trust store could not verify the remote certificate.

Current data: 1,048 building records; 540 place records (not necessarily unique businesses); 1,667 address records; 292 places with street + number; 2,930 road/path segments, of which 616 are routable. Some records may duplicate the same business or be outdated. OpenStreetMap is a community-maintained snapshot, not survey-certified completeness.

## Render inspection

`tests/capture.gd` produced and the agent inspected `driving.png`, `landmark.png`, `discovery.png`, and `places.png`: real street orientation, detailed façades/materials, minimap, driving controls, arrival text and address/source-date browser. The landmark overview uses an inspection camera; gameplay uses the chase camera. Screenshots are actual Godot renders.

The scene uses generic CC0 plaster material, procedural façade geometry, illustrative tower geometry, simple trees and original car art. The appearance is not photogrammetry. No claim of matching individual real shopfronts is made.

## Offline packaging

The iOS preset successfully produced `build/Brisa.pck`, including the runtime JSON, shaders and material textures. This is a Godot resource pack, not an iOS executable, signed IPA or Xcode device build.

## Remaining physical-device checks

- Full Xcode + matching Godot iOS export templates + signing, then run on iPhone 11/iOS 16 or later.
- Landscape safe areas, physical multitouch, text readability and button reach.
- Manual complete drive and routes to several shops; buildings/corners and all perimeter edges.
- Background while holding pedals, resume without stuck controls, terminate/relaunch and check saves.
- Airplane Mode cold launch and complete sightseeing loop.
- Instruments/Godot profiling over 10–15 minutes: startup time, memory, thermals, battery and 33.3 ms frame budget. Evaluate the optional 60 FPS cap separately.
- Check real-device sound and interruptions.

The denser scene is more demanding than the original grid. The iPhone 11 / 30 FPS baseline remains an unverified target.
