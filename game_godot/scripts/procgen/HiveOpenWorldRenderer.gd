class_name HiveOpenWorldRenderer
extends "res://scripts/procgen/HiveProcGenChunkRenderer.gd"

const VehicleClass = preload("res://scripts/vehicles/HiveVehicle.gd")
const LucaGuideClass = preload("res://scripts/actors/LucaGuide.gd")
const LucaWorldNPCClass = preload("res://scripts/actors/LucaWorldNPC.gd")
const WeatherClass = preload("res://scripts/runtime/LucaWeatherSystem.gd")
const TerrainShader = preload("res://shaders/luca_terrain.gdshader")
const RiverShader = preload("res://shaders/luca_river.gdshader")
const TERRAIN_RADIUS := 2
const TERRAIN_GRID := 16
const RIVER_HALF_WIDTH := 5.5
const RIVER_BANK_WIDTH := 12.0
const TERRAIN_TEXTURE_ROOT := "res://assets/terrain/"
const NPCS_PER_CELL := 3
const CLOUDSTEP_PEAK_METERS := 3218.0
const STARLIGHT_PEAK_METERS := 4023.0
const NPC_FIRST_NAMES := ["Mara", "Jonah", "Devin", "Rhea", "Cal", "Noor", "Elsie", "Milo", "Tess", "Warren", "June", "Isaac", "Nina", "Parker", "Hollis", "Mae", "Gideon", "Lena", "Owen", "Vera"]
const NPC_LAST_NAMES := ["Bell", "Morrow", "Kline", "Mercer", "Dunn", "Vale", "Cross", "Hart", "Pike", "Rowan", "Hale", "Voss", "Field", "Moss", "Reed", "Stone"]
const NPC_ROLES := ["ranger", "mechanic", "beekeeper", "surveyor", "orchard keeper", "fisher", "courier", "trail worker", "photographer", "forager"]
const NPC_PERSONAL_LINES := [
	"I keep a paper map because batteries have a sense of humor.",
	"I have been fixing the same fence for three summers.",
	"The hills look closer than they are. They always do.",
	"I swear the river changes its mind after heavy rain.",
	"I came out here for one quiet week and never really left.",
	"Every road has a shortcut until you actually take it.",
	"There are old foundations under half these fields.",
	"I mark good berry patches and pretend the birds cannot read.",
	"The weather turns fast above the tree line.",
	"Some nights you can hear coyotes all the way across the valley."
]
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
var _river_material: ShaderMaterial
var _world_sun: DirectionalLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _weather_system: LucaWeatherSystem
var _tree_trunk_material: StandardMaterial3D
var _tree_leaf_material: StandardMaterial3D
var _grass_material: StandardMaterial3D
var _rock_material: StandardMaterial3D
var _mountain_lods: Array[MeshInstance3D] = []

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
	_configure_world_lighting()
	_spawn_weather_system()
	_build_distant_mountains()
	update_streaming(true)
	_spawn_starter_vehicle()
	_spawn_luca_guide()


func _configure_world_lighting() -> void:
	_environment = Environment.new()
	var world_environment := _breakroom.get_node_or_null("WorldEnvironment") as WorldEnvironment if is_instance_valid(_breakroom) else null
	if world_environment != null:
		if world_environment.environment != null:
			_environment = world_environment.environment
		else:
			world_environment.environment = _environment
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color(0.18, 0.39, 0.67)
	_sky_material.sky_horizon_color = Color(0.72, 0.78, 0.72)
	_sky_material.ground_bottom_color = Color(0.08, 0.10, 0.08)
	_sky_material.ground_horizon_color = Color(0.42, 0.45, 0.39)
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment.sky = sky
	_environment.background_mode = Environment.BG_SKY
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_color = Color(0.55, 0.61, 0.56, 1.0)
	_environment.ambient_light_energy = 0.92
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.58, 0.64, 0.66, 1.0)
	_environment.fog_light_energy = 0.72
	_environment.fog_density = 0.0035
	_world_sun = DirectionalLight3D.new()
	_world_sun.name = "LucaWorldSun"
	_world_sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	_world_sun.light_color = Color(1.0, 0.91, 0.74, 1.0)
	_world_sun.light_energy = 1.35
	_world_sun.shadow_enabled = true
	add_child(_world_sun)


