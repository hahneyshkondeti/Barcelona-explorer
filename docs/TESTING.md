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

## Streaming optimization — 24 September 2026

Local regression suites passed: 29 gameplay, 42 city, 11 handling, 11 future-building-asset integration, 10 streaming/navigation and 8 Python city-data checks (111 total). Import completed successfully after correcting shader resource ownership. The new streaming test covers interruption by recovery and preserves collision geometry. Both the city test and rendered benchmark now drain pending construction before teardown; the final local runs exit without coroutine leak warnings.

A single controlled before/after rendered drive on Apple M2 Pro, Godot 4.5, desktop Forward+ / Metal, 1280×720, 60 FPS cap: 120 stationary warm-up frames then 720 frames accelerating along the introductory road and crossing a streaming boundary. Previous code: `6a27cf8`; optimized code: `efac21b`. Both use the same offline map and rendering configuration. This measures frame intervals, including rendering and scheduling, not just geometry CPU time.

| Frame measure | Previous | Optimized |
| --- | ---: | ---: |
| Median | 16.653 ms | 16.642 ms |
| 95th percentile | 29.070 ms | 28.130 ms |
| 99th percentile | 184.355 ms | 31.683 ms |
| Maximum | 329.098 ms | 93.089 ms |
| Frames over 50 ms | 13 | 2 |
| Frames over 100 ms | 13 | 0 |

Reproduce with `Godot --path . --script tools/benchmark_drive.gd` using a graphical session; never use `--headless` for this frame comparison. It uses a disposable save and does not overwrite the player's journey. Close other running game instances first. These are one-run desktop measurements, not a comprehensive benchmark or an iPhone FPS guarantee. The remaining stalls, initial city index load, synchronous district jumps, JSON decoding and individual physics/mesh uploads still need device profiling. The 2.5 ms construction budget is cooperative, not a hard frame-time ceiling.

GitHub run [35929020609](https://github.com/hahneyshkondeti/Barcelona-explorer/actions/runs/35929020609) passed all 111 checks on `macos-26` and compiled the unsigned arm64 iPhone app using Xcode 26.6 (17F113). Post-build validation confirmed bundle `com.hahneyshkondeti.brisa`, build `2`, minimum iOS `16.0`, iPhone-only landscape configuration, bundled city data, app icon and one privacy manifest with no tracking/collected-data declarations. The run contains no ObjectDB leak warning or GDScript errors. [Download the Xcode project](https://github.com/hahneyshkondeti/Barcelona-explorer/actions/runs/35929020609/artifacts/10780366238); artifact retention is seven days. Signing, installing on an actual iPhone and uploading to App Store Connect remain untested and parked.

## Expanded map, address starts and street labels

The new `tests/exploration.gd` integration suite passes 17 checks covering the user's misspelled/accent-free address query, truthful address ranges, missing house numbers, pause behavior, reversible map coordinates, pointer-anchored zoom, map preview, drag versus tap, safe launch, save persistence, address launch, invalid coordinates, full named-street coverage, cross-tile duplicate suppression and lossless multi-line names. The existing 29-check gameplay suite also passes. City validation now checks that every named address record is included in the offline street-to-tile index and that overview geometry covers the routing dataset (9 Python checks).

Actual rendered UI captures: `expanded-map.png`, `expanded-map-detail.png`, `address-start.png`, and `street-labels.png`. Reproduce with `Godot --path . --script tests/exploration.gd -- --capture`. The address example resolves to the existing OSM range `Carrer de Gretel Ammann Martínez 16-12`; no single-door location is fabricated. The map uses a 2048px overview loaded on demand plus vector roads and non-overlapping street labels at close zoom. Search retains at most eight address tile payloads and is debounced while typing. Normal street labels remain culled at 55 metres and are constructed within the existing streaming budget.

## Minimap orientation

The exploration suite now passes 24 checks, including heading-up and north-up transforms at all four cardinal headings, switching mode without pausing, and saved north-lock preference restoration. In heading-up mode all map geometry, route points and destination markers use the same rotation; the car arrow stays forward and N indicates geographic north. The expanded selection map remains north-up. Saves without the new optional `north_locked` field default to heading-up.

### Transit and traffic furniture

`python3 tests/check_infrastructure.py` checks transit tag semantics, source-coordinate preservation, stop-area names, polygon/pole deduplication, envelope filtering, and estimated roadside offsets. `tests/check_city.py` validates every shipped infrastructure record and its cell ownership. `Godot --headless --script tests/infrastructure.gd` checks runtime tile attachment, transit search, geometry reuse, bounded labels, and the absence of fabricated entrances at underground station centers. CI runs these alongside the existing driving/exploration suites.

Current local checks: 10 city data checks, 2 importer fixture tests, 14 infrastructure checks, 24 exploration checks, 10 streaming/performance checks, and 42 full-city checks pass (102 total). These are functional checks, not a physical-iPhone FPS measurement.
