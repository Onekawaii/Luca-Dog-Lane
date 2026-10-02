class_name HiveOpenWorldRenderer
extends "res://scripts/procgen/HiveProcGenChunkRenderer.gd"

const VehicleClass = preload("res://scripts/vehicles/HiveVehicle.gd")
const LucaGuideClass = preload("res://scripts/actors/LucaGuide.gd")
const TerrainShader = preload("res://shaders/luca_terrain.gdshader")
const TERRAIN_RADIUS := 2
const TERRAIN_GRID := 16
const RIVER_HALF_WIDTH := 5.5
const RIVER_BANK_WIDTH := 12.0
const TERRAIN_TEXTURE_ROOT := "res://assets/terrain/"
const WORLD_LEVEL_TYPES := [
	"trailhead_camp", "creek_crossing", "meadow_homestead", "pine_watch",
	"old_orchard", "stone_bridge", "ranger_shed", "lakeside_dock",
	"hill_farm", "firefly_marsh", "hollow_barn", "windmill_field",
	"quarry_path", "mountain_pass", "summit_overlook", "forest_cabin",
	"rail_trail", "storm_shelter", "roadside_garage", "luca_rest",
]

var terrain_cells: Dictionary = {}
var _open_world_ready := false
var _world_origin_plan := Vector2.ZERO
var _height_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _starter_vehicle: HiveVehicle
var _luca_guide: CharacterBody3D
var _terrain_material_cache: Dictionary = {}
var _river_material: StandardMaterial3D

func configure(plan: Dictionary, player: Node3D, breakroom: Node3D) -> void:
	_open_world_ready = false
	super.configure(plan, player, breakroom)
	var breakroom_site := _site_by_id("site.breakroom")
	_world_origin_plan = _plan_position(breakroom_site)
	_height_noise = FastNoiseLite.new()
	_height_noise.seed = int(plan.get("seed", 6060)) + 90439
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.frequency = 0.0018
	_height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_height_noise.fractal_octaves = 4
	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = int(plan.get("seed", 6060)) + 22021
	_detail_noise.frequency = 0.006
	_open_world_ready = true
	update_streaming(true)
	_spawn_starter_vehicle()
	_spawn_luca_guide()

func update_streaming(force: bool = false) -> void:
	super.update_streaming(force)
	if not _open_world_ready or not is_instance_valid(_player):
		return
	var center := Vector2i(
		int(floor(_player.global_position.x / LOCAL_CELL_SIZE)),
		int(floor(_player.global_position.z / LOCAL_CELL_SIZE))
	)
	var desired := {}
	for z in range(center.y - TERRAIN_RADIUS, center.y + TERRAIN_RADIUS + 1):
		for x in range(center.x - TERRAIN_RADIUS, center.x + TERRAIN_RADIUS + 1):
			var key := "%d:%d" % [x, z]
			if slice_cells.has(key):
				continue
			if _cell_inside_world(Vector2i(x, z)):
				desired[key] = true
	for key in terrain_cells.keys():
		if not desired.has(key):
			var node: Node = terrain_cells[key]
			if is_instance_valid(node):
				node.queue_free()
			terrain_cells.erase(key)
	for key in desired.keys():
		if not terrain_cells.has(key):
			_load_terrain_cell(str(key))
	_open_roam_portal_if_loaded()

func terrain_loaded_count() -> int:
	return terrain_cells.size()

func biome_at_local_position(local_pos: Vector2) -> String:
	return _biome_for_plan_position(_world_origin_plan + local_pos)

func open_world_level_type_count() -> int:
	return WORLD_LEVEL_TYPES.size()

func _cell_inside_world(coords: Vector2i) -> bool:
	var center_local := Vector2(
		(float(coords.x) + 0.5) * LOCAL_CELL_SIZE,
		(float(coords.y) + 0.5) * LOCAL_CELL_SIZE
	)
	var plan_pos := _world_origin_plan + center_local
	var size := float(world_plan.get("world_size", 0.0))
	return plan_pos.x >= 0.0 and plan_pos.y >= 0.0 and plan_pos.x <= size and plan_pos.y <= size

