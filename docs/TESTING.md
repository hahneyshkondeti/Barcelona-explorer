# Real-map verification — 2026-09-23

Godot 4.5 stable (`876b29033`), macOS on Apple M2 Pro; Forward+ and Mobile renderer paths exercised with Metal 3.2. **29 gameplay/geometry checks, 11 handling checks and 10 map/import/refresh checks passed.** This is desktop validation; no iOS build or device performance benchmark is claimed.

## Gameplay

`tests/smoke.gd` loads the actual imported scene and steps physics. It tests visible controls/minimap, acceleration, braking, reverse, both steering directions, mapped wall collision, camera obstruction, the snapshot boundary, ground stability, pause, keyboard input, simultaneous touch input and release, directed map routing and its alignment with road segments.

The end-to-end test drives the real car from the mapped start along Carrer de Mallorca to the Sagrada Família arrival point using a steering/throttle controller. It does not teleport to complete arrival. It verifies the discovery card, continue exploring, offline street-name search, provenance dates, nonmutating place filtering, selected-place routing, save restoration, settings, safe-road recovery and malformed-save fallback. Test saves are isolated from the player save. Headless audio generation is disabled; audio settings are still tested.

The controller test validates the first trip, not every intersection, turn restriction or possible collision. Physical iPhone multitouch, audio output and interruptions remain untested. Directions respect one-way tags, but imported turn-restriction relations and live traffic restrictions are not implemented.

## Handling refinement

`tests/handling.gd` exercises the controller at 30/60/120 Hz: stationary steering, progressive takeoff, tight low-speed turning, bounded lateral acceleration at cruising speed, recentering, braking distance, the delay before reverse, reverse steering and both-pedal braking. The full scene test additionally checks that a wall impact removes stored speed and still completes the physical drive to the landmark. These are automated behavior checks, not a subjective playtest or a real-vehicle simulation claim.

```sh
godot --headless --path . --script tests/handling.gd
```

## Future building-asset integration

Eleven checks in `tests/building_assets.gd` pass with an actual imported original glTF fixture: placement transforms, source credits, visual replacement without removing collision, missing/invalid assets, unknown or overlapping footprint IDs, mobile fallback and schema rejection. The production manifest is empty. The full 29-check gameplay suite passes with the adapter enabled. No real scan, scan alignment or scan performance is claimed.

## Municipal tree verification

Six checks in `tests/check_trees.py` passed: preserved coordinates, distinct IDs/provenance, park-only OSM fallback with municipal deduplication, reproducible source transformation, rejected invalid input and count consistency. The full 29-check scene suite passes with the new tree layer. Desktop captures were refreshed; the older `*-mobile.png` captures document the previous OSM-only tree layer. Tree shapes and heights remain illustrative and no field/photo verification has been performed.

## Data and refresh

`tests/check_map.py` validates real street names, per-place geographic projection, finite building rings/heights, connected routing nodes/edges, honest partial-address counts, presence of one-way data, projection scale, rejection of a truncated refresh, acceptance of unchanged geometry and reproducibility from the included source extract.

The refresh workflow was exercised end to end: download a staged snapshot, validate it, rebuild from staged source during promotion, apply it, then validate the resulting runtime database. The counts remained unchanged. It is developer-run, not an automatic weekly job or in-app update channel. Network errors preserve the active map. The update script uses system curl with normal TLS verification because this Mac's standalone Python trust store could not verify the remote certificate.

Current data: 1,048 building records; 540 place records (not necessarily unique businesses); 1,667 address records; 292 places with street + number; 2,930 road/path segments, of which 616 are routable. Some records may duplicate the same business or be outdated. OpenStreetMap is a community-maintained snapshot, not survey-certified completeness.

## Render inspection

`tests/capture.gd` produced and the agent inspected `driving.png`, `landmark.png`, `discovery.png`, and `places.png`: real street orientation, detailed façades/materials, minimap, driving controls, arrival text and address/source-date browser. The landmark overview uses an inspection camera; gameplay uses the chase camera. Screenshots are actual Godot renders.

The scene uses generic CC0 scanned asphalt and plaster materials, procedural tiled pavements and façade geometry, illustrative tower geometry, leaf-cutout tree clusters and original tapered car art. The appearance is not photogrammetry. No claim of matching individual real shopfronts is made.

The additional geometry regression checks that a 45-degree façade instance retains its intended width/depth and orthogonal axes. This catches the former world-axis scaling/shear bug. Desktop rendering enables SSAO and TAA; Mobile omits these and uses a hard sun to avoid noisy soft shadows without temporal filtering. `driving-mobile.png` is the Mobile renderer running on the Mac, **not an iPhone screenshot**. Metal emits a sampler LOD-bias support warning with desktop TAA; captures complete successfully. Mobile startup is free of renderer errors.

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
