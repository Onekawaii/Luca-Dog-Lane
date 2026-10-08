extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died(npc: Node3D)

const SPEED := 1.9
const ACCEL := 5.5
const GRAVITY := 18.0
const MAX_HEALTH := 100.0
const KNOCKBACK_DECAY := 8.5

var display_name := "Wanderer"
var world_half := 480.0
var target_direction := Vector3.ZERO
var think_time := 0.0
var rng := RandomNumberGenerator.new()
var health := MAX_HEALTH
var alive := true
var knockback_velocity := Vector3.ZERO
var visual_root: Node3D
var damage_feedback: Node3D

func _ready() -> void:
	add_to_group("npc")
	add_to_group("damageable")

	# Player can raycast NPCs; vehicles can physically hit them.
	collision_layer = 8
	collision_mask = 1 | 16
	floor_snap_length = 0.28
	floor_max_angle = deg_to_rad(50.0)

	rng.seed = hash(name)
	_build_person()
	damage_feedback = load("res://scripts/systems/DamageFeedback.gd").new()
	visual_root.add_child(damage_feedback)
	_choose_direction()

func _physics_process(delta: float) -> void:
	if not alive:
		_process_dead(delta)
		return

	think_time -= delta
	if think_time <= 0.0:
		_choose_direction()

	var desired := target_direction * SPEED
	velocity.x = move_toward(velocity.x, desired.x + knockback_velocity.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, desired.z + knockback_velocity.z, ACCEL * delta)

	if target_direction.length() > 0.01 and knockback_velocity.length() < 1.5:
		var target_yaw := atan2(-target_direction.x, -target_direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(4.5 * delta, 1.0))

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -0.2

	if knockback_velocity.y > 0.0:
		velocity.y = maxf(velocity.y, knockback_velocity.y)

	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)

	if abs(global_position.x) > world_half - 12.0 or abs(global_position.z) > world_half - 12.0:
		global_position.x = clamp(global_position.x, -world_half + 16.0, world_half - 16.0)
		global_position.z = clamp(global_position.z, -world_half + 16.0, world_half - 16.0)
		_choose_direction()

	if global_position.y < -2.0:
		global_position.y = 2.0
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO

