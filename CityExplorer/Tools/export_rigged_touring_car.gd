extends SceneTree

# Bake the original procedural meshes into a rigid-weighted vehicle skin.
# The chassis and each wheel remain distinct bones for Unreal's native vehicle animation.
func _initialize() -> void:
	call_deferred("export_car")

func meshes_below(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node)
	for child in node.get_children():
		meshes_below(child, into)

func export_car() -> void:
	var car = load("res://scripts/car.gd").new()
	root.add_child(car)
	car.set_physics_process(false)
	var scene := Node3D.new()
	scene.name = "TouringCar"
	root.add_child(scene)
	var skeleton := Skeleton3D.new()
	skeleton.name = "TouringRig"
	scene.add_child(skeleton)
	skeleton.add_bone("Root")
	skeleton.set_bone_rest(0, Transform3D.IDENTITY)
	var wheel_bones: Dictionary = {}
	var forward_basis := Basis(Vector3.UP, -PI / 2) # Unreal importer keeps X forward and swaps Y/Z.
	for node in car.body.get_children():
		if node is Node3D and not node is MeshInstance3D and not node is Light3D and node.get_child_count() == 2:
			var name := "Wheel_" + ("F" if node.position.z < 0 else "R") + ("L" if node.position.x < 0 else "R")
			var index := skeleton.get_bone_count()
			skeleton.add_bone(name)
			skeleton.set_bone_parent(index, 0)
			skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, forward_basis * node.position))
			wheel_bones[node] = index
	var skin := Skin.new()
	for i in skeleton.get_bone_count():
		skin.add_bind(i, skeleton.get_bone_global_rest(i).affine_inverse())
	var combined := ArrayMesh.new()
	var parts: Array[MeshInstance3D] = []
	meshes_below(car.body, parts)
	for part in parts:
		var bone := 0
		var parent := part.get_parent()
		while parent != car.body:
			if wheel_bones.has(parent):
				bone = wheel_bones[parent]
				break
			parent = parent.get_parent()
		var transform: Transform3D = Transform3D(forward_basis, Vector3.ZERO) * car.body.global_transform.affine_inverse() * part.global_transform
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			bones.resize(vertices.size() * 4)
			weights.resize(vertices.size() * 4)
			for i in vertices.size():
				vertices[i] = transform * vertices[i]
				if i < normals.size():
					normals[i] = (transform.basis.inverse().transposed() * normals[i]).normalized()
				bones[i * 4] = bone
				weights[i * 4] = 1
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null # Regenerated on Unreal import after rigid transform baking.
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat: Material = part.get_active_material(surface)
			combined.surface_set_material(combined.get_surface_count() - 1, mat)
	var body := MeshInstance3D.new()
	body.name = "SK_TouringCar"
	body.mesh = combined
	body.skin = skin
	body.skeleton = NodePath("..")
	skeleton.add_child(body)
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var status := document.append_from_scene(scene, state)
	if status == OK:
		status = document.write_to_filesystem(state, "res://CityExplorer/SourceAssets/TouringCarRigged.glb")
	print("CITY_EXPLORER_RIG_EXPORT: ", status, " bones=", skeleton.get_bone_count(), " surfaces=", combined.get_surface_count())
	car.queue_free()
	scene.queue_free()
	quit(0 if status == OK else 1)
