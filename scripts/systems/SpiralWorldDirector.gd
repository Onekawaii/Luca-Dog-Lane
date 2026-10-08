extends Node3D
class_name SpiralWorldDirector

const SAVE_PATH := "user://spiral_field_state_v2.json"
const LEGACY_SAVE_PATH := "user://spiral_field_state_v1.json"

func state_save_path() -> String:
	var override := OS.get_environment("SPIRAL_STATE_SAVE_PATH")
	return SAVE_PATH if override.is_empty() else override

func legacy_state_save_path() -> String:
	return LEGACY_SAVE_PATH if OS.get_environment("SPIRAL_STATE_SAVE_PATH").is_empty() else state_save_path() + ".legacy"
const WITNESS_POS := Vector3(-155.0, 0.0, -132.0)
const WAIL_POS := Vector3(176.0, 0.0, 148.0)
const TABBY_POS := Vector3(54.0, 0.0, -42.0)
const SPIRAL_STANDOFF_RADIUS := 7.5

var game: Node
var player: CharacterBody3D
var hud: CanvasLayer

var affection := 0.0
var corruption := 0.0
var witnessing := 0.0
var wailing := 0.0
var interaction_count := 0
var stage := "DORMANT"

var infection_root: Node3D
var site_nodes: Dictionary = {}
var guidance_timer := 0.0
var animation_time := 0.0
var cat_reaction_remaining := 0.0
var cat_reaction_action := ""

func _ready() -> void:
	name = "SpiralWorldDirector"
	_load_state()
	_build_sites()
	_refresh_world_state()
	print(
		"SPIRAL_FIELD_READY stage=", stage,
		" affection=", affection,
		" corruption=", corruption,
		" witnessing=", witnessing,
		" wailing=", wailing
	)

func _process(delta: float) -> void:
	animation_time += delta
	cat_reaction_remaining = maxf(0.0, cat_reaction_remaining - delta)
	guidance_timer += delta
	_animate_encounters()
	if guidance_timer >= 0.20:
		guidance_timer = 0.0
		_update_guidance()

func get_encounter_title(target: Object) -> String:
	if target == null or not target.has_meta("spiral_id"):
		return "THE FIELD"
	match str(target.get_meta("spiral_id")):
		"tabbytulhu":
			return "TABBY'TULHU // THE SMALL GOD THAT NOTICED YOU"
		"witnessing":
			return "THE SPIRAL OF WITNESSING"
		"wailing":
			return "THE SPIRAL OF WAILING"
	return "THE FIELD"

func get_encounter_options(target: Object) -> Array:
	if target == null or not target.has_meta("spiral_id"):
		return []
	match str(target.get_meta("spiral_id")):
		"tabbytulhu":
			return [
				{"label": "TALK", "action": "talk"},
				{"label": "PET", "action": "pet"},
				{"label": "FEED", "action": "feed"},
				{"label": "MERCY", "action": "mercy"},
			]
		"witnessing":
			return [
				{"label": "BEHOLD", "action": "behold"},
				{"label": "AVERT", "action": "avert"},
				{"label": "TOUCH", "action": "touch"},
				{"label": "MERCY", "action": "mercy"},
			]
		"wailing":
			return [
				{"label": "ANSWER", "action": "answer"},
				{"label": "LISTEN", "action": "listen"},
				{"label": "HUSH", "action": "hush"},
				{"label": "MERCY", "action": "mercy"},
			]
	return []

