class_name TerrainWorld
extends Node3D

const TILE := 192
const STEP := 6
const RADIUS := 2
var patches: Dictionary = {}
var center := Vector2i(999999, 999999)
var near_material: ShaderMaterial
var far_material: ShaderMaterial

func _ready() -> void:
	near_material = ShaderMaterial.new()
	near_material.shader = load("res://assets/shaders/terrain.gdshader")
	far_material = near_material.duplicate()
	far_material.set_shader_parameter("distant", true)
	var meta := TerrainData.metadata
	var size := Vector2i(meta.columns - 1, meta.rows - 1) * STEP
	add_child(mesh_patch(TerrainData.origin, size, 48, far_material, false))
	build_sea()

func stream_at(point: Vector3) -> void:
	var cell := Vector2i(floori(point.x / TILE), floori(point.z / TILE))
	if cell == center: return
	center = cell
	var desired := {}
	for x in range(cell.x - RADIUS, cell.x + RADIUS + 1):
		for z in range(cell.y - RADIUS, cell.y + RADIUS + 1):
			var key := Vector2i(x, z)
			desired[key] = true
			if not patches.has(key):
				var patch := mesh_patch(Vector2(x, z) * TILE, Vector2i(TILE, TILE), STEP, near_material, true)
				patches[key] = patch
				add_child(patch)
	for key in patches.keys():
		if not desired.has(key):
			patches[key].visible = false
			patches[key].queue_free()
			patches.erase(key)
	far_material.set_shader_parameter("fine_bounds", Vector4((cell.x - RADIUS) * TILE, (cell.y - RADIUS) * TILE, (cell.x + RADIUS + 1) * TILE, (cell.y + RADIUS + 1) * TILE))

func mesh_patch(start: Vector2, size: Vector2i, step: int, mat: Material, collision: bool) -> Node3D:
	var nx := ceili(float(size.x) / step) + 1
	var nz := ceili(float(size.y) / step) + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()
	vertices.resize(nx * nz)
	normals.resize(nx * nz)
	colors.resize(nx * nz)
	for z in nz:
		for x in nx:
			var px := start.x + mini(x * step, size.x)
			var pz := start.y + mini(z * step, size.y)
			var ix := roundi((px - TerrainData.origin.x) / STEP)
			var iz := roundi((pz - TerrainData.origin.y) / STEP)
			colors[z * nx + x] = Color(1 if TerrainData.park_at(ix, iz) else 0, 0, 0)
			vertices[z * nx + x] = Vector3(px - start.x, TerrainData.sample(ix, iz), pz - start.y)
			normals[z * nx + x] = Vector3(TerrainData.sample(ix - 1, iz) - TerrainData.sample(ix + 1, iz), 12, TerrainData.sample(ix, iz - 1) - TerrainData.sample(ix, iz + 1)).normalized()
	for z in nz - 1:
		for x in nx - 1:
			var a := z * nx + x
			indices.append_array(PackedInt32Array([a, a + 1, a + nx + 1, a, a + nx + 1, a + nx]))
	if collision:
		# Skirts conceal the coarse/fine edge without changing playable collision.
		var border: Array[int] = []
		for x in nx: border.append(x)
		for z in range(1, nz): border.append(z * nx + nx - 1)
		for x in range(nx - 2, -1, -1): border.append((nz - 1) * nx + x)
		for z in range(nz - 2, 0, -1): border.append(z * nx)
		for i in border.size():
			var a := border[i]
			var b := border[(i + 1) % border.size()]
			var c := vertices.size()
			vertices.append(vertices[a] - Vector3.UP * 128)
			vertices.append(vertices[b] - Vector3.UP * 128)
			normals.append(normals[a])
			normals.append(normals[b])
			colors.append(colors[a])
			colors.append(colors[b])
			indices.append_array(PackedInt32Array([a,c,c+1,a,c+1,b]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = Vector3(start.x, 0, start.y)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var concave := ConcavePolygonShape3D.new()
		concave.backface_collision = true
		concave.set_faces(mesh.get_faces())
		shape.shape = concave
		body.add_child(shape)
		node.add_child(body)
	return node

func build_sea() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain/coast.json"))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for p in data.triangles:
		vertices.append(Vector3(p[0], 0, p[1]))
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sea := MeshInstance3D.new()
	sea.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/sea.gdshader")
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	var horizon := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100000, 100000)
	horizon.mesh = plane
	horizon.position.y = -0.5
	horizon.material_override = mat
	horizon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(horizon)
