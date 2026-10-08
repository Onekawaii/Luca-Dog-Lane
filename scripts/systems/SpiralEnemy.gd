extends CharacterBody3D
class_name SpiralEnemy

signal defeated(enemy: Node, was_boss: bool)

const GRAVITY := 19.0

var player: CharacterBody3D
var enemy_kind := "witness"
var boss := false
var health := 50.0
var max_health := 50.0
var move_speed := 3.4
var attack_damage := 8.0
var attack_range := 1.8
var activation_range := 48.0
var attack_cooldown := 0.0
var home := Vector3.ZERO
var visual_root: Node3D
var animation_time := 0.0

func configure(
	player_node: CharacterBody3D,
	kind: String,
	is_boss: bool,
	home_position: Vector3
) -> void:
	player = player_node
	enemy_kind = kind
	boss = is_boss
	home = home_position
	if boss:
		max_health = 300.0
		move_speed = 2.35
		attack_damage = 22.0
		attack_range = 3.1
		activation_range = 86.0
	health = max_health

func _ready() -> void:
	name = "The_Coil_Maw" if boss else ("Witness_Sentinel" if enemy_kind == "witness" else "Wailing_Sentinel")
	add_to_group("spiral_enemy")
	if boss:
		add_to_group("spiral_boss")
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(54.0)
	_build_collision()
	_build_visuals()

func _physics_process(delta: float) -> void:
	animation_time += delta
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_animate_visuals()
	if player == null or not is_instance_valid(player) or bool(player.get("defeated")):
		_slow_to_stop(delta)
		return

	var offset := player.global_position - global_position
	var planar := Vector3(offset.x, 0.0, offset.z)
	var distance := planar.length()
	if distance > activation_range:
		var home_offset := home - global_position
		var home_planar := Vector3(home_offset.x, 0.0, home_offset.z)
		if home_planar.length() > 5.0:
			_drive(home_planar.normalized(), move_speed * 0.45, delta)
		else:
			_slow_to_stop(delta)
		return

	if distance > attack_range:
		_drive(planar.normalized(), move_speed, delta)
	else:
		_slow_to_stop(delta)
		if attack_cooldown <= 0.0:
			attack_cooldown = 1.55 if boss else 1.15
			player.call("take_spiral_damage", attack_damage, display_name())

func _drive(direction: Vector3, speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, direction.x * speed, 13.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 13.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)
	move_and_slide()

func _slow_to_stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()

func take_damage(amount: float, impulse: Vector3, _source: Vector3) -> String:
	if health <= 0.0:
		return display_name() + " is already collapsing"
	health = maxf(0.0, health - maxf(0.0, amount))
	velocity += Vector3(impulse.x, maxf(1.5, impulse.y + 1.5), impulse.z) * (0.28 if boss else 0.55)
	if health <= 0.0:
		defeated.emit(self, boss)
		queue_free()
		return display_name() + " DEFEATED"
	return "%s // %.0f / %.0f" % [display_name(), health, max_health]

func display_name() -> String:
	if boss:
		return "THE COIL MAW"
	return "WITNESS SENTINEL" if enemy_kind == "witness" else "WAILING SENTINEL"

func health_ratio() -> float:
	return health / maxf(1.0, max_health)

func _build_collision() -> void:
	var shape_node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 1.25 if boss else 0.48
	shape.height = 3.5 if boss else 1.45
	shape_node.shape = shape
	shape_node.position.y = 1.75 if boss else 0.72
	add_child(shape_node)

func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	visual_root.position.y = 1.75 if boss else 0.80
	add_child(visual_root)
	var color := Color(1.0, 0.22, 0.055) if enemy_kind == "witness" else Color(0.68, 0.08, 0.88)
	if boss:
		color = Color(0.86, 0.09, 0.42)
	_add_core(color)
	var ring_count := 5 if boss else 2
	for i in range(ring_count):
		var ring := MeshInstance3D.new()
		ring.name = "Ring_%02d" % i
		var mesh := TorusMesh.new()
		mesh.inner_radius = (1.25 if boss else 0.42) + float(i) * (0.20 if boss else 0.12)
		mesh.outer_radius = mesh.inner_radius + (0.22 if boss else 0.11)
		mesh.rings = 24
		mesh.ring_segments = 10
		ring.mesh = mesh
		ring.rotation_degrees = Vector3(65.0 + i * 9.0, i * 31.0, i * 13.0)
		ring.material_override = _material(color.lightened(float(i) * 0.035), 2.4 if boss else 1.8)
		visual_root.add_child(ring)
	if boss:
		for i in range(8):
			var limb := MeshInstance3D.new()
			limb.name = "Tendril_%02d" % i
			var limb_mesh := CylinderMesh.new()
			limb_mesh.top_radius = 0.06
			limb_mesh.bottom_radius = 0.17
			limb_mesh.height = 2.8
			limb.mesh = limb_mesh
			var angle := float(i) / 8.0 * TAU
			limb.position = Vector3(cos(angle) * 1.3, -0.55, sin(angle) * 1.3)
			limb.rotation_degrees = Vector3(62.0, rad_to_deg(angle), 0.0)
			limb.material_override = _material(color.darkened(0.22), 1.2)
			visual_root.add_child(limb)

func _add_core(color: Color) -> void:
	var core := MeshInstance3D.new()
	core.name = "Core"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 1.35 if boss else 0.52
	core_mesh.height = core_mesh.radius * 2.0
	core.mesh = core_mesh
	core.scale = Vector3(1.0, 0.72, 0.82)
	core.material_override = _material(color.darkened(0.42), 0.8)
	visual_root.add_child(core)
	var pupil := MeshInstance3D.new()
	pupil.name = "Pupil"
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.48 if boss else 0.18
	pupil_mesh.height = pupil_mesh.radius * 2.0
	pupil.mesh = pupil_mesh
	pupil.position = Vector3(0.0, 0.05, -1.02 if boss else -0.39)
	pupil.scale = Vector3(1.0, 1.45, 0.35)
	pupil.material_override = _material(Color(1.0, 0.82, 0.24) if enemy_kind == "witness" else Color(1.0, 0.30, 0.70), 4.8)
	visual_root.add_child(pupil)
	var light := OmniLight3D.new()
	light.name = "ThreatGlow"
	light.light_color = color
	light.light_energy = 2.8 if boss else 1.2
	light.omni_range = 13.0 if boss else 5.0
	visual_root.add_child(light)

func _animate_visuals() -> void:
	if visual_root == null:
		return
	visual_root.position.y = (1.75 if boss else 0.80) + sin(animation_time * (1.8 if boss else 2.6)) * (0.16 if boss else 0.08)
	visual_root.rotation.y = animation_time * (0.35 if boss else 0.75)
	for child in visual_root.get_children():
		if child.name.begins_with("Ring_"):
			child.rotation.z += 0.012 if boss else 0.021

func _material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.63
	return material
