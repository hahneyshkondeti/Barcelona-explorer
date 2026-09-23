class_name WorldBuilder
extends Node3D

static var materials: Dictionary = {}
var batches: Dictionary = {}
var building_assets := BuildingAssets.new()
var is_chunk := false
var features: Dictionary = {}
var loaded_chunks: Dictionary = {}
var pending_chunks: Array = []
var stream_center := Vector2i(99999,99999)
var stream_position := Vector3.ZERO
var desired_chunks: Dictionary = {}
var surfaces: Dictionary = {}
var route_root: Node3D
var landmark_beacon: MeshInstance3D
var wall_faces := PackedVector3Array()
var unit_box := BoxMesh.new()
var pavement: ShaderMaterial
var asphalt: ShaderMaterial
var plaster: Array[ShaderMaterial] = []
var leaves: SphereMesh
var street_signs: Array[Label3D] = []
const CHUNK := 100.0

static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.85
		materials[key] = mat
	return materials[key]

static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color)
	parent.add_child(instance)
	instance.position = at
	return instance

static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color, top: float = -1) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 16
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color)
	parent.add_child(instance)
	instance.position = at
	return instance

func solid_box(size: Vector3, at: Vector3, color: Color) -> void:
	box(self, size, at, color)
	var collider := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var geometry := BoxShape3D.new()
	geometry.size = size
	shape.shape = geometry
	collider.add_child(shape)
	add_child(collider)
	collider.position = at

func _ready() -> void:
	unit_box.size = Vector3.ONE
	leaves = SphereMesh.new()
	leaves.radial_segments = 8
	leaves.rings = 4
	leaves.radius = 0.5
	leaves.height = 1
	asphalt = ShaderMaterial.new()
	asphalt.shader = load("res://assets/shaders/asphalt.gdshader")
	pavement = ShaderMaterial.new()
	pavement.shader = load("res://assets/shaders/pavement.gdshader")
	for channel in ["Color", "NormalGL", "Roughness"]:
		asphalt.set_shader_parameter(channel.to_lower(), load("res://assets/materials/asphalt/Asphalt030_1K-JPG_%s.jpg" % channel))
	for color in [Color("a89982"), Color("c2b497"), Color("b4aa99"), Color("b49a87"), Color("c8c1ac"), Color("9e998e")]:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/masonry.gdshader")
		mat.set_shader_parameter("base_color", color)
		mat.set_shader_parameter("plaster_color", load("res://assets/materials/plaster/Plaster004_1K-JPG_Color.jpg"))
		mat.set_shader_parameter("plaster_normal", load("res://assets/materials/plaster/Plaster004_1K-JPG_NormalGL.jpg"))
		mat.set_shader_parameter("plaster_roughness", load("res://assets/materials/plaster/Plaster004_1K-JPG_Roughness.jpg"))
		plaster.append(mat)
	if not is_chunk:
		build_lighting()
		var bounds := District.BOUNDS.grow(20)
		var center := bounds.get_center()
		solid_box(Vector3(bounds.size.x, 1, bounds.size.y), Vector3(center.x, -0.5, center.y), Color("92918a"))
		var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_assets.json"))
		building_assets.install(self, manifest, District.DATA.buildings, RenderingServer.get_current_rendering_method() == "mobile")
		for issue in building_assets.issues: push_warning(issue)
		var replace_landmark := false
		for building in District.DATA.buildings:
			if building.landmark and building_assets.replaced.has(building.id): replace_landmark = true
		if not replace_landmark: build_landmark()
		build_boundary()
		flush_surfaces()
		flush_batches()
		route_root = Node3D.new()
		add_child(route_root)
		var torus := TorusMesh.new()
		torus.inner_radius = 3.4
		torus.outer_radius = 3.7
		landmark_beacon = MeshInstance3D.new()
		landmark_beacon.mesh = torus
		landmark_beacon.material_override = material(Color("e7bd65"))
		add_child(landmark_beacon)
		landmark_beacon.position = District.DESTINATION + Vector3.UP * 0.05
		return
	for park in features.parks:
		flat_polygon(park.ring, 0.06, material(Color("5c7050")))
	for road in features.roads: build_road(road)
	for building in features.buildings: build_building(building)
	if not wall_faces.is_empty():
		var collider := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var geometry := ConcavePolygonShape3D.new()
		geometry.backface_collision = true
		geometry.set_faces(wall_faces)
		shape.shape = geometry
		collider.add_child(shape)
		add_child(collider)
		wall_faces.clear()
	for tree in features.trees:
		build_tree(District.vector(tree.point, 0), tree)
	build_addresses()
	build_shop_signs()
	flush_surfaces()
	flush_batches()

