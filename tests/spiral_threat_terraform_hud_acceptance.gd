extends SceneTree

var failures: Array[String] = []
var save_path := "user://qa_spiral_threats_%d.json" % Time.get_ticks_usec()
var terrain_path := "user://qa_spiral_terrain_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", save_path)
	OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", terrain_path)
	OS.set_environment("SPIRAL_SKIP_TITLE", "1")
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures.append(message)
		print("[FAIL] ", message)

func _run() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var world := packed.instantiate()
	root.add_child(world)
	for _i in range(150):
		await physics_frame
	var director = world.get("spiral_world")
	var player = world.get("player")
	var hud = world.get("hud")
	var terrain = world.get("terrain_slice")
	var macro = world.get("macro_terrain")
	check(director != null and player != null and hud != null and terrain != null, "threat/terrain/HUD owners exist")

	var dormant: Dictionary = director.call("get_threat_snapshot_for_test")
	check(int(dormant.minor) == 0 and int(dormant.boss) == 0, "DORMANT has no hostile spawn")

	director.set("witnessing", 30.0)
	director.set("wailing", 0.0)
	director.set("corruption", 0.0)
	director.call("_refresh_world_state")
	await process_frame
	var awake: Dictionary = director.call("get_threat_snapshot_for_test")
	check(str(director.get("stage")) == "AWAKE" and int(awake.minor) == 2 and int(awake.boss) == 0, "AWAKE owns exactly two sentinels")

	director.set("witnessing", 70.0)
	director.call("_refresh_world_state")
	await process_frame
	var infected: Dictionary = director.call("get_threat_snapshot_for_test")
	check(str(director.get("stage")) == "INFECTED" and int(infected.minor) == 4, "INFECTED owns exactly four sentinels")

	director.set("witnessing", 100.0)
	director.set("corruption", 22.0)
	director.call("_refresh_world_state")
	await process_frame
	var breach: Dictionary = director.call("get_threat_snapshot_for_test")
	check(str(director.get("stage")) == "VELVET BREACH" and int(breach.minor) == 6 and int(breach.boss) == 1, "VELVET BREACH owns six sentinels and one boss")

	var enemies := get_nodes_in_group("spiral_enemy")
	var minor: Node
	var boss: Node
	for enemy in enemies:
		if enemy.is_in_group("spiral_boss"):
			boss = enemy
		elif minor == null:
			minor = enemy
	check(minor != null and boss != null, "procedural sentinel and Coil Maw are live bodies")
	if minor != null:
		var health_before := float(minor.get("health"))
		var response := str(minor.call("take_damage", 25.0, Vector3.ZERO, player.global_position))
		check(float(minor.get("health")) < health_before and "SENTINEL" in response, "hammer-compatible damage reduces sentinel health")
		minor.global_position = player.global_position + Vector3(0.0, 0.0, 1.2)
		var player_before := float(player.get("health"))
		minor.call("_physics_process", 0.016)
		check(float(player.get("health")) < player_before, "sentinel proximity attack damages player vitals")

	if boss != null:
		boss.call("take_damage", 1000.0, Vector3.ZERO, player.global_position)
		for _i in range(3):
			await process_frame
		var after_boss: Dictionary = director.call("get_threat_snapshot_for_test")
		check(bool(after_boss.boss_defeated) and int(after_boss.boss) == 0, "Coil Maw defeat removes boss and records completion")

	var small_brush: Array = terrain.call("_brush_offsets", 0.75)
	var medium_brush: Array = terrain.call("_brush_offsets", 1.25)
	var large_brush: Array = terrain.call("_brush_offsets", 1.75)
	check(small_brush.size() == 1 and medium_brush.size() == 7 and large_brush.size() == 27, "terraform brush is spherical, bounded and deterministic")

	var terrain_mesh: ArrayMesh = macro.get("terrain_body").get_node("TerrainMesh").mesh
	var arrays := terrain_mesh.surface_get_arrays(0)
	check((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0, "macro mountains use indexed shared geometry for smooth normals")

	var inventory_panel = hud.get("inventory_panel")
	var quickbar = hud.get("quickbar")
	var quickbar_buttons: Array = quickbar.get("buttons")
	check(hud.get("header_panel").size.x <= 470.0 and hud.get("map_panel").size.x <= 700.0, "header and world map use compact footprints")
	check(inventory_panel.size.x <= 540.0 and hud.get("encounter_panel").size.x <= 620.0, "inventory and encounter menus are compact")
	check(not quickbar_buttons.is_empty() and quickbar_buttons[0].size.y <= 48.0, "hotbar preserves more vertical game view")

	check(director.call("save_state_now"), "Spiral v3 threat state saves")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(typeof(parsed) == TYPE_DICTIONARY and int(parsed.schema_version) == 3 and bool(parsed.boss_defeated), "saved schema persists boss defeat")

	world.queue_free()
	for _i in range(12):
		await physics_frame
	var world2 := packed.instantiate()
	root.add_child(world2)
	for _i in range(150):
		await physics_frame
	var director2 = world2.get("spiral_world")
	var reloaded: Dictionary = director2.call("get_threat_snapshot_for_test")
	check(bool(reloaded.boss_defeated) and int(reloaded.boss) == 0 and int(reloaded.minor) == 6, "reload restores breach sentinels without respawning defeated boss")
	director2.call("clear_state_for_test")
	_finish()

func _finish() -> void:
	for path in [terrain_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("[ALL SPIRAL THREAT + TERRAFORM + HUD GATES PASSED]")
		quit(0)
	else:
		print("[SPIRAL THREAT + TERRAFORM + HUD FAILURES] ", failures.size())
		for item in failures:
			print(" - ", item)
		quit(1)