func _process_dead(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if visual_root != null:
		visual_root.rotation.z = lerp_angle(
			visual_root.rotation.z,
			deg_to_rad(82.0),
			minf(5.0 * delta, 1.0)
		)

func _choose_direction() -> void:
	if not alive:
		target_direction = Vector3.ZERO
		return
	think_time = rng.randf_range(2.5, 6.5)
	if rng.randf() < 0.32:
		target_direction = Vector3.ZERO
	else:
		var angle := rng.randf_range(0.0, TAU)
		target_direction = Vector3(cos(angle), 0, sin(angle))

func take_damage(amount: float, impulse := Vector3.ZERO, _source := Vector3.ZERO) -> String:
	if not alive:
		return "%s // already down" % display_name

	var applied := maxf(0.0, amount)
	health = maxf(0.0, health - applied)
	knockback_velocity += Vector3(impulse.x, maxf(0.0, impulse.y), impulse.z)
	if applied > 0.0:
		knockback_velocity.y = maxf(knockback_velocity.y, 1.8)
	health_changed.emit(health, MAX_HEALTH)
	if applied > 0.0:
		damage_feedback.call("hit", health, MAX_HEALTH, false, _source)

	if health <= 0.0:
		_die()
		return "%s // DOWN // 0/%d HP" % [display_name, int(MAX_HEALTH)]

	think_time = maxf(think_time, 0.75)
	target_direction = Vector3.ZERO
	return "%s // -%d // %d/%d HP" % [
		display_name,
		int(round(applied)),
		int(ceil(health)),
		int(MAX_HEALTH),
	]

func _die() -> void:
	if not alive:
		return
	alive = false
	target_direction = Vector3.ZERO
	knockback_velocity *= 0.45
	var collision := get_node_or_null("BodyCollision") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	died.emit(self)

func describe() -> String:
	if not alive:
		return "%s // DOWN // 0/%d HP" % [display_name, int(MAX_HEALTH)]
	return "%s // %d/%d HP // wandering" % [
		display_name,
		int(ceil(health)),
		int(MAX_HEALTH),
	]

func get_health_for_test() -> float:
	return health

func is_alive_for_test() -> bool:
	return alive

func _build_person() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "BodyCollision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.78
	collision.shape = shape
	collision.position.y = 0.89
	add_child(collision)

	visual_root = Node3D.new()
	visual_root.name = "Anatomy"
	add_child(visual_root)

	var outfit: StandardMaterial3D = load("res://scripts/systems/ObjectMaterials.gd").make("fabric", Color.from_hsv(rng.randf(), 0.44, 0.68))
	var accent := _material(Color.from_hsv(fposmod(rng.randf() + 0.18, 1.0), 0.38, 0.55))
	var skin := _skin_material()
	var boot := _material(Color(0.10, 0.09, 0.08))
	var hair := _material(Color.from_hsv(rng.randf_range(0.04, 0.12), 0.55, rng.randf_range(0.16, 0.32)))

	_add_box("Pelvis", Vector3(0.0, 0.77, 0.0), Vector3(0.58, 0.32, 0.34), accent)
	_add_box("Torso", Vector3(0.0, 1.19, 0.0), Vector3(0.72, 0.72, 0.38), outfit)

	var neck := MeshInstance3D.new()
	neck.name = "Neck"
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.105
	neck_mesh.bottom_radius = 0.115
	neck_mesh.height = 0.22
	neck.mesh = neck_mesh
	neck.position = Vector3(0.0, 1.61, 0.0)
	neck.material_override = skin
	visual_root.add_child(neck)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.27
	head_mesh.height = 0.54
	head.mesh = head_mesh
	head.scale = Vector3(0.88, 1.08, 0.92)
	head.position = Vector3(0.0, 1.86, -0.015)
	head.material_override = skin
	visual_root.add_child(head)

	var hair_cap := MeshInstance3D.new()
	hair_cap.name = "Hair"
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.275
	hair_mesh.height = 0.55
	hair_cap.mesh = hair_mesh
	hair_cap.scale = Vector3(0.90, 0.52, 0.94)
	hair_cap.position = Vector3(0.0, 2.00, 0.015)
	hair_cap.material_override = hair
	visual_root.add_child(hair_cap)

	for side in [-1.0, 1.0]:
		var side_name := "L" if side < 0.0 else "R"
		_add_limb(
			"UpperArm_" + side_name,
			Vector3(0.46 * side, 1.31, 0.0),
			0.11,
			0.48,
			outfit,
			Vector3(0.0, 0.0, -8.0 * side)
		)
		_add_limb(
			"Forearm_" + side_name,
			Vector3(0.50 * side, 0.91, -0.01),
			0.095,
			0.42,
			skin,
			Vector3(0.0, 0.0, -2.0 * side)
		)
		_add_sphere(
			"Hand_" + side_name,
			Vector3(0.51 * side, 0.68, -0.02),
			0.12,
			skin,
			Vector3(0.78, 1.0, 0.85)
		)

		_add_limb(
			"Leg_" + side_name,
			Vector3(0.19 * side, 0.43, 0.0),
			0.13,
			0.68,
			accent
		)
		_add_box(
			"Foot_" + side_name,
			Vector3(0.19 * side, 0.09, -0.08),
			Vector3(0.28, 0.18, 0.46),
			boot
		)

func _add_limb(
	label: String,
	at: Vector3,
	radius: float,
	height: float,
	material: StandardMaterial3D,
	rotation_degrees_value := Vector3.ZERO
) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.92
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation_degrees_value
	node.material_override = material
	visual_root.add_child(node)

func _add_box(label: String, at: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	visual_root.add_child(node)

func _add_sphere(
	label: String,
	at: Vector3,
	radius: float,
	material: StandardMaterial3D,
	scale_value := Vector3.ONE
) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = at
	node.scale = scale_value
	node.material_override = material
	visual_root.add_child(node)

func _skin_material() -> StandardMaterial3D:
	var tones := [
		Color(0.88, 0.70, 0.55),
		Color(0.76, 0.57, 0.43),
		Color(0.58, 0.39, 0.28),
		Color(0.40, 0.27, 0.20),
	]
	return _material(tones[rng.randi_range(0, tones.size() - 1)])

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material