func _load_terrain_cell(key: String) -> void:
	var coords := _parse_cell_key(key)
	var root := Node3D.new()
	root.name = "Terrain_" + key.replace(":", "_")
	root.position = Vector3(coords.x * LOCAL_CELL_SIZE, 0.0, coords.y * LOCAL_CELL_SIZE)
	root.set_meta("open_world_cell", key)
	add_child(root)
	terrain_cells[key] = root
	_build_terrain(root, coords)
	_build_river_patch(root, coords)
	_build_road_patch(root, coords)
	for site in _sites_for_cell(coords):
		_build_world_site(root, coords, site)

func _build_terrain(root: Node3D, coords: Vector2i) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_material_for_biome(_biome_for_cell(coords)))
	for z in range(TERRAIN_GRID + 1):
		for x in range(TERRAIN_GRID + 1):
			var lx := float(x) / float(TERRAIN_GRID) * LOCAL_CELL_SIZE
			var lz := float(z) / float(TERRAIN_GRID) * LOCAL_CELL_SIZE
			var world_local := Vector2(
				float(coords.x) * LOCAL_CELL_SIZE + lx,
				float(coords.y) * LOCAL_CELL_SIZE + lz
			)
			var plan_pos := _world_origin_plan + world_local
			var wetness := clampf(1.0 - (_river_distance(world_local) / RIVER_BANK_WIDTH), 0.0, 1.0)
			st.set_uv(Vector2(float(x) / TERRAIN_GRID, float(z) / TERRAIN_GRID))
			st.set_color(Color(wetness, 0.0, 0.0, 1.0))
			st.add_vertex(Vector3(lx, _terrain_height(plan_pos, world_local), lz))
	for z in range(TERRAIN_GRID):
		for x in range(TERRAIN_GRID):
			var a := z * (TERRAIN_GRID + 1) + x
			var b := a + 1
			var c := a + TERRAIN_GRID + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	var mesh := st.commit()
	if mesh == null:
		return
	var visual := MeshInstance3D.new()
	visual.name = "TerrainMesh"
	visual.mesh = mesh
	root.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	root.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)

func _terrain_height(plan_pos: Vector2, local_pos: Vector2) -> float:
	if local_pos.x >= -16.0 and local_pos.x <= 1400.0 and absf(local_pos.y) <= 28.0:
		return 0.0
	if local_pos.x >= 60.0 and local_pos.x <= 102.0 and local_pos.y >= 40.0 and local_pos.y <= 104.0:
		return 0.0
	var base_height := _raw_terrain_height(plan_pos)
	var river_distance := _river_distance(local_pos)
	if river_distance < RIVER_BANK_WIDTH:
		var bank_factor := clampf(1.0 - river_distance / RIVER_BANK_WIDTH, 0.0, 1.0)
		base_height -= bank_factor * bank_factor * 3.6
	return snappedf(base_height, 0.02)


func _raw_terrain_height(plan_pos: Vector2) -> float:
	var biome := _biome_for_plan_position(plan_pos)
	var amplitude := _amplitude_for_biome(biome)
	var broad := _height_noise.get_noise_2d(plan_pos.x, plan_pos.y) * amplitude
	var detail := _detail_noise.get_noise_2d(plan_pos.x, plan_pos.y) * amplitude * 0.18
	return broad + detail


func _river_center_z(local_x: float) -> float:
	return 150.0 + sin(local_x * 0.0042) * 74.0 + sin(local_x * 0.0127 + 1.1) * 20.0


func _river_distance(local_pos: Vector2) -> float:
	return absf(local_pos.y - _river_center_z(local_pos.x))

func _amplitude_for_biome(biome: String) -> float:
	match biome:
		"sunmeadow_fields": return 5.0
		"whisperpine_woods": return 12.0
		"creekglass_wetlands": return 4.0
		"golden_dune_ridge": return 18.0
		"cloudstep_highlands": return 48.0
		"moonfrost_basin": return 22.0
		"redclay_badlands": return 28.0
		"old_orchard_vale": return 9.0
		"firefly_marsh": return 3.0
		"starlight_range": return 42.0
	return 8.0

func _biome_for_cell(coords: Vector2i) -> String:
	var center := Vector2(
		(float(coords.x) + 0.5) * LOCAL_CELL_SIZE,
		(float(coords.y) + 0.5) * LOCAL_CELL_SIZE
	)
	return _biome_for_plan_position(_world_origin_plan + center)

