extends CharacterBody3D

const MAX_SPEED := 5.8
const RETREAT_SPEED := 3.4
const ACCEL := 10.5
const DECEL := 13.0
const TURN_RESPONSE := 6.2
const GRAVITY := 18.0
const FOLLOW_DISTANCE := 6.5
const FOLLOW_SIDE_OFFSET := 1.8
const PERSONAL_SPACE := 3.6
const PERSONAL_SPACE_RELEASE := 4.8
const FOLLOW_WAKE_RADIUS := 2.6
const ARRIVAL_RADIUS := 1.15
const PLAYER_MOVE_EPSILON := 0.035
const RECOVER_DISTANCE := 62.0
const OBSTACLE_PROBE := 2.4

var player: CharacterBody3D
var world_half := 480.0
var state := "WAIT"
var follow_engaged := false
var giving_space := false
var follow_heading := Vector3(0.0, 0.0, -1.0)
var follow_anchor := Vector3.ZERO
var previous_player_position := Vector3.ZERO
var anchor_initialized := false
var follow_enabled := true
var gait_clock := 0.0

func _ready() -> void:
	add_to_group("luca")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.32
	floor_max_angle = deg_to_rad(50.0)
	_build_dog()
	call_deferred("_initialize_follow_anchor")

func _initialize_follow_anchor() -> void:
	if player == null or not is_instance_valid(player):
		return
	previous_player_position = player.global_position
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length() > 0.01:
		follow_heading = forward.normalized()
	follow_anchor = _compute_follow_anchor()
	anchor_initialized = true

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not anchor_initialized:
		_initialize_follow_anchor()
		if not anchor_initialized:
			return

	if not follow_enabled:
		state = "STAY"
		velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECEL * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		_animate_gait(delta)
		return
	_update_follow_anchor_from_player_motion()

	var player_offset := player.global_position - global_position
	player_offset.y = 0.0
	var player_distance := player_offset.length()

	if player_distance > RECOVER_DISTANCE:
		state = "RECOVER"
		global_position = follow_anchor + Vector3.UP * 0.6
		velocity = Vector3.ZERO
		follow_engaged = false
		giving_space = false
		return

	if giving_space:
		giving_space = player_distance < PERSONAL_SPACE_RELEASE
	elif player_distance < PERSONAL_SPACE:
		giving_space = true

	var target := follow_anchor
	var target_offset := target - global_position
	target_offset.y = 0.0
	var target_distance := target_offset.length()

	if follow_engaged:
		follow_engaged = target_distance > ARRIVAL_RADIUS
	elif target_distance > FOLLOW_WAKE_RADIUS:
		follow_engaged = true

	var desired := Vector3.ZERO
	if giving_space and player_distance > 0.05:
		state = "GIVE_SPACE"
		desired = -player_offset.normalized() * RETREAT_SPEED
	elif follow_engaged and target_distance > ARRIVAL_RADIUS:
		state = "FOLLOW"
		var direction := target_offset.normalized()
		direction = _avoid_obstacle(direction)
		var arrival_scale := clampf(
			(target_distance - ARRIVAL_RADIUS) / 5.0,
			0.18,
			1.0
		)
		desired = direction * MAX_SPEED * arrival_scale
	else:
		state = "WAIT"

	var rate := ACCEL if desired.length() > 0.05 else DECEL
	velocity.x = move_toward(velocity.x, desired.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired.z, rate * delta)

	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if planar_velocity.length() > 0.22:
		var direction := planar_velocity.normalized()
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(TURN_RESPONSE * delta, 1.0))
	elif desired.is_zero_approx():
		velocity.x = 0.0 if absf(velocity.x) < 0.08 else velocity.x
		velocity.z = 0.0 if absf(velocity.z) < 0.08 else velocity.z

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -0.2

	move_and_slide()
	_animate_gait(delta)

	if (
		absf(global_position.x) > world_half - 4.0
		or absf(global_position.z) > world_half - 4.0
		or global_position.y < -2.0
	):
		global_position = follow_anchor + Vector3.UP * 0.6
		velocity = Vector3.ZERO
		follow_engaged = false
		giving_space = false

func toggle_stay() -> String:
	follow_enabled = not follow_enabled
	state = "FOLLOW" if follow_enabled else "STAY"
	velocity = Vector3.ZERO
	return "LUCA // FOLLOWING" if follow_enabled else "LUCA // STAY HERE"

func _animate_gait(delta: float) -> void:
	var pace := clampf(Vector2(velocity.x, velocity.z).length() / MAX_SPEED, 0.0, 1.0)
	gait_clock += delta * (2.0 + pace * 12.0)
	for side in [-1.0, 1.0]:
		for front in ["F", "B"]:
			var limb := get_node_or_null("Leg_%s_%s" % [front, "L" if side < 0.0 else "R"])
			if limb != null:
				var offset := 0.0 if front == "F" else PI
				limb.rotation.x = lerpf(limb.rotation.x, sin(gait_clock + offset) * side * 0.35 * pace, minf(delta * 14.0, 1.0))
	var tail := get_node_or_null("Tail")
	if tail != null:
		tail.rotation.z = sin(gait_clock * 0.48) * 0.3

