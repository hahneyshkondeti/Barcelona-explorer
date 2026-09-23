# Brisa — Barcelona city explorer

An offline Godot 4.5 driving prototype with map coverage across **all ten Barcelona districts**, using OpenStreetMap roads, footprints, addresses and places, plus the municipal street-tree inventory. Sagrada Família remains the introductory sightseeing destination.

![Driving in Barcelona](docs/driving.png)

## Coverage and accuracy

The playable envelope contains Barcelona's complete municipal boundary (OSM relation 347950) and neighboring fringe inside its bounding rectangle: longitude 2.0524977–2.2283555, latitude 41.3170354–41.4679135. It is approximately 14.7 × 16.8 km in the local projection; this rectangle is larger than the municipality itself. The municipal boundary is included as data, not claimed to match the rectangular perimeter barrier.

The bulk snapshot contains **104,694 building records, 20,576 place records, 136,853 addresses and 930 park polygons**. There are 502,007 road/path segments, including 126,836 segments in the connected surface-road routing graph. These are segments and source records, not counts of distinct streets or verified active businesses. 9,594 places have both street and house number recorded. Geometry and provenance come from the included dated source, retrieved 2026-09-23.

This is geographic expansion, **not a photorealistic or survey-complete digital twin**:

- Façades, roof details, shop appearance, missing heights, road widths, pavement edges and markings remain estimates. The basilica model remains illustrative.
- Terrain is flat, including the hills. Bridges, tunnels and nonzero road layers are omitted by the current surface-road importer. Private/pedestrian-only roads and disconnected components are excluded from driving navigation. Turn restrictions and traffic signals are not simulated.
- The outer rectangle includes neighboring municipalities and some water/port extent; there is no accurately modeled coastline, water surface or terrain mesh yet.
- OSM records can be old, missing or duplicated. A download date is not a field-survey date. No Google imagery is used.

## Run and explore

