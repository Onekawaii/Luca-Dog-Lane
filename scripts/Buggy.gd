extends CharacterBody3D

const MAX_SPEED := 18.0
const ACCEL := 22.0
const TURN_SPEED := 1.7
const GRAVITY := 20.0

var world_half := 480.0
var drive_input := Vector2.ZERO
var driver_active := false
var current_speed := 0.0

func _ready() -> void:
	add_to_group("vehicle")
	_build_buggy()

func set_driver_active(active: bool) -> void:
	driver_active = active
	if not active:
		drive_input = Vector2.ZERO

func set_drive_input(value: Vector2) -> void:
	drive_input = value.limit_length(1.0) if driver_active else Vector2.ZERO

func _physics_process(delta: float) -> void:
	var throttle := -drive_input.y if driver_active else 0.0
	var target_speed := throttle * MAX_SPEED
	current_speed = move_toward(current_speed, target_speed, ACCEL * delta)

	if driver_active and abs(current_speed) > 0.4:
		var direction_sign := 1.0 if current_speed >= 0.0 else -1.0
		rotation.y -= drive_input.x * TURN_SPEED * delta * direction_sign

	var forward := -global_transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()

	if abs(global_position.x) > world_half - 5.0:
		global_position.x = clamp(global_position.x, -world_half + 6.0, world_half - 6.0)
		current_speed = 0.0
	if abs(global_position.z) > world_half - 5.0:
		global_position.z = clamp(global_position.z, -world_half + 6.0, world_half - 6.0)
		current_speed = 0.0
	if global_position.y < -10.0:
		global_position = Vector3(13, 2, 10)
		current_speed = 0.0
		velocity = Vector3.ZERO

func _build_buggy() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 1.1, 4.2)
	collision.shape = shape
	collision.position.y = 0.65
	add_child(collision)

	var chassis := MeshInstance3D.new()
	var chassis_mesh := BoxMesh.new()
	chassis_mesh.size = Vector3(2.5, 0.75, 4.2)
	chassis.mesh = chassis_mesh
	chassis.position.y = 0.75
	chassis.material_override = _material(Color(0.14, 0.32, 0.48))
	add_child(chassis)

	var cab := MeshInstance3D.new()
	var cab_mesh := BoxMesh.new()
	cab_mesh.size = Vector3(2.1, 0.85, 1.7)
	cab.mesh = cab_mesh
	cab.position = Vector3(0, 1.45, -0.35)
	cab.material_override = _material(Color(0.20, 0.46, 0.62))
	add_child(cab)

	for x in [-1.30, 1.30]:
		for z in [-1.35, 1.35]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.48
			wheel_mesh.bottom_radius = 0.48
			wheel_mesh.height = 0.34
			wheel.mesh = wheel_mesh
			wheel.position = Vector3(x, 0.48, z)
			wheel.rotation_degrees.z = 90
			wheel.material_override = _material(Color(0.035, 0.04, 0.04))
			add_child(wheel)

	var label := Label3D.new()
	label.text = "SANDBOX BUGGY"
	label.position = Vector3(0, 2.35, 0)
	label.font_size = 30
	label.pixel_size = 0.008
	label.outline_size = 7
	add_child(label)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	return material
