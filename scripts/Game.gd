extends Node3D

const WORLD_HALF := 480.0
const GROUND_THICKNESS := 2.0
const DEFAULT_WORLD_SEED := 6060
const DEFAULT_PLAYER_START := Vector3(0.0, 2.5, 24.0)

var player: CharacterBody3D
var hud: CanvasLayer
var session_menu: CanvasLayer
var luca: CharacterBody3D
var terrain_slice: Node3D
var quarry_expedition: Node3D
var macro_terrain: MacroTerrain
var egg_hunt: EggHunt
var prop_serial := 0
var active_blasts: Array[Dictionary] = []
var processing_blasts := false
var spawn_menu_serial := 0
var spawned_npc_serial := 0
var world_plan: KimiWorldPlan
var world_generator: KimiWorldGenerator
var content_registry: ContentRegistry
var spiral_world: SpiralWorldDirector
var active_map_id := "lucas_field"
var active_map_profile: Dictionary = {}
var world_seed := DEFAULT_WORLD_SEED
var player_start := DEFAULT_PLAYER_START
var terrain_scale := 1.0
var world_environment_node: WorldEnvironment
var field_environment: Environment
var field_sky_material: ProceduralSkyMaterial
var field_sun: DirectionalLight3D
var base_sky_top := Color(0.16, 0.42, 0.73)
var base_sky_horizon := Color(0.72, 0.86, 0.88)
var base_fog_color := Color(0.56, 0.66, 0.68)
var base_fog_density := 0.00115

func uses_world_voxels() -> bool:
	var override := OS.get_environment("SPIRAL_WORLD_VOXELS")
	if not override.is_empty():
		return override == "1"
	return bool(ProjectSettings.get_setting("spiral_field/world_voxels", true))

func _ready() -> void:
	print(
		"RENDERER_READY method=", RenderingServer.get_current_rendering_method(),
		" driver=", RenderingServer.get_current_rendering_driver_name(),
		" mobile=", OS.has_feature("mobile")
	)
	if OS.get_environment("LUCA_V013_EXPORT_PROBE") == "1":
		_run_v013_export_probe()
		return
	var player_terrain_probe := OS.get_environment("SPIRAL_PLAYER_TERRAIN_PROBE") == "1"

	_setup_content_registry()
	world_plan = KimiWorldPlan.new(world_seed)
	world_generator = KimiWorldGenerator.new(world_plan)
	_setup_environment()
	_build_ground_and_boundaries()
	_build_roads()
	_build_landmarks()
	_spawn_macro_terrain()
	_build_wilderness()
	_spawn_player()
	_spawn_terrain_slice()
	_spawn_quarry_expedition()
	_spawn_luca()
	_spawn_people()
	_spawn_buggy(Vector3(13.0, 1.2, 10.0))
	_spawn_starter_props()
	_spawn_hud()
	_spawn_spiral_world()
	_spawn_egg_hunt()
	session_menu = load("res://scripts/systems/SessionMenu.gd").new()
	session_menu.game = self
	session_menu.hud = hud
	session_menu.player = player
	add_child(session_menu)
	print(
		"SPIRAL_FIELD_WORLD_READY world_half=", WORLD_HALF,
		" map=", active_map_id,
		" seed=", world_seed
	)
	if player_terrain_probe:
		call_deferred("_run_player_terrain_probe")
	if OS.get_environment("SPIRAL_PC_MENU_PROBE") == "1":
		var probe: Node = load("res://scripts/systems/PCMenuAcceptanceProbe.gd").new()
		probe.world = self
		add_child(probe)

func _setup_content_registry() -> void:
	content_registry = ContentRegistry.new()
	content_registry.name = "ContentRegistry"
	add_child(content_registry)
	if not content_registry.is_valid():
		push_error("Content registry failed validation")

	var default_id := content_registry.get_default_map_id()
	var requested := str(ProjectSettings.get_setting("spiral_field/session_map", default_id))
	if content_registry.get_map(requested).is_empty():
		requested = default_id

	active_map_id = requested
	active_map_profile = content_registry.get_map(active_map_id)
	world_seed = int(active_map_profile.get("seed", DEFAULT_WORLD_SEED))
	terrain_scale = float(active_map_profile.get("terrain_scale", 1.0))
	player_start = _vector3_from_array(
		active_map_profile.get("spawn", [0.0, 2.5, 24.0]),
		DEFAULT_PLAYER_START
	)

func save_session() -> bool:
	# Flush existing schemas; no fabricated player/entity persistence promises.
	var terrain_saved := true
	if terrain_slice != null:
		terrain_saved = bool(terrain_slice.persistence.call("save_now"))
	var spiral_saved := true
	if spiral_world != null:
		spiral_saved = bool(spiral_world.call("save_state_now"))
	return terrain_saved and spiral_saved

func get_tool_ids() -> Array[String]:
	return content_registry.get_tool_ids() if content_registry != null else []

func get_tool_definition(tool_id: String) -> Dictionary:
	return content_registry.get_tool(tool_id) if content_registry != null else {}

func get_map_options() -> Array[Dictionary]:
	return content_registry.get_map_options() if content_registry != null else []

func get_active_map_id() -> String:
	return active_map_id

