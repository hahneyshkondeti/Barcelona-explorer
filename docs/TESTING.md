# Barcelona city verification — 2026-09-23

Godot 4.5 stable (`876b29033`) on an Apple M2 Pro Mac. These checks validate the desktop prototype and renderer paths, not a physical iPhone build, iPhone frame rate or complete geographic survey.

## Full-city checks

`tests/city.gd` performs 42 checks: all ten districts exist; each district jump lands on a safe connected street; each has a directed route from the original start; tile residency follows the selected neighborhood and releases the previous one; the spatial nearest-road result agrees with exhaustive geometry; and the car physically drives across a streaming-cell boundary without falling. District points come from the municipal inventory, not fabricated landmarks.

`tests/check_city.py` performs eight checks across the complete shipped tile set: municipal envelope inclusion, all ten district codes, connected graph and valid edges, valid tile ownership references, payload/count consistency, no duplicated tree IDs, finite footprints, preserved introduction coordinates, and refresh rejection of truncated data or changed coverage. The complete manifest references 5,744 tiles; the renderer loads only nearby ownership tiles.

The dataset contains 104,694 building records, 502,007 source road/path segments (126,836 routable), 20,576 places, 136,853 addresses, 930 park polygons, 144,957 municipal street trees and 13,258 deduplicated OSM park-tree records. Place/address counts describe records, not independently verified active businesses.

## Gameplay and future assets

The existing 29-check `tests/smoke.gd` passes against the city: acceleration, braking/reverse, both steering directions, mapped wall collisions and impact speed, camera obstruction, ground/boundary behavior, pause, keyboard/multitouch state, directed navigation, the physical Sagrada arrival drive, discovery/continue, place search and source dates, route selection, save/settings reload, safe recovery and malformed-save fallback.

The 11-check `tests/building_assets.gd` passes against the city's footprint index and local tile data. It loads an actual original glTF fixture and checks georeferencing, credits, preserved collision, suppression of procedural visuals, rejection/fallback for missing scenes or provenance, bad transforms, unknown/overlapping IDs, missing mobile variants and invalid schema. The production building asset manifest remains empty.

The unchanged 11 handling checks cover progressive takeoff, stationary/tight/speed-limited steering, recentering, braking distance, reverse delay/direction, both-pedal braking and 30/60/120 Hz step consistency. Original pilot data remains as a regression fixture; its 10 importer/map checks still pass after making optional detailed tree records available to the city builder.

## Render and packaging

`tests/capture.gd` captures the original driving area, landmark/card/place UI, a distant Sant Martí street and the district selector. The desktop renderer is Forward+ using Metal. Mobile renderer captures run on this Mac; they are not iPhone screenshots. The known desktop Metal sampler LOD-bias warning with TAA remains; it is not a failed render.

The iOS preset exports `build/Brisa.pck` successfully, approximately 340 MiB, with the city manifest and tile JSON included and source archives, old pilot runtime files and test fixtures excluded. This is a resource pack, not a signed iOS executable or Xcode device build.

## Reproduction

```sh
python3 tests/check_city.py
python3 tests/check_map.py
godot --headless --path . --fixed-fps 60 --script tests/smoke.gd
godot --headless --path . --fixed-fps 60 --script tests/city.gd
godot --headless --path . --script tests/building_assets.gd
godot --headless --path . --script tests/handling.gd
```

The city was built from the downloaded bulk extract, then rebuilt from the included bounded source. `refresh_city.py --check` was exercised. The validated city/source bundle was staged with hashes and promoted using `--apply`; this tested the promotion path with unchanged data. A second network download via the new wrapper was not necessary and was not performed. Staging/promotion checks reject unexpected counts, coverage and changed file hashes. The original small-map refresh pipeline is retained for pilot regression and does not update the active city.

## Practical limitations to verify next

The global routing/places index remains in memory. Nearby geometry generation/JSON loading happens on the main thread and may cause startup, transition or district-jump hitches. The optional frame cap does not prove sustained frame rate. No Instruments memory/thermal benchmark or iPhone 11 frame-time measurement has been performed.

Terrain/coastline, grade-separated roads and surveyed collision shapes are incomplete. Tunnels and nonzero road layers are excluded; private/pedestrian-only and disconnected roads are not routed. Full road-law compliance, every intersection, every street and every municipal boundary segment have not been playtested. Large imported scans still need alignment checks and mobile optimization.

Physical-device acceptance still requires full Xcode, Godot iOS templates and signing, then safe-area/touch tests, app interruptions, airplane-mode cold launch, save recovery, long drives across tile boundaries, repeated district jumps, sound, memory pressure and thermal profiling. The iPhone 11/iOS 16/30 FPS baseline remains an unverified target.
