class_name ChaseCamera
extends Camera3D

var target: TouringCar
var snapped := false

func _ready() -> void:
	fov = 64
	near = 0.15
	far = 520
	current = true

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var focus := target.global_position + Vector3.UP * 1.7
	var desired := target.global_position + target.global_transform.basis.z * 9.8 + Vector3.UP * 5.6
	# Shorten the boom against buildings; never look through a façade.
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.5
	var smoothed := desired if not snapped else global_position.lerp(desired, 1 - exp(-6 * delta))
	query.to = smoothed
	hit = get_world_3d().direct_space_state.intersect_ray(query)
	global_position = smoothed if hit.is_empty() else hit.position + hit.normal * 0.5
	look_at(focus + -target.global_transform.basis.z * 2, Vector3.UP)
	snapped = true

func reset() -> void:
	snapped = false
	_physics_process(0)