func get_active_map_label() -> String:
	return str(active_map_profile.get("label", active_map_id.to_upper()))

func request_map(map_id: String) -> bool:
	if content_registry == null or content_registry.get_map(map_id).is_empty():
		return false
	ProjectSettings.set_setting("spiral_field/session_map", map_id)
	call_deferred("_reload_requested_map")
	return true

func restart_field() -> void:
	call_deferred("_reload_requested_map")

func reset_field(all_maps := false) -> String:
	# Never silently destroy progress. Back up each existing file before removing it.
	var seeds: Array[int] = [world_seed]
	if all_maps and content_registry != null:
		for map_id in content_registry.maps:
			var seed := int(content_registry.maps[map_id].get("seed", world_seed))
			if not seeds.has(seed):
				seeds.append(seed)
	var paths: Array[String] = []
	var custom_save := OS.get_environment("LUCA_V013_SLICE_SAVE_PATH")
	if custom_save.is_empty():
		for seed in seeds:
			paths.append("user://v023_world_voxels_%d.json" % seed)
			paths.append("user://v020_world_voxels_%d.json" % seed)
			paths.append("user://v016_terrain_slice_%d.json" % seed)
	else:
		for seed in seeds:
			paths.append(custom_save.replace("{seed}", str(seed)))
	if terrain_slice != null and terrain_slice.get("persistence") != null:
		var active_path := str(terrain_slice.get("persistence").get("save_path"))
		if not paths.has(active_path):
			paths.append(active_path)
	if spiral_world != null:
		paths.append(str(spiral_world.call("state_save_path")))
		paths.append(str(spiral_world.call("legacy_state_save_path")))
	var backup_suffix := ".pre-reset-%d.bak" % int(Time.get_unix_time_from_system())
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var source := ProjectSettings.globalize_path(path)
		if DirAccess.copy_absolute(source, source + backup_suffix) != OK:
			return "RESET BLOCKED // Could not back up " + path
	if terrain_slice != null and terrain_slice.get("persistence") != null:
		terrain_slice.get("persistence").set("save_pending", false)
	for path in paths:
		if FileAccess.file_exists(path):
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
				return "RESET BLOCKED // Could not clear " + path
	call_deferred("_reload_requested_map")
	return "NEW FIELD // current map reset (backups saved)" if not all_maps else "NEW FIELDS // all map saves reset (backups saved)"

func toggle_companion_stay() -> String:
	if luca == null:
		return "Companion unavailable"
	return str(luca.call("toggle_stay"))

func cleanup_spawned() -> int:
	var removed := 0
	for obj in get_tree().get_nodes_in_group("operator_spawned"):
		if is_instance_valid(obj):
			obj.queue_free()
			removed += 1
	for obj in get_tree().get_nodes_in_group("ragdoll"):
		if is_instance_valid(obj) and not obj.is_queued_for_deletion():
			obj.queue_free()
			removed += 1
	return removed

func set_daytime(hour: int) -> void:
	if field_sun == null:
		return
	# Development clock controls sunlight; it does not modify canonical Spiral stage.
	field_sun.rotation_degrees.x = -52.0 if hour >= 6 and hour <= 18 else 46.0
	field_sun.light_energy = 1.02 if hour >= 6 and hour <= 18 else 0.08

func _reload_requested_map() -> void:
	if get_tree().current_scene == null:
		# Test harnesses often instantiate Main manually, without a registered current_scene.
		print("WORLD_RELOAD_SKIPPED // no active scene in this harness")
		return
	get_tree().reload_current_scene()

func _vector3_from_array(value, fallback: Vector3) -> Vector3:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _color_from_array(value, fallback: Color) -> Color:
	if typeof(value) != TYPE_ARRAY or value.size() < 3:
		return fallback
	return Color(float(value[0]), float(value[1]), float(value[2]))

func _run_v013_export_probe() -> void:
	var required := [
		"VoxelTerrain",
		"VoxelViewer",
		"VoxelMesherBlocky",
		"VoxelBlockyLibrary",
		"VoxelBlockyModelCube",
		"VoxelTool",
		"VoxelBuffer",
	]
	for type_name in required:
		if not ClassDB.class_exists(type_name):
			print("[FAIL] exported runtime class missing: ", type_name)
			get_tree().quit(1)
			return

	var terrain = ClassDB.instantiate("VoxelTerrain")
	if terrain == null:
		print("[FAIL] exported runtime could not instantiate VoxelTerrain")
		get_tree().quit(1)
		return
	terrain.free()
	print("[ALL EXPORTED VOXEL RUNTIME GATES PASSED]")
	get_tree().quit(0)

