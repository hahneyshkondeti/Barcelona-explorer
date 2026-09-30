# Migration status — 30 September 2026

## Preservation and scope

GitHub default: `main`, verified with remote symbolic HEAD. Active local Godot branch: `codex/mac-first`. Its previously staged and unstaged tracked application changes were committed together as `53fb555` before branching. No Godot source files were deleted or changed for the Unreal scaffold. Git history was not rewritten. Existing `/Applications/City Explorer.app` was left untouched. The Unreal branch and its inherited preservation commit are now pushed to `origin/unreal-migration`. The Godot branch remote was not updated. Upstream tracking is configured.

`unreal-migration` is checked out in `Explorer/UnrealMigration`. The original `Explorer` checkout remains on `codex/mac-first`. The Unreal project is `CityExplorer/CityExplorer.uproject` in the migration checkout. Both branches retain the Godot source and data. A separate checkout avoids disrupting normal Godot development.

## Current toolchain verification

Full Xcode 27.0 (27A266a) is now installed and selected at `/Applications/Xcode.app/Contents/Developer`. The host is arm64 and `xcrun --find metal` locates the Metal compiler. However, UE 5.5.4 rejects the detected Xcode version 27.0 against its 15.2.0–16.9.0 range in `Engine/Config/Apple/Apple_SDK.json`. Both renewed platform validation and the explicit `-architecture=arm64` editor build failed before project compilation. See the `*-resume.log` diagnostics. No compatible alternate Xcode was discovered.

Install a compatible Xcode side by side and pass its Developer path through `DEVELOPER_DIR` to `Tools/build_editor.py`. This avoids changing the default Xcode for other applications. The helper validates using Unreal itself and refuses to continue when Mac is INVALID, even though Unreal platform validation returns process exit code zero. No SDK bounds or compiler compatibility checks were bypassed.

## Original prerequisite failure (historical)

Installed engine: Unreal 5.5.4, changelist 40574608, Apple Silicon bundled .NET runtime. Only `/Library/Developer/CommandLineTools` is selected; no Xcode.app was found in Applications. Unreal platform validation reports `Mac INVALID`; the actual CityExplorerEditor build exits 6 with `Platform Mac is not a valid platform to build`. Unreal's local SDK diagnostic requires Xcode 15.2–16.9. Full compatible Xcode and its Metal tools must be installed, first-launch setup completed, and its Developer directory selected. Installing the current newest Xcode without checking that range may not resolve the UE 5.5 prerequisite.

No Unreal MCP tools are advertised in this session, and the Codex configuration inspected exposes no Unreal MCP connection. The installed client skill describes tools but does not itself establish an editor connection. An available live connection must be configured and verified with a read-only editor call before MCP asset work. No existing editor session was modified.

No editor launch, shader compilation, gameplay comparison, package or installed Unreal application is claimed. The module scaffold has not compiled. No binary assets have been generated.

## Source architecture discovered

The single main scene is a Node3D with `main.gd`; most content is created at runtime. No project-config autoloads or packaged Godot add-ons are configured. Runtime networking is optional Google Places New autocomplete/details; map generation/refresh downloads occur in separate developer tools. Barcelona is the only supported city and the touring car the only supported vehicle. Offline behavior is part of the product requirement.

