extends CharacterBody3D

const WALK_SPEED := 8.5
const SPRINT_SPEED := 13.5
const NOCLIP_SPEED := 18.0
const JUMP_SPEED := 7.2
const GRAVITY := 19.0
const SAFE_MARGIN := 16.0
const TOOL_MODES := ["GRAB", "REMOVE", "DUPLICATE", "INSPECT"]

var game: Node
var hud: CanvasLayer
var pivot: Node3D
var camera: Camera3D
var body_collision: CollisionShape3D
var touch_move := Vector2.ZERO
var vertical_axis := 0.0
var jump_requested := false
var yaw := 0.0
var pitch := -0.08
var noclip := false
var tool_index := 0
var held_body: RigidBody3D
var riding: CharacterBody3D

func _ready() -> void:
	add_to_group("player")
	body_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.8
	body_collision.shape = shape
	body_collision.position.y = 0.9
	add_child(body_collision)

	pivot = Node3D.new()
	pivot.name = "ViewPivot"
	pivot.position = Vector3(0, 1.58, 0)
	add_child(pivot)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.fov = 76.0
	camera.near = 0.05
	pivot.add_child(camera)
	rotation.y = yaw
	pivot.rotation.x = pitch

	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if riding != null and is_instance_valid(riding):
		_process_vehicle()
		_recover_if_outside()
		return
	if riding != null and not is_instance_valid(riding):
		riding = null
		body_collision.set_deferred("disabled", noclip)

	var input_vec := _combined_move_input()
	if noclip:
		_process_noclip(input_vec, delta)
	else:
		_process_walk(input_vec, delta)

	if held_body != null:
		if is_instance_valid(held_body):
			var target := camera.global_position - camera.global_transform.basis.z * 4.0
			held_body.global_position = held_body.global_position.lerp(target, min(delta * 14.0, 1.0))
			held_body.linear_velocity = Vector3.ZERO
			held_body.angular_velocity = Vector3.ZERO
		else:
			held_body = null
	_recover_if_outside()

func _combined_move_input() -> Vector2:
	var value := touch_move
	if Input.is_key_pressed(KEY_A):
		value.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		value.x += 1.0
	if Input.is_key_pressed(KEY_W):
		value.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		value.y += 1.0
	return value.limit_length(1.0)

func _process_walk(input_vec: Vector2, delta: float) -> void:
	var direction := (global_transform.basis.x * input_vec.x + global_transform.basis.z * input_vec.y)
	direction.y = 0.0
	direction = direction.normalized()
	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction.x * speed, 30.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 30.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if (jump_requested or Input.is_key_pressed(KEY_SPACE)) and is_on_floor():
		velocity.y = JUMP_SPEED
	jump_requested = false
	move_and_slide()

func _process_noclip(input_vec: Vector2, delta: float) -> void:
	var flat_forward := -global_transform.basis.z
	var flat_right := global_transform.basis.x
	var direction := flat_right * input_vec.x + flat_forward * -input_vec.y
	var vertical := vertical_axis
	if Input.is_key_pressed(KEY_SPACE):
		vertical += 1.0
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C):
		vertical -= 1.0
	direction += Vector3.UP * vertical
	if direction.length() > 1.0:
		direction = direction.normalized()
	global_position += direction * NOCLIP_SPEED * delta
	velocity = Vector3.ZERO