func _run_player_terrain_probe() -> void:
	for _i in range(30):
		await get_tree().physics_frame
	if terrain_slice == null:
		print("[FAIL] player terrain probe: TerrainSlice missing")
		get_tree().quit(1)
		return
	var voxel_tool = terrain_slice.call("get_voxel_tool_for_test")
	if voxel_tool == null:
		print("[FAIL] player terrain probe: VoxelTool is null")
		get_tree().quit(1)
		return
	if int(terrain_slice.call("get_terrain_instance_id_for_test")) == 0:
		print("[FAIL] player terrain probe: VoxelTerrain missing")
		get_tree().quit(1)
		return
	var inventory = terrain_slice.call("get_inventory_for_test")
	if inventory == null:
		print("[FAIL] player terrain probe: inventory missing")
		get_tree().quit(1)
		return
	# The VoxelViewer is parented to the player. Move it into the actual slice
	# so this exported probe exercises streaming and a real read/write/restore.
	player.global_position = Vector3(310.0, 48.0, 282.0)
	player.velocity = Vector3.ZERO
	for _i in range(180):
		await get_tree().physics_frame
	if not bool(terrain_slice.call("probe_voxel_roundtrip_for_test")):
		print("[FAIL] player terrain probe: streamed VoxelTool round-trip failed")
		get_tree().quit(1)
		return
	print("[ALL PLAYER TERRAIN TOOL GATES PASSED]")
	get_tree().quit(0)

func _setup_environment() -> void:
	world_environment_node = WorldEnvironment.new()
	world_environment_node.name = "FieldEnvironment"
	field_environment = Environment.new()
	field_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	field_sky_material = ProceduralSkyMaterial.new()
	base_sky_top = _color_from_array(
		active_map_profile.get("sky_top", [0.16, 0.42, 0.73]),
		Color(0.16, 0.42, 0.73)
	)
	base_sky_horizon = _color_from_array(
		active_map_profile.get("sky_horizon", [0.72, 0.86, 0.88]),
		Color(0.72, 0.86, 0.88)
	)
	base_fog_color = _color_from_array(
		active_map_profile.get("fog_color", [0.56, 0.66, 0.68]),
		Color(0.56, 0.66, 0.68)
	)
	base_fog_density = float(active_map_profile.get("fog_density", 0.00115))
	field_sky_material.sky_top_color = base_sky_top
	field_sky_material.sky_horizon_color = base_sky_horizon
	field_sky_material.ground_bottom_color = Color(0.08, 0.09, 0.09)
	field_sky_material.ground_horizon_color = Color(0.38, 0.44, 0.40)
	sky.sky_material = field_sky_material
	field_environment.sky = sky
	field_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	field_environment.ambient_light_energy = 0.56
	field_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	field_environment.fog_enabled = true
	field_environment.fog_light_color = base_fog_color
	field_environment.fog_density = base_fog_density
	world_environment_node.environment = field_environment
	add_child(world_environment_node)

	field_sun = DirectionalLight3D.new()
	field_sun.name = "FieldSun"
	field_sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	field_sun.light_energy = 1.02
	field_sun.light_color = Color(1.0, 0.94, 0.82)
	field_sun.shadow_enabled = true
	add_child(field_sun)

func apply_spiral_world_state(
	pressure: float,
	affection: float,
	stage: String,
	witnessing: float,
	wailing: float
) -> void:
	if field_environment == null or field_sky_material == null or field_sun == null:
		return
	var t := clampf(pressure / 100.0, 0.0, 1.0)
	var witness_mix := clampf(witnessing / maxf(1.0, witnessing + wailing), 0.0, 1.0)
	var wound_color := Color(0.17, 0.025, 0.18).lerp(Color(0.30, 0.055, 0.02), witness_mix)
	field_sky_material.sky_top_color = base_sky_top.lerp(wound_color, t * 0.88)
	field_sky_material.sky_horizon_color = base_sky_horizon.lerp(Color(0.27, 0.18, 0.28), t * 0.78)
	field_sky_material.ground_horizon_color = Color(0.38, 0.44, 0.40).lerp(Color(0.12, 0.045, 0.13), t)
	field_environment.fog_light_color = base_fog_color.lerp(Color(0.21, 0.08, 0.22), t * 0.90)
	field_environment.fog_density = lerpf(base_fog_density, 0.0105, t)
	field_environment.ambient_light_energy = lerpf(0.56, 0.24, t)
	field_sun.light_energy = lerpf(1.02, 0.42, t)
	field_sun.light_color = Color(1.0, 0.94, 0.82).lerp(Color(0.78, 0.34, 0.46), t)
	if stage == "VELVET BREACH":
		field_environment.fog_density = maxf(field_environment.fog_density, 0.013)
	# Affection does not cancel the horror; it warms a small portion of the light.
	field_sun.light_color = field_sun.light_color.lerp(
		Color(1.0, 0.62, 0.38),
		clampf(affection / 100.0, 0.0, 1.0) * 0.16
	)

func _build_ground_and_boundaries() -> void:
	# Invisible fail-safe floor only. MacroTerrain owns the visible/collidable
	# surface now, so there is no second giant flat world rendered underneath it.
	_create_boundary_wall(
		"WorldGround",
		Vector3(0.0, -GROUND_THICKNESS * 0.5 - 0.25, 0.0),
		Vector3(WORLD_HALF * 2.0, GROUND_THICKNESS, WORLD_HALF * 2.0)
	)
	if uses_world_voxels():
		get_node("WorldGround").set("collision_layer", 0)
	# Collision-only outer walls.
	_create_boundary_wall("NorthBoundary", Vector3(0, 3, -WORLD_HALF), Vector3(WORLD_HALF * 2.0, 6, 2))
	_create_boundary_wall("SouthBoundary", Vector3(0, 3, WORLD_HALF), Vector3(WORLD_HALF * 2.0, 6, 2))
	_create_boundary_wall("WestBoundary", Vector3(-WORLD_HALF, 3, 0), Vector3(2, 6, WORLD_HALF * 2.0))
	_create_boundary_wall("EastBoundary", Vector3(WORLD_HALF, 3, 0), Vector3(2, 6, WORLD_HALF * 2.0))

