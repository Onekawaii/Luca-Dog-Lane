class_name FirstPersonPlayer
extends CharacterBody3D

@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 5.4
@export var fly_speed: float = 12.0
@export var fly_boost_speed: float = 24.0
@export var fly_land_clearance: float = 1.25
@export var mouse_sensitivity: float = 0.0022
@export var touch_look_sensitivity: float = 0.0032
@export var interaction_distance: float = 3.2

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay

var virtual_move_input: Vector2 = Vector2.ZERO
var input_locked: bool = false
var _last_prompt: String = ""
var _active_vehicle: Node = null
var free_fly_enabled: bool = false
var fly_vertical_input: float = 0.0
var _saved_collision_layer: int = 1
var _saved_collision_mask: int = 1


func _ready() -> void:
	interaction_ray.target_position = Vector3(0.0, 0.0, -interaction_distance)
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	floor_max_angle = deg_to_rad(70.0)
	floor_snap_length = 0.75
	EventBus.virtual_move_input.connect(_on_virtual_move_input)
	EventBus.virtual_look_input.connect(_on_virtual_look_input)
	EventBus.first_person_interact_pressed.connect(_try_interact)
	EventBus.first_person_fly_toggle_requested.connect(toggle_free_fly)
	EventBus.first_person_fly_vertical_input.connect(_on_fly_vertical_input)
	EventBus.first_person_input_lock_changed.connect(_on_input_lock_changed)
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not input_locked:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not input_locked:
		var motion := event as InputEventMouseMotion
		_apply_look(motion.relative * mouse_sensitivity)

	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_E and not input_locked:
			_try_interact()
		elif key.keycode == KEY_R and not input_locked:
			var runtime := get_tree().root.find_child("HiveProcGenRuntime", true, false)
			if runtime != null and runtime.has_method("recover_player_now"):
				runtime.call("recover_player_now")
		elif key.keycode == KEY_F and not input_locked:
			toggle_free_fly()
		elif key.keycode == KEY_ESCAPE:
			if input_locked:
				return
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	if event is InputEventJoypadButton and event.pressed and not input_locked:
		var button := event as InputEventJoypadButton
		if button.button_index == JOY_BUTTON_A:
			_try_interact()


func _physics_process(delta: float) -> void:
	if is_instance_valid(_active_vehicle):
		global_position = _active_vehicle.global_position + Vector3(0.0, 1.32, 0.0)
		velocity = Vector3.ZERO
		return
	if free_fly_enabled:
		velocity = Vector3.ZERO
		if input_locked:
			return
		var fly_keyboard := Vector2(
			float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		)
		var fly_move_input := fly_keyboard if fly_keyboard.length_squared() > 0.001 else virtual_move_input
		if fly_move_input.length() > 1.0:
			fly_move_input = fly_move_input.normalized()
		var horizontal := global_transform.basis * Vector3(fly_move_input.x, 0.0, fly_move_input.y)
		horizontal.y = 0.0
		if horizontal.length_squared() > 0.001:
			horizontal = horizontal.normalized()
		var vertical := fly_vertical_input
		if Input.is_key_pressed(KEY_SPACE):
			vertical += 1.0
		if Input.is_key_pressed(KEY_C):
			vertical -= 1.0
		vertical = clampf(vertical, -1.0, 1.0)
		var current_fly_speed := fly_boost_speed if Input.is_key_pressed(KEY_SHIFT) else fly_speed
		global_position += (horizontal + Vector3.UP * vertical) * current_fly_speed * delta
		return
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif not input_locked and Input.is_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity

	if input_locked:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed)
		move_and_slide()
		return

	var keyboard := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	var stick := virtual_move_input
	var move_input := keyboard if keyboard.length_squared() > 0.001 else stick
	if move_input.length() > 1.0:
		move_input = move_input.normalized()

	var speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	var direction := (global_transform.basis * Vector3(move_input.x, 0.0, move_input.y))
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 8.0)

	move_and_slide()