func _biome_for_plan_position(plan_pos: Vector2) -> String:
	var nearest := "sunmeadow_fields"
	var best := INF
	for raw in world_plan.get("regions", []):
		if not raw is Dictionary:
			continue
		var region: Dictionary = raw
		var rp: Vector2 = _position_dict_to_v2(region.get("position", {}))
		var dist := plan_pos.distance_squared_to(rp)
		if dist < best:
			best = dist
			nearest = str(region.get("biome", nearest))
	return nearest

func _position_dict_to_v2(raw: Variant) -> Vector2:
	if raw is Dictionary:
		var value: Dictionary = raw
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO


func _material_for_biome(biome: String) -> Material:
	if _terrain_material_cache.has(biome):
		return _terrain_material_cache[biome]
	var profile := _biome_material_profile(biome)
	var material := ShaderMaterial.new()
	material.shader = TerrainShader
	material.set_shader_parameter("ground_tex", load(TERRAIN_TEXTURE_ROOT + str(profile["ground"]) + ".png"))
	material.set_shader_parameter("soil_tex", load(TERRAIN_TEXTURE_ROOT + str(profile["soil"]) + ".png"))
	material.set_shader_parameter("rock_tex", load(TERRAIN_TEXTURE_ROOT + str(profile["rock"]) + ".png"))
	material.set_shader_parameter("ground_tint", profile["ground_tint"])
	material.set_shader_parameter("soil_tint", profile["soil_tint"])
	material.set_shader_parameter("rock_tint", profile["rock_tint"])
	material.set_shader_parameter("texture_scale", float(profile["texture_scale"]))
	material.set_shader_parameter("rock_start", float(profile["rock_start"]))
	material.set_shader_parameter("rock_full", float(profile["rock_full"]))
	material.set_shader_parameter("soil_strength", float(profile["soil_strength"]))
	_terrain_material_cache[biome] = material
	return material


func _biome_material_profile(biome: String) -> Dictionary:
	var profile := {
		"ground": "meadow_grass", "soil": "dry_dirt", "rock": "granite_rock",
		"ground_tint": Vector3(1.0, 1.0, 1.0), "soil_tint": Vector3(1.0, 1.0, 1.0),
		"rock_tint": Vector3(1.0, 1.0, 1.0), "texture_scale": 0.11,
		"rock_start": 0.24, "rock_full": 0.62, "soil_strength": 0.34,
	}
	match biome:
		"whisperpine_woods":
			profile.merge({"ground": "forest_floor", "soil": "dry_dirt", "rock": "cold_stone", "soil_strength": 0.42}, true)
		"creekglass_wetlands":
			profile.merge({"ground": "meadow_grass", "soil": "river_mud", "rock": "granite_rock", "soil_strength": 0.58}, true)
		"golden_dune_ridge":
			profile.merge({"ground": "pale_sand", "soil": "dry_dirt", "rock": "granite_rock", "rock_start": 0.32}, true)
		"cloudstep_highlands":
			profile.merge({"ground": "meadow_grass", "soil": "cold_stone", "rock": "cold_stone", "rock_start": 0.15, "rock_full": 0.50}, true)
		"moonfrost_basin":
			profile.merge({"ground": "snow_grit", "soil": "cold_stone", "rock": "granite_rock", "soil_strength": 0.20}, true)
		"redclay_badlands":
			profile.merge({"ground": "red_clay", "soil": "dry_dirt", "rock": "granite_rock", "rock_start": 0.20}, true)
		"old_orchard_vale":
			profile.merge({"ground": "meadow_grass", "soil": "forest_floor", "rock": "granite_rock", "soil_strength": 0.46}, true)
		"firefly_marsh":
			profile.merge({"ground": "river_mud", "soil": "forest_floor", "rock": "granite_rock", "soil_strength": 0.62}, true)
		"starlight_range":
			profile.merge({"ground": "forest_floor", "soil": "cold_stone", "rock": "cold_stone", "rock_start": 0.18, "rock_full": 0.52}, true)
	return profile


