# Future building models and scans

The game supports per-building static visual replacements now. No licensed scan is included or needed to run the game. `data/building_assets.json` deliberately ships with an empty asset list; the current city remains procedural until approved content is added.

The JSON contract uses geographic anchors, metres, explicit footprint IDs and source metadata. It can be reused by a future Unreal importer; `scripts/building_assets.gd` is the Godot-specific loading adapter, not an Unreal implementation.

## Asset preparation

1. Obtain redistribution rights for the model and its textures, including offline application distribution. Metadata fields record provenance; validation does not establish legal permission.
2. Convert raw scans/point clouds into a cleaned, textured static mesh using an external asset tool. Crop away roads, trees, cars and neighboring buildings unless those building footprints are intentionally included. Raw LiDAR, point clouds, photographs and remote 3D Tiles services are not direct inputs to this adapter.
3. Export glTF 2.0 (`.glb` recommended, or `.gltf` plus local dependencies) in metres, Y-up, with a known ground-level pivot. Place it under `assets/buildings/<asset-id>/`. Import it in Godot before running/exporting. Imported `.tscn`/`.scn` static scenes are also accepted. Scene nodes must be static Node3D/MeshInstance3D nodes, with at least one mesh; scripts, lights, cameras, physics and animation nodes are rejected. Wrap or clean the imported scene accordingly.
4. Prepare a lower-detail mobile scene and assign `mobile_scene` when needed. Decimate geometry, generate mesh LODs with Godot's import settings, simplify materials, and budget textures on the target phone. The adapter supplies a visibility cutoff but does not generate mobile-quality assets or certify frame rate.
5. Add an entry to the manifest using real IDs from `data/city/manifest.json`. One asset can replace multiple footprint IDs. One footprint can belong to only one successfully loaded replacement.

## Manifest format

Illustrative entry (replace placeholders before use; this is not installed content):

```json
{
  "schema": 1,
  "assets": [{
    "id": "mallorca-building-001",
    "building_ids": ["way/REPLACE_WITH_EXISTING_OSM_ID"],
    "scene": "res://assets/buildings/mallorca-building-001/desktop.glb",
    "mobile_scene": "res://assets/buildings/mallorca-building-001/mobile.glb",
    "anchor_lonlat": [2.1744, 41.4036],
    "elevation_m": 0,
    "yaw_degrees": 0,
    "scale": 1,
    "visibility_m": 420,
    "source": {
      "url": "REPLACE_WITH_SOURCE_URL",
      "license": "REPLACE_WITH_LICENSE_OR_PERMISSION_REFERENCE",
      "license_url": "REPLACE_WITH_TERMS_REFERENCE",
      "attribution": "REPLACE_WITH_REQUIRED_CREDIT",
      "capture_date": "unknown"
    }
  }]
}
```

`anchor_lonlat` is longitude then latitude (WGS84), matching the model pivot. The adapter applies the same local projection as the map: +X east, +Y up, −Z north. `elevation_m` is relative to the prototype's flat ground, not altitude above sea level. `yaw_degrees` rotates about +Y using Godot's convention, not a compass bearing. `scale` is a positive uniform multiplier; use 1 for a metre-scale export. Existing scene-root transforms are preserved inside this placement wrapper. Confirm alignment visually against the footprint before distribution.

The Mobile renderer chooses `mobile_scene` when provided, otherwise `scene`. A supplied but missing mobile variant falls back to the procedural building; it does not silently load the heavier desktop model. `visibility_m` is a cutoff between 50 and 1,000 metres. Distant proxy LODs are not yet provided.

## Fallbacks and collisions

Missing files, unsupported schema, unknown/overlapping footprint IDs, invalid transforms, unsupported nodes or missing provenance leave procedural visuals in place and report an issue. Successfully loaded assets suppress the selected procedural walls, façades and roof. The building footprint collision stays active, keeping car and camera behavior independent from expensive scan meshes. Replacing a landmark-tagged footprint also suppresses the illustrative Sagrada tower assembly; a complete basilica replacement must cover every relevant footprint and include the complete visual structure.

Collision still follows the old flat-map footprint, not the scan's balconies, arcades or entrances. There is no walkable interior or custom collision importer in this version. Nearby shop/address labels also remain data overlays. After a map refresh, review IDs and alignment; unmatched IDs fall back instead of attaching to another building.

Only project-local, editor-imported assets are supported. Updates require restarting the game and rebuilding the installed iPhone application. The iOS preset includes the manifest and imported assets, while excluding test fixtures. Loaded asset credits appear in Credits & licenses. Keep original source and permission records in your asset archive; do not commit private contracts or unlicensed binaries.

## Verification

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/building_assets.gd
godot --headless --path . --fixed-fps 60 --script tests/smoke.gd
```

The test fixture is an original glTF triangle under `assets/buildings/_test_only/`, not a real building or scan. Tests cover actual glTF loading, transforms, attribution, collision preservation, absence of duplicate procedural geometry, missing assets, bad metadata, unknown IDs, overlap, mobile fallback and schema rejection. Real source assets will still need visual alignment, license review and device profiling.

Godot format reference: https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
