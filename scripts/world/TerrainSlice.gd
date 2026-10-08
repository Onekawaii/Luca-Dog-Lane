extends Node3D

const CHANNEL_TYPE := 0
const AIR := 0
const STONE := 1
const SURFACE := 2
const BRICK := 3

const SLICE_BOUNDS := AABB(Vector3(256.0, -2.0, 228.0), Vector3(112.0, 54.0, 108.0))
const MOUNTAIN_CENTER := Vector3(310.0, 0.0, 282.0)
const MAX_TOOL_DISTANCE := 8.0
const REPLAY_INTERVAL := 0.75

var player: CharacterBody3D
var macro_terrain: MacroTerrain
var hud: CanvasLayer
var save_path_override := ""
var world_seed := 6060
var world_voxels := false
var height_scale := 1.0
var active_bounds := SLICE_BOUNDS

var terrain: Node
var viewer: Node3D
var voxel_tool
var persistence: Node
var inventory: Node
var replay_timer := 0.0
var replay_queued := false
var selected_place_item := "stone_brick"

func _ready() -> void:
	if world_voxels:
		active_bounds = AABB(Vector3(-480, -16, -480), Vector3(960, 128, 960))
	if not _extension_ready():
		push_error("ENG-003 terrain slice requires staged Voxel Tools")
		return
	_setup_persistence()
	if world_voxels and macro_terrain != null:
		macro_terrain.sync_voxel_edit_columns(persistence.call("get_voxel_deltas"))
	_setup_inventory()
	_setup_terrain()
	_setup_viewer()
	print("V013_TERRAIN_SLICE_READY bounds=", active_bounds, " world_voxels=", world_voxels)

func _process(delta: float) -> void:
	replay_timer += delta
	if replay_timer < REPLAY_INTERVAL:
		return
	replay_timer = 0.0
	if player == null:
		return
	if world_voxels or player.global_position.distance_to(MOUNTAIN_CENTER) <= 140.0:
		_replay_saved_edits()

func _exit_tree() -> void:
	if viewer != null and is_instance_valid(viewer):
		viewer.queue_free()

func set_hud(hud_node: CanvasLayer) -> void:
	hud = hud_node
	if inventory == null:
		return
	var callback := Callable(self, "_on_inventory_changed")
	if not inventory.is_connected("changed", callback):
		inventory.connect("changed", callback)
	_on_inventory_changed(str(inventory.call("summary")))

func mine_from_ray(origin: Vector3, direction: Vector3, max_distance := MAX_TOOL_DISTANCE) -> String:
	if voxel_tool == null:
		return "Voxel terrain unavailable"
	var result = voxel_tool.call("raycast", origin, direction.normalized(), max_distance)
	if result == null:
		return "No mineable voxel in reach"

	var pos: Vector3i = result.call("get_position")
	if not _is_editable(pos):
		return "Terrain chunk is still streaming"

	var current := int(voxel_tool.call("get_voxel", pos))
	if current == AIR:
		return "That voxel is already air"

	voxel_tool.call("set_voxel", pos, AIR)
	persistence.call("set_voxel_delta", pos, AIR)
	if macro_terrain != null:
		macro_terrain.mark_voxel_edit(pos)
	var drop_id := "grass_block" if current == SURFACE else ("stone_brick" if current == BRICK else "stone")
	_spawn_resource_pickup(pos, drop_id, 1)
	return "MINED // " + drop_id.replace("_", " ") + " dropped"

func place_from_ray(origin: Vector3, direction: Vector3, max_distance := MAX_TOOL_DISTANCE) -> String:
	if voxel_tool == null:
		return "Voxel terrain unavailable"
	if int(inventory.call("count_item", selected_place_item)) < 1:
		return "Need 1 " + selected_place_item.replace("_", " ").to_upper() + " // open INVENTORY"

	var result = voxel_tool.call("raycast", origin, direction.normalized(), max_distance)
	if result == null:
		return "Aim at voxel terrain to place"

	var pos: Vector3i = result.call("get_previous_position")
	if not _inside_slice(pos):
		return "Placement outside the terrain slice"
	if not _is_editable(pos):
		return "Terrain chunk is still streaming"
	if int(voxel_tool.call("get_voxel", pos)) != AIR:
		return "Placement cell is occupied"

	var world_center := _voxel_world_center(pos)
	if player != null and world_center.distance_to(player.global_position + Vector3.UP * 0.9) < 1.35:
		return "Placement rejected // player overlap"

	var voxel_id := STONE if selected_place_item == "stone" else (SURFACE if selected_place_item == "grass_block" else BRICK)
	voxel_tool.call("set_voxel", pos, voxel_id)
	persistence.call("set_voxel_delta", pos, voxel_id)
	if macro_terrain != null:
		macro_terrain.mark_voxel_edit(pos)
	inventory.call("consume", selected_place_item, 1)
	return "PLACED " + selected_place_item.replace("_", " ").to_upper() + " // " + str(inventory.call("summary"))

