extends Node3D
class_name SpiralWorldDirector

const SAVE_PATH := "user://spiral_field_state_v1.json"
const WITNESS_POS := Vector3(-205.0, 0.0, -175.0)
const WAIL_POS := Vector3(205.0, 0.0, 175.0)
const TABBY_POS := Vector3(58.0, 0.0, -42.0)

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

func _ready() -> void:
	name = "SpiralWorldDirector"
	_load_state()
	_build_sites()
	_refresh_world_state()
	print("SPIRAL_FIELD_READY stage=", stage, " affection=", affection, " corruption=", corruption)

func interact(target: Object, action: String) -> String:
	if target == null or not target.has_meta("spiral_id"):
		return "The field does not answer."
	var spiral_id := str(target.get_meta("spiral_id"))
	interaction_count += 1
	var response := ""
	match spiral_id:
		"witnessing":
			if action == "act":
				affection += 2.0
				witnessing += 7.0
				response = "ACT // Behold. The eye notices that you noticed."
			else:
				corruption = maxf(0.0, corruption - 2.5)
				witnessing += 3.0
				response = "MERCY // The eye closes one lid. You remain."
		"wailing":
			if action == "act":
				corruption += 4.0
				wailing += 8.0
				response = "ACT // Speak, spiral. Your voice returns as weather."
			else:
				corruption = maxf(0.0, corruption - 3.5)
				affection += 1.0
				wailing += 3.0
				response = "MERCY // Your mouth is quiet. The message continues."
		"tabbytulhu":
			if action == "act":
				var act_cycle := interaction_count % 3
				if act_cycle == 0:
					affection += 5.0
					response = "ACT // PET // The void purrs back."
				elif act_cycle == 1:
					affection += 4.0
					corruption += 1.0
					response = "ACT // TALK // Tabby'tulhu understands too much."
				else:
					affection += 6.0
					response = "ACT // FEED // Cosmic kibble accepted."
			else:
				affection += 3.0
				corruption = maxf(0.0, corruption - 2.0)
				response = "MERCY // SPARE // The small god-cat decides this is interesting."
		_:
			return "The field does not answer."

	affection = clampf(affection, 0.0, 100.0)
	corruption = clampf(corruption, 0.0, 100.0)
	witnessing = clampf(witnessing, 0.0, 100.0)
	wailing = clampf(wailing, 0.0, 100.0)
	_refresh_world_state()
	_save_state()
	return response + "  //  " + status_summary()

func status_summary() -> String:
	return "AFF %.0f  COR %.0f  EYE %.0f  MOUTH %.0f  // %s" % [
		affection, corruption, witnessing, wailing, stage
	]

func _refresh_world_state() -> void:
	var pressure := maxf(maxf(witnessing, wailing), corruption)
	if pressure >= 75.0:
		stage = "VELVET BREACH"
	elif pressure >= 45.0:
		stage = "INFECTED"
	elif pressure >= 15.0:
		stage = "AWAKE"
	else:
		stage = "DORMANT"
	if hud != null and hud.has_method("set_spiral_status"):
		hud.call("set_spiral_status", status_summary())
	_rebuild_infection_geometry()

