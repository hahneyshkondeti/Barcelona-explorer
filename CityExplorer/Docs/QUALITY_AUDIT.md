# Unreal quality audit — 1 October 2026

Baseline: existing CityExplorer project, UE5.8.3, Apple M2 Pro, Xcode27.0, origin/unreal-migration milestone f31c8d7. Godot is the behavioral reference, not the visual target. Preserve onboarding, search and safe-spawn services while replacing prototype simulation and rendering. No project recreation or Godot changes.

## Findings

| Area | Existing implementation | Consequence | Decision |
| --- | --- | --- | --- |
| Vehicle simulation | APawn + custom UPawnMovementComponent, fixed-step speed/yaw formulas, swept box, prescribed terrain Z | No suspension, wheel loads, tire friction, mass, inertia, physical body roll or realistic impacts. Ground-following masks road/terrain collision errors. | Replace driving with Chaos Wheeled Vehicles. Keep reusable input and spawn services. Retain custom handling only as a historical behavioral test reference. |
| Vehicle asset | Engine cube currently displayed; original procedural car exported to glTF | Collision dimensions are plausible but visual body/wheels are placeholders | Reuse touring car geometry, add a root/four-wheel skeletal rig and physics asset, tune mass/center of gravity and suspension in vehicle data. Improve paint/glass/tire PBR materials. |
| Camera | SpringArm850cm, focus170cm, FOV60, positional lag6 and obstruction probe | Native foundation, but no rotation lag, speed response or acceleration/braking response | Retain SpringArm/Camera; tune after physics, test obstruction and transitions. |
| Roads | Independent terrain-draped strips subdivided6m, one vertex-color material shared with all city geometry; pavement wider by1.5m | Strip overlap at nodes, no road topology/junction blend, markings, curbs, PBR normals, camber, shoulders or dedicated surface collision | Build a topology-aware spline road service with distinct road/pavement/curb/marking sections, metric UVs and shared PBR material instances. Resolve intersections once per junction and prevent overlapping coplanar surfaces. |
| Terrain | Correct centimetre conversion and source6m triangle sampler; per192m tile procedural mesh | Bare-earth source lacks bridge/tunnel decks; no distant terrain, biome materials or LOD. It is not an Unreal Landscape. | Keep validated terrain data/service; evaluate editor-baked Landscape tiles and World Partition for fixed datasets. Do not simultaneously replace streaming while validating Chaos. Runtime-generated cities still require a renderer interface rather than hardwired Landscape. |
| Streaming | Ownership-aware5x5 neighborhood, critical neighbors synchronous, farther tiles one per Tick | Synchronous parsing, mesh construction and collision cooking can hitch; unbounded per-tile work and redundant road/terrain collision | Split data preparation from game-thread submission, budget uploads and collision activation, measure boundary crossings. Prevent entry before collision readiness. |
| Lighting | One directional light, sky atmosphere/skylight; auto exposure disabled | Flat/dark baseline and inconsistent exposure; no fog/post-process or measured reflection settings | Establish realistic neutral exposure, sun/sky/fog, restrained post-process, Mac-tested Lumen software tracing and VSM/TSR where supported. Avoid enabling costly systems without measurement. |
| Materials | Vertex colors and engine default car material | Flat prototype presentation | Import existing licensed asphalt/plaster/paving textures, invert OpenGL normal green channel, use sensible roughness and metre-scale UVs. Shared material instances per surface type. |
| Architecture | GameMode/Controller + map/session/API GameInstance subsystems + WorldSubsystem + native UMG + BP input/Pawn config | Useful Unreal-native separation already present | Preserve these boundaries. Extract configurable city/vehicle/road/terrain DataAssets; remove Barcelona bounds and single-Pawn assumptions from service implementations. |
| UI/persistence | Basic onboarding, address search, screen delegates and independent SaveGame | Functional foundation; style, mouse flow, resume and settings parity require validation | Preserve flows, validate pointer/keyboard and focus/pause. Extend view models rather than putting physics/world logic in widgets. |
| Packaging | Game C++ compiled; cook/stage succeeded; local signing required FinderInfo removal; automatic archive raised Sequence contains no matching element | Toolchain is viable, but independent launch and installation are not yet validated | Fix reproducible packaging/archive; use City Explorer Unreal.app in /Applications only after validation, preserving City Explorer.app. |

## What is already verified

Mac platform VALID, arm64 editor compilation, original project opened in UE5.8.3 with Metal SM6, core handling/terrain/offline map automation passed. Native game runtime completed Home → Barcelona → offline address → safe location → vehicle → exploration and keyboard pause. A procedural winding bug was found visually and corrected. Source units are metres with X east/Y south; Unreal units are centimetres with X east/Y south/Z elevation.

These checks do not establish vehicle physics quality, sustained collision driving, visual parity or production readiness. The original car glTF export succeeded, but it is not yet rigged/imported. Directed routing changes started before this audit remain uncommitted and require tests; they are not a validated feature.

## Ordered phase gates

1. Audit: complete this source/asset/configuration review and record measured baseline limitations.
2. Physics: Chaos vehicle, proper rig/physics asset, suspension/wheel contact, braking/reverse/steering, physical collision, safe recovery and pause. Compile, editor launch, onboarding and driving test before proceeding.
3. Roads: test one representative junction/curved/sloped road region before applying the system citywide. Check surface continuity, collision, markings and UV scale.
4. Terrain/world: align roads, establish renderer interfaces and LOD/streaming budgets; then choose baked Landscape/World Partition based on data lifecycle and measured performance.
5. Lighting/materials: neutral PBR baseline on Mac, shadow/reflection/exposure checks and frame-time measurements.
6. Camera: validate acceleration/braking/cornering, collision avoidance, reset and comfortable FOV.
7. Data/architecture: catalogs and per-city/vehicle settings with clean service boundaries.
8. Gameplay validation: preserve all startup/search/spawn/driving/pause/recovery/settings/save flows; complete navigation/maps/API comparisons.
9. Optimization: profile CPU, GPU, memory and tile-boundary spikes on this Mac; fix measured bottlenecks.
10. Package: native arm64 build, independent launch, installed alongside Godot, final visual/handling review and push.

For each gate record exact build/test evidence, visible changes, physics changes, performance measurements and remaining issues. Do not equate compilation with completion. Visual approval is most useful after a representative road/material/lighting sample and after the tuned driving camera can be inspected; it should not block implementation of an initial reviewable sample.
