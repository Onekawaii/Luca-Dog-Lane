class_name HiveVehicle
extends CharacterBody3D

@export var vehicle_id := "vehicle.field_car.01"
@export var max_forward_speed := 18.0
@export var max_reverse_speed := 7.0
@export var acceleration := 14.0
@export var braking := 22.0
@export var steering_rate := 1.55

var _driver: Node = null
var _speed := 0.0
var _persist_timer := 0.0

func _ready() -> void:
	_build_visual_body()
	_restore_state()

func get_interaction_prompt() -> String:
	return "EXIT VEHICLE" if is_instance_valid(_driver) else "DRIVE TRAIL CAR"

func interact(player: Node) -> void:
	if is_instance_valid(_driver):
		if player == _driver:
			request_exit(player)
		return
	_driver = player
	if player.has_method("enter_vehicle"):
		player.call("enter_vehicle", self)
		EventBus.notification_posted.emit("TRAIL CAR // ready for the road")

func request_exit(player: Node) -> void:
	if player != _driver:
		return
	var exit_point := global_position + global_transform.basis.x.normalized() * 2.0 + Vector3(0.0, 0.6, 0.0)
	if player.has_method("exit_vehicle"):
		player.call("exit_vehicle", self, exit_point)
	_driver = null
	_speed = 0.0
	_persist_state()
	EventBus.notification_posted.emit("TRAIL CAR // parked")

func _physics_process(delta: float) -> void:
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	var drive_input := Vector2.ZERO
	if is_instance_valid(_driver):
		drive_input = _driver_input()
		var throttle := -drive_input.y
		var target_speed := throttle * (max_forward_speed if throttle >= 0.0 else max_reverse_speed)
		var rate := acceleration if absf(target_speed) > absf(_speed) else braking
		_speed = move_toward(_speed, target_speed, rate * delta)
		if absf(_speed) > 0.35:
			var direction_sign := 1.0 if _speed >= 0.0 else -1.0
			rotate_y(-drive_input.x * steering_rate * delta * direction_sign)
	else:
		_speed = move_toward(_speed, 0.0, braking * 0.45 * delta)
	var forward := -global_transform.basis.z.normalized()
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed
	move_and_slide()
	if get_slide_collision_count() > 0:
		_speed *= 0.62
	_persist_timer += delta
	if _persist_timer >= 0.75:
		_persist_timer = 0.0
		_persist_state()

func _driver_input() -> Vector2:
	var keyboard := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if keyboard.length_squared() > 0.001:
		return keyboard.normalized() if keyboard.length() > 1.0 else keyboard
	var stick: Variant = _driver.get("virtual_move_input")
	if typeof(stick) == TYPE_VECTOR2:
		var v := stick as Vector2
		return v.normalized() if v.length() > 1.0 else v
	return Vector2.ZERO

func _build_visual_body() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.22, 0.16, 0.25)
	body_material.metallic = 0.35
	body_material.roughness = 0.67
	var mesh := MeshInstance3D.new()
	mesh.name = "CarBody"
	var box := BoxMesh.new()
	box.size = Vector3(1.9, 0.85, 3.8)
	mesh.mesh = box
	mesh.position = Vector3(0.0, 0.85, 0.0)
	mesh.material_override = body_material
	add_child(mesh)
	var cabin := MeshInstance3D.new()
	cabin.name = "Cabin"
	var cabin_box := BoxMesh.new()
	cabin_box.size = Vector3(1.65, 0.72, 1.8)
	cabin.mesh = cabin_box
	cabin.position = Vector3(0.0, 1.48, -0.15)
	cabin.material_override = body_material
	add_child(cabin)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.15, 3.8)
	collision.shape = shape
	collision.position = Vector3(0.0, 0.72, 0.0)
	add_child(collision)
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.035, 0.035, 0.04)
	rubber.roughness = 0.94
	for wheel_pos in [
		Vector3(-1.02, 0.45, -1.25), Vector3(1.02, 0.45, -1.25),
		Vector3(-1.02, 0.45, 1.25), Vector3(1.02, 0.45, 1.25),
	]:
		var wheel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.36
		cylinder.bottom_radius = 0.36
		cylinder.height = 0.28
		wheel.mesh = cylinder
		wheel.rotation_degrees.z = 90.0
		wheel.position = wheel_pos
		wheel.material_override = rubber
		add_child(wheel)
	var tag := Label3D.new()
	tag.name = "VehicleTag"
	tag.text = "LUCA WORLD // TRAIL CAR"
	tag.position = Vector3(0.0, 1.15, 1.93)
	tag.font_size = 28
	tag.modulate = Color(0.78, 0.62, 0.92)
	add_child(tag)

func _persist_state() -> void:
	if GameRuntime.world_state == null:
		return
	var proc: Dictionary = GameRuntime.world_state.world_state.get("procedural_world", {})
	var vehicles: Dictionary = proc.get("vehicle_state", {})
	vehicles[vehicle_id] = {
		"x": global_position.x, "y": global_position.y, "z": global_position.z,
		"rotation_y": rotation.y,
	}
	proc["vehicle_state"] = vehicles
	GameRuntime.world_state.world_state["procedural_world"] = proc

func _restore_state() -> void:
	if GameRuntime.world_state == null:
		return
	var proc: Dictionary = GameRuntime.world_state.world_state.get("procedural_world", {})
	var vehicles: Dictionary = proc.get("vehicle_state", {})
	var saved: Dictionary = vehicles.get(vehicle_id, {})
	if saved.is_empty():
		return
	global_position = Vector3(
		float(saved.get("x", global_position.x)),
		float(saved.get("y", global_position.y)),
		float(saved.get("z", global_position.z))
	)
	rotation.y = float(saved.get("rotation_y", rotation.y))
