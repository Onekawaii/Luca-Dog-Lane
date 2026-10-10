extends Node3D

# Missing voxel data or collision never licenses gravity. Far actors are dormant.
const WAKE_DISTANCE := 64.0
const SLEEP_DISTANCE := 80.0
var slice: Node
var owner_body: PhysicsBody3D
var viewer: Node3D
var paused := false
var was_frozen := false
var was_processing := true
var dormant := true

func _ready() -> void:
	owner_body = get_parent() as PhysicsBody3D
	process_physics_priority = -100
	_pause()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(slice) or not is_instance_valid(owner_body):
		_pause()
		return
	var player: Node3D = slice.get("player")
	if not is_instance_valid(player):
		_pause()
		return
	if owner_body.has_method("recover_stream_position"):
		owner_body.call("recover_stream_position")
	var distance := owner_body.global_position.distance_to(player.global_position)
	if owner_body.global_position.y < preload("res://scripts/world/WorldBounds.gd").FALL_RECOVERY_Y:
		owner_body.global_position.y = preload("res://scripts/world/WorldBounds.gd").BEDROCK_TOP + 1.0
		if owner_body is CharacterBody3D:
			owner_body.velocity = Vector3.ZERO
		elif owner_body is RigidBody3D:
			owner_body.linear_velocity = Vector3.ZERO
			owner_body.angular_velocity = Vector3.ZERO
	if distance > SLEEP_DISTANCE or (dormant and distance > WAKE_DISTANCE):
		dormant = true
		_pause()
		if is_instance_valid(viewer):
			remove_child(viewer)
			viewer.queue_free()
			viewer = null
		return
	dormant = false
	if not is_instance_valid(viewer) and ClassDB.class_exists("VoxelViewer"):
		viewer = ClassDB.instantiate("VoxelViewer")
		viewer.name = "ActorCollisionViewer"
		viewer.set("view_distance", 32)
		viewer.set("requires_visuals", false)
		viewer.set("requires_collisions", true)
		add_child(viewer)
	if is_instance_valid(viewer):
		viewer.set("view_distance", slice.call("collision_view_distance", owner_body.global_position))
	if not slice.call("physics_support_ready", owner_body):
		_pause()
		return
	_resume()

func _pause() -> void:
	if paused or not is_instance_valid(owner_body):
		return
	paused = true
	if owner_body is RigidBody3D:
		was_frozen = owner_body.freeze
		owner_body.freeze = true
	else:
		was_processing = owner_body.is_physics_processing()
		owner_body.set_physics_process(false)

func _resume() -> void:
	if not paused:
		return
	if owner_body is RigidBody3D:
		owner_body.freeze = was_frozen
	else:
		owner_body.set_physics_process(was_processing)
	paused = false


func request_freeze(value: bool) -> void:
	# Holding/releasing updates the desired state while support owns suspension.
	if owner_body is RigidBody3D:
		was_frozen = value
		owner_body.freeze = true if paused else value