func _build_river_patch(root: Node3D, coords: Vector2i) -> void:
	var x0 := float(coords.x) * LOCAL_CELL_SIZE
	var z0 := float(coords.y) * LOCAL_CELL_SIZE
	var intersects := false
	for probe in range(5):
		var wx := x0 + float(probe) / 4.0 * LOCAL_CELL_SIZE
		var center_z := _river_center_z(wx)
		if center_z >= z0 - RIVER_HALF_WIDTH and center_z <= z0 + LOCAL_CELL_SIZE + RIVER_HALF_WIDTH:
			intersects = true
			break
	if not intersects:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_get_river_material())
	var samples := 12
	for i in range(samples + 1):
		var wx := x0 + float(i) / float(samples) * LOCAL_CELL_SIZE
		var center_z := _river_center_z(wx)
		var local_x := wx - x0
		var local_z := center_z - z0
		var plan_pos := _world_origin_plan + Vector2(wx, center_z)
		var water_y := _raw_terrain_height(plan_pos) - 1.15
		st.set_uv(Vector2(float(i) / float(samples), 0.0))
		st.add_vertex(Vector3(local_x, water_y, local_z - RIVER_HALF_WIDTH))
		st.set_uv(Vector2(float(i) / float(samples), 1.0))
		st.add_vertex(Vector3(local_x, water_y, local_z + RIVER_HALF_WIDTH))
	for i in range(samples):
		var a := i * 2
		var b := a + 1
		var c := a + 2
		var d := a + 3
		st.add_index(a); st.add_index(c); st.add_index(b)
		st.add_index(b); st.add_index(c); st.add_index(d)
	var mesh := st.commit()
	if mesh == null:
		return
	var river := MeshInstance3D.new()
	river.name = "RiverWater"
	river.mesh = mesh
	root.add_child(river)


func _get_river_material() -> StandardMaterial3D:
	if is_instance_valid(_river_material):
		return _river_material
	_river_material = StandardMaterial3D.new()
	_river_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_river_material.albedo_color = Color(0.08, 0.27, 0.32, 0.72)
	_river_material.roughness = 0.18
	_river_material.metallic = 0.06
	_river_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _river_material


func _sites_for_cell(coords: Vector2i) -> Array:
	var result: Array = []
	for raw in world_plan.get("sites", []):
		if not raw is Dictionary:
			continue
		var site: Dictionary = raw
		if str(site.get("id", "")) == "site.breakroom":
			continue
		var local := _plan_position(site) - _world_origin_plan
		var sc := Vector2i(
			int(floor(local.x / LOCAL_CELL_SIZE)),
			int(floor(local.y / LOCAL_CELL_SIZE))
		)
		if sc == coords:
			result.append(site)
	return result

func _build_world_site(root: Node3D, coords: Vector2i, site: Dictionary) -> void:
	var local_world := _plan_position(site) - _world_origin_plan
	var local := Vector3(
		local_world.x - float(coords.x) * LOCAL_CELL_SIZE,
		0.0,
		local_world.y - float(coords.y) * LOCAL_CELL_SIZE
	)
	local.y = _terrain_height(_plan_position(site), local_world) + 0.12
	var archetype := str(site.get("archetype", "transitional"))
	var type_index := WORLD_LEVEL_TYPES.find(archetype)
	if type_index < 0:
		type_index = posmod(archetype.hash(), WORLD_LEVEL_TYPES.size())
	var accent := _site_material(type_index)
	var dark := accent.duplicate() as StandardMaterial3D
	dark.albedo_color = accent.albedo_color.darkened(0.55)
	_add_static_box(root, "SiteFloor_" + str(site.get("id", "")).replace(".", "_"),
		Vector3(15.0, 0.25, 15.0), local + Vector3(0.0, -0.12, 0.0), dark)
	var height := 2.6 + float(type_index % 4) * 0.35
	_add_static_box(root, "SiteBack", Vector3(15.0, height, 0.28), local + Vector3(0.0, height * 0.5, -7.35), dark)
	_add_static_box(root, "SiteLeft", Vector3(0.28, height, 11.0), local + Vector3(-7.35, height * 0.5, -1.9), dark)
	_add_static_box(root, "SiteRight", Vector3(0.28, height, 11.0), local + Vector3(7.35, height * 0.5, -1.9), dark)
	for i in range(1 + type_index % 4):
		var lane := -4.5 + float(i) * 3.0
		var box_size := Vector3(1.1 + float(type_index % 3), 0.8 + float(i % 2), 2.2)
		_add_static_box(root, "SiteFeature_%02d_%02d" % [type_index, i], box_size,
			local + Vector3(lane, box_size.y * 0.5, 1.5 + float(type_index % 3)), accent)
	var label := Label3D.new()
	label.name = "SiteIdentity"
	label.text = "%02d // %s\n%s" % [type_index + 1, archetype.replace("_", " ").to_upper(), str(site.get("id", ""))]
	label.position = local + Vector3(0.0, height + 0.55, -6.9)
	label.font_size = 26
	label.modulate = accent.albedo_color.lightened(0.35)
	root.add_child(label)

