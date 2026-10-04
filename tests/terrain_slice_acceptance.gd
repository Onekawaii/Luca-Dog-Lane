extends SceneTree

const TEST_SAVE := "user://eng003_terrain_acceptance.json"
const SAMPLE_X := 310.5
const SAMPLE_Z := 282.5

var failures: Array[String] = []
var world: Node3D
var player: CharacterBody3D
var slice: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup_save()
	world = Node3D.new()
	root.add_child(world)
	player = CharacterBody3D.new()
	player.name = "AcceptancePlayer"
	player.position = Vector3(310.0, 38.0, 282.0)
	world.add_child(player)

	slice = _make_slice()
	var tool = await _wait_for_tool(slice)
	if tool == null:
		_fail("terrain center never became editable")
		_finish()
		return
	_pass("terrain center streamed and editable")

	tool.set("channel", 0)
	_check(int(tool.call("get_voxel", Vector3i(310, 2, 282))) != 0, "mountain base is solid")
	_check(int(tool.call("get_voxel", Vector3i(310, 8, 282))) == 0, "through-cave is empty")
	_check(int(tool.call("get_voxel", Vector3i(310, 16, 282))) != 0, "cave has solid overhead matter")

	var terrain_id := int(slice.call("get_terrain_instance_id_for_test"))
	var ray_origin := Vector3(SAMPLE_X, 46.0, SAMPLE_Z)
	var down := Vector3.DOWN
	var first_hit = tool.call("raycast", ray_origin, down, 64.0)
	_check(first_hit != null, "voxel ray finds mountain surface")
	if first_hit == null:
		_finish()
		return

	var mined_pos: Vector3i = first_hit.call("get_position")
	var original_value := int(tool.call("get_voxel", mined_pos))
	_check(original_value != 0, "mine target starts solid")

	var collision_before: Variant = await _physics_hit_y(ray_origin)
	_check(collision_before != null, "physics ray hits generated terrain collision before edit")

	var mine_message := str(slice.call("mine_from_ray", ray_origin, down, 64.0))
	_check(mine_message.begins_with("MINED"), "mine action succeeds through player-facing API")
	_check(int(tool.call("get_voxel", mined_pos)) == 0, "mined voxel becomes authoritative air")
	_check(int(slice.call("get_terrain_instance_id_for_test")) == terrain_id, "mining does not rebuild terrain node")

	var collision_after_mine: Variant = await _wait_for_collision_lower(ray_origin, float(collision_before))
	_check(collision_after_mine != null, "collision remesh reflects mined voxel")

	var inventory: Node = slice.call("get_inventory_for_test")
	var drop: Variant = await _wait_for_drop()
	_check(drop != null, "mining creates physical resource drop")
	if drop != null:
		player.global_position = drop.global_position
		for i in range(90):
			await physics_frame
			if not is_instance_valid(drop):
				break
	_check(int(inventory.call("count_item", "stone")) >= 1, "physical drop enters inventory")

	var no_brick_message := str(slice.call("place_from_ray", ray_origin, down, 64.0))
	_check(no_brick_message.begins_with("Need 1 STONE BRICK"), "placement is rejected without crafted material")
	_check(int(tool.call("get_voxel", mined_pos)) == 0, "rejected no-material placement leaves voxel unchanged")

	while int(inventory.call("count_item", "stone")) < 3:
		inventory.call("add_item", "stone", 1)
	var craft_message := str(slice.call("craft_stone_brick"))
	_check(craft_message.contains("CRAFTED"), "genuine data-driven crafting recipe succeeds")
	_check(int(inventory.call("count_item", "stone_brick")) == 1, "craft produces one stone brick")

	var target_center := Vector3(float(mined_pos.x) + 0.5, float(mined_pos.y) + 0.5, float(mined_pos.z) + 0.5)
	player.global_position = target_center - Vector3.UP * 0.9
	var overlap_message := str(slice.call("place_from_ray", ray_origin, down, 64.0))
	_check(overlap_message.contains("player overlap"), "placement rejects a voxel overlapping the player")
	_check(int(tool.call("get_voxel", mined_pos)) == 0, "overlap rejection leaves voxel unchanged")
	_check(int(inventory.call("count_item", "stone_brick")) == 1, "overlap rejection does not consume brick")

	player.global_position = Vector3(300.0, 38.0, 272.0)
	var place_message := str(slice.call("place_from_ray", ray_origin, down, 64.0))
	_check(place_message.begins_with("PLACED"), "place action succeeds through player-facing API")
	_check(int(tool.call("get_voxel", mined_pos)) == 3, "placed voxel is authoritative stone brick")
	_check(int(inventory.call("count_item", "stone_brick")) == 0, "placement consumes crafted brick")
	_check(int(slice.call("get_terrain_instance_id_for_test")) == terrain_id, "placement does not rebuild terrain node")

	var collision_after_place: Variant = await _wait_for_collision_restore(ray_origin, float(collision_before))
	_check(collision_after_place != null, "collision remesh reflects placed voxel")

	inventory.call("add_item", "stone", 2)
	_check(int(inventory.call("count_item", "stone")) == 2, "inventory state prepared for restart persistence")

	world.remove_child(slice)
	slice.queue_free()
	await process_frame
	await process_frame

	slice = _make_slice()
	var restored_tool: Variant = await _wait_for_tool(slice)
	_check(restored_tool != null, "terrain restreams after restart")
	if restored_tool != null:
		restored_tool.set("channel", 0)
		for i in range(120):
			await process_frame
			if int(restored_tool.call("get_voxel", mined_pos)) == 3:
				break
		_check(int(restored_tool.call("get_voxel", mined_pos)) == 3, "saved voxel delta survives terrain restart")
		var restored_inventory: Node = slice.call("get_inventory_for_test")
		_check(int(restored_inventory.call("count_item", "stone")) == 2, "inventory survives terrain restart")

	_cleanup_save()
	_finish()