| Godot source | Unreal destination and responsibility |
| --- | --- |
| main.gd | GameMode for world startup; PlayerController for pause/input/UI coordination; application session subsystem for onboarding state. Avoid one coordinator owning all business logic. |
| app_session.gd | GameInstanceSubsystem with typed screen state, selected city/place/vehicle and event delegates. |
| app_catalog.gd | City and vehicle PrimaryDataAssets; supported city bounds, spawn metadata and configurable Pawn classes. |
| district.gd | Split immutable map repository, spatial road index, tile ownership resolver and safe-spawn service. GameInstanceSubsystem owns persistent data; WorldSubsystem owns active tiles. |
| terrain_data.gd | Shared terrain sampler loading little-endian float32 data and masks; use the same triangle diagonal for visual terrain, collision and safe-spawn checks. |
| navigation.gd | Directed road graph service; preserve one-way edges, partial-edge endpoint costs, unreachable routes and route trimming within the first 160 m. |
| address_search.gd | Offline search service with accent normalization, address-range matching, tolerant street suggestions and bounded tile cache; retain transit/public-square records. |
| services/place_search_service.gd | HTTP service subsystem, typed results, asynchronous cancellation/request generations, timeout and offline fallback. Runtime environment key only; no credential in source, assets or logs. |
| car.gd | Configurable Pawn with reusable movement component and swept collision. Preserve arcade handling rather than silently replacing it with materially different Chaos handling. Blueprint configures mesh, wheel visuals and lights. |
| drive_input.gd | Enhanced Input actions and mapping context, with UI-to-controller touch input. Clear held input on pause/focus loss. |
| chase_camera.gd | SpringArm/Camera components with obstruction checks, damping and reset. Preserve 60-degree FOV and camera behavior. |
| world_builder.gd | World tile streaming subsystem and tile renderer actors; async data preparation, budgeted game-thread mesh/collision submission, shared materials and instancing. Do not spawn an Actor per tree/building detail. |
| terrain_world.gd | Streamed terrain renderer and collision patches, coast/sea renderer and distant terrain. |
| street_furniture.gd | Instanced transit/sign components with source names, bounded labels and existing placement corrections. |
| street_lights.gd | Instanced lamp fixtures plus capped eight-light pool; dusk intensity from shared solar state. |
| public_spaces.gd | Configurable procedural feature builders for Catalunya and Espanya; retain island/basin collision and mapped ownership. |
| building_assets.gd | Validated engine-neutral placement/provenance adapter; Unreal static meshes and configurable replacement registry. Reject overlapping IDs and unsafe paths. |
| solar_cycle.gd | One-second timer-driven solar system using UTC NOAA approximation and mapped observer coordinates. Feed lighting/material parameters; avoid per-frame CPU updates. |
| engine_audio.gd | Procedural audio/MetaSound component parameterized by speed, mute and pause. There is no source engine recording to import. |
| landmarks.gd | Arrival component/service with speed/radius conditions, discovery state and dismissal cooldown. |
| hud.gd, ui/onboarding_flow.gd, ui/design_system.gd | UMG widget Blueprints and reusable C++ view models; keep business logic in services. Home → City → Location → Car → Explore, pause/settings/arrival overlays. |
| minimap.gd, city_map.gd | Map UMG widgets drawing shared road/route data; heading-up and north-lock, compass, zoom/pan and checked map selection. |
| save_store.gd | Versioned SaveGame in separate Unreal storage. Preserve Godot user data. Optional legacy JSON reader must validate schema, terrain and roads before importing. |

Projection: Godot map x is east, z is south, y is elevation in metres. Use Unreal X=east, Y=south, Z=up in centimetres. Convert `(x,y,z)` to `(100*x,100*z,100*y)`; derive vehicle yaw from converted forward vectors rather than copying Godot Euler angles. Validate winding/normals, bounds, metric thresholds and heading on known anchors.

The current dataset spans roughly 14.7 × 16.8 km. Runtime uses 192 m cells, nearby 5×5 tiles plus ownership dependencies, synchronous collision-critical neighbors and incremental farther construction. Keep reusable road/places indexes resident, unload distant tile data, and prevent driving into unready collision. Large coordinate precision and streaming need profiling in Unreal; a blank generic level is not feature parity.

## Assets and configuration

Compatible JPG/PNG textures and original icons remain intact; imports are pending. Original procedural cars, basilica, square monuments, furniture and terrain must be regenerated as Unreal meshes/components. Godot shaders require Unreal materials; they cannot be imported as working materials. The building-asset manifest is empty; `_test_only/triangle.gltf` is a test fixture, not a real building asset. No replacement art has been created or substituted.