func _build_roads() -> void:
	# Roads are visual skins over the one continuous collidable ground.
	# They must not create tiny vertical curbs that CharacterBody3D cannot step over.
	var road := Color(0.28, 0.30, 0.31)
	_create_surface_box("MainRoadNS", Vector3(0, 0.025, 0), Vector3(16, 0.05, 760), road)
	_create_surface_box("MainRoadEW", Vector3(0, 0.030, 0), Vector3(760, 0.06, 16), road)
	_create_surface_box("ForestRoad", Vector3(-180, 0.025, -120), Vector3(220, 0.05, 10), road, Vector3(0, -18, 0))
	_create_surface_box("QuarryRoad", Vector3(185, 0.025, 145), Vector3(250, 0.05, 11), road, Vector3(0, 30, 0))
	for marker_z in range(-330, 331, 30):
		_create_visual_box(Vector3(0, 0.065, marker_z), Vector3(0.22, 0.02, 7.0), Color(0.88, 0.80, 0.36))

func _build_landmarks() -> void:
	# Central sandbox pad is a visual ground treatment, not a blocking curb.
	_create_surface_box("SandboxPad", Vector3(55, 0.03, 55), Vector3(80, 0.06, 70), Color(0.42, 0.43, 0.39))
	_create_static_box("WorkshopBack", Vector3(88, 4, 70), Vector3(2, 8, 38), Color(0.35, 0.22, 0.16))
	_create_static_box("WorkshopRoof", Vector3(68, 8, 70), Vector3(42, 1, 38), Color(0.48, 0.29, 0.18))
	_create_static_box("WorkshopSideA", Vector3(68, 4, 51), Vector3(42, 8, 2), Color(0.35, 0.22, 0.16))
	_create_static_box("WorkshopSideB", Vector3(68, 4, 89), Vector3(42, 8, 2), Color(0.35, 0.22, 0.16))

	# Skate / physics test area. Floor is visual-only; ramps deliberately sink
	# their low edge below y=0 so there is no impassable entry lip.
	_create_surface_box("SkateFloor", Vector3(-95, 0.03, 72), Vector3(100, 0.06, 82), Color(0.46, 0.48, 0.48))
	_create_static_box("RampA", Vector3(-122, 2.10, 68), Vector3(22, 1.4, 14), Color(0.68, 0.47, 0.24), Vector3(0, 0, -10))
	_create_static_box("RampB", Vector3(-70, 2.10, 68), Vector3(22, 1.4, 14), Color(0.68, 0.47, 0.24), Vector3(0, 0, 10))
	_create_static_box("LongPlatform", Vector3(-95, 4.0, 96), Vector3(55, 1.2, 12), Color(0.58, 0.38, 0.20))

	# Quarry terraces: real collision, not decorative mountains.
	for level in range(5):
		var radius := 68.0 - float(level) * 10.0
		var height := 4.0
		_create_static_cylinder(
			"QuarryTerrace_%d" % level,
			Vector3(245, 2.0 + float(level) * 4.0, -180),
			radius,
			height,
			Color(0.38 + level * 0.025, 0.36, 0.32)
		)
	_create_static_box("QuarryClimbRamp", Vector3(190, 9, -180), Vector3(75, 1.5, 16), Color(0.45, 0.39, 0.31), Vector3(0, 0, -14))

	# Plaza is painted onto the continuous ground instead of sitting above it.
	_create_surface_cylinder("RoundPlaza", Vector3(-235, 0.04, -205), 42.0, 0.08, Color(0.44, 0.50, 0.47))
	_create_surface_box("PlazaBridge", Vector3(-190, 0.04, -205), Vector3(70, 0.08, 10), Color(0.47, 0.40, 0.30))

func _build_wilderness() -> void:
	var min_chunk := floori(-WORLD_HALF / KimiChunkDescriptor.SIZE_M)
	var max_chunk := floori(WORLD_HALF / KimiChunkDescriptor.SIZE_M)
	var descriptor_digest := 0
	var tree_total := 0
	var rock_total := 0

	for chunk_z in range(min_chunk, max_chunk + 1):
		for chunk_x in range(min_chunk, max_chunk + 1):
			var desc := world_generator.describe_chunk(Vector2i(chunk_x, chunk_z))
			descriptor_digest = KimiDeterministic.mix_value(descriptor_digest, desc.generation_hash)
			for candidate in desc.vegetation_candidates:
				var x := float(candidate["pos_x"])
				var z := float(candidate["pos_z"])
				if not _wilderness_candidate_allowed(x, z, 28.0):
					continue
				var terrain_y := _surface_height(x, z)
				_create_tree(Vector3(x, terrain_y, z), float(candidate["scale"]))
				tree_total += 1

			for candidate in desc.rock_candidates:
				var x := float(candidate["pos_x"])
				var z := float(candidate["pos_z"])
				if not _wilderness_candidate_allowed(x, z, 18.0):
					continue
				var size := float(candidate["scale"])
				var rotation := Vector3(
					float(candidate["rot_x"]),
					float(candidate["rot_y"]),
					float(candidate["rot_z"])
				)
				var terrain_y := _surface_height(x, z)
				_create_static_rock(Vector3(x, terrain_y + size * 0.4, z), size, rotation)
				rock_total += 1

	print(
		"KIMI_WORLD_CORE_READY seed=", world_seed,
		" descriptor_digest=", descriptor_digest,
		" trees=", tree_total,
		" rocks=", rock_total
	)

