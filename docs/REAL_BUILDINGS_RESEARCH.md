# Real Barcelona buildings: research and recommendation

Research date: 2026-09-28. User priority: recognizable real buildings; Mac or web acceptable, iPhone performance no longer a design constraint. This is a research report, not a completed asset import or an engine migration.

## Recommendation

Build a Mac-first, address-specific pilot around Carrer de Gretel Ammann Martínez 12, covering the building and adjacent street fronts. Acquire one genuinely usable source sample before migrating engines or committing to citywide production. Combine surveyed building geometry with licensed street-level photography/scans. Engine changes improve rendering tools but cannot recover missing balconies, entrances, shop fronts or real materials from footprint polygons.

For the first imported block, keep the existing Godot game to test whether the source actually achieves the desired resemblance. If the chosen supplier delivers large tiled photogrammetry datasets, evaluate Unreal + Cesium for the Mac production version. For browser-first streaming, evaluate CesiumJS with a licensed tileset; it requires a separate browser gameplay integration, not simply running the Godot adapter.

## Sources checked

| Source | Verified value | Unresolved or missing |
|---|---|---|
| [CartoBCN municipal topography](https://w20.bcn.cat/CartoBCN/atom.ashx?file=144) | Official GeoPackage already downloaded. Direct SQLite inspection of TOPO1000_POLIGONS found 464,087 CON_01pol_PL building polygon records in EPSG:25831, plus covered structures and construction polygons. | These are polygon records, not 464,087 distinct buildings. No façade imagery or finished textured building assets in that layer. COTA requires documented interpretation; it must not be blindly treated as building height. |
| [Spanish Cadastre INSPIRE](https://www.catastro.hacienda.gob.es/webinspire/index_eng.html) | Building/building-part geometry and municipality downloads; useful for matching addresses and distinguishing volumes. [Schema description](https://www.catastro.hacienda.gob.es/webinspire/documentos/Conjuntos%20de%20datos_en.pdf) explains parts and floor counts. | Not a textured street-level reconstruction. Floor counts do not establish exact measured heights. Review dataset-specific reuse terms before integration. |
| [ICGC Urban Digital Twin / 3DCarrers](https://www.icgc.cat/en/Geoinformation-and-Maps/Data-and-products/Digital-twins/Urban-Digital-Twin-Catalonia) | Street-level panoramic photography plus high-resolution terrestrial LiDAR. Public image consultation; point-cloud access restricted to authorized users. Product page displays CC BY 4.0 geoinformation notice. | Exact address coverage, survey date, downloadable source access, and texture/derivative redistribution rights need confirmation for the supplied files. Public viewing is not proof of unrestricted bulk access. No verified downloadable sample for the pilot address yet. |
| [AMB cartography](https://geoportalcartografia.amb.cat/) | Metropolitan 1:1,000 3D cartography. [AMB report](https://memoria2023.amb.cat/urbanisme/informaci%C3%B3-i-estudis-territorials) describes simplified and realistic territorial 3D models. | Investigate sample download, texture resolution at car-camera height, Barcelona coverage and specific license. The word “realistic” alone does not establish street-level quality. |
| [Cyclomedia](https://www.cyclomedia.com/en-us) | Commercial street-level imagery and LiDAR provider; plausible route to licensed capture or a dataset agreement. | Barcelona pilot-address availability, game redistribution/offline rights, deliverable format and price need a supplier response. No quote obtained and no supplier contacted. |
| [Google Photorealistic 3D Tiles](https://mapsplatform.google.com/maps-products/map-tiles/) | Textured real-world mesh from the same 3D source as Google Earth; supported by Cesium renderers. | Streaming service, not an offline asset library. [Policies](https://developers.google.com/maps/documentation/tile/policies) restrict extraction/storage/offline use and require visible attribution. [EEA changes](https://developers.google.com/maps/comms/eea/map-tiles?hl=en) make Photorealistic 3D Tiles unavailable for projects subject to new EEA terms (403); unchanged pre-existing integrations have separate treatment. Billing eligibility must be verified, not inferred from user location. |

Google's EEA documentation suggests Maps JavaScript API 3D Maps as an alternative. It [supports custom glTF models](https://developers.google.com/maps/documentation/javascript/3d/models), but that does not provide an exportable city mesh or a turnkey driving physics engine. Its suitability for this game's camera, collision and relighting requirements needs a separate proof of concept.

## What the game needs

1. **Surveyed geometry:** building parts, heights, setbacks, courtyards and roofs, matched to addresses. Obtain CRS, height datum, capture dates and accuracy metadata.
2. **Recognizable façades:** clean photographs/scans showing windows, balconies, doors, shops and materials. Aerial geometry is not enough to guarantee good ground-level façades. If no reusable street-level dataset exists, commission/capture the pilot block or author it from appropriately licensed references.
3. **Asset processing:** align to geographic anchors; remove captured cars, people, trees and street surfaces that duplicate the game; repair holes; build clean textured meshes. Separate baked sunlight/shadows from materials where feasible so the existing moving sun does not conflict with captured lighting.
4. **Runtime integration:** import GLB meshes or tile large datasets, retain a stable road/collision layer, stream surrounding blocks, maintain source attribution and address associations.
5. **Acceptance:** compare the same viewpoints at the pilot address; check floor count, window/balcony spacing, entrance positions, surrounding buildings, scale and terrain alignment; drive both directions and inspect day/night lighting. No whole-city rollout until this sample is convincing.

## Existing code and required work

`data/building_assets.json` is empty. `scripts/building_assets.gd` already loads local GLB/glTF/static scenes, places them geographically, supports terrain-relative elevation, replaces selected mapped building IDs and records credits. It retains simplified footprint collision.

Crucially, the adapter currently instantiates **all manifest assets at startup**; its visibility range only hides rendering. It is suitable for a pilot, not a full scanned city. Citywide imports require asynchronous asset loading/unloading tied to the existing 192 m tile system, a memory budget and distinct near/far representations. Raising desktop fidelity does not remove the need to bound memory and avoid loading stalls. [Godot 4.5 mesh LOD](https://docs.godotengine.org/en/4.5/tutorials/3d/mesh_lod.html) helps geometry cost but is not asset streaming.

Unreal + Cesium supports [Apple Silicon/macOS](https://github.com/CesiumGS/cesium-unreal/blob/main/Documentation/developer-setup-osx.md). Check the selected [Unreal version's Mac feature requirements](https://dev.epicgames.com/documentation/en-us/unreal-engine/macos-development-requirements-for-unreal-engine): some advanced M2 features are beta/experimental. Migration would rebuild vehicle control, camera, UI, navigation integration and saving; coordinate/source data can be reused. [Cesium's view-dependent tile culling](https://cesium.com/learn/unreal/unreal-placing-objects/) also affects available collision surfaces, so a robust driving surface needs explicit handling.

## Weekly downloadable-asset refresh

User prefers downloadable assets with roughly weekly refresh checks. This is the preferred delivery model, subject to the chosen source permitting local storage and redistribution. A weekly check discovers newly **published** data; it cannot make a quarterly/annual survey reflect last week's real-world changes.

Proposed pipeline, not yet implemented:

1. Check the publisher's version/feed weekly; keep publication and capture dates separately.
2. Compare version IDs/content hashes; download only changed geographic tiles/buildings to a staging directory. Retain source URL, license, coordinates, capture date and checksum per asset.
3. Convert and validate offline: geometry/material integrity, supported formats, coordinate/elevation alignment, duplicate building replacements, address-ID mapping and collision continuity. Do not silently apply deleted/reassigned IDs or large unexpected changes.
4. Generate a visual change report for substantial geometry differences; keep manually corrected assets protected from automatic overwrite.
5. Promote a complete validated snapshot atomically and keep the previous version for rollback. Failed or partial downloads do not alter the installed city.
6. For the current adapter, import in Godot and rebuild the Mac application. A future external asset-pack loader could fetch verified packs between sessions without rebuilding the app; that loader does not exist yet. A browser version would serve versioned assets from hosting and switch manifests after validation.

The provider must offer versioned downloads or a detectable update feed and suitable redistribution rights. Hosting and download costs are unknown until sample size and source terms are established. No weekly automation has been created; this section defines the requested future capability.

## Concrete next step

Request or locate a small downloadable sample from ICGC/AMB covering the pilot address, with capture date, CRS and explicit permission to redistribute derived textured meshes in a public game. Evaluate it in the current Mac game. If unavailable, use an owned/commissioned photo capture for that block. A vendor request should ask for exterior mesh + textures (GLB/OBJ/3D Tiles), façade detail near eye level, roof coverage, exclusions, attribution, offline and web redistribution rights, and a sample before a citywide quote.

No paid service, account, contact message, API key, new engine installation or game source changes were made for this research. Source sample acquisition and street-level visual validation remain outstanding. There is no verified free, turnkey, complete Barcelona façade mesh established by this research.
