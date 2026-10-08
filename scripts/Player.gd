extends CharacterBody3D

const WALK_SPEED := 8.5
const SPRINT_SPEED := 13.5
const NOCLIP_SPEED := 18.0
const JUMP_SPEED := 7.8
const GRAVITY := 19.0
const SAFE_MARGIN := 16.0
const JUMP_BUFFER_TIME := 0.22
const COYOTE_TIME := 0.14
const FALL_RECOVERY_Y := -1.25

var game: Node
var hud: CanvasLayer
var pivot: Node3D
var camera: Camera3D
var equipped_tool: Node3D
var body_collision: CollisionShape3D

var touch_move := Vector2.ZERO
var vertical_axis := 0.0
var jump_buffer := 0.0
var coyote_timer := 0.0
var yaw := 0.0
var pitch := -0.08
var noclip := false
var tool_ids: Array[String] = []
var tool_index := 0
var held_body: RigidBody3D
var riding: Node3D

var last_safe_ground_position := Vector3(0.0, 2.5, 24.0)
var safe_ground_timer := 0.0

func _ready() -> void:
	add_to_group("player")

	# Player gets its own layer so Luca/NPCs do not physically body-block it.
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)

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
	equipped_tool = load("res://scripts/systems/EquippedTool.gd").new()
	equipped_tool.name = "EquippedTool"
	camera.add_child(equipped_tool)

	rotation.y = yaw
	pivot.rotation.x = pitch
	last_safe_ground_position = global_position
	_refresh_tool_catalog()

	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	jump_buffer = max(0.0, jump_buffer - delta)
	_recover_if_outside()
	# Hold on spawn/teleport until local voxel data is available, not on a hidden floor.
	if game != null and game.call("uses_world_voxels") and riding == null and not noclip:
		var terrain_node = game.get("terrain_slice")
		if terrain_node != null and not terrain_node.call("_is_editable", Vector3i(global_position)):
			velocity = Vector3.ZERO
			return
		var floor_query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 2.0, global_position - Vector3.UP * 24.0, 1)
		var voxel_floor = terrain_node.get("voxel_tool").call("raycast", floor_query.from, Vector3.DOWN, 26.0)
		if voxel_floor != null and get_world_3d().direct_space_state.intersect_ray(floor_query).is_empty():
			velocity = Vector3.ZERO
			return

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

	_update_held_body(delta)
	_update_safe_ground(delta)
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
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	if Input.is_key_pressed(KEY_SPACE):
		request_jump()

	var direction := global_transform.basis.x * input_vec.x + global_transform.basis.z * input_vec.y
	direction.y = 0.0
	direction = direction.normalized()

	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction.x * speed, 30.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 30.0 * delta)

	if jump_buffer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_SPEED
		jump_buffer = 0.0
		coyote_timer = 0.0
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if game != null and game.call("uses_world_voxels"):
		_try_voxel_step(delta)
	move_and_slide()

func _try_voxel_step(delta: float) -> void:
	if not is_on_floor() or velocity.y > 0.0:
		return
	var forward := Vector3(velocity.x, 0, velocity.z) * delta
	if forward.length_squared() < 0.0001 or not test_move(global_transform, forward):
		return
	var raised := global_transform
	if test_move(raised, Vector3.UP * 1.05):
		return
	raised.origin.y += 1.05
	if test_move(raised, forward):
		return
	raised.origin += forward
	var landing := KinematicCollision3D.new()
	if not test_move(raised, Vector3.DOWN * 1.10, landing):
		return
	if landing.get_normal().y < cos(floor_max_angle):
		return
	global_position = raised.origin + landing.get_travel()

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

func _update_held_body(delta: float) -> void:
	if held_body == null:
		return
	if not is_instance_valid(held_body):
		held_body = null
		return

	var target := camera.global_position - camera.global_transform.basis.z * 4.0
	held_body.global_position = held_body.global_position.lerp(target, min(delta * 14.0, 1.0))
	held_body.linear_velocity = Vector3.ZERO
	held_body.angular_velocity = Vector3.ZERO

func _update_safe_ground(delta: float) -> void:
	if noclip or riding != null:
		safe_ground_timer = 0.0
		return

	if (
		is_on_floor()
		and global_position.y > -0.5
		and abs(global_position.x) < 465.0
		and abs(global_position.z) < 465.0
	):
		safe_ground_timer += delta
		if safe_ground_timer >= 0.20:
			last_safe_ground_position = global_position + Vector3.UP * 0.12
			safe_ground_timer = 0.0
	else:
		safe_ground_timer = 0.0

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
		if hud != null and hud.has_method("developer_mode_enabled") and bool(hud.call("developer_mode_enabled")):
			toggle_noclip()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R and riding != null:
		toggle_vehicle_view()