func _update_follow_anchor_from_player_motion() -> void:
	var current := player.global_position
	var motion := current - previous_player_position
	motion.y = 0.0

	if motion.length() >= PLAYER_MOVE_EPSILON:
		follow_heading = motion.normalized()
		follow_anchor = _compute_follow_anchor()
	else:
		# Preserve the formation slot when the player only rotates the camera.
		# Tiny physics jitter may translate the slot, but yaw alone never orbits it.
		var translation := current - previous_player_position
		translation.y = 0.0
		if translation.length() > 0.0001:
			follow_anchor += translation

	previous_player_position = current

func _compute_follow_anchor() -> Vector3:
	var heading := follow_heading
	heading.y = 0.0
	if heading.length() <= 0.01:
		heading = Vector3(0.0, 0.0, -1.0)
	heading = heading.normalized()
	var right := heading.cross(Vector3.UP).normalized()
	return (
		player.global_position
		- heading * FOLLOW_DISTANCE
		+ right * FOLLOW_SIDE_OFFSET
	)

func _avoid_obstacle(direction: Vector3) -> Vector3:
	if direction.length() <= 0.01:
		return direction
	var query := PhysicsRayQueryParameters3D.new()
	query.from = global_position + Vector3.UP * 0.65
	query.to = query.from + direction * OBSTACLE_PROBE
	query.exclude = [get_rid(), player.get_rid()]
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return direction

	var side := Vector3.UP.cross(direction).normalized()
	var toward_anchor := follow_anchor - global_position
	toward_anchor.y = 0.0
	if side.dot(toward_anchor) < 0.0:
		side = -side
	return (direction * 0.45 + side * 0.85).normalized()

func get_follow_anchor_for_test() -> Vector3:
	return follow_anchor

func _build_dog() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 1.25
	collision.shape = shape
	collision.position.y = 0.62
	add_child(collision)

	var fur := _material(Color(0.86, 0.69, 0.35))
	var dark := _material(Color(0.10, 0.085, 0.065))
	var eye_white := _material(Color(0.96, 0.95, 0.88))

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.9, 0.85, 1.65)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.82, 0.10)
	body.material_override = fur
	add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.48
	head_mesh.height = 0.96
	head.mesh = head_mesh
	head.position = Vector3(0, 1.28, -0.82)
	head.material_override = fur
	add_child(head)

	var muzzle := MeshInstance3D.new()
	var muzzle_mesh := SphereMesh.new()
	muzzle_mesh.radius = 0.25
	muzzle_mesh.height = 0.42
	muzzle.mesh = muzzle_mesh
	muzzle.scale = Vector3(1.0, 0.8, 1.2)
	muzzle.position = Vector3(0, 1.13, -1.20)
	muzzle.material_override = _material(Color(0.90, 0.76, 0.48))
	add_child(muzzle)

	var nose := MeshInstance3D.new()
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.11
	nose_mesh.height = 0.20
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 1.18, -1.43)
	nose.material_override = dark
	add_child(nose)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.105
		eye_mesh.height = 0.21
		eye.mesh = eye_mesh
		eye.name = "EyeWhite_%s" % ("L" if side < 0.0 else "R")
		eye.scale = Vector3(0.90, 1.12, 0.62)
		eye.position = Vector3(0.21 * side, 1.46, -1.20)
		eye.material_override = eye_white
		add_child(eye)

		var pupil := MeshInstance3D.new()
		var pupil_mesh := SphereMesh.new()
		pupil_mesh.radius = 0.055
		pupil_mesh.height = 0.11
		pupil.mesh = pupil_mesh
		pupil.name = "Pupil_%s" % ("L" if side < 0.0 else "R")
		pupil.scale = Vector3(0.85, 1.0, 0.55)
		pupil.position = Vector3(0.21 * side, 1.46, -1.29)
		pupil.material_override = dark
		add_child(pupil)

		var ear := MeshInstance3D.new()
		var ear_mesh := BoxMesh.new()
		ear_mesh.size = Vector3(0.20, 0.52, 0.30)
		ear.mesh = ear_mesh
		ear.position = Vector3(0.42 * side, 1.28, -0.80)
		ear.rotation_degrees.z = 18.0 * side
		ear.material_override = _material(Color(0.68, 0.49, 0.25))
		add_child(ear)

		for front in [-0.48, 0.56]:
			var leg := MeshInstance3D.new()
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.12
			leg_mesh.bottom_radius = 0.14
			leg_mesh.height = 0.72
			leg.mesh = leg_mesh
			leg.name = "Leg_%s_%s" % ["F" if front < 0.0 else "B", "L" if side < 0.0 else "R"]
			leg.position = Vector3(0.31 * side, 0.37, front)
			leg.material_override = fur
			add_child(leg)

	var tail := MeshInstance3D.new()
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.08
	tail_mesh.bottom_radius = 0.13
	tail_mesh.height = 0.88
	tail.mesh = tail_mesh
	tail.name = "Tail"
	tail.position = Vector3(0, 1.05, 1.13)
	tail.rotation_degrees.x = 58
	tail.material_override = fur
	add_child(tail)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func recover_stream_position() -> void:
	# Called by the guard even while motion is suspended; STAY never teleports.
	if not follow_enabled or not is_instance_valid(player):
		return
	var offset := player.global_position - global_position
	offset.y = 0.0
	if offset.length() > RECOVER_DISTANCE:
		_initialize_follow_anchor()
		global_position = follow_anchor + Vector3.UP * 0.6
		velocity = Vector3.ZERO
		follow_engaged = false
		giving_space = false