func _process(_delta: float) -> void:
	var prompt := ""
	if is_instance_valid(_active_vehicle):
		prompt = "EXIT VEHICLE"
		if prompt != _last_prompt:
			_last_prompt = prompt
			EventBus.first_person_prompt_changed.emit(prompt)
		return
	var target := _interaction_target()
	if target != null:
		prompt = target.get_interaction_prompt()
	if prompt != _last_prompt:
		_last_prompt = prompt
		EventBus.first_person_prompt_changed.emit(prompt)


func _interaction_target() -> Node:
	if not interaction_ray.is_colliding():
		return null
	var collider := interaction_ray.get_collider()
	if collider != null and collider.has_method("interact") and collider.has_method("get_interaction_prompt"):
		return collider
	return null


func _try_interact() -> void:
	if input_locked:
		return
	if is_instance_valid(_active_vehicle):
		if _active_vehicle.has_method("request_exit"):
			_active_vehicle.call("request_exit", self)
		return
	var target := _interaction_target()
	if target != null:
		target.interact(self)


func _apply_look(delta_look: Vector2) -> void:
	rotate_y(-delta_look.x)
	head.rotation.x = clampf(head.rotation.x - delta_look.y, deg_to_rad(-85.0), deg_to_rad(85.0))


func _on_virtual_move_input(value: Vector2) -> void:
	virtual_move_input = value


func _on_virtual_look_input(value: Vector2) -> void:
	if not input_locked:
		_apply_look(value * touch_look_sensitivity)


func _on_fly_vertical_input(value: float) -> void:
	fly_vertical_input = clampf(value, -1.0, 1.0)


func toggle_free_fly() -> void:
	if input_locked:
		return
	if is_instance_valid(_active_vehicle):
		EventBus.notification_posted.emit("FLY MODE // exit the vehicle first")
		return
	if free_fly_enabled:
		_attempt_land_from_free_fly()
	else:
		_enable_free_fly()


func _enable_free_fly() -> void:
	if free_fly_enabled:
		return
	if collision_layer != 0:
		_saved_collision_layer = collision_layer
	if collision_mask != 0:
		_saved_collision_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	fly_vertical_input = 0.0
	free_fly_enabled = true
	EventBus.first_person_fly_state_changed.emit(true)
	EventBus.notification_posted.emit("FLY MODE // NOCLIP ON — use the stick to roam, ▲/▼ for height")


func _attempt_land_from_free_fly() -> void:
	if not free_fly_enabled:
		return
	var world := get_world_3d()
	if world == null:
		return
	var query := PhysicsRayQueryParameters3D.new()
	query.from = global_position + Vector3.UP * 0.5
	query.to = global_position + Vector3.DOWN * 500.0
	query.collision_mask = _saved_collision_mask
	query.exclude = [get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		EventBus.notification_posted.emit("FLY MODE // no safe surface below — still flying")
		return
	var hit_position: Vector3 = hit.get("position", global_position)
	global_position = Vector3(global_position.x, hit_position.y + fly_land_clearance, global_position.z)
	collision_layer = _saved_collision_layer
	collision_mask = _saved_collision_mask
	velocity = Vector3.ZERO
	fly_vertical_input = 0.0
	free_fly_enabled = false
	EventBus.first_person_fly_state_changed.emit(false)
	EventBus.notification_posted.emit("FLY MODE // landed — collisions restored")


func enter_vehicle(vehicle: Node) -> void:
	if free_fly_enabled:
		EventBus.notification_posted.emit("LAND FIRST // vehicle entry is disabled during noclip")
		return
	if is_instance_valid(_active_vehicle):
		return
	_active_vehicle = vehicle
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	EventBus.first_person_prompt_changed.emit("EXIT VEHICLE")

func exit_vehicle(vehicle: Node, exit_point: Vector3) -> void:
	if vehicle != _active_vehicle:
		return
	_active_vehicle = null
	global_position = exit_point
	collision_layer = _saved_collision_layer
	collision_mask = _saved_collision_mask
	velocity = Vector3.ZERO
	EventBus.first_person_prompt_changed.emit("")

func is_driving_vehicle() -> bool:
	return is_instance_valid(_active_vehicle)

func _on_input_lock_changed(locked: bool) -> void:
	input_locked = locked
	if locked:
		fly_vertical_input = 0.0
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if locked else Input.MOUSE_MODE_CAPTURED
