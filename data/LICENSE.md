# OpenStreetMap source and derived database

© OpenStreetMap contributors. OpenStreetMap is available under the Open Database License (ODbL) 1.0:
https://www.openstreetmap.org/copyright
https://opendatacommons.org/licenses/odbl/1-0/

`eixample.json` is an adapted database, distributed under ODbL 1.0. `source/eixample.osm.gz` is the corresponding OSM extract. `tools/import_map.py` describes the transformation and can reproduce it. Preserve attribution and offer this adapted database/source under the same applicable terms when distributing a produced game. This notice does not relicense unrelated game code or original artwork.

Bounding box: west 2.169, south 41.400, east 2.180, north 41.407 (WGS84). Downloaded 2026-09-23 from the OSM map API. Record edit dates are stored individually and may substantially predate the download. A fresh download does not constitute field verification.

Source: https://api.openstreetmap.org/api/0.6/map?bbox=2.169,41.400,2.180,41.407

Modified: bounded segments; metric-coordinate projection; building ring assembly; inferred widths/heights where tags are absent; drivable connected-component filtering; place/address tag selection. Appearance is generated independently. Unknown addresses are not inferred.

The municipal Barcelona address table was investigated but is NOT included in the runtime or derived OSM database: its street-code lookup was unavailable. All displayed address records currently come from OSM, not municipal verification.
