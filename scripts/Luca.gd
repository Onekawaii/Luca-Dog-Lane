extends CharacterBody3D

const MAX_SPEED := 6.1
const RETREAT_SPEED := 3.8
const ACCEL := 8.5
const TURN_RESPONSE := 5.2
const GRAVITY := 18.0
const FOLLOW_DISTANCE := 7.0
const FOLLOW_SIDE_OFFSET := 2.0
const PERSONAL_SPACE := 4.5
const PERSONAL_SPACE_RELEASE := 5.4
const FOLLOW_START_RADIUS := 3.0
const FOLLOW_STOP_RADIUS := 1.35
const RECOVER_DISTANCE := 60.0

var player: CharacterBody3D
var world_half := 480.0
var state := "WAIT"
var follow_engaged := false
var giving_space := false

func _ready() -> void:
	add_to_group("luca")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.28
	floor_max_angle = deg_to_rad(50.0)
	_build_dog()

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var player_offset := player.global_position - global_position
	player_offset.y = 0.0
	var player_distance := player_offset.length()

	if player_distance > RECOVER_DISTANCE:
		state = "RECOVER"
		global_position = _preferred_follow_position() + Vector3.UP * 0.6
		velocity = Vector3.ZERO
		follow_engaged = false
		giving_space = false
		return

	var preferred := _preferred_follow_position()
	var target_offset := preferred - global_position
	target_offset.y = 0.0
	var target_distance := target_offset.length()

	if giving_space:
		giving_space = player_distance < PERSONAL_SPACE_RELEASE
	elif player_distance < PERSONAL_SPACE:
		giving_space = true

	if follow_engaged:
		follow_engaged = target_distance > FOLLOW_STOP_RADIUS
	elif target_distance > FOLLOW_START_RADIUS:
		follow_engaged = true

	var desired := Vector3.ZERO
	if giving_space and player_distance > 0.05:
		state = "GIVE_SPACE"
		desired = -player_offset.normalized() * RETREAT_SPEED
	elif follow_engaged and target_distance > 0.05:
		state = "FOLLOW"
		var speed_scale := clampf(target_distance / 8.0, 0.45, 1.0)
		desired = target_offset.normalized() * MAX_SPEED * speed_scale
	else:
		state = "WAIT"

	velocity.x = move_toward(velocity.x, desired.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, desired.z, ACCEL * delta)

	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if planar_velocity.length() > 0.28:
		var direction := planar_velocity.normalized()
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(TURN_RESPONSE * delta, 1.0))

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	move_and_slide()

	if (
		absf(global_position.x) > world_half - 4.0
		or absf(global_position.z) > world_half - 4.0
		or global_position.y < -5.0
	):
		global_position = _preferred_follow_position() + Vector3.UP * 0.6
		velocity = Vector3.ZERO
		follow_engaged = false
		giving_space = false

func _preferred_follow_position() -> Vector3:
	return (
		player.global_position
		+ player.global_transform.basis.z * FOLLOW_DISTANCE
		+ player.global_transform.basis.x * FOLLOW_SIDE_OFFSET
	)

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
			leg.position = Vector3(0.31 * side, 0.37, front)
			leg.material_override = fur
			add_child(leg)

	var tail := MeshInstance3D.new()
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.08
	tail_mesh.bottom_radius = 0.13
	tail_mesh.height = 0.88
	tail.mesh = tail_mesh
	tail.position = Vector3(0, 1.05, 1.13)
	tail.rotation_degrees.x = 58
	tail.material_override = fur
	add_child(tail)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