func interact(target: Object, action: String) -> String:
	if target == null or not target.has_meta("spiral_id"):
		return "The field does not answer."

	var spiral_id := str(target.get_meta("spiral_id"))
	interaction_count += 1
	var response := ""

	match spiral_id:
		"witnessing":
			match action:
				"behold":
					witnessing += 8.0
					corruption += 1.0
					response = "You look directly into it. Something looks back from behind your eyes."
				"avert":
					witnessing += 2.0
					corruption = maxf(0.0, corruption - 1.0)
					response = "You look away. It learns the exact shape of your refusal."
				"touch":
					witnessing += 12.0
					corruption += 4.0
					response = "The ring is cold. Your shadow blinks before you do."
				"mercy":
					witnessing += 1.0
					corruption = maxf(0.0, corruption - 2.0)
					response = "You leave the eye unchallenged. It closes almost all the way."
				_:
					return "The eye waits for a clearer gesture."
		"wailing":
			match action:
				"answer":
					wailing += 8.0
					corruption += 2.0
					response = "You answer. The reply comes from every direction except the spiral."
				"listen":
					wailing += 5.0
					affection += 1.0
					response = "You listen without speaking. The sound starts using your breathing."
				"hush":
					wailing += 3.0
					corruption = maxf(0.0, corruption - 2.0)
					response = "You ask for quiet. The world lowers its voice, not its volume."
				"mercy":
					wailing += 1.0
					corruption = maxf(0.0, corruption - 2.5)
					response = "You do not answer. The mouth remembers the silence."
				_:
					return "The mouth keeps forming a word you cannot hear."
		"tabbytulhu":
			match action:
				"talk":
					affection += 2.0
					corruption += 0.25
					response = "You speak softly. Tabby'tulhu tilts its head before the sentence ends."
				"pet":
					affection += 3.0
					response = "Your hand passes through one whisker and touches something warm underneath reality."
				"feed":
					affection += 4.0
					corruption += 0.5
					response = "It accepts the offering, then watches the empty space beside you chew."
				"mercy":
					affection += 2.0
					corruption = maxf(0.0, corruption - 1.5)
					response = "You choose not to demand anything from it. The tail uncurls."
				_:
					return "Tabby'tulhu watches your hand."

	if spiral_id == "tabbytulhu":
		cat_reaction_action = action
		cat_reaction_remaining = 2.0
	affection = clampf(affection, 0.0, 100.0)
	corruption = clampf(corruption, 0.0, 100.0)
	witnessing = clampf(witnessing, 0.0, 100.0)
	wailing = clampf(wailing, 0.0, 100.0)
	_refresh_world_state()
	_save_state()
	return response

func pressure() -> float:
	var spiral_resonance := maxf(witnessing, wailing)
	return clampf(spiral_resonance * 0.75 + corruption * 0.35, 0.0, 100.0)

func status_summary() -> String:
	return "AFF %.0f  COR %.0f  EYE %.0f  MOUTH %.0f  PRESS %.0f  // %s" % [
		affection, corruption, witnessing, wailing, pressure(), stage
	]

func player_status_text() -> String:
	match stage:
		"VELVET BREACH":
			return "THE FIELD HAS OPENED"
		"INFECTED":
			return "THE FIELD IS INFECTED"
		"AWAKE":
			return "THE FIELD IS AWAKE"
	return "THE FIELD IS DORMANT"

func _refresh_world_state() -> void:
	var p := pressure()
	if p >= 80.0:
		stage = "VELVET BREACH"
	elif p >= 50.0:
		stage = "INFECTED"
	elif p >= 20.0:
		stage = "AWAKE"
	else:
		stage = "DORMANT"

	if hud != null:
		if hud.has_method("set_spiral_status"):
			hud.call("set_spiral_status", player_status_text())
	if game != null and game.has_method("apply_spiral_world_state"):
		game.call("apply_spiral_world_state", p, affection, stage, witnessing, wailing)
	_rebuild_infection_geometry()

func _build_sites() -> void:
	_spawn_spiral_site("witnessing", WITNESS_POS, Color(1.0, 0.23, 0.06), true)
	_spawn_spiral_site("wailing", WAIL_POS, Color(0.48, 0.08, 0.62), false)
	_spawn_tabbytulhu(TABBY_POS)
	_spawn_spawn_omens()

func _terrain_position(base: Vector3, lift: float) -> Vector3:
	var p := base
	if game != null and game.has_method("surface_height_at"):
		p.y = float(game.call("surface_height_at", p.x, p.z)) + lift
	else:
		p.y = lift
	return p

