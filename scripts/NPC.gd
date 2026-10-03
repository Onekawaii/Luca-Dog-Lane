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
	else:
		velocity.y = 0.0
	move_and_slide()

	if abs(global_position.x) > world_half - 12.0 or abs(global_position.z) > world_half - 12.0:
		global_position.x = clamp(global_position.x, -world_half + 16.0, world_half - 16.0)
		global_position.z = clamp(global_position.z, -world_half + 16.0, world_half - 16.0)
		_choose_direction()
	if global_position.y < -8.0:
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

	var label := Label3D.new()
	label.text = display_name
	label.position = Vector3(0, 2.25, 0)
	label.font_size = 34
	label.pixel_size = 0.007
	label.outline_size = 7
	label.modulate = Color(0.92, 0.95, 0.94)
	add_child(label)

func _skin_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.62, 0.48)
	material.roughness = 0.9
	return material
