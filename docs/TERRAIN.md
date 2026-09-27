# Barcelona terrain

The game uses an offline **ICGC MET5** bare-earth terrain model and an OpenStreetMap coastline. MET5 has a 5 m source grid, orthometric heights, and a published estimated vertical RMS error of 0.90 m. That is the source specification, **not a measured accuracy guarantee for the game**. Retrieval: 27 September 2026; this is not the survey date.

The source grid is reprojected from EPSG:25831 into the game's existing local metre coordinates, resampled to 6 m, and stored as little-endian float32 heights. Roads keep their existing OSM horizontal coordinates. Road surfaces, collision terrain, navigation endpoints, recovery, and save migration use the same triangular height interpolation. Buildings remain upright on level foundations. The car hull and visual body follow local road grade. Existing flat-world saves migrate their elevation while retaining discoveries.

Detailed terrain streams in 192 m patches around the car. Park colors use a compact 6 m OSM polygon mask on the terrain itself, avoiding floating overlays and their geometry cost. Rebuilding the terrain bundle updates that dated park mask too. A 48 m distant mesh keeps Collserola and Montjuïc visible. Sea geometry follows completed OSM coastline polygons at orthometric zero; the underwater -4 m floor is an illustrative rendering aid, **not bathymetry**. Terrain coloring, water waves, foundations and unsurveyed road crossfalls are illustrative. Small piers and sharp cliffs are limited by the 6 m grid. Where the older MET5 shoreline lacks heights for current OSM land within 1 km of water (principally reclaimed port land), heights use nearest valid MET5 samples before resampling and remain approximate. The count is recorded in metadata.

This does not reconstruct bridge decks, tunnels, retaining walls or stacked road levels. The surface-road importer already excludes tunnels and nonzero road layers. Remaining untagged elevated structures can still have incorrect grades. Bare-earth height is not a surveyed road engineering profile. No Google Earth or Street View assets are used.

## Rebuild offline

```
python3 -m venv .venv-terrain
.venv-terrain/bin/pip install -r tools/requirements-terrain.txt
.venv-terrain/bin/python tools/build_terrain.py
```

The committed source GeoTIFF is a losslessly compressed conversion of the original ICGC ARCGRID response; source CRS is explicitly EPSG:25831. The exact download URL, attribution, hashes and adaptations are recorded in `data/terrain/metadata.json`. The service advertises `icc:met5` but its public proxy expects `COVERAGE=icc:met` for this endpoint.

`python3 tools/fetch_coastline.py` optionally refreshes missing coastline chains through the read-only OSM API before rebuilding. It preserves complete ways that the rectangular city extract omitted. The output is an attributed ODbL source extract. The builder fails if coastal topology or inland height coverage is incomplete; it does not silently substitute flat land.

Elevation is a separate, versioned offline bundle and is retained during ordinary weekly road/address refreshes. Rebuild terrain deliberately when updating its source; geospatial Python libraries are only developer tools, never game dependencies. Both JSON and binary heights are explicitly included in the iOS export preset.

## Attribution

Institut Cartogràfic i Geològic de Catalunya (ICGC), MET5, **CC BY 4.0**: https://www.icgc.cat/en/Geoinformation-and-Maps/Data-and-products/Bessons-digitals-Elevacions/5x5-m-Terrain-elevation-model

Coastline © OpenStreetMap contributors, **ODbL 1.0**: https://www.openstreetmap.org/copyright