func _wilderness_candidate_allowed(x: float, z: float, road_clearance: float) -> bool:
	if abs(x) > WORLD_HALF - 24.0 or abs(z) > WORLD_HALF - 24.0:
		return false
	if abs(x) < road_clearance or abs(z) < road_clearance:
		return false
	if Vector2(x - 55.0, z - 55.0).length() < 70.0:
		return false
	if x >= 250.0 and x <= 370.0 and z >= 215.0 and z <= 345.0:
		return false
	return true

func _surface_height(x: float, z: float) -> float:
	if macro_terrain == null:
		return 0.0
	return float(macro_terrain.height_at(x, z))

func surface_height_at(x: float, z: float) -> float:
	return _surface_height(x, z)

func _spawn_spiral_world() -> void:
	var node := SpiralWorldDirector.new()
	node.game = self
	node.player = player
	node.hud = hud
	add_child(node)
	spiral_world = node

func spiral_encounter_title(target: Object) -> String:
	if spiral_world == null:
		return "THE FIELD"
	return str(spiral_world.call("get_encounter_title", target))

func spiral_encounter_options(target: Object) -> Array:
	if spiral_world == null:
		return []
	return spiral_world.call("get_encounter_options", target)

func spiral_interact(target: Object, action: String) -> String:
	if spiral_world == null:
		return "The field is silent."
	return spiral_world.interact(target, action)

func spiral_status_summary() -> String:
	if spiral_world == null:
		return "AFF 0  COR 0  EYE 0  MOUTH 0  // DORMANT"
	return spiral_world.status_summary()

func _spawn_macro_terrain() -> void:
	var node := Node3D.new()
	node.name = "MacroTerrain"
	node.set_script(load("res://scripts/world/MacroTerrain.gd"))
	node.set("world_plan", world_plan)
	node.set("world_half", WORLD_HALF)
	node.set("height_scale", terrain_scale)
	node.set("voxel_preview", uses_world_voxels())
	add_child(node)
	macro_terrain = node as MacroTerrain

func _spawn_player() -> void:
	var node := CharacterBody3D.new()
	node.name = "Player"
	node.set_script(load("res://scripts/Player.gd"))
	node.position = player_start
	node.set("game", self)
	add_child(node)
	player = node

func _spawn_terrain_slice() -> void:
	var node := Node3D.new()
	node.name = "V013TerrainSlice"
	node.set_script(load("res://scripts/world/TerrainSlice.gd"))
	node.set("player", player)
	node.set("world_seed", world_seed)
	node.set("world_voxels", uses_world_voxels())
	node.set("height_scale", terrain_scale)
	node.set("macro_terrain", macro_terrain)
	add_child(node)
	terrain_slice = node

func _spawn_quarry_expedition() -> void:
	var node := Node3D.new()
	node.name = "QuarryExpedition"
	node.set_script(load("res://scripts/world/QuarryExpedition.gd"))
	node.set("player", player)
	add_child(node)
	quarry_expedition = node

func _spawn_luca() -> void:
	var node := CharacterBody3D.new()
	node.name = "Luca"
	node.set_script(load("res://scripts/Luca.gd"))
	# Spawn Luca well behind/right of the player instead of in camera space.
	node.position = player_start + Vector3(7.5, 0.0, 9.0)
	node.set("player", player)
	node.set("world_half", WORLD_HALF)
	add_child(node)
	luca = node
	_attach_stream_guard(node)

func _spawn_people() -> void:
	var positions := [
		Vector3(35, 1.1, -25),
		Vector3(-52, 1.1, -42),
		Vector3(105, 1.1, 18),
		Vector3(-160, 1.1, 125),
		Vector3(210, 1.1, 92),
		Vector3(-248, 1.1, -180)
	]
	for i in range(positions.size()):
		var at: Vector3 = positions[i]
		at.y = _surface_height(at.x, at.z) + 1.1
		_spawn_npc(at, "Drifter %02d" % (i + 1))

func _spawn_starter_props() -> void:
	for i in range(4):
		spawn_prop("crate", Vector3(42 + i * 3.0, 1.3, 45))
	spawn_prop("barrel", Vector3(53, 1.2, 45))
	spawn_prop("explosive_barrel", Vector3(55.5, 1.2, 45))
	spawn_prop("ball", Vector3(58, 1.0, 48))
	spawn_prop("cone", Vector3(62, 1.0, 44))