func select_place_item(item_id: String) -> bool:
	if item_id not in ["stone", "grass_block", "stone_brick"]:
		return false
	selected_place_item = item_id
	return true

func craft_recipe(recipe_id: String) -> String:
	if inventory == null:
		return "Inventory unavailable"
	var result: Dictionary = inventory.call("craft", recipe_id)
	return str(result.get("message", "Craft failed"))

func craft_stone_brick() -> String:
	if inventory == null:
		return "Inventory unavailable"
	var result: Dictionary = inventory.call("craft", "stone_brick")
	return str(result.get("message", "Craft failed")) + " // " + str(inventory.call("summary"))

func inventory_summary() -> String:
	if inventory == null:
		return "STONE 0  //  BRICK 0"
	return str(inventory.call("summary"))

func get_voxel_tool_for_test():
	return voxel_tool

func get_inventory_for_test() -> Node:
	return inventory

func get_persistence_for_test() -> Node:
	return persistence

func get_terrain_instance_id_for_test() -> int:
	return terrain.get_instance_id() if terrain != null else 0

func probe_voxel_roundtrip_for_test() -> bool:
	if voxel_tool == null or terrain == null:
		return false
	var candidates := [
		Vector3i(310, 4, 282),
		Vector3i(310, 12, 282),
		Vector3i(310, 20, 282),
		Vector3i(310, 28, 282),
		Vector3i(310, 36, 282),
		Vector3i(310, 44, 282),
	]
	for pos in candidates:
		if not _is_editable(pos):
			continue
		var before := int(voxel_tool.call("get_voxel", pos))
		var replacement := STONE if before == AIR else AIR
		voxel_tool.call("set_voxel", pos, replacement)
		var changed := int(voxel_tool.call("get_voxel", pos))
		voxel_tool.call("set_voxel", pos, before)
		var restored := int(voxel_tool.call("get_voxel", pos))
		return changed == replacement and restored == before
	return false

func apply_voxel_for_test(pos: Vector3i, value: int, persist := true) -> bool:
	if voxel_tool == null or not _is_editable(pos):
		return false
	voxel_tool.call("set_voxel", pos, value)
	if persist:
		persistence.call("set_voxel_delta", pos, value)
	return true

func replay_for_test() -> void:
	_replay_saved_edits()

func _extension_ready() -> bool:
	for type_name in [
		"VoxelTerrain",
		"VoxelViewer",
		"VoxelMesherBlocky",
		"VoxelBlockyLibrary",
		"VoxelBlockyModelEmpty",
		"VoxelBlockyModelCube",
	]:
		if not ClassDB.class_exists(type_name):
			return false
	return true

func _setup_persistence() -> void:
	persistence = Node.new()
	persistence.name = "SlicePersistence"
	persistence.set_script(load("res://scripts/systems/SlicePersistence.gd"))
	if world_voxels:
		persistence.set("generator_version", 2)
		persistence.set("deferred_saves", true)
	add_child(persistence)
	var selected_path := save_path_override
	if selected_path.is_empty():
		selected_path = OS.get_environment("LUCA_V013_SLICE_SAVE_PATH")
	if selected_path.is_empty():
		selected_path = ("user://v020_world_voxels_%d.json" if world_voxels else "user://v016_terrain_slice_%d.json") % world_seed
	else:
		# Seeded test namespaces prevent maps sharing one override file.
		selected_path = selected_path.replace("{seed}", str(world_seed))
	persistence.call("configure", selected_path, world_seed)
	# Copy compatible authored-quarry deltas/inventory once; never modify the old save.
	if world_voxels and save_path_override.is_empty() and OS.get_environment("LUCA_V013_SLICE_SAVE_PATH").is_empty() and not FileAccess.file_exists(selected_path):
		var legacy_path := "user://v016_terrain_slice_%d.json" % world_seed
		if FileAccess.file_exists(legacy_path):
			var legacy = JSON.parse_string(FileAccess.get_file_as_string(legacy_path))
			if typeof(legacy) == TYPE_DICTIONARY and int(legacy.get("schema_version", -1)) == 1 and int(legacy.get("generator_version", -1)) == 1 and int(legacy.get("world_seed", -1)) == world_seed:
				legacy["generator_version"] = 2
				persistence.set("state", legacy)
				persistence.call("save_now")
				print("WORLD_SAVE_MIGRATION_COPY source=", legacy_path, " destination=", selected_path)

func _setup_inventory() -> void:
	inventory = Node.new()
	inventory.name = "SandboxInventory"
	inventory.set_script(load("res://scripts/systems/SandboxInventory.gd"))
	add_child(inventory)
	inventory.call("configure", persistence)