func load_chunk(key: String) -> void:
	if loaded_chunks.has(key): return
	var chunk := WorldBuilder.new()
	chunk.is_chunk = true
	chunk.features = District.tile(key)
	chunk.building_assets = building_assets
	loaded_chunks[key] = chunk
	add_child(chunk)

func stream_at(point: Vector3, immediate: bool = false) -> void:
	if not point.is_finite() or not District.in_bounds(point, 20): return
	stream_position = point
	var center := Vector2i(floori(point.x/District.CELL),floori(point.z/District.CELL))
	if center != stream_center or immediate:
		stream_center = center
		desired_chunks = District.needed_tiles(point, 2)
		pending_chunks.clear()
		# Near collision tiles are ready before motion/recovery can enter them.
		for key in District.needed_tiles(point, 1): load_chunk(key)
		for key in desired_chunks:
			if not loaded_chunks.has(key): pending_chunks.append(key)
		for key in loaded_chunks.keys():
			if not desired_chunks.has(key):
				loaded_chunks[key].queue_free()
				loaded_chunks.erase(key)
		for key in District.tile_cache.keys():
			if not desired_chunks.has(key): District.tile_cache.erase(key)
	if immediate:
		for key in pending_chunks: load_chunk(key)
		pending_chunks.clear()

func _process(_delta: float) -> void:
	if not is_chunk and not pending_chunks.is_empty(): load_chunk(pending_chunks.pop_front())

func build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("547da5")
	sky_mat.sky_horizon_color = Color("c8d1d4")
	sky_mat.ground_horizon_color = Color("c8d1d4")
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("bac6d3")
	env.ambient_light_energy = 0.65
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true
		env.ssao_radius = 1.8
		env.ssao_intensity = 1.6
		env.ssao_power = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color("b7c3cd")
	env.fog_density = 0.00035
	env.fog_sky_affect = 0.2
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff1d8")
	sun.light_energy = 1.2
	sun.light_angular_distance = 0.25 if RenderingServer.get_current_rendering_method() == "forward_plus" else 0.0
	sun.rotation_degrees = Vector3(-44, -115, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

func chunk_key(at: Vector3) -> String:
	return "%d:%d" % [floori(at.x / CHUNK), floori(at.z / CHUNK)]

func surface(at: Vector3, mat: Material) -> SurfaceTool:
	var key := chunk_key(at) + ":" + str(mat.get_instance_id())
	if not surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mat)
		surfaces[key] = st
	return surfaces[key]

func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, width: float, height: float) -> void:
	var vertices := [a, b, c, a, c, d]
	var uvs := [Vector2(0, 0), Vector2(width, 0), Vector2(width, height), Vector2(0, 0), Vector2(width, height), Vector2(0, height)]
	for i in 6:
		st.set_uv(uvs[i])
		st.add_vertex(vertices[i])

func strip(a: Vector3, b: Vector3, width: float, y: float, mat: Material) -> void:
	if a.distance_to(b) < 0.1:
		return
	a.y = y
	b.y = y
	var side := (b - a).normalized().cross(Vector3.UP) * width / 2
	quad(surface((a + b) / 2, mat), a - side, b - side, b + side, a + side, a.distance_to(b), width)