func _spawn_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SandboxHUD"
	layer.set_script(load("res://scripts/HUD.gd"))
	layer.set("game", self)
	layer.set("player", player)
	add_child(layer)
	hud = layer
	player.set("hud", hud)
	player.call("_sync_tool_label")
	player.call("_sync_vitals")
	if terrain_slice != null:
		terrain_slice.call("set_hud", hud)
	if quarry_expedition != null:
		quarry_expedition.call("set_hud", hud)

func _spawn_egg_hunt() -> void:
	var node := Node3D.new()
	node.name = "EggHunt"
	node.set_script(load("res://scripts/world/EggHunt.gd"))
	node.set("player", player)
	node.set("hud", hud)
	node.set("macro_terrain", macro_terrain)
	add_child(node)
	egg_hunt = node as EggHunt

func get_inventory_snapshot_for_ui() -> Dictionary:
	if terrain_slice == null or terrain_slice.get("inventory") == null:
		return {}
	return terrain_slice.get("inventory").call("snapshot")

func get_item_catalog_for_ui() -> Dictionary:
	return content_registry.items.duplicate(true) if content_registry != null else {}

func get_recipe_catalog_for_ui() -> Dictionary:
	return content_registry.recipes.duplicate(true) if content_registry != null else {}

func get_selected_build_material() -> String:
	return str(terrain_slice.get("selected_place_item")) if terrain_slice != null else "stone_brick"

func select_build_material(item_id: String) -> bool:
	if terrain_slice == null or not bool(terrain_slice.call("select_place_item", item_id)):
		return false
	if player != null:
		player.call("select_tool", "place")
	return true

func toggle_build_mode() -> String:
	if terrain_slice == null:
		return "No editable terrain"
	var active := bool(terrain_slice.call("toggle_creative_build"))
	return "BUILD // CREATIVE MATERIALS ON" if active else "BUILD // RESOURCE MODE"

func cycle_build_material() -> String:
	if terrain_slice == null:
		return "No editable terrain"
	var material := str(terrain_slice.call("cycle_place_item"))
	if player != null:
		player.call("select_tool", "place")
		player.call("_sync_tool_label")
	return "BUILD // " + material.replace("_", " ").to_upper()

func place_explosive_barrel() -> String:
	if player == null or terrain_slice == null:
		return "World not ready"
	if not bool(terrain_slice.get("creative_build")):
		return "Enable BUILD mode first (F)"
	var camera_node: Camera3D = player.get("camera")
	if camera_node == null:
		return "No active camera"
	var aim := camera_node.global_position - camera_node.global_transform.basis.z * 4.5
	var query := PhysicsRayQueryParameters3D.create(aim + Vector3.UP * 5.0, aim - Vector3.UP * 12.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "No solid foundation below barrel"
	var point: Vector3 = hit.position + Vector3.UP * 1.08
	if point.distance_to(player.global_position) < 2.0:
		return "Move back before placing barrel"
	for prop in get_tree().get_nodes_in_group("sandbox_prop"):
		if prop is Node3D and prop.global_position.distance_to(point) < 1.5:
			return "Barrel placement obstructed"
	spawn_prop("explosive_barrel", point)
	return "EXPLOSIVE BARREL PLACED // HAMMER TO DETONATE"

func trigger_build_explosion(location: Vector3, radius: float, damage: float, source: Node) -> void:
	active_blasts.append({"point": location, "radius": radius, "damage": damage, "source": source})
	if processing_blasts:
		return
	processing_blasts = true
	var triggered := 0
	while not active_blasts.is_empty() and triggered < 16:
		var blast: Dictionary = active_blasts.pop_front()
		_execute_build_explosion(blast)
		triggered += 1
	active_blasts.clear()
	processing_blasts = false

func _execute_build_explosion(blast: Dictionary) -> void:
	var center: Vector3 = blast.point
	var radius := float(blast.radius)
	var damage := float(blast.damage)
	var source: Node = blast.source
	var blocks := 0
	if terrain_slice != null:
		blocks = int(terrain_slice.call("blast_placed_blocks", center, radius, 6.5))
	for enemy in get_tree().get_nodes_in_group("spiral_enemy"):
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		var delta: Vector3 = enemy.global_position - center
		if delta.length() < radius and enemy.has_method("take_damage"):
			enemy.call("take_damage", damage * (1.0 - delta.length() / radius), delta.normalized() * 9.0, center)
	for body in get_tree().get_nodes_in_group("sandbox_prop"):
		if not is_instance_valid(body) or body == source or not body is RigidBody3D:
			continue
		var delta: Vector3 = body.global_position - center
		if delta.length() >= radius:
			continue
		var impulse := delta.normalized() * (radius - delta.length()) * 5.0 + Vector3.UP * 5.0
		if body.is_in_group("explosive_barrel") and body.has_method("take_damage"):
			body.call("take_damage", damage, impulse, center)
		elif not body.freeze:
			body.apply_central_impulse(impulse)
	if player != null:
		var player_distance := player.global_position.distance_to(center)
		if player_distance < radius and player.has_method("take_spiral_damage"):
			player.call("take_spiral_damage", damage * (1.0 - player_distance / radius), "EXPLOSIVE BARREL")
	_spawn_blast_visual(center, radius)
	if hud != null:
		hud.call("flash", "BOOM // %d BUILT BLOCKS DESTROYED" % blocks, 2.0)
	print("SPIRAL_BUILD_BLAST radius=", radius, " blocks=", blocks)

func _spawn_blast_visual(point: Vector3, radius: float) -> void:
	var sfx := AudioStreamPlayer3D.new()
	sfx.name = "ExplosionSound"
	sfx.stream = load("res://assets/audio/explosion.wav")
	sfx.position = point
	sfx.volume_db = -5.0
	sfx.max_distance = 65.0
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
	var flash := MeshInstance3D.new()
	flash.name = "ExplosionFlash"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	flash.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.65, 0.13, 0.65)
	material.no_depth_test = true
	flash.material_override = material
	flash.position = point
	flash.scale = Vector3.ONE * 0.25
	add_child(flash)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * radius, 0.4)
	tween.tween_property(material, "albedo_color", Color(0.95, 0.2, 0.04, 0.0), 0.4)
	tween.chain().tween_callback(flash.queue_free)

