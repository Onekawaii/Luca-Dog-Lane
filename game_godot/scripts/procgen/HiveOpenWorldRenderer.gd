class_name HiveOpenWorldRenderer
extends "res://scripts/procgen/HiveProcGenChunkRenderer.gd"

const VehicleClass = preload("res://scripts/vehicles/HiveVehicle.gd")
const TERRAIN_RADIUS := 2
const TERRAIN_GRID := 8
const WORLD_LEVEL_TYPES := [
	"industrial_plant", "service_tunnel", "records_archive", "wet_lab",
	"generator_hall", "cold_storage", "observation_ward", "machine_floor",
	"flooded_office", "roof_utility", "false_cafeteria", "lattice_vault",
	"ruined_suburb", "fungal_cavern", "mountain_pass", "quarry",
	"forest_service", "rail_yard", "drainage_network", "roadside_station",
]

var terrain_cells: Dictionary = {}
var _open_world_ready := false
var _world_origin_plan := Vector2.ZERO
var _height_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _starter_vehicle: HiveVehicle

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
			st.set_uv(Vector2(float(x) / TERRAIN_GRID, float(z) / TERRAIN_GRID))
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
	var biome := _biome_for_plan_position(plan_pos)
	var amplitude := _amplitude_for_biome(biome)
	var broad := _height_noise.get_noise_2d(plan_pos.x, plan_pos.y) * amplitude
	var detail := _detail_noise.get_noise_2d(plan_pos.x, plan_pos.y) * amplitude * 0.18
	return snappedf(broad + detail, 0.02)

func _amplitude_for_biome(biome: String) -> float:
	match biome:
		"department_hell_industrial": return 5.0
		"bruise_moor": return 11.0
		"fungal_wetlands": return 7.0
		"glasswood_verge": return 14.0
		"ash_highlands": return 46.0
		"frozen_archive": return 20.0
		"dry_scripture_salt_flats": return 3.0
		"drowned_suburb": return 4.0
		"amber_hive": return 13.0
		"deep_lattice": return 30.0
	return 8.0

func _biome_for_cell(coords: Vector2i) -> String:
	var center := Vector2(
		(float(coords.x) + 0.5) * LOCAL_CELL_SIZE,
		(float(coords.y) + 0.5) * LOCAL_CELL_SIZE
	)
	return _biome_for_plan_position(_world_origin_plan + center)

func _biome_for_plan_position(plan_pos: Vector2) -> String:
	var nearest := "department_hell_industrial"
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


func _material_for_biome(biome: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 0.92
	match biome:
		"department_hell_industrial": material.albedo_color = Color(0.19, 0.17, 0.16)
		"bruise_moor": material.albedo_color = Color(0.24, 0.13, 0.25)
		"fungal_wetlands": material.albedo_color = Color(0.18, 0.24, 0.13)
		"glasswood_verge": material.albedo_color = Color(0.12, 0.24, 0.25)
		"ash_highlands": material.albedo_color = Color(0.23, 0.20, 0.21)
		"frozen_archive": material.albedo_color = Color(0.35, 0.43, 0.48)
		"dry_scripture_salt_flats": material.albedo_color = Color(0.52, 0.48, 0.39)
		"drowned_suburb": material.albedo_color = Color(0.12, 0.21, 0.22)
		"amber_hive": material.albedo_color = Color(0.34, 0.24, 0.08)
		"deep_lattice": material.albedo_color = Color(0.10, 0.08, 0.12)
		_: material.albedo_color = Color(0.20, 0.22, 0.19)
	return material

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
		sign.text = "FREE ROAM // MOTOR POOL // TEN BIOMES"
		sign.position = Vector3(16.0, 2.3, 20.0)
		sign.font_size = 30
		sign.modulate = Color(0.78, 0.62, 0.92)
		branch.add_child(sign)

func _spawn_starter_vehicle() -> void:
	if is_instance_valid(_starter_vehicle):
		return
	_starter_vehicle = VehicleClass.new()
	_starter_vehicle.name = "StarterFieldCar"
	_starter_vehicle.vehicle_id = "vehicle.field_car.starter"
	_starter_vehicle.position = Vector3(80.0, 1.05, 76.0)
	_starter_vehicle.rotation.y = -PI * 0.5
	add_child(_starter_vehicle)
