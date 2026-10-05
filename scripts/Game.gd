extends Node3D

const WORLD_HALF := 480.0
const GROUND_THICKNESS := 2.0
const PLAYER_START := Vector3(0.0, 2.5, 24.0)
const WORLD_SEED := 6060

var player: CharacterBody3D
var hud: CanvasLayer
var luca: CharacterBody3D
var terrain_slice: Node3D
var quarry_expedition: Node3D
var macro_terrain: MacroTerrain
var egg_hunt: EggHunt
var prop_serial := 0
var spawn_menu_serial := 0
var spawned_npc_serial := 0
var world_plan: KimiWorldPlan
var world_generator: KimiWorldGenerator

func _ready() -> void:
	if OS.get_environment("LUCA_V013_EXPORT_PROBE") == "1":
		_run_v013_export_probe()
		return

	world_plan = KimiWorldPlan.new(WORLD_SEED)
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
	_spawn_egg_hunt()
	print("LUCA_SANDBOX_READY world_half=", WORLD_HALF)

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

func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16, 0.42, 0.73)
	sky_material.sky_horizon_color = Color(0.72, 0.86, 0.88)
	sky_material.ground_bottom_color = Color(0.12, 0.18, 0.16)
	sky_material.ground_horizon_color = Color(0.50, 0.61, 0.55)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.63, 0.72, 0.74)
	environment.fog_density = 0.0018
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = true
	add_child(sun)

func _build_ground_and_boundaries() -> void:
	# One continuous slab: rendered top and collision top are both exactly y=0.
	_create_static_box(
		"WorldGround",
		Vector3(0.0, -GROUND_THICKNESS * 0.5, 0.0),
		Vector3(WORLD_HALF * 2.0, GROUND_THICKNESS, WORLD_HALF * 2.0),
		Color(0.14, 0.27, 0.16)
	)
	# Collision-only outer walls. The old visible wall created the dark horizon/lip.
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
		"KIMI_WORLD_CORE_READY seed=", WORLD_SEED,
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

func _spawn_macro_terrain() -> void:
	var node := Node3D.new()
	node.name = "MacroTerrain"
	node.set_script(load("res://scripts/world/MacroTerrain.gd"))
	node.set("world_plan", world_plan)
	node.set("world_half", WORLD_HALF)
	add_child(node)
	macro_terrain = node as MacroTerrain

func _spawn_player() -> void:
	var node := CharacterBody3D.new()
	node.name = "Player"
	node.set_script(load("res://scripts/Player.gd"))
	node.position = PLAYER_START
	node.set("game", self)
	add_child(node)
	player = node

func _spawn_terrain_slice() -> void:
	var node := Node3D.new()
	node.name = "V013TerrainSlice"
	node.set_script(load("res://scripts/world/TerrainSlice.gd"))
	node.set("player", player)
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
	node.position = PLAYER_START + Vector3(7.5, 0.0, 9.0)
	node.set("player", player)
	node.set("world_half", WORLD_HALF)
	add_child(node)
	luca = node

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
		_spawn_npc(positions[i], "Wanderer %02d" % (i + 1))

func _spawn_starter_props() -> void:
	for i in range(4):
		spawn_prop("crate", Vector3(42 + i * 3.0, 1.3, 45))
	spawn_prop("barrel", Vector3(53, 1.2, 45))
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

func terrain_mine(origin: Vector3, direction: Vector3) -> String:
	if terrain_slice == null:
		return "Terrain slice unavailable"
	return str(terrain_slice.call("mine_from_ray", origin, direction))

func terrain_place(origin: Vector3, direction: Vector3) -> String:
	if terrain_slice == null:
		return "Terrain slice unavailable"
	return str(terrain_slice.call("place_from_ray", origin, direction))

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
		_spawn_npc(at, "Spawned Wanderer %02d" % spawned_npc_serial)
	elif kind == "buggy":
		_spawn_buggy(at)
	else:
		spawn_prop(kind, at)

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
		"barrel":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.7
			cylinder.bottom_radius = 0.7
			cylinder.height = 1.8
			mesh_instance.mesh = cylinder
			var cylinder_shape := CylinderShape3D.new()
			cylinder_shape.radius = 0.7
			cylinder_shape.height = 1.8
			collision.shape = cylinder_shape
			color = Color(0.25, 0.45, 0.62)
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
	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)
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

func _spawn_buggy(at: Vector3) -> void:
	var buggy := CharacterBody3D.new()
	buggy.name = "SandboxBuggy"
	buggy.set_script(load("res://scripts/Buggy.gd"))
	buggy.position = Vector3(clamp(at.x, -440.0, 440.0), max(at.y, 1.1), clamp(at.z, -440.0, 440.0))
	buggy.set("world_half", WORLD_HALF)
	add_child(buggy)

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