func build_road(road: Dictionary) -> void:
	var a := District.vector(road.a, 0)
	var b := District.vector(road.b, 0)
	if road.drivable:
		strip(a, b, road.width + 7.0, 0.065, pavement)
		strip(a, b, road.width, 0.09, asphalt)
		var length := a.distance_to(b)
		var direction := (b - a).normalized()
		var side := direction.cross(Vector3.UP)
		var inset := minf(8.0, length * 0.3)
		for offset in [-1, 1]:
			var curb_a: Vector3 = a + direction * inset + side * (road.width / 2 + 0.15) * offset
			var curb_b: Vector3 = b - direction * inset + side * (road.width / 2 + 0.15) * offset
			if length > 20:
				strip(curb_a, curb_b, 0.3, 0.115, pavement)
			strip(a + direction * inset + side * (road.width / 2 - 0.25) * offset, b - direction * inset + side * (road.width / 2 - 0.25) * offset, 0.12, 0.105, material(Color("c3c1b3")))
		# Visual markings estimated; geometry and driving graph retain source coordinates.
		if road.width >= 10:
			for d in range(3, int(length) - 4, 9):
				strip(a + direction * d, a + direction * (d + 3), 0.1, 0.106, material(Color("c3c1b3")))
		if length > 30:
			var pole: Vector3 = a.lerp(b, 0.5) + side * (road.width / 2 + 2.5)
			instance_box(Vector3(0.12, 7, 0.12), pole + Vector3.UP * 3.5, 0, Color("444b4a"), false)
			instance_box(Vector3(0.7, 0.16, 0.4), pole + Vector3.UP * 7, 0, Color("c0bab0"), false)
	else:
		strip(a, b, road.width, 0.07, pavement)

func flat_polygon(coords: Array, y: float, mat: Material) -> void:
	var polygon := PackedVector2Array()
	for p in coords:
		polygon.append(Vector2(p[0], p[1]))
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		return
	var st := surface(Vector3(polygon[0].x, 0, polygon[0].y), mat)
	for i in indices:
		st.set_uv(polygon[i])
		st.add_vertex(Vector3(polygon[i].x, y, polygon[i].y))

func build_building(building: Dictionary) -> void:
	var custom_visual := building_assets.replaced.has(building.id)
	var height: float = building.height
	var mat: ShaderMaterial = plaster[abs(hash(building.id)) % plaster.size()]
	for ring_data in building.rings:
		var ring := PackedVector2Array()
		for p in ring_data:
			ring.append(Vector2(p[0], p[1]))
		var clockwise := Geometry2D.is_polygon_clockwise(ring)
		for i in ring.size():
			var a := Vector3(ring[i].x, 0.1, ring[i].y)
			var b := Vector3(ring[(i + 1) % ring.size()].x, 0.1, ring[(i + 1) % ring.size()].y)
			var length := a.distance_to(b)
			if length < 0.1:
				continue
			var up := Vector3.UP * height
			if not custom_visual:
				quad(surface(a, mat), a, b, b + up, a + up, length, height)
			wall_faces.append_array(PackedVector3Array([a, b, b + up, a, b + up, a + up]))
			if custom_visual:
				continue
			var heading := atan2(-(b - a).z, (b - a).x)
			instance_box(Vector3(length, 0.32, 0.45), (a + b) / 2 + Vector3.UP * height, heading, Color("b9b2a2"), false)
			if ring_data != building.rings[0] or length < 3 or building.landmark:
				continue
			var mid := (a + b) / 2
			var nearest := District.nearest_segment(mid)
			var normal := (b - a).normalized().cross(Vector3.UP) * (-1 if clockwise else 1)
			# Either winding is accepted: orient details toward the adjacent road.
			if normal.dot(nearest.point - mid) < 0:
				normal = -normal
			if nearest.distance < 32:
				facade(a, b, normal, height, heading, hash(building.id))
	# Preserve courtyard openings rather than covering them with a false solid roof.
	if not custom_visual and building.rings.size() == 1:
		flat_polygon(building.rings[0], height + 0.1, material(Color("80796c")))

