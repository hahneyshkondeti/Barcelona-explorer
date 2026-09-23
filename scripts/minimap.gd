class_name MiniMap
extends Control

var car: TouringCar
var navigation: RoadNavigation
const RANGE := 190.0
var cached_cell := Vector2i(99999, 99999)
var nearby: Dictionary = {}
var background := panel_style()

func _ready() -> void:
	custom_minimum_size = Vector2(184, 184)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func map_point(point: Vector3) -> Vector2:
	var center := car.global_position if is_instance_valid(car) else District.START
	return Vector2(point.x - center.x, point.z - center.z) / (RANGE * 2) * size + size * 0.5

func _draw() -> void:
	draw_style_box(background, Rect2(Vector2.ZERO, size))
	if not is_instance_valid(car):
		return
	var cell := Vector2i(floori(car.global_position.x / District.CELL), floori(car.global_position.z / District.CELL))
	if cell != cached_cell:
		cached_cell = cell
		nearby = District.nearby_features(car.global_position)
	for building in nearby.buildings:
		var p := District.vector(building.rings[0][0])
		if p.distance_to(car.global_position) > RANGE * 1.7:
			continue
		var ring := PackedVector2Array()
		for coordinate in building.rings[0]:
			ring.append(map_point(District.vector(coordinate)))
		if ring.size() > 2:
			draw_colored_polygon(ring, Color("50635f"))
	for road in nearby.roads:
		var a := map_point(District.vector(road.a))
		var b := map_point(District.vector(road.b))
		if a.distance_to(size * 0.5) < size.x or b.distance_to(size * 0.5) < size.x:
			draw_line(a, b, Color("8d9890") if road.drivable else Color("587069"), maxf(1, road.width * size.x / (RANGE * 2)), true)
	if navigation != null and navigation.active:
		for i in range(1, navigation.points.size()):
			draw_line(map_point(navigation.points[i - 1]), map_point(navigation.points[i]), Color("f6cf79"), 2, true)
		var marker := map_point(navigation.destination)
		marker = marker.clamp(Vector2(8, 8), size - Vector2(8, 8))
		draw_circle(marker, 5, Color("f6cf79"))
	var arrow := PackedVector2Array()
	for v in [Vector2(0, -7), Vector2(-5, 5), Vector2(5, 5)]:
		arrow.append(size * 0.5 + v.rotated(-car.rotation.y))
	draw_colored_polygon(arrow, Color("fff9e8"))

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("233d40")
	style.set_corner_radius_all(16)
	return style