func add_look_delta(delta_pixels: Vector2) -> void:
	if riding != null:
		if is_instance_valid(riding):
			riding.call("add_camera_look", delta_pixels)
		return
	var sensitivity := 0.0032
	yaw -= delta_pixels.x * sensitivity
	pitch = clamp(pitch - delta_pixels.y * sensitivity, -1.48, 1.48)
	rotation.y = yaw
	pivot.rotation.x = pitch

func set_touch_move(value: Vector2) -> void:
	touch_move = value.limit_length(1.0)

func request_jump() -> void:
	if noclip:
		return
	jump_buffer = JUMP_BUFFER_TIME

func set_vertical_input(value: float) -> void:
	vertical_axis = clamp(value, -1.0, 1.0)
	if value > 0.0 and not noclip:
		request_jump()

func _refresh_tool_catalog() -> void:
	tool_ids.clear()
	if game != null:
		for tool_id in game.call("get_tool_ids"):
			tool_ids.append(str(tool_id))
	if tool_ids.is_empty():
		tool_ids = ["grab", "inspect", "mine", "place", "craft"]
	tool_index = clampi(tool_index, 0, tool_ids.size() - 1)
	_sync_tool_label()

func _current_tool_id() -> String:
	if tool_ids.is_empty():
		return "grab"
	return tool_ids[tool_index]

func _current_tool_definition() -> Dictionary:
	if game == null:
		return {"label": _current_tool_id().to_upper(), "action": _current_tool_id(), "range": 7.0}
	var definition: Dictionary = game.call("get_tool_definition", _current_tool_id())
	if definition.is_empty():
		return {"label": _current_tool_id().to_upper(), "action": _current_tool_id(), "range": 7.0}
	return definition

func _sync_tool_label() -> void:
	if equipped_tool != null:
		equipped_tool.call("equip", _current_tool_id())
	if hud == null:
		return
	var definition := _current_tool_definition()
	hud.call("set_tool_mode", str(definition.get("label", _current_tool_id().to_upper())))
	if hud.has_method("set_tool_icon"):
		hud.call("set_tool_icon", equipped_tool.get("icon"))

func select_tool(tool_id: String) -> void:
	if not tool_ids.has(tool_id):
		return
	if held_body != null:
		_release_held()
	tool_index = tool_ids.find(tool_id)
	_sync_tool_label()

func cycle_tool() -> void:
	if held_body != null:
		_release_held()
	if tool_ids.is_empty():
		_refresh_tool_catalog()
	tool_index = (tool_index + 1) % tool_ids.size()
	_sync_tool_label()

func toggle_noclip() -> void:
	if riding != null:
		exit_vehicle()

	noclip = not noclip
	body_collision.set_deferred("disabled", noclip)
	velocity = Vector3.ZERO
	jump_buffer = 0.0
	vertical_axis = 0.0

	if hud != null:
		hud.call("set_noclip", noclip)
		hud.call("flash", "NOCLIP ON" if noclip else "NOCLIP OFF")

func use_tool() -> void:
	if equipped_tool != null:
		equipped_tool.call("use_animation")
	if riding != null:
		exit_vehicle()
		return

	# Encounter verbs are contextual, not tools. A Spiral target always takes
	# priority over the ordinary sandbox/tool belt.
	var encounter_hit := _raycast(9.5)
	if not encounter_hit.is_empty():
		var encounter_target = encounter_hit.get("collider")
		if encounter_target != null and encounter_target.is_in_group("spiral_interactable"):
			if hud != null and hud.has_method("open_encounter"):
				var title := str(game.call("spiral_encounter_title", encounter_target))
				var options: Array = game.call("spiral_encounter_options", encounter_target)
				hud.call("open_encounter", encounter_target, title, options)
			return

	var definition := _current_tool_definition()
	var action := str(definition.get("action", "inspect"))
	var reach := float(definition.get("range", 7.0))
	var direction := -camera.global_transform.basis.z

	if action == "craft":
		if hud != null:
			hud.call("flash", str(game.call("terrain_craft")), 1.8)
		return

	if action == "mine" or action == "place":
		var result := ""
		if action == "mine":
			result = str(game.call("terrain_mine", camera.global_position, direction, reach))
		else:
			result = str(game.call("terrain_place", camera.global_position, direction, reach))
		if hud != null:
			hud.call("flash", result, 1.8)
		return

	if action == "grab" and held_body != null:
		_release_held()
		if hud != null:
			hud.call("flash", "Released prop")
		return

	var hit := _raycast(reach)
	if hit.is_empty():
		if hud != null:
			hud.call("flash", "Nothing in reach")
		return

	var target = hit.get("collider")
	if target == null:
		return

	if target.is_in_group("vehicle") and action != "strike":
		enter_vehicle(target)
		return

	if target.is_in_group("luca"):
		if hud != null:
			hud.call("flash", "The hound stays close. It keeps looking past you.")
		return

	if action == "strike":
		_strike_target(target, direction, definition)
		return

	if target.is_in_group("npc"):
		if hud != null:
			hud.call("flash", str(target.call("describe")))
		return

	match action:
		"grab":
			if target is RigidBody3D and target.is_in_group("sandbox_prop"):
				held_body = target
				held_body.freeze = true
				if hud != null:
					hud.call("flash", "Grabbed " + str(target.name))
		"remove":
			if target.is_in_group("sandbox_prop"):
				target.queue_free()
				if hud != null:
					hud.call("flash", "Removed prop")
		"duplicate":
			if target.is_in_group("sandbox_prop"):
				game.call("duplicate_prop", target)
				if hud != null:
					hud.call("flash", "Duplicated prop")
		"inspect":
			if hud != null:
				var groups = target.get_groups()
				hud.call("flash", "%s // %s" % [target.name, str(groups)])