func facade(a: Vector3, b: Vector3, normal: Vector3, height: float, heading: float, seed_value: int) -> void:
	var length := a.distance_to(b)
	var columns := maxi(1, floori(length / 3.5))
	var floors := maxi(1, floori((height - 4) / 3.2))
	var tangent := (b - a).normalized()
	var mid := (a + b) * 0.5
	var stone := Color("b9b09b")
	for level in [3.3, height - 0.65, height - 0.25]:
		instance_box(Vector3(length, 0.18, 0.48), mid + Vector3.UP * level + normal * 0.12, heading, stone, true)
	for edge in [0.12, length - 0.12]:
		instance_box(Vector3(0.24, height - 0.5, 0.18), a + tangent * edge + Vector3.UP * height * 0.5 + normal * 0.07, heading, stone, true)
	for j in columns:
		var center := a.lerp(b, (j + 0.5) / columns) + normal * 0.09
		var awning_color := Color("4f5b51") if posmod(seed_value, 2) == 0 else Color("776052")
		instance_box(Vector3(minf(2.6, length / columns - 0.35), 2.6, 0.12), center + Vector3.UP * 1.55, heading, Color("303b3b"), true)
		instance_box(Vector3(minf(2.8, length / columns - 0.2), 0.25, 0.85), center + Vector3.UP * 3.1 + normal * 0.25, heading, awning_color, true)
		for floor_index in floors:
			var p := center + Vector3.UP * (5.5 + floor_index * 3.2)
			if p.y + 1.1 > height:
				continue
			instance_box(Vector3(1.48, 2.25, 0.15), p, heading, Color("d0c5af"), true)
			instance_box(Vector3(1.17, 1.93, 0.18), p + normal * 0.09, heading, Color("344044"), true)
			instance_box(Vector3(0.06, 1.94, 0.22), p + normal * 0.12, heading, Color("706d5f"), true)
			instance_box(Vector3(1.65, 0.12, 0.36), p + Vector3.UP * 1.15 + normal * 0.12, heading, stone, true)
			instance_box(Vector3(1.4, 0.12, 0.3), p - Vector3.UP * 1.05 + normal * 0.12, heading, stone, true)
			instance_box(Vector3(1.18, 0.05, 0.23), p + normal * 0.13, heading, Color("706d5f"), true)
			if posmod(seed_value + j, 3) == 0:
				for side in [-1, 1]:
					var shutter: Vector3 = p + tangent * side * 0.92 + normal * 0.1
					instance_box(Vector3(0.43, 1.96, 0.1), shutter, heading, Color("526054"), true)
					for slat in 8:
						instance_box(Vector3(0.4, 0.035, 0.14), shutter + Vector3.UP * (slat * 0.23 - 0.8), heading, Color("737666"), true)
			if floor_index < 4:
				var balcony := p - Vector3.UP * 1.14 + normal * 0.35
				instance_box(Vector3(1.9, 0.12, 0.8), balcony, heading, Color("a99e89"), true)
				instance_box(Vector3(1.85, 0.055, 0.055), balcony + Vector3.UP * 0.8 + normal * 0.4, heading, Color("343c3a"), true)
				for rail in [-0.8, -0.4, 0.0, 0.4, 0.8]:
					instance_box(Vector3(0.035, 0.8, 0.035), balcony + tangent * rail + Vector3.UP * 0.4 + normal * 0.4, heading, Color("343c3a"), true)

func instance_box(size: Vector3, at: Vector3, heading: float, color: Color, detail: bool) -> void:
	instance(unit_box, Transform3D(Basis(Vector3.UP, heading).scaled_local(size), at), color, detail)