func _site_material(type_index: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var hue := fmod(0.05 + float(type_index) * 0.071, 1.0)
	mat.albedo_color = Color.from_hsv(hue, 0.58, 0.62)
	mat.roughness = 0.78
	return mat

func _build_road_patch(root: Node3D, coords: Vector2i) -> void:
	if posmod(coords.y, 4) != 2 and posmod(coords.x, 6) != 2:
		return
	var road := StandardMaterial3D.new()
	road.albedo_color = Color(0.07, 0.065, 0.075)
	road.roughness = 0.96
	var center_local := Vector2(
		(float(coords.x) + 0.5) * LOCAL_CELL_SIZE,
		(float(coords.y) + 0.5) * LOCAL_CELL_SIZE
	)
	var plan := _world_origin_plan + center_local
	var y := _terrain_height(plan, center_local) + 0.08
	if posmod(coords.y, 4) == 2:
		_add_static_box(root, "RoadEW", Vector3(LOCAL_CELL_SIZE, 0.10, 5.8), Vector3(LOCAL_CELL_SIZE * 0.5, y, LOCAL_CELL_SIZE * 0.5), road)
	if posmod(coords.x, 6) == 2:
		_add_static_box(root, "RoadNS", Vector3(5.8, 0.10, LOCAL_CELL_SIZE), Vector3(LOCAL_CELL_SIZE * 0.5, y + 0.02, LOCAL_CELL_SIZE * 0.5), road)

func _open_roam_portal_if_loaded() -> void:
	var branch := get_node_or_null("Cell_2_1")
	if branch == null:
		return
	var wall := branch.get_node_or_null("BranchFarWall")
	if wall != null:
		wall.visible = false
		wall.process_mode = Node.PROCESS_MODE_DISABLED
		var collision := wall.get_node_or_null("Collision") as CollisionShape3D
		if collision != null:
			collision.disabled = true
	if branch.get_node_or_null("OpenWorldRoadLink") == null:
		var road := StandardMaterial3D.new()
		road.albedo_color = Color(0.07, 0.065, 0.075)
		road.roughness = 0.95
		_add_static_box(branch, "OpenWorldRoadLink", Vector3(5.5, 0.20, 20.0), Vector3(16.0, -0.10, 22.0), road)
		var sign := Label3D.new()
		sign.name = "FreeRoamSign"
		sign.text = "LUCA DOG WORLD // OPEN ROAD // TEN BIOMES"
		sign.position = Vector3(16.0, 2.3, 20.0)
		sign.font_size = 30
		sign.modulate = Color(0.78, 0.62, 0.92)
		branch.add_child(sign)

func _spawn_starter_vehicle() -> void:
	if is_instance_valid(_starter_vehicle):
		return
	_starter_vehicle = VehicleClass.new()
	_starter_vehicle.name = "StarterTrailCar"
	_starter_vehicle.vehicle_id = "vehicle.trail_car.starter"
	_starter_vehicle.position = Vector3(80.0, 1.05, 76.0)
	_starter_vehicle.rotation.y = -PI * 0.5
	add_child(_starter_vehicle)

func _spawn_luca_guide() -> void:
	if is_instance_valid(_luca_guide):
		return
	_luca_guide = LucaGuideClass.new()
	_luca_guide.name = "Luca"
	_luca_guide.position = Vector3(72.0, 0.8, 72.0)
	_luca_guide.set_target(_player)
	add_child(_luca_guide)
