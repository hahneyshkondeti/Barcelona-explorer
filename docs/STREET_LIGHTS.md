# Official lamp coordinates

City Explorer uses Ajuntament de Barcelona's **CartoBCN municipal topography** GeoPackage, `TOPO1000_PUNTS`, layer `ENE_06_PT` (Fanal). Downloaded 2026-09-27. The catalog entry reports update 2025-12-13; archive members are dated 2026-07-10. These are dataset dates, not an assurance that every lamp has been recently surveyed; individual rows can contain a 1970 revision sentinel.

- [Official catalog](https://w20.bcn.cat/CartoBCN/atom.ashx?file=144)
- [Official GeoPackage ZIP](https://w20.bcn.cat/CartoBCN/getFile.ashx?prod=144.BARCELONA.42)
- [Official reuse terms](https://w20.bcn.cat/CartoBCN/getFile.ashx?f=82071224678486&t=bdd): CC BY 3.0 ES, attribution and source date required.

132,637 source records; 132,556 unique visible points within the game envelope. Source attributes and unmodified EPSG:25831 coordinates are in `data/source/cartobcn-lamps.json.gz`; transformed game X/Z coordinates are in `data/lighting/street_lights.json`. Conversion uses EPSG:25831 → WGS84 → the same local projection as the roads, retaining 0.1 mm numeric precision (not a claim of survey accuracy). Hidden, duplicate and outside-envelope points are omitted from rendering. No road snapping or inferred offsets. The older invented road-midpoint lamps are removed.

**Shapes are not exact.** This point layer supplies no manufacturer/model, dimensions, pole height, arm geometry or 3D mesh. `LITERAL`, `ANGLE_TXT` and `COTA` are cartographic attributes, not assumed fixture specifications. The original cylindrical pole and flat luminaire are explicitly illustrative, 7 m high; base elevation follows terrain. Light color, intensity, timing threshold and cone are game approximations. This is not a live operational lighting feed or complete photometric simulation. Exact bodies require a licensed fixture inventory/model mapping to survey IDs; source IDs and attributes are preserved for that future import.

Fixtures stream with city tiles and use shared meshes/materials. A shared emissive material fades with solar altitude (off above +2°, full below −3°). Up to eight nearest lamps within 65 m use shadow-free downward spotlights, refreshed twice a second. No one-node-per-lamp city allocation. This bounded pool can change which roads receive direct illumination while moving; distant fixtures remain emissive. Physical iPhone performance has not been measured.

## Refresh

The lighting bundle is separate from `data/city`, so ordinary weekly city refresh does not erase it. To check a newer official snapshot, download the catalog/archive above, extract `TOPO1000_PUNTS.gpkg`, then run with the terrain Python environment (`pyproj`):

```sh
python3 tools/build_street_lights.py /path/to/TOPO1000_PUNTS.gpkg --source-updated 2025-12-13 --output /tmp/street_lights.json --source-output /tmp/cartobcn-lamps.json.gz
```

Review the official feed's publication date, pass the correct `--source-updated` date when it changes, compare counts/coverage and inspect changes before replacing the two installed files. The importer rejects missing CRS, unexpected geometry or fewer than 100,000 visible points. Run `python3 tests/check_street_lights.py` and `Godot --headless --script tests/street_lights.gd` after promotion; update the known survey checkpoint if the publisher legitimately revises it. Commit the dated snapshot, rebuild/reinstall the offline app. The city's publishing cadence may be slower than weekly. No credentials or runtime network access are needed.
