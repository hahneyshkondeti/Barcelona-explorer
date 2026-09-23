class_name District
extends RefCounted

const ID := "barcelona_city_v1"
const TITLE := "Sagrada Família"
const DESCRIPTION := "Antoni Gaudí transformed this basilica into a forest of branching columns, sculpted façades and soaring towers. Construction began in 1882. Its architecture draws on nature, geometry and light.\n\nYou are at its mapped Barcelona location. Streets and footprints come from OpenStreetMap. The basilica's upper structure and façade details remain illustrative models, not a photographic reconstruction."
static var DATA: Dictionary = {}
static var TREE_DATA: Dictionary = {}
static var START := Vector3.ZERO
static var START_HEADING := 0.0
static var DESTINATION := Vector3.ZERO
static var LANDMARK_CENTER := Vector3.ZERO
static var BOUNDS := Rect2()
static var ROAD_SEGMENTS: Array = []
static var road_cells: Dictionary = {}
static var tile_cache: Dictionary = {}
static var CELL := 192.0
static var AREAS: Array = []
static var INFRASTRUCTURE: Dictionary = {}
static var TRANSIT: Array = []

static func _static_init() -> void:
	DATA = JSON.parse_string(FileAccess.get_file_as_string("res://data/city/manifest.json"))
	INFRASTRUCTURE = JSON.parse_string(FileAccess.get_file_as_string("res://data/city/infrastructure.json"))
	for records in INFRASTRUCTURE.cells.values():
		for record in records:
			if record.kind in ["metro_station", "metro_entrance", "bus_stop"]: TRANSIT.append(record)
	AREAS = JSON.parse_string(FileAccess.get_file_as_string("res://data/city/areas.json"))
	for key in INFRASTRUCTURE.cells:
		if not DATA.tile_dependencies.has(key): DATA.tile_dependencies[key] = []
		if key not in DATA.tile_dependencies[key]: DATA.tile_dependencies[key].append(key)
	TREE_DATA = {"metadata": DATA.tree_metadata, "trees": []}
	START = vector(DATA.start)
	START_HEADING = float(DATA.start_heading)
	DESTINATION = vector(DATA.destination)
	LANDMARK_CENTER = vector(DATA.landmark_center, 0)
	var lo := Vector2(DATA.bounds[0][0], DATA.bounds[0][1])
	var hi := Vector2(DATA.bounds[1][0], DATA.bounds[1][1])
	BOUNDS = Rect2(lo, hi - lo)
	for road in DATA.roads:
		if road.routable:
			ROAD_SEGMENTS.append(road)
			var a := vector(road.a)
			var b := vector(road.b)
			for x in range(floori(minf(a.x,b.x)/CELL), floori(maxf(a.x,b.x)/CELL)+1):
				for z in range(floori(minf(a.z,b.z)/CELL), floori(maxf(a.z,b.z)/CELL)+1):
					var key := Vector2i(x,z)
					if not road_cells.has(key): road_cells[key] = []
					road_cells[key].append(road)

static func vector(point: Array, y: float = 0.55) -> Vector3:
	return Vector3(point[0], y, point[1])

static func nearest_segment(point: Vector3) -> Dictionary:
	var best := {}
	var distance := INF
	var p := Vector2(point.x, point.z)
	var cell := Vector2i(floori(p.x/CELL), floori(p.y/CELL))
	var visited := {}
	for radius in [0,1,2,4,8,16,32,64,128]:
		for x in range(cell.x-radius, cell.x+radius+1):
			for z in range(cell.y-radius, cell.y+radius+1):
				var key := Vector2i(x,z)
				if visited.has(key): continue
				visited[key] = true
				for road in road_cells.get(key, []):
					var q := Geometry2D.get_closest_point_to_segment(p, Vector2(road.a[0],road.a[1]),Vector2(road.b[0],road.b[1]))
					var d := p.distance_squared_to(q)
					if d < distance:
						distance = d
						best = {"road":road,"point":Vector3(q.x,0.55,q.y),"distance":sqrt(d)}
		var edge := minf(minf(p.x-(cell.x-radius)*CELL,(cell.x+radius+1)*CELL-p.x), minf(p.y-(cell.y-radius)*CELL,(cell.y+radius+1)*CELL-p.y))
		if distance < edge*edge: break
	return best

static func nearest_road(point: Vector3) -> Vector3:
	if not point.is_finite():
		return START
	return nearest_segment(point).point

static func heading_at(point: Vector3) -> float:
	var road: Dictionary = nearest_segment(point).road
	var direction := vector(road.b) - vector(road.a)
	if road.oneway == -1:
		direction = -direction
	return atan2(-direction.x, -direction.z)

static func in_bounds(point: Vector3, margin: float = 0) -> bool:
	return point.is_finite() and BOUNDS.grow(margin).has_point(Vector2(point.x, point.z))

static func is_safe(point: Vector3) -> bool:
	return in_bounds(point, -3) and point.y > -0.5 and point.y < 3 and nearest_segment(point).distance < 4.0

static func tile_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

static func needed_tiles(point: Vector3, radius: int) -> Dictionary:
	var center := Vector2i(floori(point.x/CELL),floori(point.z/CELL))
	var result := {}
	for x in range(center.x-radius,center.x+radius+1):
		for z in range(center.y-radius,center.y+radius+1):
			for owner in DATA.tile_dependencies.get(tile_key(Vector2i(x,z)),[]):
				result[owner] = true
	return result

static func tile(key: String) -> Dictionary:
	if not tile_cache.has(key):
		if DATA.tiles.has(key):
			tile_cache[key] = JSON.parse_string(FileAccess.get_file_as_string(DATA.tiles[key]))
		else:
			tile_cache[key] = {"roads":[], "buildings":[], "trees":[], "parks":[], "addresses":[], "places":[]}
		tile_cache[key]["infrastructure"] = INFRASTRUCTURE.cells.get(key, [])
	return tile_cache[key]

static func nearby_features(point: Vector3, radius: int = 1) -> Dictionary:
	var result := {"roads":[],"buildings":[],"infrastructure":[]}
	for key in needed_tiles(point, radius):
		var data := tile(key)
		result.roads.append_array(data.roads)
		result.buildings.append_array(data.buildings)
		result.infrastructure.append_array(data.infrastructure)
	return result
