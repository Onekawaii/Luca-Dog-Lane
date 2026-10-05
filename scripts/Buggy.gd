extends VehicleBody3D

const ENGINE_FORCE_MAX := 1450.0
const REVERSE_FORCE_MAX := 900.0
const BRAKE_FORCE := 52.0
const COAST_BRAKE := 14.0
const MAX_STEER := 0.46
const STEER_RESPONSE := 2.8
const RESET_Y := -2.5
const IMPACT_MIN_SPEED := 4.0

var world_half := 480.0
var drive_input := Vector2.ZERO
var driver_active := false
var camera_mode := 0
var impact_cooldowns: Dictionary = {}

const CAMERA_NAMES := ["DRIVER", "CHASE", "HOOD", "OVERHEAD"]

var driver_camera: Camera3D
var chase_arm: SpringArm3D
var chase_camera: Camera3D
var hood_camera: Camera3D
var overhead_camera: Camera3D
var camera_nodes: Array[Camera3D] = []
var wheel_nodes: Array[VehicleWheel3D] = []

func _ready() -> void:
	add_to_group("vehicle")
	collision_layer = 16
	collision_mask = 1 | 8
	mass = 620.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 12
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.34, 0.15)
	body_entered.connect(_on_body_entered)
	_build_buggy()
	_build_wheels()
	_build_cameras()

func set_driver_active(active: bool) -> void:
	driver_active = active
	if active:
		activate_camera(0)
	else:
		drive_input = Vector2.ZERO
		engine_force = 0.0
		brake = COAST_BRAKE
		steering = 0.0
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
	_tick_impact_cooldowns(delta)

	if driver_active:
		var throttle := -drive_input.y
		var target_force := 0.0
		if throttle > 0.03:
			target_force = -throttle * ENGINE_FORCE_MAX
		elif throttle < -0.03:
			target_force = -throttle * REVERSE_FORCE_MAX
		engine_force = target_force
		brake = COAST_BRAKE if absf(throttle) <= 0.03 else 0.0
		var target_steer := -drive_input.x * MAX_STEER
		steering = move_toward(steering, target_steer, STEER_RESPONSE * delta)
	else:
		engine_force = 0.0
		brake = BRAKE_FORCE
		steering = move_toward(steering, 0.0, STEER_RESPONSE * delta)

	_update_camera_fov()

	if (
		absf(global_position.x) > world_half - 5.0
		or absf(global_position.z) > world_half - 5.0
		or global_position.y < RESET_Y
	):
		_reset_vehicle(Vector3(13.0, 0.18, 10.0))

func _reset_vehicle(at: Vector3) -> void:
	global_position = at
	global_rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	engine_force = 0.0
	brake = BRAKE_FORCE
	steering = 0.0
	sleeping = false

func _tick_impact_cooldowns(delta: float) -> void:
	for key in impact_cooldowns.keys():
		var remaining := float(impact_cooldowns[key]) - delta
		if remaining <= 0.0:
			impact_cooldowns.erase(key)
		else:
			impact_cooldowns[key] = remaining

func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("npc") or not body.has_method("take_damage"):
		return
	var id := body.get_instance_id()
	if impact_cooldowns.has(id):
		return
	var speed := linear_velocity.length()
	if speed < IMPACT_MIN_SPEED:
		return
	var damage := clampf((speed - 3.0) * 7.5, 8.0, 80.0)
	var direction := linear_velocity.normalized()
	body.call(
		"take_damage",
		damage,
		direction * clampf(speed * 0.55, 3.0, 9.0),
		global_position
	)
	impact_cooldowns[id] = 0.65

func get_wheel_contact_count_for_test() -> int:
	var count := 0
	for wheel in wheel_nodes:
		if wheel.is_in_contact():
			count += 1
	return count

func get_vehicle_speed_for_test() -> float:
	return linear_velocity.length()

func _update_camera_fov() -> void:
	var speed_ratio := clampf(linear_velocity.length() / 22.0, 0.0, 1.0)
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
	collision.name = "ChassisCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.35, 0.82, 3.85)
	collision.shape = shape
	collision.position = Vector3(0.0, 0.78, 0.0)
	add_child(collision)

	var chassis := MeshInstance3D.new()
	chassis.name = "Chassis"
	var chassis_mesh := BoxMesh.new()
	chassis_mesh.size = Vector3(2.45, 0.68, 3.9)
	chassis.mesh = chassis_mesh
	chassis.position = Vector3(0.0, 0.84, 0.05)
	chassis.material_override = _material(Color(0.10, 0.28, 0.48))
	add_child(chassis)

	var hood := MeshInstance3D.new()
	hood.name = "Hood"
	var hood_mesh := BoxMesh.new()
	hood_mesh.size = Vector3(2.05, 0.28, 1.18)
	hood.mesh = hood_mesh
	hood.position = Vector3(0.0, 1.22, -1.28)
	hood.material_override = _material(Color(0.16, 0.43, 0.68))
	add_child(hood)

	var cab := MeshInstance3D.new()
	cab.name = "Cab"
	var cab_mesh := BoxMesh.new()
	cab_mesh.size = Vector3(1.95, 0.72, 1.42)
	cab.mesh = cab_mesh
	cab.position = Vector3(0.0, 1.43, 0.22)
	cab.material_override = _material(Color(0.18, 0.48, 0.72))
	add_child(cab)

	var bumper := MeshInstance3D.new()
	bumper.name = "FrontBumper"
	var bumper_mesh := BoxMesh.new()
	bumper_mesh.size = Vector3(2.42, 0.20, 0.18)
	bumper.mesh = bumper_mesh
	bumper.position = Vector3(0.0, 0.58, -2.02)
	bumper.material_override = _material(Color(0.10, 0.11, 0.12))
	add_child(bumper)

func _build_wheels() -> void:
	_add_wheel("FrontLeft", Vector3(-1.12, 0.62, -1.38), true)
	_add_wheel("FrontRight", Vector3(1.12, 0.62, -1.38), true)
	_add_wheel("RearLeft", Vector3(-1.12, 0.62, 1.30), false)
	_add_wheel("RearRight", Vector3(1.12, 0.62, 1.30), false)

func _add_wheel(label: String, at: Vector3, steering_wheel: bool) -> void:
	var wheel := VehicleWheel3D.new()
	wheel.name = label
	wheel.position = at
	wheel.wheel_radius = 0.48
	wheel.wheel_rest_length = 0.30
	wheel.suspension_travel = 0.22
	wheel.suspension_stiffness = 7.5
	wheel.suspension_max_force = 7800.0
	wheel.damping_compression = 0.75
	wheel.damping_relaxation = 0.88
	wheel.wheel_friction_slip = 4.6
	wheel.use_as_steering = steering_wheel
	wheel.use_as_traction = true
	add_child(wheel)

	var visual := MeshInstance3D.new()
	visual.name = "WheelVisual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.48
	mesh.bottom_radius = 0.48
	mesh.height = 0.34
	mesh.radial_segments = 16
	visual.mesh = mesh
	visual.rotation_degrees.z = 90.0
	visual.material_override = _material(Color(0.025, 0.03, 0.035))
	wheel.add_child(visual)
	wheel_nodes.append(wheel)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
