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

const CAMERA_NAMES := ["DRIVER", "CHASE", "HOOD", "OVERHEAD"]

var driver_camera: Camera3D
var chase_arm: SpringArm3D
var chase_camera: Camera3D
var hood_camera: Camera3D
var overhead_camera: Camera3D
var camera_nodes: Array[Camera3D] = []

func _ready() -> void:
	add_to_group("vehicle")
	floor_snap_length = 0.65
	floor_max_angle = deg_to_rad(54.0)
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
	camera_mode = posmod(index, CAMERA_NAMES.size())
	for i in range(camera_nodes.size()):
		camera_nodes[i].current = i == camera_mode
	return get_camera_mode_name()

func cycle_camera() -> String:
	return activate_camera(camera_mode + 1)

func deactivate_cameras() -> void:
	for camera in camera_nodes:
		if camera != null:
			camera.current = false

func get_camera_mode_name() -> String:
	return CAMERA_NAMES[camera_mode]

func add_camera_look(delta_pixels: Vector2) -> void:
	if camera_mode != 1 or chase_arm == null:
		return
	var sensitivity := 0.12
	var degrees := chase_arm.rotation_degrees
	degrees.y = clampf(degrees.y - delta_pixels.x * sensitivity, -115.0, 115.0)
	degrees.x = clampf(degrees.x - delta_pixels.y * sensitivity, -32.0, 8.0)
	chase_arm.rotation_degrees = degrees

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
	_update_camera_fov()

	if absf(global_position.x) > world_half - 5.0:
		global_position.x = clamp(global_position.x, -world_half + 6.0, world_half - 6.0)
		current_speed = 0.0
	if absf(global_position.z) > world_half - 5.0:
		global_position.z = clamp(global_position.z, -world_half + 6.0, world_half - 6.0)
		current_speed = 0.0
	if global_position.y < -2.0:
		global_position = Vector3(13, 2, 10)
		current_speed = 0.0
		velocity = Vector3.ZERO

func _update_camera_fov() -> void:
	var speed_ratio := clampf(absf(current_speed) / MAX_SPEED, 0.0, 1.0)
	if driver_camera != null:
		driver_camera.fov = lerpf(82.0, 90.0, speed_ratio)
	if chase_camera != null:
		chase_camera.fov = lerpf(72.0, 80.0, speed_ratio)
	if hood_camera != null:
		hood_camera.fov = lerpf(88.0, 98.0, speed_ratio)

func _build_cameras() -> void:
	driver_camera = Camera3D.new()
	driver_camera.name = "DriverCamera"
	driver_camera.position = Vector3(-0.58, 1.78, -0.42)
	driver_camera.fov = 82.0
	driver_camera.near = 0.08
	add_child(driver_camera)

	chase_arm = SpringArm3D.new()
	chase_arm.name = "ChaseSpringArm"
	chase_arm.position = Vector3(0.0, 2.55, 0.55)
	chase_arm.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	chase_arm.spring_length = 7.4
	chase_arm.margin = 0.35
	chase_arm.collision_mask = 1
	add_child(chase_arm)

	chase_camera = Camera3D.new()
	chase_camera.name = "ChaseCamera"
	chase_camera.fov = 72.0
	chase_camera.near = 0.12
	chase_arm.add_child(chase_camera)

	hood_camera = Camera3D.new()
	hood_camera.name = "HoodCamera"
	hood_camera.position = Vector3(0.0, 1.56, -2.08)
	hood_camera.rotation_degrees = Vector3(-2.0, 0.0, 0.0)
	hood_camera.fov = 88.0
	hood_camera.near = 0.05
	add_child(hood_camera)

	overhead_camera = Camera3D.new()
	overhead_camera.name = "OverheadCamera"
	overhead_camera.position = Vector3(0.0, 15.5, 5.4)
	overhead_camera.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	overhead_camera.fov = 74.0
	overhead_camera.near = 0.10
	add_child(overhead_camera)

	camera_nodes = [driver_camera, chase_camera, hood_camera, overhead_camera]
	deactivate_cameras()

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
