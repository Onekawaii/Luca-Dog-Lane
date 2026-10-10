extends SceneTree

const Journal = preload("res://scripts/rpg/ExplorationJournal.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		printerr("FAIL: " + detail)

func verify_model(catalog: Dictionary, locations: Array) -> void:
	var model := Journal.new()
	check(model.configure(catalog, locations), "valid three-record quest configured")
	model.talk("unknown", "history")
	check(not model.accepted, "history does not silently accept work")
	model.read_record(str(locations[0].id))
	model.read_record(str(locations[0].id))
	check(model.read_ids.size() == 1 and not model.completed, "duplicate pages do not advance twice")
	model.talk("unknown", "work")
	check(model.accepted and model.goal().id == locations[1].id, "accepted quest credits already-read record")
	model.read_record("invalid")
	check(model.read_ids.size() == 1, "unknown record cannot fabricate progress")
	model.read_record(str(locations[2].id))
	model.read_record(str(locations[1].id))
	check(not model.completed and model.goal().is_empty(), "all records require return to resident")
	model.talk("unknown", "work")
	check(model.completed and model.objective().contains(str(catalog.quest.reward_title)), "return grants persisted earned title")
	var completed := model.snapshot()
	model.talk("unknown", "work")
	check(model.snapshot() == completed, "repeat turn-in cannot grant another reward")
	var reopened := Journal.new()
	check(reopened.configure(catalog, locations, JSON.parse_string(JSON.stringify(completed))), "journal roundtrip configured")
	check(reopened.snapshot() == completed, "same-world journal roundtrip retains exact progress")
	check(reopened.journal_text().contains(str(locations[2].text)), "journal retains readable full lore")
	var reset := Journal.new()
	check(reset.configure(catalog, locations, {"accepted": true, "completed": true, "read_ids": ["invalid"]}), "old/corrupt IDs can be filtered")
	check(not reset.completed, "invalid records cannot restore a completed quest")
	var duplicate := locations.duplicate(true)
	duplicate[1].id = duplicate[0].id
	check(not reopened.configure(catalog, duplicate), "duplicate location rejected")
	check(reopened.snapshot() == completed, "failed reconfigure cannot corrupt existing progress")

class Player extends CharacterBody3D:
	var blocked := false
	func set_gameplay_blocked(value: bool) -> void:
		blocked = value

class Game extends Node3D:
	var world_seed := 11111
	var active_map_id := "lucas_field"
	var session_menu: Node
	var story_director: Node
	var player: CharacterBody3D
	var hud: CanvasLayer
	func surface_height_at(_x: float, _z: float) -> float:
		return 3.0

class SessionGame extends "res://scripts/Game.gd":
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass

class HUD extends "res://scripts/HUD.gd":
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass

func _verify() -> void:
	var prefix := "user://rpg_test_%d_{map}_{seed}.json" % Time.get_ticks_usec()
	OS.set_environment("SPIRAL_RPG_SAVE_PATH", prefix)
	var game := Game.new()
	root.add_child(game)
	var player := Player.new()
	game.player = player
	root.add_child(player)
	var director = preload("res://scripts/rpg/FieldStoryDirector.gd").new()
	root.add_child(director)
	game.story_director = director
	check(director.configure(game), "field journal configured")
	verify_model(director.model.catalog, director.model.anchors)
	var hud := HUD.new()
	hud.game = game
	hud.player = player
	hud.mobile_ui = true
	root.add_child(hud)
	game.hud = hud
	hud.root = Control.new()
	hud.add_child(hud.root)
	for field in ["spawn_panel", "map_panel", "inventory_panel", "build_panel", "loadout_panel", "encounter_panel"]:
		var panel := Panel.new()
		hud.root.add_child(panel)
		panel.hide()
		hud.set(field, panel)
	var panel = preload("res://scripts/rpg/RPGPanel.gd").new()
	panel.game = game
	panel.hud = hud
	hud.rpg_panel = panel
	hud.root.add_child(panel)
	panel.show_text("Road journal", director.model.journal_text())
	check(hud.has_modal() and player.blocked, "actual HUD modal owns player input while journal is open")
	panel._close()
	check(not hud.has_modal() and not player.blocked, "closing journal restores actual HUD player input")
	var npc = preload("res://scripts/NPC.gd").new()
	npc.resident_id = "resident_0"
	root.add_child(npc)
	panel.show_text("Mara", "Welcome", npc.resident_id, npc)
	check(npc.is_talking, "dialogue pauses actual resident wandering")
	panel._choose("work")
	check(director.model.accepted, "dialogue work choice accepts quest")
	panel._close()
	check(not npc.is_talking, "closing dialogue releases resident")
	director.spawn_records()
	check(director.markers.size() == 3 and director.markers[0].position.y == 3.0, "three records placed on queried terrain")
	var residents := [Vector3(-52, 3, -42), Vector3(105, 3, 18), Vector3(210, 3, 92)]
	for i in director.markers.size():
		check(director.markers[i].position.distance_to(residents[i]) > 4.0, "record slab cannot overlap resident spawn")
		var at: Array = director.model.anchors[i].position
		check(director.markers[i].position.x == float(at[0]) and director.markers[i].position.z == float(at[2]), "quest guidance exactly matches record placement")
	for entry in director.model.anchors:
		director.open_record(str(entry.id))
	director.converse("resident_0", "work")
	check(director.model.completed, "read and return completes persisted field quest")
	var old_path: String = director.save_path
	var reopened = preload("res://scripts/rpg/FieldStoryDirector.gd").new()
	root.add_child(reopened)
	check(reopened.configure(game) and reopened.model.completed, "disk reload retains same-world quest progress")
	game.world_seed = 22222
	var fresh = preload("res://scripts/rpg/FieldStoryDirector.gd").new()
	root.add_child(fresh)
	check(fresh.configure(game) and not fresh.model.accepted, "fresh world starts its own quest")
	check(fresh.save_path != old_path and FileAccess.file_exists(old_path), "fresh quest preserves earlier-world journal file")
	var bad_file := FileAccess.open(fresh.save_path, FileAccess.WRITE)
	bad_file.store_string("broken journal")
	bad_file.close()
	var corrupt = preload("res://scripts/rpg/FieldStoryDirector.gd").new()
	root.add_child(corrupt)
	check(not corrupt.configure(game) and not corrupt.enabled, "corrupt supplemental journal disables story without enabling writes")
	check(FileAccess.get_file_as_string(fresh.save_path) == "broken journal", "corrupt journal is retained for recovery")
	var real_session := SessionGame.new()
	real_session.story_director = corrupt
	check(real_session.save_session(), "disabled supplemental journal cannot block real session save/new-world prerequisite")
	real_session.free()
	game.story_director = corrupt
	panel._close()
	hud.show_road_journal()
	check(hud.has_modal(), "disabled journal exposes recovery explanation in working HUD")
	panel._close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fresh.save_path))
	var terrain := MacroTerrain.new()
	terrain.world_half = 16.0
	terrain.world_plan = KimiWorldPlan.new(11111, 2)
	root.add_child(terrain)
	var material: ShaderMaterial = terrain.terrain_body.get_node("TerrainMesh").mesh.surface_get_material(0)
	check(material.get_shader_parameter("ground_color") != null and material.get_shader_parameter("rock_normal") != null, "actual terrain material binds colour and normal detail")
	var voxel_material := terrain.make_voxel_visibility_material("grass", Color.WHITE)
	check(voxel_material.get_shader_parameter("block_normal") != null and voxel_material.get_shader_parameter("block_roughness") != null, "voxel faces receive available normal and roughness maps")
	check(voxel_material.get_shader_parameter("distance_preview_active") == false, "absent distance mesh cannot hide authoritative voxel surface")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
	print("GROUNDED RPG: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
