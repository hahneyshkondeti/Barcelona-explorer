# Migration status — 30 September 2026

## Preservation and scope

GitHub default: `main`, verified with remote symbolic HEAD. Active local Godot branch: `codex/mac-first`. Its previously staged and unstaged tracked application changes were committed together as `53fb555` before branching. No Godot source files were deleted or changed for the Unreal scaffold. Git history was not rewritten. Existing `/Applications/City Explorer.app` was left untouched. The Unreal branch and its inherited preservation commit are now pushed to `origin/unreal-migration`. The Godot branch remote was not updated. Upstream tracking is configured.

`unreal-migration` is checked out in `Explorer/UnrealMigration`. The original `Explorer` checkout remains on `codex/mac-first`. The Unreal project is `CityExplorer/CityExplorer.uproject` in the migration checkout. Both branches retain the Godot source and data. A separate checkout avoids disrupting normal Godot development.

## Current toolchain verification

Upgraded the existing project to Unreal 5.8.3 (CL 58210709), regenerated its Xcode workspace and compiled CityExplorerEditor for arm64 using Xcode 27.0 and Mac SDK 27.0. Mac validation is VALID. Installed the optional Xcode Metal Toolchain through Apple's component downloader. The editor opens the existing project and initializes Metal SM6 on the M2 Pro. See UE58_UPGRADE.md for upgrade details. Historical UE5.5 failures are retained in BuildDiagnostics.

## Implemented foundation

Native GameMode and PlayerController coordinate the application. GameInstance subsystems own immutable geographic data, screen state, preferences and optional Google Places requests. A WorldSubsystem owns procedural tile actors. A reusable movement component preserves the existing arcade handling and uses Enhanced Input assets configured in the touring car Blueprint. A native UMG view subscribes to service events rather than owning search or world logic.

Automation passes: handling (speed, braking, reverse delay, steering and frame-rate consistency), terrain triangle interpolation, offline road/address loading, bounded spawn and tile dependencies. Native Mac runtime validation completed Home → Barcelona → offline search → location → car → exploration and keyboard pause. A procedural winding issue discovered during rendering validation is being corrected. Driving collision and sustained tile-boundary driving remain under validation.

Offline staging copies preserved data and attribution into an ignored Content mirror; rerun Tools/stage_offline_data.py before cooking. Tools/bootstrap_assets.py creates the Blueprint configuration, Enhanced Input assets, vertex-color material and Barcelona level idempotently. Google Places uses the runtime environment key, cancellation generations, timeout and offline fallback; live authenticated requests remain untested.

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

| Feature | Godot behavior | Unreal behavior | Status | Differences / known issues |
| --- | --- | --- | --- | --- |
| Startup | Home → City → Location → Car → Explore | Same stages in native UMG | Runtime checked | Styling and mouse interaction need further validation |
| Search | Offline addresses/places/transit/squares and Google | Addresses/places plus optional HTTP adapter | Partial | Fuzzy suggestions, transit and squares pending; live API untested |
| Spawn | Connected, bounded road with terrain height | Map subsystem performs checked projection | Automated pass | Height clearance adjusted for Unreal road collision |
| Vehicle | Arcade handling and procedural touring car | Movement component, Enhanced Input, Blueprint configuration | Core tests pass | Sustained driving validation and final car visuals pending |
| Camera | Damped chase, obstruction, reset | SpringArm/Camera | Implemented | Obstruction comparison pending |
| World | Terrain, roads, buildings and rich street detail | Streamed procedural terrain/road/building mesh actors | Partial | Winding correction, async construction and detailed assets pending |
| Navigation/maps | Directed routing, minimap, expanded map, arrival | Not yet implemented | Pending | Required before parity |
| Lighting/audio | Solar cycle, street lamps, headlights, generated engine | Basic level light/sky | Pending | Dynamic lighting/audio pending |
| Settings/save | Sound/FPS/theme and safe journey | Separate versioned Unreal SaveGame, FPS/theme state | Partial | Audio and journey resume comparison pending |
| Pause/recover/focus | Clear held input and recover | Controller plus focus delegate | Keyboard pause checked | Recovery and focus tests pending |
| Mac toolchain/editor | Preserved working Godot app | UE5.8.3 arm64 module, editor and standalone development session | Passed | Independent packaged app pending |
| Installed application | /Applications/City Explorer.app | No installed Unreal app yet | Pending | Must use separate Unreal location |

Migration is not complete. Continue driving/rendering validation, implement navigation/maps, richer world visuals, lighting/audio and remaining UI/persistence behavior, then compare and package a separate native macOS app. Commit verified milestones and push origin/unreal-migration. Never replace the Godot application.