func _spawn_spiral_site(site_id: String, base: Vector3, color: Color, witnessing_site: bool) -> void:
	var body := StaticBody3D.new()
	body.name = "Spiral_" + site_id.capitalize()
	body.position = _terrain_position(base, 1.4)
	body.add_to_group("spiral_interactable")
	body.add_to_group("spiral_landmark")
	body.set_meta("spiral_id", site_id)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	# The outer ring reaches roughly 5.1 m. Leave enough clearance for the
	# first-person camera instead of letting the glowing torus engulf the view.
	shape.radius = SPIRAL_STANDOFF_RADIUS
	shape.height = 4.0
	collision.shape = shape
	body.add_child(collision)

	for ring_index in range(3):
		var torus := MeshInstance3D.new()
		var torus_mesh := TorusMesh.new()
		torus_mesh.inner_radius = 2.2 + ring_index * 0.65
		torus_mesh.outer_radius = 3.7 + ring_index * 0.70
		torus_mesh.rings = 48
		torus_mesh.ring_segments = 14
		torus.mesh = torus_mesh
		torus.position.y = ring_index * 1.7
		torus.rotation_degrees = Vector3(
			90.0 if ring_index == 0 else 90.0 - ring_index * 18.0,
			ring_index * 24.0,
			ring_index * 11.0
		)
		torus.material_override = _emissive_material(color.lightened(ring_index * 0.08), 3.0)
		body.add_child(torus)

	var beacon := MeshInstance3D.new()
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 0.20
	beacon_mesh.bottom_radius = 0.55
	beacon_mesh.height = 28.0
	beacon.mesh = beacon_mesh
	beacon.name = "DistantBeacon"
	beacon.position.y = 14.0
	beacon.material_override = _emissive_material(color, 4.2)
	body.add_child(beacon)

	for h in [7.0, 14.0, 21.0, 28.0]:
		var halo := MeshInstance3D.new()
		var halo_mesh := TorusMesh.new()
		halo_mesh.inner_radius = 1.8
		halo_mesh.outer_radius = 2.5
		halo_mesh.rings = 32
		halo_mesh.ring_segments = 10
		halo.mesh = halo_mesh
		halo.position.y = h
		halo.rotation_degrees.x = 90.0
		halo.material_override = _emissive_material(color.lightened(0.25), 4.0)
		body.add_child(halo)

	if witnessing_site:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 1.05
		eye_mesh.height = 1.45
		eye.mesh = eye_mesh
		eye.name = "WitnessEye"
		eye.scale = Vector3(1.55, 0.62, 0.52)
		eye.position = Vector3(0.0, 2.0, -0.8)
		eye.material_override = _emissive_material(Color(1.0, 0.82, 0.32), 4.6)
		body.add_child(eye)
	else:
		for j in range(6):
			var mouth := MeshInstance3D.new()
			var mouth_mesh := TorusMesh.new()
			mouth_mesh.inner_radius = 0.28 + j * 0.15
			mouth_mesh.outer_radius = 0.58 + j * 0.16
			mouth.mesh = mouth_mesh
			mouth.name = "Mouth_%02d" % j
			mouth.position = Vector3(0.0, float(j) * 0.58 - 0.6, -0.7)
			mouth.rotation_degrees.x = 90.0
			mouth.material_override = _emissive_material(color.lightened(0.05 * j), 3.5)
			body.add_child(mouth)

	var light := OmniLight3D.new()
	light.name = "FieldLight"
	light.position = Vector3(0.0, 5.0, 0.0)
	light.light_color = color
	light.light_energy = 5.0
	light.omni_range = 28.0
	body.add_child(light)

	add_child(body)
	load("res://scripts/systems/EncounterVisuals.gd").rebuild_spiral(body, color, witnessing_site)
	site_nodes[site_id] = body

