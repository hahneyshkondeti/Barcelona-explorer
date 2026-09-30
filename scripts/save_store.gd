class_name SaveStore
extends RefCounted

var path := "user://journey.json"
var safe_position := District.START
var heading := District.START_HEADING
var discovered: Array[String] = []
var muted := false
var fps := 30
var north_locked := false
var theme := "dark"
var selected_city := AppCatalog.DEFAULT_CITY_ID
var selected_vehicle := AppCatalog.DEFAULT_VEHICLE_ID
var last_error := ""

func load_journey() -> void:
	var source := path
	if not FileAccess.file_exists(source) and path == "user://journey.json":
		# Desktop user-data folders follow the app name. Preserve the former journey.
		source = OS.get_user_data_dir().get_base_dir().path_join("Brisa — Barcelona/journey.json")
	if not FileAccess.file_exists(source): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not data is Dictionary or int(data.get("version", -1)) not in [1, 2] or data.get("district") not in [District.ID, "sagrada_osm_v2"]:
		return
	var p = data.get("position", [])
	if p is Array and p.size() == 3 and (p[0] is float or p[0] is int) and (p[1] is float or p[1] is int) and (p[2] is float or p[2] is int):
		var candidate := Vector3(p[0], p[1], p[2])
		# Migrate flat-world saves once, preserving longitude/latitude and discoveries.
		if not data.get("terrain_aligned", false) and candidate.is_finite() and candidate.y > -0.5 and candidate.y < 3:
			candidate.y = TerrainData.height(candidate.x, candidate.z) + 0.55
		if District.is_safe(candidate):
			safe_position = candidate
	var h = data.get("heading", 0)
	if (h is float or h is int) and is_finite(float(h)):
		heading = float(h)
	if data.get("discovered", []) is Array and "sagrada_familia" in data.get("discovered", []):
		discovered.assign(["sagrada_familia"])
	muted = data.get("muted", false) == true
	north_locked = data.get("north_locked", false) == true
	fps = 60 if data.get("fps", 30) == 60 else 30
	theme = data.get("theme", "dark") if data.get("theme", "dark") in ["dark", "light", "system"] else "dark"
	selected_city = str(data.get("selected_city", AppCatalog.DEFAULT_CITY_ID))
	selected_vehicle = str(data.get("selected_vehicle", AppCatalog.DEFAULT_VEHICLE_ID))

func write_journey() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not save this journey."
		return false
	file.store_string(JSON.stringify({"version": 2, "terrain_aligned": true, "district": District.ID, "position": [safe_position.x, safe_position.y, safe_position.z], "heading": heading, "discovered": discovered, "muted": muted, "fps": fps, "north_locked": north_locked, "theme": theme, "selected_city": selected_city, "selected_vehicle": selected_vehicle}))
	file.close()
	last_error = ""
	return true
