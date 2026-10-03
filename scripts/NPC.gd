extends CharacterBody3D

const SPEED := 2.2
const GRAVITY := 18.0

var display_name := "Wanderer"
var world_half := 480.0
var target_direction := Vector3.ZERO
var think_time := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("npc")

	# NPCs should not body-block the player or each other.
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 0.24
	floor_max_angle = deg_to_rad(50.0)

	rng.seed = hash(name)
	_build_person()
	_choose_direction()

func _physics_process(delta: float) -> void:
	think_time -= delta
	if think_time <= 0.0:
		_choose_direction()

	velocity.x = target_direction.x * SPEED
	velocity.z = target_direction.z * SPEED

	if target_direction.length() > 0.01:
		look_at(global_position + target_direction, Vector3.UP)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	move_and_slide()

	if abs(global_position.x) > world_half - 12.0 or abs(global_position.z) > world_half - 12.0:
		global_position.x = clamp(global_position.x, -world_half + 16.0, world_half - 16.0)
		global_position.z = clamp(global_position.z, -world_half + 16.0, world_half - 16.0)
		_choose_direction()

	if global_position.y < -5.0:
		global_position.y = 2.0
		velocity = Vector3.ZERO

func _choose_direction() -> void:
	think_time = rng.randf_range(2.0, 6.0)
	if rng.randf() < 0.25:
		target_direction = Vector3.ZERO
	else:
		var angle := rng.randf_range(0.0, TAU)
		target_direction = Vector3(cos(angle), 0, sin(angle))

func describe() -> String:
	return "%s // just wandering around" % display_name

func _build_person() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.7
	collision.shape = shape
	collision.position.y = 0.85
	add_child(collision)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color.from_hsv(rng.randf(), 0.38, 0.78)
	material.roughness = 0.9

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.36
	torso_mesh.height = 1.25
	torso.mesh = torso_mesh
	torso.position.y = 0.92
	torso.material_override = material
	add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.29
	head_mesh.height = 0.58
	head.mesh = head_mesh
	head.position.y = 1.72
	head.material_override = _skin_material()
	add_child(head)


func _skin_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.62, 0.48)
	material.roughness = 0.9
	return material
