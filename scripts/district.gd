class_name District
extends RefCounted

const ID := "sagrada_osm_v2"
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

static func _static_init() -> void:
	DATA = JSON.parse_string(FileAccess.get_file_as_string("res://data/eixample.json"))
	TREE_DATA = JSON.parse_string(FileAccess.get_file_as_string("res://data/trees.json"))
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

static func vector(point: Array, y: float = 0.55) -> Vector3:
	return Vector3(point[0], y, point[1])

static func nearest_segment(point: Vector3) -> Dictionary:
	var best := {}
	var distance := INF
	var p := Vector2(point.x, point.z)
	for road in ROAD_SEGMENTS:
		var q := Geometry2D.get_closest_point_to_segment(p, Vector2(road.a[0], road.a[1]), Vector2(road.b[0], road.b[1]))
		var d := p.distance_squared_to(q)
		if d < distance:
			distance = d
			best = {"road": road, "point": Vector3(q.x, 0.55, q.y), "distance": sqrt(d)}
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
