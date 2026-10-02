class_name FirstPersonPlayer
extends CharacterBody3D

@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 5.4
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
var _saved_collision_layer: int = 1
var _saved_collision_mask: int = 1


func _ready() -> void:
	interaction_ray.target_position = Vector3(0.0, 0.0, -interaction_distance)
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.45
	EventBus.virtual_move_input.connect(_on_virtual_move_input)
	EventBus.virtual_look_input.connect(_on_virtual_look_input)
	EventBus.first_person_interact_pressed.connect(_try_interact)
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


func enter_vehicle(vehicle: Node) -> void:
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
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if locked else Input.MOUSE_MODE_CAPTURED