func spiral_choice(target: Object, action: String) -> void:
	if target == null or not is_instance_valid(target):
		if hud != null:
			hud.call("flash", "The encounter is gone.", 1.4)
		return
	if not target.is_in_group("spiral_interactable"):
		return
	var result := str(game.call("spiral_interact", target, action))
	if hud != null:
		hud.call("flash", result, 4.2)

func _strike_target(target, direction: Vector3, definition: Dictionary) -> void:
	var damage := float(definition.get("damage", 0.0))
	var knockback := float(definition.get("knockback", 0.0))
	if target.has_method("take_damage"):
		var result := str(
			target.call(
				"take_damage",
				damage,
				direction.normalized() * knockback,
				camera.global_position
			)
		)
		if hud != null:
			hud.call("flash", result, 1.4)
		return

	if target is RigidBody3D:
		target.apply_central_impulse(direction.normalized() * knockback)
		if hud != null:
			hud.call("flash", "Hammer impact")
		return

	if hud != null:
		hud.call("flash", "Hammer cannot damage that")

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

func enter_vehicle(vehicle: Node3D) -> void:
	if noclip:
		noclip = false
		if hud != null:
			hud.call("set_noclip", false)

	_release_held()
	riding = vehicle
	body_collision.set_deferred("disabled", true)
	camera.current = false
	riding.call("set_driver_active", true)
	var camera_name := str(riding.call("get_camera_mode_name"))

	if hud != null:
		hud.call("set_vehicle_mode", true, camera_name)
		hud.call("flash", "Driving // VIEW switches camera", 1.8)

func toggle_vehicle_view() -> void:
	if riding == null or not is_instance_valid(riding):
		return
	var camera_name := str(riding.call("cycle_camera"))
	if hud != null:
		hud.call("set_vehicle_camera", camera_name)
		hud.call("flash", camera_name + " camera", 1.0)

func exit_vehicle() -> void:
	if riding == null:
		return

	if is_instance_valid(riding):
		riding.call("set_driver_active", false)
		global_position = (
			riding.global_position
			+ riding.global_transform.basis.x * 2.6
			+ Vector3.UP * 1.0
		)

	riding = null
	body_collision.set_deferred("disabled", noclip)
	camera.current = true

	if hud != null:
		hud.call("set_vehicle_mode", false)
		hud.call("flash", "Exited buggy", 1.2)

func get_spawn_point() -> Vector3:
	return camera.global_position - camera.global_transform.basis.z * 6.0 + Vector3.UP * 0.5

func _recover_if_outside() -> void:
	var limit: float = 480.0 + SAFE_MARGIN
	var recovery_y := -24.0 if game != null and game.call("uses_world_voxels") else FALL_RECOVERY_Y
	var fell_below_world: bool = global_position.y < recovery_y
	var escaped_bounds: bool = absf(global_position.x) > limit or absf(global_position.z) > limit

	if not fell_below_world and not escaped_bounds:
		return

	_release_held()
	if riding != null:
		exit_vehicle()

	var recovery := last_safe_ground_position
	if escaped_bounds:
		recovery = Vector3(0.0, 2.5, 24.0)

	global_position = recovery + Vector3.UP * 0.25
	velocity = Vector3.ZERO

	if hud != null:
		hud.call(
			"flash",
			"Recovered from edge // returned to last safe ground"
			if fell_below_world
			else "Boundary recovery // returned to spawn"
		)
