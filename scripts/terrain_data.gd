class_name TerrainData
extends RefCounted

# One offline metric grid shared by visuals, collisions, navigation and recovery.
static var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain/metadata.json"))
static var samples := FileAccess.get_file_as_bytes("res://data/terrain/heights.f32").to_float32_array()
static var estimates := FileAccess.get_file_as_bytes("res://data/terrain/estimated.bin")
static var parks := FileAccess.get_file_as_bytes("res://data/terrain/parks.bin")
static var columns: int = metadata.columns
static var rows: int = metadata.rows
static var spacing: float = metadata.spacing_m
static var origin := Vector2(metadata.origin[0], metadata.origin[1])

static func sample(x: int, z: int) -> float:
	return samples[clampi(z, 0, rows - 1) * columns + clampi(x, 0, columns - 1)]

static func height(x: float, z: float) -> float:
	var p := (Vector2(x, z) - origin) / spacing
	var ix := clampi(floori(p.x), 0, columns - 2)
	var iz := clampi(floori(p.y), 0, rows - 2)
	var u := clampf(p.x - ix, 0, 1)
	var v := clampf(p.y - iz, 0, 1)
	var a := sample(ix, iz)
	var b := sample(ix + 1, iz)
	var c := sample(ix, iz + 1)
	var d := sample(ix + 1, iz + 1)
	# Matches the NW-SE diagonal in TerrainWorld; no bilinear/physics mismatch.
	if u >= v: return a + u * (b - a) + v * (d - b)
	return a + v * (c - a) + u * (d - c)

static func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y + height(p.x, p.z), p.z)

static func normal_at(x: float, z: float) -> Vector3:
	return Vector3(height(x - 3, z) - height(x + 3, z), 6, height(x, z - 3) - height(x, z + 3)).normalized()

static func is_estimated(p: Vector3) -> bool:
	var x := clampi(floori((p.x - origin.x) / spacing), 0, columns - 2)
	var z := clampi(floori((p.z - origin.y) / spacing), 0, rows - 2)
	for offset in [0, 1, columns, columns + 1]:
		var index: int = z * columns + x + offset
		if estimates[index / 8] & (1 << (index % 8)): return true
	return false

static func park_at(x: int, z: int) -> bool:
	var index := clampi(z, 0, rows - 1) * columns + clampi(x, 0, columns - 1)
	return bool(parks[index / 8] & (1 << (index % 8)))