func terrain_craft_recipe(recipe_id: String) -> String:
	if terrain_slice == null:
		return "Terrain slice unavailable"
	return str(terrain_slice.call("craft_recipe", recipe_id))

func terrain_mine(origin: Vector3, direction: Vector3, max_distance := 8.0, brush_radius := 0.75) -> String:
	if terrain_slice == null:
		return "Terrain slice unavailable"
	return str(terrain_slice.call("mine_from_ray", origin, direction, max_distance, brush_radius))

func terrain_place(origin: Vector3, direction: Vector3, max_distance := 8.0, brush_radius := 0.75) -> String:
	if terrain_slice == null:
		return "Terrain slice unavailable"
	return str(terrain_slice.call("place_from_ray", origin, direction, max_distance, brush_radius))

func terrain_craft() -> String:
	if terrain_slice == null:
		return "Terrain slice unavailable"
	return str(terrain_slice.call("craft_stone_brick"))

func terrain_inventory_summary() -> String:
	if terrain_slice == null:
		return "STONE 0  //  BRICK 0"
	return str(terrain_slice.call("inventory_summary"))

func spawn_from_menu(kind: String) -> void:
	spawn_menu_serial += 1
	var at := _menu_spawn_point(player.call("get_spawn_point"), kind)
	if kind == "npc":
		spawned_npc_serial += 1
		_spawn_npc(at, "Spawned Drifter %02d" % spawned_npc_serial)
	elif kind == "buggy":
		_spawn_buggy(at)
	else:
		spawn_prop(kind, at)
	# Only operator-created actors are eligible for live cleanup.
	var spawned := get_child(get_child_count() - 1)
	if spawned is Node3D and (spawned.is_in_group("sandbox_prop") or spawned.is_in_group("npc") or spawned is VehicleBody3D):
		spawned.add_to_group("operator_spawned")

func _menu_spawn_point(base: Vector3, kind: String) -> Vector3:
	# Golden-angle spiral keeps repeated spawns from occupying the same physics
	# coordinates and exploding into a tower/pile.
	var angle := float(spawn_menu_serial) * 2.399963
	var spacing := 1.9
	if kind == "npc":
		spacing = 2.8
	elif kind == "buggy":
		spacing = 4.2
	var radius := spacing * sqrt(float(max(spawn_menu_serial - 1, 0)))
	var point := base + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	point.x = clamp(point.x, -450.0, 450.0)
	point.z = clamp(point.z, -450.0, 450.0)
	point.y = max(point.y, 1.2)
	return point

func spawn_prop(kind: String, at: Vector3) -> RigidBody3D:
	prop_serial += 1
	var body := RigidBody3D.new()
	body.name = "Prop_%s_%04d" % [kind, prop_serial]
	body.position = Vector3(clamp(at.x, -450.0, 450.0), max(at.y, 1.0), clamp(at.z, -450.0, 450.0))
	body.mass = 2.0
	if kind == "explosive_barrel":
		body.set_script(load("res://scripts/systems/ExplosiveBarrel.gd"))
		body.set("game", self)
		body.mass = 12.0
	body.add_to_group("sandbox_prop")
	body.set_meta("prop_kind", kind)
	body.set_meta("spawned_by_sandbox", true)

	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()
	var color := Color(0.72, 0.48, 0.24)
	match kind:
		"ball":
			var sphere := SphereMesh.new()
			sphere.radius = 0.75
			sphere.height = 1.5
			mesh_instance.mesh = sphere
			var sphere_shape := SphereShape3D.new()
			sphere_shape.radius = 0.75
			collision.shape = sphere_shape
			color = Color(0.92, 0.72, 0.18)
		"barrel", "explosive_barrel":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.7
			cylinder.bottom_radius = 0.7
			cylinder.height = 1.8
			mesh_instance.mesh = cylinder
			var cylinder_shape := CylinderShape3D.new()
			cylinder_shape.radius = 0.7
			cylinder_shape.height = 1.8
			collision.shape = cylinder_shape
			color = Color(0.85, 0.16, 0.10) if kind == "explosive_barrel" else Color(0.25, 0.45, 0.62)
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.05
			cone.bottom_radius = 0.75
			cone.height = 1.7
			mesh_instance.mesh = cone
			var cone_shape := CylinderShape3D.new()
			cone_shape.radius = 0.72
			cone_shape.height = 1.7
			collision.shape = cone_shape
			color = Color(0.95, 0.40, 0.12)
		"ramp":
			var box_ramp := BoxMesh.new()
			box_ramp.size = Vector3(4.0, 0.6, 2.4)
			mesh_instance.mesh = box_ramp
			var ramp_shape := BoxShape3D.new()
			ramp_shape.size = Vector3(4.0, 0.6, 2.4)
			collision.shape = ramp_shape
			body.rotation_degrees.z = -14.0
			color = Color(0.48, 0.50, 0.52)
		_:
			var box := BoxMesh.new()
			box.size = Vector3(1.8, 1.8, 1.8)
			mesh_instance.mesh = box
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(1.8, 1.8, 1.8)
			collision.shape = box_shape
			color = Color(0.58, 0.34, 0.16)

	mesh_instance.material_override = _material(color, 0.78)
	var prop_material: StandardMaterial3D = mesh_instance.material_override
	if kind == "crate" or kind == "barrel" or kind == "explosive_barrel":
		prop_material = load("res://scripts/systems/ObjectMaterials.gd").make("wood" if kind == "crate" else "metal", color)
		mesh_instance.material_override = prop_material
	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)
	_attach_stream_guard(body)
	return body