func _process_vehicle() -> void:
	var input_vec := _combined_move_input()
	riding.call("set_drive_input", input_vec)
	global_position = riding.global_position + Vector3(0, 2.5, 0)
	velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look_delta(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E:
		use_tool()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		cycle_tool()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_V:
		toggle_noclip()

func add_look_delta(delta_pixels: Vector2) -> void:
	var sensitivity := 0.0032
	yaw -= delta_pixels.x * sensitivity
	pitch = clamp(pitch - delta_pixels.y * sensitivity, -1.48, 1.48)
	rotation.y = yaw
	pivot.rotation.x = pitch

func set_touch_move(value: Vector2) -> void:
	touch_move = value.limit_length(1.0)

func set_vertical_input(value: float) -> void:
	vertical_axis = clamp(value, -1.0, 1.0)
	if value > 0.0 and not noclip:
		jump_requested = true

func cycle_tool() -> void:
	if held_body != null:
		_release_held()
	tool_index = (tool_index + 1) % TOOL_MODES.size()
	if hud != null:
		hud.call("set_tool_mode", TOOL_MODES[tool_index])

func toggle_noclip() -> void:
	if riding != null:
		exit_vehicle()
	noclip = not noclip
	body_collision.set_deferred("disabled", noclip)
	velocity = Vector3.ZERO
	if hud != null:
		hud.call("set_noclip", noclip)
		hud.call("flash", "NOCLIP ON" if noclip else "NOCLIP OFF")

func use_tool() -> void:
	if riding != null:
		exit_vehicle()
		return
	if TOOL_MODES[tool_index] == "GRAB" and held_body != null:
		_release_held()
		if hud != null:
			hud.call("flash", "Released prop")
		return

	var hit := _raycast(7.0)
	if hit.is_empty():
		if hud != null:
			hud.call("flash", "Nothing in reach")
		return
	var target = hit.get("collider")
	if target == null:
		return
	if target.is_in_group("vehicle"):
		enter_vehicle(target)
		return
	if target.is_in_group("luca"):
		if hud != null:
			hud.call("flash", "Luca is right here. Good dog.")
		return
	if target.is_in_group("npc"):
		if hud != null:
			hud.call("flash", str(target.call("describe")))
		return

	match TOOL_MODES[tool_index]:
		"GRAB":
			if target is RigidBody3D and target.is_in_group("sandbox_prop"):
				held_body = target
				held_body.freeze = true
				if hud != null:
					hud.call("flash", "Grabbed " + str(target.name))
		"REMOVE":
			if target.is_in_group("sandbox_prop"):
				target.queue_free()
				if hud != null:
					hud.call("flash", "Removed prop")
		"DUPLICATE":
			if target.is_in_group("sandbox_prop"):
				game.call("duplicate_prop", target)
				if hud != null:
					hud.call("flash", "Duplicated prop")
		"INSPECT":
			if hud != null:
				var groups = target.get_groups()
				hud.call("flash", "%s // %s" % [target.name, str(groups)])

func _raycast(distance: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.new()
	query.from = camera.global_position
	query.to = camera.global_position - camera.global_transform.basis.z * distance
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _release_held() -> void:
	if held_body != null and is_instance_valid(held_body):
		held_body.freeze = false
	held_body = null

func enter_vehicle(vehicle: CharacterBody3D) -> void:
	if noclip:
		noclip = false
		if hud != null:
			hud.call("set_noclip", false)
	_release_held()
	riding = vehicle
	body_collision.set_deferred("disabled", true)
	riding.call("set_driver_active", true)
	if hud != null:
		hud.call("flash", "Driving // USE to exit")

func exit_vehicle() -> void:
	if riding == null:
		return
	if is_instance_valid(riding):
		riding.call("set_driver_active", false)
		global_position = riding.global_position + riding.global_transform.basis.x * 2.6 + Vector3.UP * 1.0
	riding = null
	body_collision.set_deferred("disabled", noclip)
	if hud != null:
		hud.call("flash", "Exited buggy")

func get_spawn_point() -> Vector3:
	return camera.global_position - camera.global_transform.basis.z * 5.5 + Vector3.UP * 0.5

func _recover_if_outside() -> void:
	var limit := 480.0 + SAFE_MARGIN
	if global_position.y < -18.0 or abs(global_position.x) > limit or abs(global_position.z) > limit:
		_release_held()
		if riding != null:
			exit_vehicle()
		global_position = Vector3(0.0, 2.5, 24.0)
		velocity = Vector3.ZERO
		if hud != null:
			hud.call("flash", "Boundary recovery // returned to spawn")