func instance(mesh: Mesh, transform: Transform3D, color: Color, detail: bool) -> void:
	var key := chunk_key(transform.origin) + ":" + color.to_html() + ":" + str(mesh.get_instance_id()) + ":" + str(detail)
	if not batches.has(key):
		var origin := Vector3(floor(transform.origin.x / CHUNK) * CHUNK, 0, floor(transform.origin.z / CHUNK) * CHUNK)
		batches[key] = {"mesh": mesh, "color": color, "transforms": [], "origin": origin, "detail": detail}
	transform.origin -= batches[key].origin
	batches[key].transforms.append(transform)

func build_tree(at: Vector3, record: Dictionary = {}) -> void:
	# Trunk remains at the recorded coordinate. Species appearance is illustrative.
	if record.get("form", "broadleaf") == "palm":
		instance_box(Vector3(0.42, 8, 0.42), at + Vector3.UP * 4, 0, Color("746b55"), false)
		for frond in 10:
			var angle := frond * TAU / 10.0
			var offset := Vector3(cos(angle), 0, -sin(angle))
			instance_box(Vector3(3.5, 0.12, 0.65), at + Vector3.UP * 7.7 + offset * 1.5, angle, Color("536345"), false)
		return
	instance_box(Vector3(0.35, 5.5, 0.35), at + Vector3.UP * 2.75, 0.35, Color("5e5849"), false)
	var variation := absf(sin(at.x * 17.3 + at.z * 8.1))
	for i in 19:
		var angle := i * 2.39996 + variation * 6.28
		var radius := sqrt(float(i) / 19.0) * 2.4
		var offset := Vector3(sin(angle) * radius, 5.9 + sin(i * 1.7) * 0.7 + (1.0 - radius / 3.0), cos(angle) * radius)
		var size := Vector3(1.5, 1.7, 1.5) * (0.85 + variation * 0.35)
		var color: Color = [Color("536345"), Color("687450"), Color("465c3d")][i % 3]
		instance(leaves, Transform3D(Basis.IDENTITY.scaled(size), at + offset), color, false)

func build_landmark() -> void:
	# Original illustrative towers above the actual footprint. No scanned geometry claimed.
	var center := District.LANDMARK_CENTER
	var axis := Basis(Vector3.UP, deg_to_rad(45))
	for x in [-19, -9, 9, 19]:
		for z in [-36, 36]:
			var p: Vector3 = center + axis * Vector3(x, 0, z)
			var height := 90.0 if abs(x) == 19 else 105.0
			cylinder(self, 3.4, height, p + Vector3.UP * height / 2, Color("b4a78c"), 1.8)
			cylinder(self, 2.2, 13, p + Vector3.UP * (height + 6.5), Color("c5b79b"), 0.3)
			for y in range(45, int(height), 6):
				var ring := TorusMesh.new()
				ring.inner_radius = 2.2
				ring.outer_radius = 2.6
				var rib := MeshInstance3D.new()
				rib.mesh = ring
				rib.material_override = material(Color("867c68"))
				add_child(rib)
				rib.position = p + Vector3.UP * y
	cylinder(self, 9, 130, center + Vector3.UP * 65, Color("bfb096"), 2.0)
	cylinder(self, 3.5, 25, center + Vector3.UP * 142.5, Color("cfc6ae"), 0.7)
	box(self, Vector3(1.2, 12, 1.2), center + Vector3.UP * 161, Color("ddd7bf"))
	box(self, Vector3(8, 1.2, 1.2), center + Vector3.UP * 164, Color("ddd7bf"))

