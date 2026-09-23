# OpenStreetMap source and derived database

© OpenStreetMap contributors. OpenStreetMap is available under the Open Database License (ODbL) 1.0:
https://www.openstreetmap.org/copyright
https://opendatacommons.org/licenses/odbl/1-0/

`eixample.json` is an adapted database, distributed under ODbL 1.0. `source/eixample.osm.gz` is the corresponding OSM extract. `tools/import_map.py` describes the transformation and can reproduce it. Preserve attribution and offer this adapted database/source under the same applicable terms when distributing a produced game. This notice does not relicense unrelated game code or original artwork.

Bounding box: west 2.169, south 41.400, east 2.180, north 41.407 (WGS84). Downloaded 2026-09-23 from the OSM map API. Record edit dates are stored individually and may substantially predate the download. A fresh download does not constitute field verification.

Source: https://api.openstreetmap.org/api/0.6/map?bbox=2.169,41.400,2.180,41.407

Modified: bounded segments; metric-coordinate projection; building ring assembly; inferred widths/heights where tags are absent; drivable connected-component filtering; place/address tag selection. Appearance is generated independently. Unknown addresses are not inferred.

The municipal Barcelona address table was investigated but is NOT included in the runtime or derived OSM database: its street-code lookup was unavailable. All displayed address records currently come from OSM, not municipal verification.

## Municipal street-tree layer

`source/street_trees.csv.gz` is a bounded extract of the street-tree inventory published by Ajuntament de Barcelona / Open Data BCN under Creative Commons Attribution 4.0: https://creativecommons.org/licenses/by/4.0/

Source: https://opendata-ajuntament.barcelona.cat/data/en/dataset/arbrat-viari
Downloaded 2026-09-23. This is a retrieval date, not a survey date.

Changes: geographic clipping, coordinate projection, field selection, and combination with separately identified OSM park-tree records. `trees.json` is distributed under ODbL 1.0 with the OSM-derived layer; preserve the additional municipal attribution and CC BY notice. The original bounded municipal CSV retains its CC BY 4.0 license. No municipal endorsement is implied. `tools/refresh_trees.py` reproduces the transformation.

## Barcelona-wide runtime

`city/manifest.json` and `city/tiles/*.json` supersede the pilot at runtime. They are adapted OSM/municipal data distributed under ODbL 1.0 with the additional municipal CC BY 4.0 attribution retained. The underlying municipal extract remains CC BY 4.0.

- OSM bulk source: https://download.bbbike.org/osm/bbbike/Barcelona/Barcelona.osm.gz (BBBike distributes OSM data; © OpenStreetMap contributors).
- Municipal boundary: https://api.openstreetmap.org/api/0.6/relation/347950/full
- Street-tree source remains the Open Data BCN URL above.
- Retrieval: 2026-09-23. Retrieval is not a record verification date.
- Included bounded source: `source/barcelona.osm.gz`, `source/barcelona-boundary.osm`, `source/city_street_trees.csv.gz`.
- Transformation: `tools/build_city.py`, using `tools/import_map.py`; clipping to the municipal bounding envelope, complete-way fringe retention, metric projection, source-graph filtering, tree deduplication and spatial tiling. The runtime includes neighboring fringe; it is not clipped exactly to the municipal polygon. Source park-tree IDs and municipal tree IDs are kept distinct.

`city/areas.json` contains convenient district starting anchors derived from the municipal tree inventory. They are not official district centers. The smaller pilot files remain as historical reproducible regression fixtures, not the active runtime map.
