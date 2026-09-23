class_name RoadNavigation
extends RefCounted

var active := true
var points := PackedVector3Array()
var destination := District.DESTINATION
var destination_name := District.TITLE
var reachable := true
var graph := AStar3D.new()
var ids: Dictionary = {}
var routed_destination := Vector3.INF
var search_count := 0

func _init() -> void:
	for key in District.DATA.graph.nodes:
		var id := ids.size()
		ids[key] = id
		graph.add_point(id, District.vector(District.DATA.graph.nodes[key]))
	for edge in District.DATA.graph.edges:
		var a: int = ids[edge[0]]
		var b: int = ids[edge[1]]
		if edge[2] == -1:
			graph.connect_points(b, a, false)
		else:
			graph.connect_points(a, b, edge[2] == 0)

func route(from: Vector3) -> PackedVector3Array:
	# Trim the existing directed route while following it; search again after a
	# deviation or destination change. Only consider nearby progress, not later
	# crossings of the same road in a long route.
	if active and destination == routed_destination and points.size() > 1:
		var travelled := 0.0
		var closest := INF
		var segment := -1
		var projected := Vector3.ZERO
		for i in range(1, points.size()):
			var q := Geometry3D.get_closest_point_to_segment(from, points[i - 1], points[i])
			var distance := from.distance_to(q)
			if distance < closest:
				closest = distance
				segment = i
				projected = q
			travelled += points[i - 1].distance_to(points[i])
			if travelled > 160: break
		if closest < 8.0:
			var remaining := PackedVector3Array([projected])
			remaining.append_array(points.slice(segment))
			points = remaining
			return points
	points.clear()
	reachable = true
	if not active:
		return points
	routed_destination = destination
	search_count += 1
	var start := District.nearest_segment(from)
	var finish := District.nearest_segment(destination)
	var sr: Dictionary = start.road
	var dr: Dictionary = finish.road
	var best_cost := INF
	var best := PackedVector3Array()
	# Same segment can be traveled directly only in a permitted direction.
	if sr.id == dr.id:
		var forward := District.vector(sr.b) - District.vector(sr.a)
		var progress: float = (finish.point - start.point).dot(forward)
		if sr.oneway == 0 or (sr.oneway == 1 and progress >= 0) or (sr.oneway == -1 and progress <= 0):
			best = PackedVector3Array([start.point, finish.point])
			best_cost = start.point.distance_to(finish.point)
	var starts: Array = [sr.a_id, sr.b_id] if sr.oneway == 0 else [sr.b_id if sr.oneway == 1 else sr.a_id]
	var ends: Array = [dr.a_id, dr.b_id] if dr.oneway == 0 else [dr.a_id if dr.oneway == 1 else dr.b_id]
	for a in starts:
		for b in ends:
			var path := graph.get_point_path(ids[a], ids[b])
			if path.is_empty():
				continue
			var cost: float = start.point.distance_to(path[0]) + finish.point.distance_to(path[-1])
			for i in range(1, path.size()):
				cost += path[i - 1].distance_to(path[i])
			if cost < best_cost:
				best_cost = cost
				best = PackedVector3Array([start.point])
				best.append_array(path)
				best.append(finish.point)
	for p in best:
		if points.is_empty() or points[-1].distance_to(p) > 0.1:
			points.append(p)
	reachable = not points.is_empty()
	return points

func distance_remaining() -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total