Install [Godot 4.5 stable](https://godotengine.org/download/archive/4.5-stable/), import `project.godot`, and press **F5**. Initial startup now parses a city-wide routing/places index and builds nearby geometry; allow more startup time than the original district prototype.

Development engine on this Mac (temporary installation):

```sh
/tmp/barcelona-godot/Godot.app/Contents/MacOS/Godot --path /Users/hahneyshkondeti/Documents/ChatGPT/Explorer
```

| Control | Action |
| --- | --- |
| W / Up / DRIVE | Accelerate |
| S / Down / Space / BRAKE | Brake; hold 0.35 seconds after stopping for reverse |
| A / D or Left / Right | Steer |
| C / Camera | Reset camera |
| R | Recover to last safe road |
| P / Escape / Pause | Pause/resume |
| Pause → district selector → Start in district | Move to a safe mapped road in any of the ten districts |
| Places & addresses | Search city-wide records and route to a nearby mapped road |

District spawn anchors are selected from municipal tree records near each district's average inventory location, then projected to a connected road. They are convenient starting points, not district centroids or sightseeing claims. Place search displays up to 300 matches; refine the query to find a specific record. The minimap shows the local streets around the car.

Progressive acceleration, speed-sensitive steering, reverse delay, collision response, pause, sound controls, 30/60 FPS caps and local saves remain. Saves from the real-map Sagrada pilot are accepted when their positions are still safe; the older fictional-grid saves are not migrated.

## City loading

`data/city/manifest.json` holds the city-wide connected road graph, places, footprint identifiers and tile index. Geometry, addresses, parks and trees live in 192 m spatial tiles. The loader keeps a nearby 5×5 cell neighborhood plus ownership dependencies, so a building spanning tile edges is loaded once rather than cut or duplicated. Immediate neighboring collision tiles are loaded before movement enters them; farther tiles are added one per frame. Old tiles and cached payloads are released as the car travels. District jumps load their neighborhood before resuming driving.

The global routing/places index remains resident. Geometry generation and JSON loading are still on the main thread, so startup, tile crossings and district jumps can hitch. This is bounded local geometry loading, not a completed iPhone memory/frame-time optimization. The 30 FPS iPhone target is unverified at city scale.

Desktop uses Forward+ (Metal on macOS), SSAO, MSAA and TAA. iOS uses Mobile without desktop-only SSAO/TAA. Imported detail uses distance cutoffs and shared meshes/materials. `--rendering-method gl_compatibility` is a desktop fallback. A frame-rate cap is not a quality preset or a performance guarantee.

## Tree sources and future scans

Street trunks use 144,957 municipal records within the city envelope, preserving coordinates and source IDs. Mapped OSM park trees are used as fallback where no municipal tree is within three metres. Heights, crowns and seasonal appearance remain illustrative. Trees are not moved to fit estimated road widths. Source counts and retrieval dates are recorded in the manifest.

The empty `data/building_assets.json` manifest is ready for future local GLB/glTF or static Godot building scenes, with geographic placement, mobile variants and attribution. Missing assets retain procedural buildings; replacements retain footprint collision. See [building import instructions](docs/BUILDING_ASSETS.md).

## Refresh city data roughly weekly

Python **3.11+**, system `curl`, and sufficient free disk space are required. No API key or Python package dependency is needed. Bulk downloads and the source conversion are substantial; allow several minutes and several GB of temporary memory/disk space.

```sh
python3 tools/refresh_city.py --check
python3 tools/refresh_city.py --download
python3 tests/check_city.py --city data/.refresh/city/city
python3 tools/refresh_city.py --apply
```

Download stages the published BBBike Barcelona extract, the OSM municipal boundary and Open Data BCN street trees, then builds and checks tiles. Apply checks file hashes, count changes and coverage before replacing the runtime folder; the previous runtime is retained under `data/.refresh/previous-city`. A materially changed boundary or count needs developer review. Failed staging leaves the installed map alone.

This is a developer-run refresh, not a scheduled job or an iPhone OTA update. Restart the desktop game after promotion; rebuild/reinstall the phone app with the new offline data. The original `refresh_map.py`, `refresh_trees.py`, `data/eixample.json` and `data/trees.json` remain for pilot regression/reproducibility and **do not update the active city**.

To rebuild from the included bounded source without downloading:

```sh
python3 tools/build_city.py --trees data/source/city_street_trees.csv.gz --retrieved-at 2026-09-23T07:26:55.113735+00:00
python3 tests/check_city.py
```

See [data attribution](data/LICENSE.md) and [asset licenses](ASSET_LICENSES.md). Source XML/CSV and transformations are included. The city bundle is hundreds of MB before export compression.

## Physical iPhone build

The product target remains **iPhone 11 / A13, iOS 16+, landscape, 30 FPS**, with an optional 60 FPS cap. It has not been performance-validated at city scale.

1. Install full Xcode, complete first-launch setup and install its iOS platform. Select Xcode's command-line tools in Settings → Locations.
2. Install Godot 4.5 and matching iOS export templates.
3. Open Project → Export → iOS. The preset targets arm64 iPhone, minimum iOS 16, bundle ID `com.hahneyshkondeti.brisa`, and Xcode project export.
4. Enter your actual Apple Team ID and use a bundle ID your signing account can provision. Do not commit signing credentials.
5. Export, open the generated Xcode project, choose the signing team and connected iPhone, enable Developer Mode if required, then build/run.
6. Verify airplane-mode launch, district jumps, a continuous drive across tiles, safe areas, physical touch input, app backgrounding and memory/thermal behavior.

Only Command Line Tools were available during development; no signed IPA, TestFlight release or physical iPhone test is claimed. A successful Godot PCK export is a resource bundle, not an iOS executable.

## Verification and next work

See [test details](docs/TESTING.md). Cross-city routing and streaming are tested in addition to the original sightseeing loop. The next priorities are device profiling, smoother asynchronous tile generation, terrain/coastline, grade-separated roads, and building-specific visual assets when licensed sources become available.