func _make_slice() -> Node3D:
	var node := Node3D.new()
	node.name = "TerrainSliceAcceptance"
	node.set_script(load("res://scripts/world/TerrainSlice.gd"))
	node.set("player", player)
	node.set("save_path_override", TEST_SAVE)
	world.add_child(node)
	return node

func _wait_for_tool(node: Node):
	for i in range(600):
		await process_frame
		var tool = node.call("get_voxel_tool_for_test")
		if tool != null and bool(tool.call("is_area_editable", AABB(Vector3(306, -1, 278), Vector3(10, 48, 10)))):
			return tool
	return null

func _wait_for_drop():
	for i in range(120):
		await physics_frame
		for child in world.get_children():
			if str(child.name).begins_with("TerrainDrop_stone"):
				return child
	return null

func _physics_hit_y(origin: Vector3):
	for i in range(180):
		await physics_frame
		var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 64.0)
		query.collision_mask = 1
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return float(hit.position.y)
	return null

func _wait_for_collision_lower(origin: Vector3, previous_y: float):
	for i in range(240):
		await physics_frame
		var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 64.0)
		query.collision_mask = 1
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and float(hit.position.y) < previous_y - 0.45:
			return float(hit.position.y)
	return null

func _wait_for_collision_restore(origin: Vector3, expected_y: float):
	for i in range(240):
		await physics_frame
		var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 64.0)
		query.collision_mask = 1
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and absf(float(hit.position.y) - expected_y) < 0.45:
			return float(hit.position.y)
	return null

func _cleanup_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

func _check(condition: bool, label: String) -> void:
	if condition:
		_pass(label)
	else:
		_fail(label)

func _pass(label: String) -> void:
	print("[PASS] ", label)

func _fail(label: String) -> void:
	failures.append(label)
	print("[FAIL] ", label)

func _finish() -> void:
	_cleanup_save()
	if world != null and is_instance_valid(world):
		world.queue_free()
	await process_frame
	if failures.is_empty():
		print("[ALL ENG-003 TERRAIN SLICE GATES PASSED]")
		quit(0)
	else:
		print("[ENG-003 TERRAIN SLICE FAILURES] ", failures.size())
		quit(1)