func _build_sites() -> void:
	_spawn_spiral_site("witnessing", WITNESS_POS, Color(1.0, 0.34, 0.10), true)
	_spawn_spiral_site("wailing", WAIL_POS, Color(0.45, 0.18, 0.66), false)
	_spawn_tabbytulhu(TABBY_POS)

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
	body.position = _terrain_position(base, 1.2)
	body.add_to_group("spiral_interactable")
	body.set_meta("spiral_id", site_id)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 5.0
	shape.height = 3.0
	collision.shape = shape
	body.add_child(collision)

	var torus := MeshInstance3D.new()
	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = 2.4
	torus_mesh.outer_radius = 4.2
	torus_mesh.rings = 48
	torus_mesh.ring_segments = 12
	torus.mesh = torus_mesh
	torus.rotation_degrees.x = 90.0
	torus.material_override = _emissive_material(color, 2.2)
	body.add_child(torus)

	for i in range(7):
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.32 if witnessing_site else 0.42
		sphere.height = sphere.radius * 2.0
		marker.mesh = sphere
		var angle := float(i) / 7.0 * TAU
		marker.position = Vector3(cos(angle) * 3.1, 0.3 + sin(angle * 2.0) * 0.4, sin(angle) * 3.1)
		marker.material_override = _emissive_material(color.lightened(0.25), 3.0)
		body.add_child(marker)

	if witnessing_site:
		var pupil := MeshInstance3D.new()
		var pupil_mesh := SphereMesh.new()
		pupil_mesh.radius = 0.9
		pupil_mesh.height = 1.3
		pupil.mesh = pupil_mesh
		pupil.scale = Vector3(1.4, 0.55, 0.55)
		pupil.material_override = _emissive_material(Color(1.0, 0.8, 0.35), 3.8)
		body.add_child(pupil)
	else:
		for j in range(5):
			var mouth := MeshInstance3D.new()
			var mouth_mesh := TorusMesh.new()
			mouth_mesh.inner_radius = 0.35 + j * 0.12
			mouth_mesh.outer_radius = 0.65 + j * 0.14
			mouth.mesh = mouth_mesh
			mouth.position = Vector3(0.0, float(j) * 0.55 - 1.1, 0.0)
			mouth.rotation_degrees.x = 90.0
			mouth.material_override = _emissive_material(color.lightened(0.12 * j), 2.8)
			body.add_child(mouth)

	add_child(body)
	site_nodes[site_id] = body

func _spawn_tabbytulhu(base: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Tabbytulhu"
	body.position = _terrain_position(base, 1.0)
	body.add_to_group("spiral_interactable")
	body.set_meta("spiral_id", "tabbytulhu")

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.8
	shape.height = 1.8
	collision.shape = shape
	body.add_child(collision)

	var torso := MeshInstance3D.new()
	var torso_mesh := SphereMesh.new()
	torso_mesh.radius = 0.85
	torso_mesh.height = 1.4
	torso.mesh = torso_mesh
	torso.scale = Vector3(0.9, 1.0, 1.2)
	torso.material_override = _emissive_material(Color(0.08, 0.06, 0.11), 0.35)
	body.add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.65
	head_mesh.height = 1.1
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.95, -0.25)
	head.material_override = _emissive_material(Color(0.12, 0.07, 0.16), 0.55)
	body.add_child(head)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.10
		eye_mesh.height = 0.20
		eye.mesh = eye_mesh
		eye.position = Vector3(0.22 * side, 1.0, -0.82)
		eye.material_override = _emissive_material(Color(1.0, 0.25, 0.08), 4.0)
		body.add_child(eye)

	add_child(body)
	site_nodes["tabbytulhu"] = body

func _rebuild_infection_geometry() -> void:
	if infection_root != null and is_instance_valid(infection_root):
		infection_root.queue_free()
	infection_root = Node3D.new()
	infection_root.name = "ProceduralSpiralInfection"
	add_child(infection_root)
	var pressure := maxf(maxf(witnessing, wailing), corruption)
	var count := clampi(int(pressure * 0.9), 0, 90)
	if count <= 0:
		return
	for i in range(count):
		var t := float(i) / maxf(1.0, float(count - 1))
		var angle := t * TAU * 6.0
		var radius := 2.0 + t * 34.0
		var mote := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.08 + 0.18 * (1.0 - t)
		mesh.height = mesh.radius * 2.0
		mote.mesh = mesh
		mote.position = _terrain_position(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), 0.5 + sin(angle * 1.7) * 1.1)
		var mix := witnessing / maxf(1.0, witnessing + wailing)
		var color := Color(0.52, 0.10, 0.62).lerp(Color(1.0, 0.28, 0.05), mix)
		mote.material_override = _emissive_material(color, 1.8)
		infection_root.add_child(mote)

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.72
	return mat

func _save_state() -> void:
	var payload := {
		"schema_version": 1,
		"affection": affection,
		"corruption": corruption,
		"witnessing": witnessing,
		"wailing": wailing,
		"interaction_count": interaction_count,
		"stage": stage,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if int(parsed.get("schema_version", -1)) != 1:
		return
	affection = float(parsed.get("affection", 0.0))
	corruption = float(parsed.get("corruption", 0.0))
	witnessing = float(parsed.get("witnessing", 0.0))
	wailing = float(parsed.get("wailing", 0.0))
	interaction_count = int(parsed.get("interaction_count", 0))
	stage = str(parsed.get("stage", "DORMANT"))

func clear_state_for_test() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