func _spawn_weather_system() -> void:
	if is_instance_valid(_weather_system):
		return
	_weather_system = WeatherClass.new()
	_weather_system.name = "LucaWeatherSystem"
	add_child(_weather_system)
	_weather_system.configure(_player, _environment, _world_sun, _sky_material, int(world_plan.get("seed", 6060)))


func set_outdoor_lighting(active: bool) -> void:
	if is_instance_valid(_world_sun):
		_world_sun.visible = active
	if is_instance_valid(_weather_system):
		_weather_system.set_outdoor_active(active)
	if _environment == null:
		return
	_environment.ambient_light_energy = 0.92 if active else 0.55
	_environment.fog_enabled = active
	if not active and _sky_material != null:
		_sky_material.sky_top_color = Color(0.015, 0.02, 0.022)
		_sky_material.sky_horizon_color = Color(0.04, 0.05, 0.05)


func _build_distant_mountains() -> void:
	_mountain_lods.clear()
	for raw_region in world_plan.get("regions", []):
		if not raw_region is Dictionary:
			continue
		var region: Dictionary = raw_region
		var biome := str(region.get("biome", ""))
		if biome not in ["cloudstep_highlands", "starlight_range"]:
			continue
		var rp: Dictionary = region.get("position", {})
		var plan_pos := Vector2(float(rp.get("x", 0.0)), float(rp.get("y", 0.0)))
		var local := plan_pos - _world_origin_plan
		var peak := CLOUDSTEP_PEAK_METERS if biome == "cloudstep_highlands" else STARLIGHT_PEAK_METERS
		var radius := 2450.0 if biome == "cloudstep_highlands" else 2850.0
		var lod := MeshInstance3D.new()
		lod.name = "DistantMountain_" + biome
		lod.mesh = _make_mountain_lod_mesh(peak, radius, biome)
		lod.position = Vector3(local.x, 0.0, local.y)
		lod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lod.visibility_range_end = 12000.0
		add_child(lod)
		_mountain_lods.append(lod)


