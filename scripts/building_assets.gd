class_name BuildingAssets
extends RefCounted

# Engine-neutral JSON placement/provenance; scene loading is this Godot adapter.
static var active_credits := PackedStringArray()
var replaced: Dictionary = {}
var instances: Array[Node3D] = []
var issues := PackedStringArray()

static func finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func anchor_position(lon: float, lat: float, elevation: float) -> Vector3:
	var origin: Array = District.DATA.origin_lonlat
	return Vector3(deg_to_rad(lon - float(origin[0])) * 6378137.0 * cos(deg_to_rad(float(origin[1]))), elevation, -deg_to_rad(lat - float(origin[1])) * 6378137.0)

func install(parent: Node3D, manifest: Variant, buildings: Array, mobile: bool) -> void:
	for instance in instances:
		if is_instance_valid(instance):
			instance.free()
	instances.clear()
	replaced.clear()
	issues.clear()
	active_credits.clear()
	if not manifest is Dictionary or manifest.get("schema") != 1 or not manifest.get("assets") is Array:
		issues.append("Invalid building manifest; using procedural buildings")
		return
	var known := {}
	for building in buildings:
		known[building.id] = true
	for entry in manifest.assets:
		var problem := validate(entry, known)
		if not problem.is_empty():
			issues.append(problem)
			continue
		var path: String = entry.get("mobile_scene", entry.scene) if mobile else entry.scene
		if not ResourceLoader.exists(path, "PackedScene"):
			issues.append("Missing/import-required scene: " + path)
			continue
		var packed = load(path)
		if not packed is PackedScene:
			issues.append("Not a scene: " + path)
			continue
		var model: Node = packed.instantiate()
		# Imported content must be a static visual scene; collisions use map proxies.
		if not visual_only(model) or mesh_count(model) == 0:
			issues.append("Expected static Node3D/MeshInstance3D scene: " + path)
			model.free()
			continue
		var placement := Node3D.new()
		placement.name = str(entry.id).validate_node_name()
		placement.position = anchor_position(entry.anchor_lonlat[0], entry.anchor_lonlat[1], entry.elevation_m)
		placement.rotation.y = deg_to_rad(entry.yaw_degrees)
		placement.scale = Vector3.ONE * float(entry.scale)
		placement.add_child(model)
		set_range(model, float(entry.visibility_m))
		parent.add_child(placement)
		instances.append(placement)
		for id in entry.building_ids:
			replaced[id] = true
		var source: Dictionary = entry.source
		active_credits.append("%s — %s\n%s\nLicense: %s\n%s\nCaptured: %s" % [entry.id, source.attribution, source.url, source.license, source.license_url, source.capture_date])

func validate(entry: Variant, known: Dictionary) -> String:
	if not entry is Dictionary:
		return "Building entry must be an object"
	for key in ["id", "scene"]:
		if not entry.get(key) is String or entry[key].strip_edges().is_empty():
			return "Missing building " + key
	var paths := [entry.scene]
	if entry.has("mobile_scene"):
		paths.append(entry.mobile_scene)
	for path in paths:
		if not path is String or not path.begins_with("res://assets/buildings/") or ".." in path or path.get_extension() not in ["glb", "gltf", "tscn", "scn"]:
			return "Scene must be a local imported building asset"
	if not entry.get("building_ids") is Array or entry.building_ids.is_empty():
		return "Missing mapped building IDs"
	var seen := {}
	for id in entry.building_ids:
		if not id is String or not known.has(id) or replaced.has(id) or seen.has(id):
			return "Unknown or overlapping building ID"
		seen[id] = true
	if not entry.get("anchor_lonlat") is Array or entry.anchor_lonlat.size() != 2:
		return "Expected WGS84 longitude/latitude anchor"
	for value in entry.anchor_lonlat:
		if not finite_number(value):
			return "Invalid anchor coordinate"
	var bounds: Array = District.DATA.bbox_lonlat
	if entry.anchor_lonlat[0] < bounds[0] or entry.anchor_lonlat[0] > bounds[2] or entry.anchor_lonlat[1] < bounds[1] or entry.anchor_lonlat[1] > bounds[3]:
		return "Anchor outside the loaded district"
	for key in ["scale", "yaw_degrees", "elevation_m", "visibility_m"]:
		if not finite_number(entry.get(key)):
			return "Missing/invalid transform field " + key
	if entry.scale <= 0 or entry.scale > 100 or entry.visibility_m < 50 or entry.visibility_m > 1000:
		return "Invalid scale or visibility distance"
	if not entry.get("source") is Dictionary:
		return "Missing asset provenance"
	for key in ["url", "license", "license_url", "attribution", "capture_date"]:
		if not entry.source.get(key) is String or entry.source[key].strip_edges().is_empty():
			return "Missing provenance field " + key
	return ""

func visual_only(node: Node) -> bool:
	if node.get_class() not in ["Node3D", "MeshInstance3D"] or node.get_script() != null:
		return false
	for child in node.get_children():
		if not visual_only(child):
			return false
	return true

func set_range(node: Node, distance: float) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_end = distance
	for child in node.get_children():
		set_range(child, distance)

func mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D and node.mesh != null else 0
	for child in node.get_children():
		count += mesh_count(child)
	return count
