extends CharacterBody3D

const MAX_SPEED := 19.0
const REVERSE_SPEED := 8.0
const ACCEL := 18.0
const BRAKE := 26.0
const TURN_SPEED := 1.55
const GRAVITY := 20.0

var world_half := 480.0
var drive_input := Vector2.ZERO
var driver_active := false
var current_speed := 0.0
var camera_mode := 0

var driver_camera: Camera3D
var overhead_camera: Camera3D

func _ready() -> void:
	add_to_group("vehicle")
	_build_buggy()
	_build_cameras()

func set_driver_active(active: bool) -> void:
	driver_active = active
	if active:
		activate_camera(0)
	else:
		drive_input = Vector2.ZERO
		current_speed = move_toward(current_speed, 0.0, BRAKE * get_physics_process_delta_time())
		deactivate_cameras()

func set_drive_input(value: Vector2) -> void:
	drive_input = value.limit_length(1.0) if driver_active else Vector2.ZERO

func activate_camera(index: int) -> String:
	camera_mode = posmod(index, 2)
	driver_camera.current = camera_mode == 0
	overhead_camera.current = camera_mode == 1
	return get_camera_mode_name()

func cycle_camera() -> String:
	return activate_camera(camera_mode + 1)

func deactivate_cameras() -> void:
	if driver_camera != null:
		driver_camera.current = false
	if overhead_camera != null:
		overhead_camera.current = false

func get_camera_mode_name() -> String:
	return "DRIVER" if camera_mode == 0 else "OVERHEAD"

func _physics_process(delta: float) -> void:
	var throttle: float = -drive_input.y if driver_active else 0.0
	var target_speed := 0.0
	if throttle > 0.0:
		target_speed = throttle * MAX_SPEED
	elif throttle < 0.0:
		target_speed = throttle * REVERSE_SPEED

	var rate := ACCEL if absf(target_speed) > absf(current_speed) else BRAKE
	current_speed = move_toward(current_speed, target_speed, rate * delta)

	if driver_active and absf(current_speed) > 0.35:
		var direction_sign := 1.0 if current_speed >= 0.0 else -1.0
		rotation.y -= drive_input.x * TURN_SPEED * delta * direction_sign

	# Godot forward is -Z. Driver camera also looks -Z, so "up" on the stick
	# always moves in the same direction the driver is looking.
	var forward := -global_transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5

	move_and_slide()

	if absf(global_position.x) > world_half - 5.0:
		global_position.x = clamp(global_position.x, -world_half + 6.0, world_half - 6.0)
		current_speed = 0.0
	if absf(global_position.z) > world_half - 5.0:
		global_position.z = clamp(global_position.z, -world_half + 6.0, world_half - 6.0)
		current_speed = 0.0
	if global_position.y < -10.0:
		global_position = Vector3(13, 2, 10)
		current_speed = 0.0
		velocity = Vector3.ZERO

func _build_cameras() -> void:
	driver_camera = Camera3D.new()
	driver_camera.name = "DriverCamera"
	driver_camera.position = Vector3(-0.62, 1.78, -0.62)
	driver_camera.fov = 84.0
	driver_camera.near = 0.08
	driver_camera.current = false
	add_child(driver_camera)

	overhead_camera = Camera3D.new()
	overhead_camera.name = "OverheadCamera"
	overhead_camera.position = Vector3(0.0, 10.5, 5.0)
	overhead_camera.rotation_degrees = Vector3(-62.0, 0.0, 0.0)
	overhead_camera.fov = 78.0
	overhead_camera.near = 0.10
	overhead_camera.current = false
	add_child(overhead_camera)

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

	# Front/hood is -Z, matching Godot camera forward.
	var hood := MeshInstance3D.new()
	var hood_mesh := BoxMesh.new()
	hood_mesh.size = Vector3(2.1, 0.35, 1.15)
	hood.mesh = hood_mesh
	hood.position = Vector3(0.0, 1.22, -1.38)
	hood.material_override = _material(Color(0.20, 0.46, 0.62))
	add_child(hood)

	var cab := MeshInstance3D.new()
	var cab_mesh := BoxMesh.new()
	cab_mesh.size = Vector3(2.1, 0.85, 1.7)
	cab.mesh = cab_mesh
	cab.position = Vector3(0, 1.45, 0.15)
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

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	return material