func build_addresses() -> void:
	# Ground-level plaques display supplied address tags only. Missing fields stay missing.
	for address in features.addresses:
		if address.street.is_empty():
			continue
		var at := District.vector(address.point, 2.5)
		var label := Label3D.new()
		label.text = address.number
		label.font_size = 32
		label.pixel_size = 0.013
		label.modulate = Color("e2dccb")
		label.outline_modulate = Color("3a4140")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.visibility_range_end = 25
		label.no_depth_test = false
		add_child(label)
		label.position = at
	for road in features.roads:
		var a := District.vector(road.a, 0)
		var b := District.vector(road.b, 0)
		if a.distance_to(b) < 45:
			continue
		var sign := Label3D.new()
		sign.text = road.name
		sign.font_size = 32
		sign.pixel_size = 0.025
		sign.modulate = Color("dedbd0")
		sign.outline_modulate = Color("252e30")
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.visibility_range_end = 55
		add_child(sign)
		sign.position = (a + b) / 2 + Vector3.UP * 4

func build_boundary() -> void:
	var rect := District.BOUNDS
	var c := rect.get_center()
	for x in [rect.position.x, rect.end.x]:
		solid_box(Vector3(0.6, 1, rect.size.y), Vector3(x, 0.5, c.y), Color("706e63"))
	for z in [rect.position.y, rect.end.y]:
		solid_box(Vector3(rect.size.x, 1, 0.6), Vector3(c.x, 0.5, z), Color("706e63"))

func flush_surfaces() -> void:
	for st in surfaces.values():
		st.generate_normals()
		st.generate_tangents()
		var node := MeshInstance3D.new()
		node.mesh = st.commit()
		add_child(node)
	surfaces.clear()

func flush_batches() -> void:
	for batch in batches.values():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = batch.mesh
		multi.instance_count = batch.transforms.size()
		for i in batch.transforms.size():
			multi.set_instance_transform(i, batch.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.material_override = material(batch.color)
		if batch.color == Color("344044") or batch.color == Color("303b3b"):
			var glass := ShaderMaterial.new()
			glass.shader = load("res://assets/shaders/glass.gdshader")
			node.material_override = glass
		if batch.mesh == leaves:
			var foliage := ShaderMaterial.new()
			foliage.shader = load("res://assets/shaders/foliage.gdshader")
			foliage.set_shader_parameter("leaf_color", batch.color)
			node.material_override = foliage
		node.position = batch.origin
		node.visibility_range_end = 180 if batch.detail else 420
		node.visibility_range_end_margin = 20
		add_child(node)
	batches.clear()

func update_route(points: PackedVector3Array) -> void:
	for child in route_root.get_children():
		child.queue_free()
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		if Geometry2D.get_closest_point_to_segment(Vector2(stream_position.x,stream_position.z),Vector2(a.x,a.z),Vector2(b.x,b.z)).distance_to(Vector2(stream_position.x,stream_position.z)) > 450: continue
		var length := a.distance_to(b)
		if length < 0.1:
			continue
		var line := box(route_root, Vector3(0.18, 0.015, length), (a + b) / 2, Color("d3ae6b"))
		line.position.y = 0.12
		line.look_at(Vector3(b.x, 0.12, b.z), Vector3.UP)

func build_shop_signs() -> void:
	for shop in features.places:
		if shop.name.begins_with("Unnamed"):
			continue
		var at := District.vector(shop.point, 3.4)
		var road := District.nearest_segment(at)
		if road.distance > 30:
			continue
		var facing: Vector3 = (road.point - Vector3(at.x, 0.55, at.z)).normalized()
		if facing.length() < 0.1:
			continue
		var sign := Label3D.new()
		sign.text = str(shop.name).left(42)
		sign.font_size = 32
		sign.pixel_size = minf(0.012, 0.22 / maxf(8, sign.text.length()))
		sign.modulate = Color("e4dbc2")
		sign.outline_modulate = Color("333e3b")
		sign.outline_size = 8
		sign.visibility_range_end = 40
		add_child(sign)
		sign.position = at + facing * 0.25
		sign.look_at(sign.position + facing, Vector3.UP)
