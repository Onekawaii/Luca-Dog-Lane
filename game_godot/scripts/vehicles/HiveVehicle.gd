class_name HiveVehicle
extends CharacterBody3D

@export var vehicle_id := "vehicle.field_car.01"
@export var max_forward_speed := 18.0
@export var max_reverse_speed := 7.0
@export var acceleration := 14.0
@export var braking := 22.0
@export var steering_rate := 1.55
@export var max_health := 100.0

var health := 100.0
var _driver: Node = null
var _speed := 0.0
var _persist_timer := 0.0
var _impact_cooldown := 0.0
var _body_material: StandardMaterial3D
var _glass_material: StandardMaterial3D
var _hood: MeshInstance3D
var _damage_label: Label3D

func _ready() -> void:
	health = max_health
	_build_visual_body()
	_restore_state()
	_update_damage_visuals()

func get_interaction_prompt() -> String:
	if health <= 0.0:
		return "TRAIL CAR DISABLED"
	if is_instance_valid(_driver):
		return "EXIT VEHICLE"
	return "DRIVE TRAIL CAR // %d%%" % int(round(health))

func interact(player: Node) -> void:
	if health <= 0.0:
		EventBus.notification_posted.emit("TRAIL CAR // disabled by damage")
		return
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
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	var drive_input := Vector2.ZERO
	if is_instance_valid(_driver) and health > 0.0:
		drive_input = _driver_input()
		var throttle := -drive_input.y
		var condition := lerpf(0.38, 1.0, clampf(health / max_health, 0.0, 1.0))
		var target_speed := throttle * (max_forward_speed if throttle >= 0.0 else max_reverse_speed) * condition
		var rate := acceleration if absf(target_speed) > absf(_speed) else braking
		_speed = move_toward(_speed, target_speed, rate * delta)
		if absf(_speed) > 0.35:
			var direction_sign := 1.0 if _speed >= 0.0 else -1.0
			rotate_y(-drive_input.x * steering_rate * delta * direction_sign)
	else:
		_speed = move_toward(_speed, 0.0, braking * 0.45 * delta)
	var impact_speed := absf(_speed)
	var forward := -global_transform.basis.z.normalized()
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed
	move_and_slide()
	if get_slide_collision_count() > 0:
		_apply_impact_damage(impact_speed)
		_speed *= 0.48
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
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Color(0.17, 0.23, 0.27)
	_body_material.metallic = 0.48
	_body_material.roughness = 0.54
	_glass_material = StandardMaterial3D.new()
	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.albedo_color = Color(0.08, 0.16, 0.20, 0.72)
	_glass_material.metallic = 0.18
	_glass_material.roughness = 0.18
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.025, 0.027, 0.03)
	rubber.roughness = 0.97
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.32, 0.34, 0.36)
	chrome.metallic = 0.82
	chrome.roughness = 0.25

	_add_box_part("LowerBody", Vector3(1.92, 0.54, 3.90), Vector3(0.0, 0.72, 0.0), _body_material)
	_hood = _add_box_part("Hood", Vector3(1.78, 0.28, 1.24), Vector3(0.0, 1.08, -1.23), _body_material)
	_add_box_part("Trunk", Vector3(1.76, 0.34, 0.92), Vector3(0.0, 1.03, 1.36), _body_material)
	_add_box_part("Roof", Vector3(1.48, 0.18, 1.52), Vector3(0.0, 1.78, 0.05), _body_material)
	_add_box_part("Windshield", Vector3(1.44, 0.58, 0.08), Vector3(0.0, 1.49, -0.73), _glass_material, Vector3(deg_to_rad(-17.0), 0.0, 0.0))
	_add_box_part("RearGlass", Vector3(1.44, 0.52, 0.08), Vector3(0.0, 1.47, 0.82), _glass_material, Vector3(deg_to_rad(16.0), 0.0, 0.0))
	for side in [-1.0, 1.0]:
		_add_box_part("SideGlass", Vector3(0.06, 0.48, 1.24), Vector3(0.77 * side, 1.48, 0.05), _glass_material)
		_add_box_part("Bumper", Vector3(0.12, 0.24, 1.92), Vector3(0.97 * side, 0.64, 0.0), chrome)
	for z in [-1.28, 1.28]:
		for side in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel"
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.39
			cylinder.bottom_radius = 0.39
			cylinder.height = 0.32
			wheel.mesh = cylinder
			wheel.rotation_degrees.z = 90.0
			wheel.position = Vector3(1.03 * side, 0.47, z)
			wheel.material_override = rubber
			add_child(wheel)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.95, 1.30, 3.9)
	collision.shape = shape
	collision.position = Vector3(0.0, 0.82, 0.0)
	add_child(collision)

	_damage_label = Label3D.new()
	_damage_label.name = "VehicleCondition"
	_damage_label.position = Vector3(0.0, 1.20, 2.02)
	_damage_label.font_size = 22
	_damage_label.modulate = Color(0.78, 0.88, 0.92)
	add_child(_damage_label)


func _add_box_part(node_name: String, size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.rotation = rot
	mesh.material_override = material
	add_child(mesh)
	return mesh


func _apply_impact_damage(impact_speed: float) -> void:
	if _impact_cooldown > 0.0 or impact_speed < 6.5 or health <= 0.0:
		return
	_impact_cooldown = 0.65
	var damage := clampf((impact_speed - 6.5) * 3.2, 2.0, 42.0)
	health = maxf(0.0, health - damage)
	_update_damage_visuals()
	_persist_state()
	EventBus.notification_posted.emit("TRAIL CAR // IMPACT // %d%% condition" % int(round(health)))
	if health <= 0.0 and is_instance_valid(_driver):
		var current_driver := _driver
		request_exit(current_driver)
		EventBus.notification_posted.emit("TRAIL CAR // disabled")


func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_update_damage_visuals()
	_persist_state()


func _update_damage_visuals() -> void:
	var ratio := clampf(health / max_health, 0.0, 1.0)
	if is_instance_valid(_body_material):
		_body_material.albedo_color = Color(0.10, 0.11, 0.12).lerp(Color(0.17, 0.23, 0.27), ratio)
		_body_material.roughness = lerpf(0.88, 0.54, ratio)
	if is_instance_valid(_hood):
		_hood.rotation.x = deg_to_rad((1.0 - ratio) * 7.0)
		_hood.position.y = 1.08 - (1.0 - ratio) * 0.08
	if is_instance_valid(_damage_label):
		_damage_label.text = "TRAIL CAR // %d%%" % int(round(health))
		_damage_label.modulate = Color(1.0 - ratio * 0.25, 0.28 + ratio * 0.60, 0.22 + ratio * 0.70)

func _persist_state() -> void:
	if GameRuntime.world_state == null:
		return
	var proc: Dictionary = GameRuntime.world_state.world_state.get("procedural_world", {})
	var vehicles: Dictionary = proc.get("vehicle_state", {})
	vehicles[vehicle_id] = {
		"x": global_position.x, "y": global_position.y, "z": global_position.z,
		"rotation_y": rotation.y,
		"health": health,
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
	health = clampf(float(saved.get("health", health)), 0.0, max_health)