func _make_mountain_lod_mesh(peak: float, radius: float, biome: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	st.set_material(material)
	var rings := 10
	var segments := 36
	for ring in range(rings + 1):
		var frac := float(ring) / float(rings)
		var radial := radius * frac
		var dome := smoothstep(0.0, 1.0, 1.0 - frac)
		var base_height := peak * dome
		for segment in range(segments):
			var angle := TAU * float(segment) / float(segments)
			var rough := sin(angle * 5.0 + frac * 11.0) * peak * 0.016 * (1.0 - frac)
			var y := maxf(0.0, base_height + rough)
			var snow := smoothstep(0.58, 0.82, y / peak)
			var low := Color(0.21, 0.24, 0.20) if biome == "cloudstep_highlands" else Color(0.17, 0.19, 0.22)
			var high := Color(0.86, 0.88, 0.86)
			st.set_color(low.lerp(high, snow))
			st.add_vertex(Vector3(cos(angle) * radial, y, sin(angle) * radial))
	for ring in range(rings):
		for segment in range(segments):
			var next_segment := (segment + 1) % segments
			var a := ring * segments + segment
			var b := ring * segments + next_segment
			var c := (ring + 1) * segments + segment
			var d := (ring + 1) * segments + next_segment
			st.add_index(a); st.add_index(c); st.add_index(b)
			st.add_index(b); st.add_index(c); st.add_index(d)
	st.generate_normals()
	return st.commit()


func _update_mountain_lods() -> void:
	if not is_instance_valid(_player):
		return
	var player_xz := Vector2(_player.global_position.x, _player.global_position.z)
	for lod in _mountain_lods:
		if not is_instance_valid(lod):
			continue
		var mountain_xz := Vector2(lod.position.x, lod.position.z)
		lod.visible = player_xz.distance_to(mountain_xz) > 520.0


func update_streaming(force: bool = false) -> void:
	super.update_streaming(force)
	if not _open_world_ready or not is_instance_valid(_player):
		return
	var center := Vector2i(
		int(floor(_player.global_position.x / LOCAL_CELL_SIZE)),
		int(floor(_player.global_position.z / LOCAL_CELL_SIZE))
	)
	if is_instance_valid(_weather_system):
		_weather_system.set_biome(biome_at_local_position(Vector2(_player.global_position.x, _player.global_position.z)))
	_update_mountain_lods()
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


func surface_height_at_local(local_pos: Vector2) -> float:
	return _terrain_height(_world_origin_plan + local_pos, local_pos)


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
	_build_environment_detail(root, coords)
	for site in _sites_for_cell(coords):
		_build_world_site(root, coords, site)
	_spawn_npcs_for_cell(root, coords)

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
	var base_height := _raw_terrain_height(plan_pos)
	# Never cut hard rectangular pits into the world. Blend the authored route
	# and starter meadow into procedural terrain over a wide shoulder so the
	# player can walk out naturally instead of hitting a vertical terrain seam.
	var flatten_weight := maxf(
		_flat_rect_weight(local_pos, Vector2(-16.0, -18.0), Vector2(1400.0, 18.0), 34.0),
		_flat_rect_weight(local_pos, Vector2(56.0, 34.0), Vector2(112.0, 112.0), 38.0)
	)
	base_height = lerpf(base_height, 0.0, flatten_weight)
	var river_distance := _river_distance(local_pos)
	if river_distance < RIVER_BANK_WIDTH:
		var bank_factor := clampf(1.0 - river_distance / RIVER_BANK_WIDTH, 0.0, 1.0)
		base_height -= bank_factor * bank_factor * 3.6
	return snappedf(base_height, 0.02)


func _flat_rect_weight(point: Vector2, rect_min: Vector2, rect_max: Vector2, feather: float) -> float:
	var dx := maxf(maxf(rect_min.x - point.x, 0.0), point.x - rect_max.x)
	var dz := maxf(maxf(rect_min.y - point.y, 0.0), point.y - rect_max.y)
	var outside_distance := Vector2(dx, dz).length()
	if outside_distance <= 0.001:
		return 1.0
	return 1.0 - smoothstep(0.0, feather, outside_distance)


func _raw_terrain_height(plan_pos: Vector2) -> float:
	var biome := _biome_for_plan_position(plan_pos)
	var amplitude := _amplitude_for_biome(biome)
	var broad := _height_noise.get_noise_2d(plan_pos.x, plan_pos.y) * amplitude
	var detail := _detail_noise.get_noise_2d(plan_pos.x, plan_pos.y) * amplitude * 0.18
	return broad + detail + _mountain_macro_height(plan_pos, biome)


func _mountain_macro_height(plan_pos: Vector2, biome: String) -> float:
	if biome not in ["cloudstep_highlands", "starlight_range"]:
		return 0.0
	var center := Vector2.ZERO
	var nearest := INF
	for raw_region in world_plan.get("regions", []):
		if not raw_region is Dictionary:
			continue
		var region: Dictionary = raw_region
		if str(region.get("biome", "")) != biome:
			continue
		var candidate := Vector2(float(region["position"]["x"]), float(region["position"]["y"]))
		var distance := candidate.distance_to(plan_pos)
		if distance < nearest:
			nearest = distance
			center = candidate
	if nearest == INF:
		return 0.0
	var peak := CLOUDSTEP_PEAK_METERS if biome == "cloudstep_highlands" else STARLIGHT_PEAK_METERS
	var radius := 2450.0 if biome == "cloudstep_highlands" else 2850.0
	var t := clampf(1.0 - nearest / radius, 0.0, 1.0)
	var dome := smoothstep(0.0, 1.0, t)
	var ridge := _detail_noise.get_noise_2d(plan_pos.x * 0.23, plan_pos.y * 0.23) * 120.0 * dome
	return peak * dome + ridge


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
		"cloudstep_highlands": return 92.0
		"moonfrost_basin": return 22.0
		"redclay_badlands": return 28.0
		"old_orchard_vale": return 9.0
		"firefly_marsh": return 3.0
		"starlight_range": return 110.0
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


func _get_river_material() -> ShaderMaterial:
	if is_instance_valid(_river_material):
		return _river_material
	_river_material = ShaderMaterial.new()
	_river_material.shader = RiverShader
	_river_material.set_shader_parameter("shallow_color", Color(0.10, 0.34, 0.38, 0.68))
	_river_material.set_shader_parameter("deep_color", Color(0.035, 0.13, 0.19, 0.82))
	_river_material.set_shader_parameter("flow_speed", 1.8)
	_river_material.set_shader_parameter("wave_height", 0.075)
	return _river_material


func _ensure_detail_materials() -> void:
	if is_instance_valid(_tree_trunk_material):
		return
	_tree_trunk_material = StandardMaterial3D.new()
	_tree_trunk_material.albedo_color = Color(0.20, 0.13, 0.075)
	_tree_trunk_material.roughness = 0.98
	_tree_leaf_material = StandardMaterial3D.new()
	_tree_leaf_material.albedo_color = Color(0.11, 0.28, 0.12)
	_tree_leaf_material.roughness = 0.96
	_grass_material = StandardMaterial3D.new()
	_grass_material.albedo_color = Color(0.18, 0.38, 0.11)
	_grass_material.roughness = 0.98
	_rock_material = StandardMaterial3D.new()
	_rock_material.albedo_color = Color(0.30, 0.31, 0.29)
	_rock_material.roughness = 0.90


func _build_environment_detail(root: Node3D, coords: Vector2i) -> void:
	_ensure_detail_materials()
	var biome := _biome_for_cell(coords)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_plan.get("seed", 6060)) + coords.x * 73856093 + coords.y * 19349663
	var tree_count := 2
	var rock_count := 2
	var grass_count := 10
	match biome:
		"whisperpine_woods": tree_count = 6; rock_count = 2; grass_count = 12
		"old_orchard_vale": tree_count = 5; rock_count = 1; grass_count = 14
		"sunmeadow_fields": tree_count = 2; rock_count = 1; grass_count = 18
		"creekglass_wetlands", "firefly_marsh": tree_count = 3; rock_count = 1; grass_count = 16
		"cloudstep_highlands", "starlight_range": tree_count = 2; rock_count = 6; grass_count = 5
		"redclay_badlands": tree_count = 0; rock_count = 7; grass_count = 1
		"golden_dune_ridge": tree_count = 0; rock_count = 3; grass_count = 2
		"moonfrost_basin": tree_count = 1; rock_count = 5; grass_count = 1
	for i in tree_count:
		var point := _detail_point(coords, rng)
		if _detail_point_allowed(point):
			_add_tree(root, coords, point, rng, biome)
	for i in rock_count:
		var point := _detail_point(coords, rng)
		if _detail_point_allowed(point):
			_add_rock(root, coords, point, rng)
	_add_grass_multimesh(root, coords, rng, grass_count)