func _setup_terrain() -> void:
	var library = ClassDB.instantiate("VoxelBlockyLibrary")
	var empty_model = ClassDB.instantiate("VoxelBlockyModelEmpty")
	var stone_model = _cube_model(Color(0.39, 0.42, 0.40))
	var surface_model = _cube_model(Color(0.30, 0.48, 0.25))
	var brick_model = _cube_model(Color(0.55, 0.53, 0.49))

	var air_id := int(library.call("add_model", empty_model))
	var stone_id := int(library.call("add_model", stone_model))
	var surface_id := int(library.call("add_model", surface_model))
	var brick_id := int(library.call("add_model", brick_model))
	library.call("bake")

	if [air_id, stone_id, surface_id, brick_id] != [AIR, STONE, SURFACE, BRICK]:
		push_error("Voxel model IDs changed; terrain contract invalid")
		return

	var mesher = ClassDB.instantiate("VoxelMesherBlocky")
	mesher.set("library", library)

	var generator = load("res://scripts/world/TerrainSliceGenerator.gd").new()
	if world_voxels:
		generator = load("res://scripts/world/WorldVoxelGenerator.gd").new()
		generator.call("configure_world", world_seed, height_scale)
	else:
		generator.call("configure", world_seed)

	terrain = ClassDB.instantiate("VoxelTerrain")
	terrain.name = "V013VoxelTerrain"
	terrain.set("generator", generator)
	terrain.set("mesher", mesher)
	terrain.set("bounds", active_bounds)
	terrain.set("max_view_distance", 96)
	terrain.set("mesh_block_size", 16)
	terrain.set("generate_collisions", true)
	terrain.set("collision_layer", 1)
	terrain.set("collision_mask", 1)
	add_child(terrain)

	voxel_tool = terrain.call("get_voxel_tool")
	voxel_tool.set("channel", CHANNEL_TYPE)
	terrain.connect("block_loaded", Callable(self, "_on_block_loaded"))

func _setup_viewer() -> void:
	if player == null:
		push_error("Terrain slice requires player before viewer setup")
		return
	viewer = ClassDB.instantiate("VoxelViewer")
	viewer.name = "TerrainSliceViewer"
	viewer.set("view_distance", 76)
	viewer.set("requires_collisions", true)
	viewer.set("requires_visuals", true)
	viewer.position = Vector3(0.0, 1.2, 0.0)
	player.add_child(viewer)

func _cube_model(color: Color):
	var model = ClassDB.instantiate("VoxelBlockyModelCube")
	model.set("color", color)
	model.set("atlas_size_in_tiles", Vector2i.ONE)
	var kind := "stone"
	if color.g > color.r * 1.3:
		kind = "grass"
	elif color.r > 0.5:
		kind = "brick"
	var material: StandardMaterial3D = load("res://scripts/systems/ObjectMaterials.gd").make(kind, Color.WHITE)
	material.vertex_color_use_as_albedo = true
	model.call("set_material_override", 0, material)
	model.set("collision_mask", 1)
	return model

func _on_block_loaded(_block_position: Vector3i) -> void:
	if not replay_queued:
		replay_queued = true
		call_deferred("_replay_saved_edits")

func _replay_saved_edits() -> void:
	replay_queued = false
	if voxel_tool == null or persistence == null:
		return
	var edits: Dictionary = persistence.call("get_voxel_deltas")
	for key in edits:
		var pos := _parse_voxel_key(str(key))
		if not _inside_slice(pos) or not _is_editable(pos):
			continue
		if int(voxel_tool.call("get_voxel", pos)) != int(edits[key]):
			voxel_tool.call("set_voxel", pos, int(edits[key]))

func _spawn_resource_pickup(pos: Vector3i, item_id: String, amount: int) -> void:
	var pickup := RigidBody3D.new()
	pickup.name = "TerrainDrop_" + item_id
	pickup.set_script(load("res://scripts/systems/ResourcePickup.gd"))
	pickup.set("inventory", inventory)
	pickup.set("player", player)
	pickup.set("item_id", item_id)
	pickup.set("amount", amount)
	var world_pos := _voxel_world_center(pos)
	var launch := Vector3.UP * 3.2
	if player != null:
		var toward_player := player.global_position + Vector3.UP - world_pos
		if toward_player.length() > 0.01:
			launch += toward_player.normalized() * 2.0
	pickup.set("launch_velocity", launch)
	pickup.position = get_parent().to_local(world_pos + Vector3.UP * 0.35)
	get_parent().add_child(pickup)

func _is_editable(pos: Vector3i) -> bool:
	if not _inside_slice(pos):
		return false
	var p := Vector3(float(pos.x), float(pos.y), float(pos.z))
	return bool(voxel_tool.call("is_area_editable", AABB(p - Vector3.ONE, Vector3(3.0, 3.0, 3.0))))

func _inside_slice(pos: Vector3i) -> bool:
	return active_bounds.has_point(Vector3(float(pos.x), float(pos.y), float(pos.z)))

func _voxel_world_center(pos: Vector3i) -> Vector3:
	return terrain.to_global(Vector3(float(pos.x) + 0.5, float(pos.y) + 0.5, float(pos.z) + 0.5))

func _parse_voxel_key(key: String) -> Vector3i:
	var parts := key.split(",")
	if parts.size() != 3:
		return Vector3i(999999, 999999, 999999)
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))

func _on_inventory_changed(summary: String) -> void:
	if hud != null:
		hud.call("set_inventory_status", summary)
