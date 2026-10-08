extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	OS.set_environment("SPIRAL_WORLD_VOXELS", "")
	OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", "user://qa_world_%d.json" % Time.get_ticks_usec())
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", "user://qa_world_spiral_%d.json" % Time.get_ticks_usec())
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	print("[PASS] " if value else "[FAIL] ", label)
	if not value:
		failures.append(label)

func _run() -> void:
	var world := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(world.call("uses_world_voxels"), "ordinary launch selects full voxel world")
	var player: CharacterBody3D = world.get("player")
	var slice = world.get("terrain_slice")
	var terrain = slice.get("terrain")
	var tool = slice.get("voxel_tool")
	var generator = terrain.get("generator")
	check(slice.get("active_bounds").size == Vector3(960, 128, 960), "full world voxel bounds")
	check(world.get_node("WorldGround").collision_layer == 0, "no hidden solid floor under mined cells")
	check(world.get_node("MacroTerrain/WorldTerrain/TerrainCollision").disabled, "far mesh has no duplicate collision")
	for prop in ClassDB.class_get_property_list("VoxelBlockyModelCube"):
		if "material" in str(prop["name"]) or "tile" in str(prop["name"]):
			print("CUBE_PROPERTY ", prop["name"], " ", prop["type"])
	for at in [Vector2(24, 24), Vector2(-300, -250), Vector2(300, 360), Vector2(-460, 400)]:
		var h: float = generator.call("height_at", at.x, at.y)
		player.global_position = Vector3(at.x, h + 3, at.y)
		player.velocity = Vector3.ZERO
		var pos := Vector3i(int(at.x), ceili(h) - 1, int(at.y))
		var ready := false
		for i in range(900):
			await physics_frame
			if slice.call("_is_editable", pos):
				ready = true
				break
		check(ready, "streamed editable terrain at " + str(at))
		if not ready:
			continue
		var original: int = tool.call("get_voxel", pos)
		check(original == 2, "grass surface generated at " + str(at))
		var before_stone: int = slice.get("inventory").call("count_item", "stone")
		var result: String = world.call("terrain_mine", Vector3(at.x + 0.5, h + 4, at.y + 0.5), Vector3.DOWN, 8.0)
		check(result.begins_with("MINED"), "public mining action at " + str(at))
		check(tool.call("get_voxel", pos) == 0, "terrain edit outside quarry at " + str(at))
		for i in range(90):
			await physics_frame
		var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x + .5, h + 8, at.y + .5), Vector3(at.x + .5, h - 4, at.y + .5), 1)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty(), "voxel terrain collision at " + str(at))
		if not hit.is_empty():
			check(absf(hit["position"].y - float(pos.y)) < 0.08, "mining removes top collision at " + str(at))
		var saved: Dictionary = slice.get("persistence").call("get_voxel_deltas")
		check(saved.get("%d,%d,%d" % [pos.x, pos.y, pos.z], -1) == 0, "mining records persistent delta at " + str(at))
		var pickup := world.get_node_or_null("TerrainDrop_stone")
		if pickup != null:
			player.global_position = pickup.global_position - Vector3.UP * 0.8
			for i in range(30):
				await physics_frame
		check(slice.get("inventory").call("count_item", "stone") > before_stone, "mined stone collected via gameplay at " + str(at))
	for npc in get_nodes_in_group("npc"):
		check(npc.global_position.y > -1.0, "remote NPC protected by streamed collision " + npc.name)
	check(world.get_node("SandboxBuggy").global_position.y > -1.0, "remote buggy retains ground support")
	player.global_position = Vector3(25.5, 2.0, 27.0)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	for i in range(180):
		await physics_frame
	var craft_result: String = world.call("terrain_craft")
	check(slice.get("inventory").call("count_item", "stone_brick") == 1, "collected resources craft a stone brick: " + craft_result)
	var place_result: String = world.call("terrain_place", Vector3(25.5, 3.0, 24.5), Vector3.DOWN, 8.0)
	check(place_result.begins_with("PLACED"), "public placement creates a solid block")
	for i in range(90):
		await physics_frame
	player.call("set_touch_move", Vector2(0, -1))
	var climbed := false
	for i in range(22):
		await physics_frame
		if player.global_position.y > 0.7:
			climbed = true
	player.call("set_touch_move", Vector2.ZERO)
	check(climbed, "walking auto-steps a one-metre voxel riser")
	var saved_path: String = slice.get("persistence").get("save_path")
	slice.get("persistence").call("save_now")
	var reload: Node = load("res://scripts/systems/SlicePersistence.gd").new()
	reload.set("generator_version", 2)
	root.add_child(reload)
	reload.call("configure", saved_path, 6060)
	check(reload.call("get_voxel_deltas").size() == 5, "world edit deltas reload from actual disk save")
	reload.queue_free()
	print("WORLD_VOXEL_PEAK_OR_CURRENT_STATIC_MEMORY=", Performance.get_monitor(Performance.MEMORY_STATIC))
	world.queue_free()
	await process_frame
	await process_frame
	var restored := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(restored)
	var restored_player: CharacterBody3D = restored.get("player")
	var restored_slice = restored.get("terrain_slice")
	restored_player.global_position = Vector3(24.5, 3.0, 24.5)
	for i in range(300):
		await physics_frame
	var restored_tool = restored_slice.get("voxel_tool")
	check(restored_tool.call("get_voxel", Vector3i(24, -1, 24)) == 0, "reconstructed world replays mined air")
	check(restored_tool.call("get_voxel", Vector3i(25, 0, 24)) == 3, "reconstructed world replays placed brick")
	check(restored_slice.get("inventory").call("count_item", "stone") == 1, "reconstructed world restores crafted inventory")
	var restored_query := PhysicsRayQueryParameters3D.create(Vector3(25.5, 4, 24.5), Vector3(25.5, -4, 24.5), 1)
	var restored_hit := restored_player.get_world_3d().direct_space_state.intersect_ray(restored_query)
	check(not restored_hit.is_empty() and absf(restored_hit.get("position", Vector3.ZERO).y - 1.0) < 0.08, "reconstructed placed voxel collision restored")
	restored.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