func _detail_point(coords: Vector2i, rng: RandomNumberGenerator) -> Vector2:
	return Vector2(
		float(coords.x) * LOCAL_CELL_SIZE + rng.randf_range(2.0, LOCAL_CELL_SIZE - 2.0),
		float(coords.y) * LOCAL_CELL_SIZE + rng.randf_range(2.0, LOCAL_CELL_SIZE - 2.0)
	)


func _detail_point_allowed(point: Vector2) -> bool:
	if _river_distance(point) < RIVER_BANK_WIDTH + 2.5:
		return false
	if posmod(int(floor(point.y / LOCAL_CELL_SIZE)), 4) == 2 and absf(fmod(point.y, LOCAL_CELL_SIZE) - LOCAL_CELL_SIZE * 0.5) < 4.2:
		return false
	if posmod(int(floor(point.x / LOCAL_CELL_SIZE)), 6) == 2 and absf(fmod(point.x, LOCAL_CELL_SIZE) - LOCAL_CELL_SIZE * 0.5) < 4.2:
		return false
	return true


func _local_detail_position(coords: Vector2i, point: Vector2) -> Vector3:
	var plan_pos := _world_origin_plan + point
	var y := _terrain_height(plan_pos, point)
	return Vector3(point.x - float(coords.x) * LOCAL_CELL_SIZE, y, point.y - float(coords.y) * LOCAL_CELL_SIZE)