Retain ASSET_LICENSES.md and data/LICENSE.md attribution: OSM/ODbL, municipal tree/terrain CC BY notices, lamp survey notice and source texture attribution. Runtime bundle staging must copy the necessary derived data and notices into the Unreal project and include it in cooked distribution. No data staging rule is enabled before a real consumer exists.

Use CITY_EXPLORER_GOOGLE_PLACES_API_KEY only at runtime. Finder launch does not inherit ordinary shell variables; offline mode must remain fully usable. Public release proxy configuration remains a deployment decision. Keep Unreal save paths and bundle identity distinct from Godot so both apps run independently.

## Validation checklist

All Unreal gameplay entries are pending implementation; these are requirements, not passed comparisons.

| Feature | Godot behavior | Unreal behavior | Status | Differences / known issues |
| --- | --- | --- | --- | --- |
| Startup | Home → City → Location → Car → Explore | Not implemented | Pending | No UMG assets |
| Catalogs | Barcelona and touring car | Not implemented | Pending | No DataAssets |
| Search | Offline places/addresses/transit/squares; optional Google Places | Not implemented | Pending | API requests untested |
| Spawn | Bounded selection projected to connected safe road | Not implemented | Pending | Unsafe raw coordinate spawning must be rejected |
| Vehicle | 150 km/h, progressive throttle, speed-sensitive steering, 0.35 s reverse delay | Not implemented | Pending | No Pawn/movement component |
| Camera | Damped chase, obstruction checks, C reset | Not implemented | Pending | No camera components |
| World | Procedural offline city and ownership-aware streaming | Not implemented | Pending | No renderer or map level |
| Terrain/coast | Shared 6 m grid, slopes, collision, sea and distant hills | Not implemented | Pending | No meshes or materials |
| Transit/signs/squares | Corrected placement, source labels, fountains and basin collision | Not implemented | Pending | Source data retained only |
| Navigation | Directed route, partial edges, trimming, arrival discovery | Not implemented | Pending | No road graph service |
| Lighting/audio | UTC solar, dusk lamps/headlights, generated engine sound | Not implemented | Pending | No lighting/audio assets |
| HUD/maps/settings | Compact HUD, heading/north map, sound/FPS/theme preferences | Not implemented | Pending | No widgets |
| Persistence | Safe-road journey JSON, local preferences | Not implemented | Pending | Godot save untouched |
| Pause/recover/focus | Pause and clear controls, recover safe position, focus-loss pause | Not implemented | Pending | No PlayerController |
| Mac editor/build | Working Godot installed application preserved | C++ scaffold only | Blocked | Xcode 27.0 exceeds UE 5.5.4 supported range; arm64 compile exits 6 |
| Packaged independent app | Existing /Applications/City Explorer.app | No Unreal app | Blocked | Package to separate Unreal folder after validation |

## Next execution milestone

1. Resolve compatible full Xcode/Metal setup and establish live Unreal MCP connection.
2. Compile the existing module scaffold and create bootstrap level, native gameplay classes and Blueprint configuration.
3. Implement map repository, shared terrain sampler, safe spawn and directed routing with fixture checks against Godot.
4. Add async tile preparation, terrain/road/building collision, vehicle/Enhanced Input and camera; validate a continuous drive across tile boundaries before expanding detail.
5. Implement UMG onboarding/search/HUD/settings/persistence and optional API adapter.
6. Recreate materials, procedural visual assets, squares, transit, solar and audio; import compatible textures with attribution.
7. Compare all flows, profile on this Mac, cook/package, then place `City Explorer.app` in a separate Unreal installation folder. Never replace the existing Godot app.

Commit each verified system milestone. Do not label migration complete before the comparison checklist and independent packaged launch pass.
