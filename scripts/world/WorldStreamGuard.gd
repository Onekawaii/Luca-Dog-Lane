extends Node3D

# Collision-only bubbles protect remote actors without rendering distant chunks.
var slice: Node
var owner_body: Node3D
var paused := false
var was_frozen := false

func _ready() -> void:
	owner_body = get_parent()
	var viewer = ClassDB.instantiate("VoxelViewer")
	viewer.name = "ActorCollisionViewer"
	viewer.set("view_distance", 24)
	viewer.set("requires_visuals", false)
	viewer.set("requires_collisions", true)
	add_child(viewer)
	_pause()

func _physics_process(_delta: float) -> void:
	if slice == null or not is_instance_valid(slice):
		return
	var at := owner_body.global_position
	if not slice.call("_is_editable", Vector3i(at)):
		_pause()
		return
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at - Vector3.UP * 24.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var voxel_floor = slice.get("voxel_tool").call("raycast", query.from, Vector3.DOWN, 26.0)
	if voxel_floor != null and hit.is_empty():
		_pause()
		return
	if paused:
		if owner_body is RigidBody3D:
			owner_body.freeze = was_frozen
		else:
			owner_body.set_physics_process(true)
		paused = false

func _pause() -> void:
	if paused:
		return
	paused = true
	if owner_body is RigidBody3D:
		was_frozen = owner_body.freeze
		owner_body.freeze = true
	else:
		owner_body.set_physics_process(false)