func duplicate_prop(source: Node3D) -> void:
	if not source.has_meta("prop_kind"):
		return
	var kind := str(source.get_meta("prop_kind"))
	spawn_prop(kind, source.global_position + Vector3(2.2, 1.0, 0))

func _spawn_npc(at: Vector3, display_name: String) -> void:
	var npc := CharacterBody3D.new()
	npc.name = display_name.replace(" ", "_")
	npc.set_script(load("res://scripts/NPC.gd"))
	npc.position = Vector3(clamp(at.x, -440.0, 440.0), max(at.y, 1.1), clamp(at.z, -440.0, 440.0))
	npc.set("display_name", display_name)
	npc.set("world_half", WORLD_HALF)
	add_child(npc)
	_attach_stream_guard(npc)

func _spawn_buggy(at: Vector3) -> void:
	var buggy := VehicleBody3D.new()
	buggy.name = "SandboxBuggy"
	buggy.set_script(load("res://scripts/Buggy.gd"))
	var x := clampf(at.x, -440.0, 440.0)
	var z := clampf(at.z, -440.0, 440.0)
	buggy.position = Vector3(x, _surface_height(x, z) + 0.18, z)
	buggy.set("world_half", WORLD_HALF)
	add_child(buggy)
	_attach_stream_guard(buggy)

func _attach_stream_guard(body: Node3D) -> void:
	if not uses_world_voxels():
		return
	var guard: Node = load("res://scripts/world/WorldStreamGuard.gd").new()
	guard.set("slice", terrain_slice)
	body.add_child(guard)

func _create_boundary_wall(label: String, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _create_surface_box(
	label: String,
	at: Vector3,
	size: Vector3,
	color: Color,
	rot := Vector3.ZERO
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.rotation_degrees = rot
	mesh_instance.material_override = _material(color)
	add_child(mesh_instance)
	return mesh_instance

func _create_surface_cylinder(
	label: String,
	at: Vector3,
	radius: float,
	height: float,
	color: Color
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.material_override = _material(color)
	add_child(mesh_instance)
	return mesh_instance

func _create_static_box(label: String, at: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.rotation_degrees = rot
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)
	return body

func _create_visual_box(at: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.material_override = _material(color, 0.65)
	add_child(mesh_instance)

func _create_static_cylinder(label: String, at: Vector3, radius: float, height: float, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)
	return body

func _create_tree(at: Vector3, scale_factor: float) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.name = "Tree"
	var trunk_mesh := MeshInstance3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.28 * scale_factor
	trunk.bottom_radius = 0.38 * scale_factor
	trunk.height = 3.2 * scale_factor
	trunk_mesh.mesh = trunk
	trunk_mesh.position.y = 1.6 * scale_factor
	trunk_mesh.material_override = _material(Color(0.30, 0.20, 0.12))
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.38 * scale_factor
	shape.height = 3.2 * scale_factor
	collision.shape = shape
	collision.position.y = 1.6 * scale_factor
	body.add_child(trunk_mesh)
	body.add_child(collision)
	for tier in range(2):
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = (1.8 - tier * 0.35) * scale_factor
		cone.height = 2.6 * scale_factor
		cone.radial_segments = 10
		crown.mesh = cone
		crown.position.y = (3.2 + tier * 1.35) * scale_factor
		crown.material_override = _material(Color(0.20 + tier * 0.03, 0.46, 0.24))
		body.add_child(crown)
	add_child(body)

func _create_static_rock(at: Vector3, scale_factor: float, rotation := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.rotation_degrees = rotation
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = scale_factor
	mesh.height = scale_factor * 1.45
	mesh_instance.mesh = mesh
	mesh_instance.scale = Vector3(1.3, 0.75, 1.0)
	mesh_instance.material_override = _material(Color(0.42, 0.45, 0.43))
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = scale_factor
	collision.shape = shape
	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)

func _material(color: Color, roughness := 0.92) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
