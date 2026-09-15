class_name KeithAmbientWorker
extends RefCounted

# Deterministic ambient breakroom cleaning routine for Keith.
# Cycles through authored floor waypoints avoiding the central table.
# Pauses cleanly when player interacts and resumes afterwards.

var keith_node: CharacterBody3D
var mop_node: Node3D
var is_active: bool = true
var is_paused: bool = false
var current_state: String = "idle" # idle, walking, cleaning

var waypoints: Array[Vector3] = [
	Vector3(-5.35, 0.95, -3.55), # Utility corner (default)
	Vector3(-2.8, 0.95, -4.2),  # North wall
	Vector3(-4.0, 0.95, -1.2),  # West aisle (safe clearance from table)
	Vector3(-2.5, 0.95, 2.2),   # South-west floor
	Vector3(2.5, 0.95, 2.0),    # South-east floor
	Vector3(3.2, 0.95, -2.5),   # East aisle (near counter/fridge approach)
]

var target_index: int = 0
var state_timer: float = 0.0
var move_speed: float = 1.2
var mop_phase: float = 0.0
var gait_phase: float = 0.0
var initial_mop_rot: Vector3 = Vector3(-10, 5, 0)
var initial_mop_pos: Vector3 = Vector3(0.45, 0.05, 0.15)
var left_arm: Node3D = null
var right_arm: Node3D = null
var left_leg: Node3D = null
var right_leg: Node3D = null
var torso: Node3D = null
var initial_left_arm_rot: Vector3 = Vector3.ZERO
var initial_right_arm_rot: Vector3 = Vector3.ZERO
var initial_left_leg_rot: Vector3 = Vector3.ZERO
var initial_right_leg_rot: Vector3 = Vector3.ZERO
var initial_torso_pos: Vector3 = Vector3.ZERO
var initial_torso_rot: Vector3 = Vector3.ZERO


func _init(p_keith: Node3D) -> void:
	keith_node = p_keith
	if is_instance_valid(keith_node):
		mop_node = keith_node.get_node_or_null("MopHandle")
		left_arm = keith_node.get_node_or_null("LeftUpperArm")
		right_arm = keith_node.get_node_or_null("RightUpperArm")
		left_leg = keith_node.get_node_or_null("LeftLeg")
		right_leg = keith_node.get_node_or_null("RightLeg")
		torso = keith_node.get_node_or_null("Torso")
		if mop_node:
			initial_mop_rot = mop_node.rotation_degrees
			initial_mop_pos = mop_node.position
		if left_arm:
			initial_left_arm_rot = left_arm.rotation_degrees
		if right_arm:
			initial_right_arm_rot = right_arm.rotation_degrees
		if left_leg:
			initial_left_leg_rot = left_leg.rotation_degrees
		if right_leg:
			initial_right_leg_rot = right_leg.rotation_degrees
		if torso:
			initial_torso_pos = torso.position
			initial_torso_rot = torso.rotation_degrees


func update(delta: float) -> void:
	if not is_active or is_paused or not is_instance_valid(keith_node):
		return

	state_timer -= delta

	match current_state:
		"idle":
			_reset_mop()
			_reset_body_pose()
			if state_timer <= 0.0:
				target_index = (target_index + 1) % waypoints.size()
				current_state = "walking"
		"walking":
			_reset_mop()
			gait_phase += delta * 6.0
			_animate_walk()
			var target_pos := waypoints[target_index]
			var cur_pos := keith_node.global_position
			var diff := target_pos - cur_pos
			diff.y = 0.0
			var dist := diff.length()
			if dist < 0.15:
				current_state = "cleaning"
				state_timer = 3.5 # clean for 3.5s
			else:
				var move_dir := diff.normalized()
				# Use CharacterBody3D velocity + move_and_slide for collision-aware motion
				var desired_vel := move_dir * move_speed
				keith_node.velocity = Vector3(desired_vel.x, keith_node.velocity.y, desired_vel.z)
				keith_node.move_and_slide()
				# Face moving direction
				var look_angle := atan2(move_dir.x, move_dir.z)
				keith_node.rotation.y = lerp_angle(keith_node.rotation.y, look_angle, delta * 6.0)
		"cleaning":
			mop_phase += delta * 4.0
			_animate_mop()
			_animate_cleaning_body()
			if state_timer <= 0.0:
				current_state = "idle"
				state_timer = 1.5 # pause for 1.5s


func pause_cleaning() -> void:
	is_paused = true
	_reset_mop()
	_reset_body_pose()


func resume_cleaning() -> void:
	is_paused = false


func _animate_mop() -> void:
	if is_instance_valid(mop_node):
		var sweep := sin(mop_phase) * 14.0
		mop_node.rotation_degrees = Vector3(
			initial_mop_rot.x + sin(mop_phase * 0.5) * 6.0,
			initial_mop_rot.y + sweep,
			initial_mop_rot.z + cos(mop_phase) * 4.0
		)
		mop_node.position = initial_mop_pos + Vector3(sin(mop_phase) * 0.06, 0.0, cos(mop_phase) * 0.04)


func _animate_walk() -> void:
	var swing := sin(gait_phase) * 9.0
	if is_instance_valid(left_leg):
		left_leg.rotation_degrees = initial_left_leg_rot + Vector3(swing, 0, 0)
	if is_instance_valid(right_leg):
		right_leg.rotation_degrees = initial_right_leg_rot + Vector3(-swing, 0, 0)
	if is_instance_valid(left_arm):
		left_arm.rotation_degrees = initial_left_arm_rot + Vector3(-swing * 0.55, 0, 0)
	if is_instance_valid(right_arm):
		right_arm.rotation_degrees = initial_right_arm_rot + Vector3(swing * 0.55, 0, 0)
	if is_instance_valid(torso):
		torso.position = initial_torso_pos + Vector3(0, abs(sin(gait_phase)) * 0.018, 0)


func _animate_cleaning_body() -> void:
	if is_instance_valid(torso):
		torso.rotation_degrees = initial_torso_rot + Vector3(sin(mop_phase * 0.5) * 2.0, 0, sin(mop_phase) * 2.5)
	if is_instance_valid(left_arm):
		left_arm.rotation_degrees = initial_left_arm_rot + Vector3(-8.0 + sin(mop_phase) * 5.0, 0, -4.0)
	if is_instance_valid(right_arm):
		right_arm.rotation_degrees = initial_right_arm_rot + Vector3(-12.0 - sin(mop_phase) * 5.0, 0, 5.0)


func _reset_body_pose() -> void:
	if is_instance_valid(left_arm):
		left_arm.rotation_degrees = initial_left_arm_rot
	if is_instance_valid(right_arm):
		right_arm.rotation_degrees = initial_right_arm_rot
	if is_instance_valid(left_leg):
		left_leg.rotation_degrees = initial_left_leg_rot
	if is_instance_valid(right_leg):
		right_leg.rotation_degrees = initial_right_leg_rot
	if is_instance_valid(torso):
		torso.position = initial_torso_pos
		torso.rotation_degrees = initial_torso_rot


func _reset_mop() -> void:
	if is_instance_valid(mop_node):
		mop_node.rotation_degrees = initial_mop_rot
		mop_node.position = initial_mop_pos
