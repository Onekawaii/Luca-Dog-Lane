extends SceneTree

const CAPTURE_DIR := "res://dist/v022-captures"

func _initialize() -> void:
	OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", "user://qa_v022_visual_%d.json" % Time.get_ticks_usec())
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", "user://qa_v022_visual_story_%d.json" % Time.get_ticks_usec())
	OS.set_environment("SPIRAL_SKIP_TITLE", "1")
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var game = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i in range(150):
		await physics_frame
	if DisplayServer.get_name() == "headless":
		print("V022_VISUAL_CAPTURE=SKIPPED_HEADLESS")
		quit(2)
		return
	var director = game.get("spiral_world")
	var player = game.get("player")
	var hud = game.get("hud")
	director.set("witnessing", 100.0)
	director.set("corruption", 22.0)
	director.call("_refresh_world_state")
	for _i in range(8):
		await physics_frame
	var boss: Node3D
	for enemy in get_nodes_in_group("spiral_enemy"):
		enemy.set_physics_process(false)
		if enemy.is_in_group("spiral_boss"):
			boss = enemy
	player.set_physics_process(false)
	if boss != null:
		player.global_position = boss.global_position + Vector3(0.0, 0.5, 9.0)
		var camera: Camera3D = player.get("camera")
		camera.look_at(boss.global_position + Vector3.UP * 1.5, Vector3.UP)
	await _capture("combat-boss-hud.png")

	hud.call("_toggle_inventory_menu")
	await _capture("compact-inventory.png")
	hud.call("_toggle_inventory_menu")
	hud.call("_toggle_map_menu")
	await _capture("compact-map.png")
	hud.call("_toggle_map_menu")
	game.get("session_menu").call("open", "pause")
	await _capture("compact-pause.png")
	print("[ALL V022 VISUAL CAPTURES WRITTEN]")
	quit(0)

func _capture(filename: String) -> void:
	for _i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_viewport().get_texture().get_image().save_png(CAPTURE_DIR.path_join(filename))
	print("V022_CAPTURE ", filename, " RC=", result)
