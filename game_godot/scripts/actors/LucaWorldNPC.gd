class_name LucaWorldNPC
extends CharacterBody3D

var npc_id := ""
var display_name := "Traveler"
var role := "traveler"
var biome := "sunmeadow_fields"
var dialogue_lines: Array = []
var home_position := Vector3.ZERO
var _seed := 0
var _wander_timer := 0.0
var _wander_direction := Vector3.ZERO
var _paused_for_talk := 0.0
var _body_tint := Color(0.35, 0.42, 0.48)

func configure(id_value: String, name_value: String, role_value: String, biome_value: String, lines: Array, tint: Color, seed_value: int) -> void:
	npc_id = id_value
	display_name = name_value
	role = role_value
	biome = biome_value
	dialogue_lines = lines.duplicate(true)
	_body_tint = tint
	_seed = seed_value

func _ready() -> void:
	home_position = global_position
	floor_max_angle = deg_to_rad(68.0)
	floor_snap_length = 0.55
	_build_body()
	_choose_wander()
func get_interaction_prompt() -> String:
	return "TALK TO " + display_name.to_upper()

func interact(_player: Node = null) -> void:
	_paused_for_talk = 4.0
	velocity.x = 0.0
	velocity.z = 0.0
	var lines := dialogue_lines
	if lines.is_empty():
		lines = ["Nice weather for getting lost.", "Luca seems to know where he is going."]
	EventBus.first_person_dialogue_requested.emit(display_name, lines)

func _physics_process(delta: float) -> void:
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	if _paused_for_talk > 0.0:
		_paused_for_talk -= delta
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		move_and_slide()
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0 or global_position.distance_to(home_position) > 12.0:
		_choose_wander()
	var target_speed := 1.15
	velocity.x = move_toward(velocity.x, _wander_direction.x * target_speed, delta * 2.6)
	velocity.z = move_toward(velocity.z, _wander_direction.z * target_speed, delta * 2.6)
	if _wander_direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-_wander_direction.x, -_wander_direction.z), minf(1.0, delta * 3.0))
	move_and_slide()
	if get_slide_collision_count() > 0:
		_choose_wander()

func _choose_wander() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + int(Time.get_ticks_msec() / 1800) + npc_id.hash()
	var angle := rng.randf_range(0.0, TAU)
	_wander_direction = Vector3(cos(angle), 0.0, sin(angle))
	_wander_timer = rng.randf_range(2.5, 7.5)
func _build_body() -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = _body_tint
	cloth.roughness = 0.88
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.70, 0.54, 0.40).lerp(Color(0.98, 0.78, 0.63), float(posmod(_seed, 7)) / 6.0)
	skin.roughness = 0.92
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.055, 0.06, 0.065)
	dark.roughness = 0.88

	_add_capsule("Torso", 0.34, 1.05, Vector3(0.0, 1.16, 0.0), cloth)
	_add_sphere("Head", 0.27, Vector3(0.0, 1.90, 0.0), skin, Vector3(1.0, 1.10, 0.94))
	for side in [-1.0, 1.0]:
		_add_capsule("Arm", 0.10, 0.86, Vector3(0.44 * side, 1.16, 0.0), cloth, Vector3(0.0, 0.0, deg_to_rad(7.0 * side)))
		_add_capsule("Leg", 0.12, 0.92, Vector3(0.19 * side, 0.47, 0.0), dark)
	var hair := MeshInstance3D.new()
	hair.name = "Hair"
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.285
	hair_mesh.height = 0.34
	hair.mesh = hair_mesh
	hair.position = Vector3(0.0, 2.07, 0.015)
	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color.from_hsv(float(posmod(_seed, 19)) / 19.0 * 0.12, 0.55, 0.25 + float(posmod(_seed, 5)) * 0.06)
	hair_mat.roughness = 0.96
	hair.material_override = hair_mat
	add_child(hair)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.78
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.89, 0.0)
	add_child(collision)
func _add_capsule(node_name: String, radius: float, height: float, pos: Vector3, material: Material, rotation_radians: Vector3 = Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	mesh.mesh = capsule
	mesh.position = pos
	mesh.rotation = rotation_radians
	mesh.material_override = material
	add_child(mesh)

func _add_sphere(node_name: String, radius: float, pos: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.position = pos
	mesh.scale = scale_value
	mesh.material_override = material
	add_child(mesh)