func _add_tree(root: Node3D, coords: Vector2i, point: Vector2, rng: RandomNumberGenerator, biome: String) -> void:
	var anchor := Node3D.new()
	anchor.name = "Tree"
	anchor.position = _local_detail_position(coords, point)
	anchor.rotation.y = rng.randf_range(0.0, TAU)
	root.add_child(anchor)
	var height := rng.randf_range(4.8, 8.5)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = height * 0.48
	trunk.mesh = trunk_mesh
	trunk.position.y = height * 0.24
	trunk.material_override = _tree_trunk_material
	anchor.add_child(trunk)
	for layer in 3:
		var canopy := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 1.25 + float(layer) * 0.28
		cone.height = height * 0.35
		canopy.mesh = cone
		canopy.position.y = height * (0.50 + float(layer) * 0.12)
		var leaf := _tree_leaf_material.duplicate() as StandardMaterial3D
		if biome == "old_orchard_vale":
			leaf.albedo_color = Color(0.20, 0.36, 0.12)
		elif biome in ["cloudstep_highlands", "starlight_range"]:
			leaf.albedo_color = Color(0.08, 0.20, 0.14)
		canopy.material_override = leaf
		anchor.add_child(canopy)


func _add_rock(root: Node3D, coords: Vector2i, point: Vector2, rng: RandomNumberGenerator) -> void:
	var rock := MeshInstance3D.new()
	rock.name = "Boulder"
	var sphere := SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 1.2
	rock.mesh = sphere
	rock.position = _local_detail_position(coords, point) + Vector3(0.0, 0.32, 0.0)
	rock.scale = Vector3(rng.randf_range(0.7, 1.7), rng.randf_range(0.45, 1.15), rng.randf_range(0.8, 1.6))
	rock.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0.0, TAU), rng.randf_range(-0.18, 0.18))
	rock.material_override = _rock_material
	root.add_child(rock)


func _add_grass_multimesh(root: Node3D, coords: Vector2i, rng: RandomNumberGenerator, count: int) -> void:
	if count <= 0:
		return
	var blade := BoxMesh.new()
	blade.size = Vector3(0.06, 0.55, 0.04)
	blade.material = _grass_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade
	var transforms: Array[Transform3D] = []
	for i in count:
		var point := _detail_point(coords, rng)
		if not _detail_point_allowed(point):
			continue
		var pos := _local_detail_position(coords, point) + Vector3(0.0, 0.27, 0.0)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(rng.randf_range(0.7, 1.25), rng.randf_range(0.75, 1.35), 1.0))
		transforms.append(Transform3D(basis, pos))
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "GrassPatch"
	instance.multimesh = multimesh
	root.add_child(instance)


func _spawn_npcs_for_cell(root: Node3D, coords: Vector2i) -> void:
	var count := 2 if OS.has_feature("android") or OS.has_feature("mobile") else NPCS_PER_CELL
	var biome := _biome_for_cell(coords)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_plan.get("seed", 6060)) + coords.x * 92821 + coords.y * 68917
	for i in count:
		var point := _detail_point(coords, rng)
		var attempts := 0
		while not _detail_point_allowed(point) and attempts < 8:
			point = _detail_point(coords, rng)
			attempts += 1
		if not _detail_point_allowed(point):
			continue
		var npc_seed := int(rng.randi())
		var first: String = str(NPC_FIRST_NAMES[posmod(npc_seed, NPC_FIRST_NAMES.size())])
		var last: String = str(NPC_LAST_NAMES[posmod(npc_seed / 7, NPC_LAST_NAMES.size())])
		var name := first + " " + last
		var role := str(NPC_ROLES[posmod(npc_seed / 13, NPC_ROLES.size())])
		var id_value := "npc.%d.%d.%d" % [coords.x, coords.y, i]
		var tint := Color.from_hsv(float(posmod(npc_seed, 1000)) / 1000.0, 0.34, 0.48)
		var npc := LucaWorldNPCClass.new()
		npc.name = "WorldNPC_%d_%d_%d" % [coords.x, coords.y, i]
		npc.configure(id_value, name, role, biome, _npc_dialogue(name, role, biome, npc_seed), tint, npc_seed)
		npc.position = _local_detail_position(coords, point) + Vector3(0.0, 0.06, 0.0)
		root.add_child(npc)