func _spawn_tabbytulhu(base: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Tabbytulhu"
	body.position = _terrain_position(base, 0.0)
	body.add_to_group("spiral_interactable")
	body.set_meta("spiral_id", "tabbytulhu")

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.72
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.85
	body.add_child(collision)

	_add_sphere(body, "Torso", Vector3(0.0, 0.72, 0.16), Vector3(0.72, 0.74, 1.05), Color(0.055, 0.028, 0.075), 0.35)
	_add_sphere(body, "Chest", Vector3(0.0, 0.92, -0.42), Vector3(0.62, 0.67, 0.72), Color(0.08, 0.035, 0.105), 0.45)
	_add_sphere(body, "Head", Vector3(0.0, 1.58, -0.44), Vector3(0.64, 0.56, 0.60), Color(0.07, 0.03, 0.10), 0.55)

	for side in [-1.0, 1.0]:
		_add_box(
			body,
			"Ear_%s" % ("L" if side < 0.0 else "R"),
			Vector3(0.34 * side, 2.08, -0.43),
			Vector3(0.34, 0.52, 0.16),
			Color(0.11, 0.035, 0.14),
			0.8,
			Vector3(0.0, 0.0, -24.0 * side)
		)
		_add_sphere(
			body,
			"Eye_%s" % ("L" if side < 0.0 else "R"),
			Vector3(0.21 * side, 1.64, -0.95),
			Vector3(0.12, 0.15, 0.08),
			Color(1.0, 0.35, 0.04),
			5.0
		)

	for i in range(4):
		var side := -1.0 if i % 2 == 0 else 1.0
		var front := -0.38 if i < 2 else 0.52
		_add_cylinder(
			body,
			"Leg_%02d" % i,
			Vector3(0.38 * side, 0.16, front),
			0.16,
			0.72,
			Color(0.045, 0.025, 0.065),
			0.25
		)

	for i in range(7):
		var t := float(i)
		var tail_pos := Vector3(
			0.42 + t * 0.28,
			0.86 + sin(t * 0.62) * 0.35,
			0.62 + t * 0.13
		)
		_add_sphere(
			body,
			"Tail_%02d" % i,
			tail_pos,
			Vector3(0.24 - t * 0.014, 0.24 - t * 0.014, 0.30),
			Color(0.06, 0.025, 0.082),
			0.35
		)

	for i in range(6):
		var angle := float(i) / 6.0 * TAU
		var tentacle := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.05
		mesh.bottom_radius = 0.12
		mesh.height = 1.8
		tentacle.mesh = mesh
		tentacle.name = "WhiskerTentacle_%02d" % i
		tentacle.position = Vector3(cos(angle) * 0.42, 1.44 + sin(angle * 2.0) * 0.12, -0.88)
		tentacle.rotation_degrees = Vector3(75.0, rad_to_deg(angle), 0.0)
		tentacle.material_override = _emissive_material(Color(0.44, 0.12, 0.52), 1.5)
		body.add_child(tentacle)

	var light := OmniLight3D.new()
	light.name = "TabbyGlow"
	light.position = Vector3(0.0, 1.6, -0.5)
	light.light_color = Color(0.62, 0.18, 0.78)
	light.light_energy = 1.8
	light.omni_range = 8.0
	body.add_child(light)

	add_child(body)
	load("res://scripts/systems/EncounterVisuals.gd").rebuild_cat(body)
	site_nodes["tabbytulhu"] = body

func _spawn_spawn_omens() -> void:
	for i in range(9):
		var t := float(i) / 8.0
		var target := WITNESS_POS.lerp(WAIL_POS, t)
		var at := _terrain_position(target + Vector3(sin(t * 13.0) * 5.0, 0.0, cos(t * 9.0) * 5.0), 0.65)
		var omen := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.22
		mesh.outer_radius = 0.45
		mesh.rings = 20
		mesh.ring_segments = 8
		omen.mesh = mesh
		omen.name = "RoadOmen_%02d" % i
		omen.position = at
		omen.rotation_degrees.x = 90.0
		omen.material_override = _emissive_material(Color(0.74, 0.20, 0.72), 2.8)
		add_child(omen)

func _rebuild_infection_geometry() -> void:
	if infection_root != null and is_instance_valid(infection_root):
		infection_root.queue_free()
	infection_root = Node3D.new()
	infection_root.name = "ProceduralSpiralInfection"
	add_child(infection_root)

	var p := pressure()
	var count := clampi(int(p * 1.35), 0, 135)
	if count <= 0:
		return

	var centers := [WITNESS_POS, WAIL_POS, TABBY_POS]
	for i in range(count):
		var t := float(i) / maxf(1.0, float(count - 1))
		var center: Vector3 = centers[i % centers.size()]
		var angle := t * TAU * 11.0 + float(i % 3)
		var radius := 2.0 + fmod(float(i) * 1.7, 30.0)
		var pos := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var height: float = 0.45 + absf(sin(angle * 1.3)) * (1.0 + p * 0.035)
		var mote := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.07 + 0.14 * (1.0 - t)
		mesh.height = mesh.radius * 2.0
		mote.mesh = mesh
		mote.position = _terrain_position(pos, height)
		var mix := witnessing / maxf(1.0, witnessing + wailing)
		var color := Color(0.42, 0.06, 0.55).lerp(Color(1.0, 0.20, 0.035), mix)
		mote.material_override = _emissive_material(color, 2.1)
		infection_root.add_child(mote)

func _animate_encounters() -> void:
	var tabby = site_nodes.get("tabbytulhu")
	if tabby != null and is_instance_valid(tabby):
		var base_y := _terrain_position(TABBY_POS, 0.0).y
		tabby.position.y = base_y + sin(animation_time * 1.15) * 0.06
		tabby.rotation.y = sin(animation_time * 0.45) * 0.12
		var head: Node3D = tabby.get_node_or_null("Head")
		if head != null:
			var talk := cat_reaction_remaining > 0.0 and cat_reaction_action == "talk"
			var feed := cat_reaction_remaining > 0.0 and cat_reaction_action == "feed"
			head.rotation.z = sin(animation_time * 5.0) * (0.28 if talk else 0.06)
			head.rotation.x = 0.34 if feed else 0.0
		for i in range(4):
			var paw: Node3D = tabby.get_node_or_null("Leg_%02d" % i)
			if paw != null:
				var active_pet := cat_reaction_remaining > 0.0 and cat_reaction_action == "pet"
				paw.position.y = 0.36 + maxf(0.0, sin(animation_time * 8.0 + i * PI)) * (0.11 if active_pet else 0.015)
		var tail: Node3D = tabby.get_node_or_null("Tail_00")
		if tail != null:
			tail.rotation.y = sin(animation_time * 2.1) * (0.32 if cat_reaction_remaining > 0.0 else 0.12)

	for site_id in ["witnessing", "wailing"]:
		var site = site_nodes.get(site_id)
		if site == null or not is_instance_valid(site):
			continue
		var beacon := site.get_node_or_null("DistantBeacon") as MeshInstance3D
		if beacon != null:
			beacon.scale.y = 1.0 + sin(animation_time * 1.6 + (0.0 if site_id == "witnessing" else 1.2)) * 0.08
		var light := site.get_node_or_null("FieldLight") as OmniLight3D
		if light != null:
			light.light_energy = 1.5 + sin(animation_time * 2.2) * 0.2 + pressure() * 0.005

func _update_guidance() -> void:
	if hud == null or player == null or not hud.has_method("set_field_guidance"):
		return
	var witness_distance := int(round(player.global_position.distance_to(_terrain_position(WITNESS_POS, 0.0))))
	var wail_distance := int(round(player.global_position.distance_to(_terrain_position(WAIL_POS, 0.0))))
	var nearest := "WITNESSING" if witness_distance <= wail_distance else "WAILING"
	hud.call(
		"set_field_guidance",
		"WITNESSING %dm  //  WAILING %dm  //  %s CALLS" % [witness_distance, wail_distance, nearest]
	)

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.72
	return mat

func _add_sphere(
	parent: Node3D,
	node_name: String,
	at: Vector3,
	scale_value: Vector3,
	color: Color,
	energy: float
) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	node.mesh = mesh
	node.name = node_name
	node.position = at
	node.scale = scale_value
	node.material_override = _emissive_material(color, energy)
	parent.add_child(node)

func _add_box(
	parent: Node3D,
	node_name: String,
	at: Vector3,
	size_value: Vector3,
	color: Color,
	energy: float,
	rotation_value := Vector3.ZERO
) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	node.mesh = mesh
	node.name = node_name
	node.position = at
	node.rotation_degrees = rotation_value
	node.material_override = _emissive_material(color, energy)
	parent.add_child(node)

func _add_cylinder(
	parent: Node3D,
	node_name: String,
	at: Vector3,
	radius: float,
	height: float,
	color: Color,
	energy: float
) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = height
	node.mesh = mesh
	node.name = node_name
	node.position = at
	node.material_override = _emissive_material(color, energy)
	parent.add_child(node)

func _save_state() -> void:
	save_state_now()

func save_state_now() -> bool:
	var payload := {
		"schema_version": 2,
		"affection": affection,
		"corruption": corruption,
		"witnessing": witnessing,
		"wailing": wailing,
		"interaction_count": interaction_count,
		"stage": stage,
	}
	var file := FileAccess.open(state_save_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
		file.flush()
		if file.get_error() == OK:
			return true
	push_error("Spiral save write failed: " + state_save_path())
	return false

func _load_state() -> void:
	if FileAccess.file_exists(state_save_path()):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(state_save_path()))
		if typeof(parsed) == TYPE_DICTIONARY and int(parsed.get("schema_version", -1)) == 2:
			_apply_loaded_state(parsed)
			return

	if FileAccess.file_exists(legacy_state_save_path()):
		var legacy = JSON.parse_string(FileAccess.get_file_as_string(legacy_state_save_path()))
		if typeof(legacy) == TYPE_DICTIONARY and int(legacy.get("schema_version", -1)) == 1:
			_apply_loaded_state(legacy)
			_save_state()

func _apply_loaded_state(parsed: Dictionary) -> void:
	affection = float(parsed.get("affection", 0.0))
	corruption = float(parsed.get("corruption", 0.0))
	witnessing = float(parsed.get("witnessing", 0.0))
	wailing = float(parsed.get("wailing", 0.0))
	interaction_count = int(parsed.get("interaction_count", 0))
	stage = str(parsed.get("stage", "DORMANT"))

func clear_state_for_test() -> void:
	for path in [state_save_path(), legacy_state_save_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