func _npc_dialogue(name: String, role: String, biome: String, npc_seed: int) -> Array:
	var lines: Array = []
	lines.append("%s. I work as a %s around here." % [name, role])
	lines.append(_biome_dialogue_line(biome, npc_seed))
	lines.append(str(NPC_PERSONAL_LINES[posmod(npc_seed / 17, NPC_PERSONAL_LINES.size())]))
	var luca_lines := [
		"That dog of yours has better trail sense than most people.",
		"Luca passed through here earlier like he owned the road.",
		"If Luca stops and stares uphill, pay attention.",
		"I keep seeing Luca choose the dry side of every crossing.",
		"Your dog looks like he already knows what is over the next ridge."
	]
	lines.append(str(luca_lines[posmod(npc_seed / 29, luca_lines.size())]))
	return lines


func _biome_dialogue_line(biome: String, npc_seed: int) -> String:
	var choices: Dictionary = {
		"sunmeadow_fields": ["The meadow drains fast after rain.", "You can see the mountains from the north fence."],
		"whisperpine_woods": ["The pines swallow sound once you get off the road.", "Watch the roots when the ground is wet."],
		"creekglass_wetlands": ["The creek comes up fast after a storm.", "There are old footbridges buried in the reeds."],
		"golden_dune_ridge": ["The ridge wind will sandblast anything left outside.", "The dunes move a little every season."],
		"cloudstep_highlands": ["The summit is miles above the valley. Do not rush it.", "Weather changes before you can see it coming up there."],
		"moonfrost_basin": ["The frost hangs in the hollows long after sunrise.", "The basin gets quiet enough to hear ice cracking."],
		"redclay_badlands": ["Red clay turns slick as soap in rain.", "Those gullies are deeper than they look."],
		"old_orchard_vale": ["Some of those apple trees are older than the road.", "The orchard still fruits where nobody tends it."],
		"firefly_marsh": ["The lights over the marsh are mostly fireflies. Mostly.", "Stay on high ground when the rain settles in."],
		"starlight_range": ["The upper ridge is over two miles above the low country.", "There are walkable lines all the way to the summit if you read the slope."]
	}
	var list: Array = choices.get(biome, ["Road is open either way.", "I have not seen anything stranger than the weather today."])
	return str(list[posmod(npc_seed, list.size())])


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
	var roof_mat := dark.duplicate() as StandardMaterial3D
	roof_mat.albedo_color = Color(0.18, 0.17, 0.15)
	roof_mat.metallic = 0.08
	roof_mat.roughness = 0.92
	_add_static_box(root, "SiteRoof", Vector3(15.6, 0.24, 15.6), local + Vector3(0.0, height + 0.12, 0.0), roof_mat)
	_add_static_box(root, "FrontPostL", Vector3(0.32, height, 0.32), local + Vector3(-6.6, height * 0.5, 6.6), dark)
	_add_static_box(root, "FrontPostR", Vector3(0.32, height, 0.32), local + Vector3(6.6, height * 0.5, 6.6), dark)
	for i in range(1 + type_index % 4):
		var lane := -4.5 + float(i) * 3.0
		var box_size := Vector3(1.1 + float(type_index % 3), 0.8 + float(i % 2), 2.2)
		_add_static_box(root, "SiteFeature_%02d_%02d" % [type_index, i], box_size,
			local + Vector3(lane, box_size.y * 0.5, 1.5 + float(type_index % 3)), accent)
	var label := Label3D.new()
	label.name = "SiteIdentity"
	label.text = archetype.replace("_", " ").to_upper()
	label.position = local + Vector3(0.0, height + 0.48, -6.9)
	label.font_size = 20
	label.modulate = Color(0.82, 0.78, 0.64)
	root.add_child(label)

func _site_material(type_index: int) -> StandardMaterial3D:
	var palette := [
		Color(0.40, 0.31, 0.20), Color(0.28, 0.36, 0.30), Color(0.34, 0.30, 0.27),
		Color(0.26, 0.31, 0.34), Color(0.43, 0.38, 0.24), Color(0.31, 0.26, 0.20),
		Color(0.29, 0.34, 0.24), Color(0.35, 0.32, 0.28)
	]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette[posmod(type_index, palette.size())]
	mat.roughness = 0.90
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
