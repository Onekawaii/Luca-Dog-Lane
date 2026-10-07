class_name MacroTerrain
extends Node3D

const TERRAIN_CELL_M := 8.0
const MAX_HEIGHT_M := 54.0
const WATER_Y := 0.18
const WATER_GAP_AT_MAIN_ROAD := 18.0

var world_plan: KimiWorldPlan
var world_half := 480.0
var terrain_body: StaticBody3D
var hydrology_nodes: Array[Node3D] = []
var biome_color_cache: Dictionary = {}
var terrain_cells := 0
var terrain_step := TERRAIN_CELL_M
var terrain_heights := PackedFloat32Array()

func _ready() -> void:
	if world_plan == null:
		world_plan = KimiWorldPlan.new(6060)
	_build_world_terrain()
	_build_hydrology_surfaces()
	print(
		"MACRO_TERRAIN_READY continuous=true cells=",
		ceili((world_half * 2.0) / TERRAIN_CELL_M),
		" seed=", world_plan.seed,
		" biomes=", world_plan.biome_ids().size(),
		" hydrology=", hydrology_nodes.size()
	)

func height_at(world_x: float, world_z: float) -> float:
	if absf(world_x) > world_half or absf(world_z) > world_half:
		return 0.0
	var height := _base_height_at(world_x, world_z)
	var hydro := _hydrology_influence_at(world_x, world_z)
	if hydro > 0.0:
		var channel_target := 0.0
		height = lerpf(height, minf(height, channel_target), pow(hydro, 1.35))
	return clampf(height, 0.0, MAX_HEIGHT_M)

func rendered_height_at(world_x: float, world_z: float) -> float:
	if terrain_cells <= 0 or terrain_heights.is_empty():
		return height_at(world_x, world_z)
	if absf(world_x) > world_half or absf(world_z) > world_half:
		return 0.0

	var gx := clampf((world_x + world_half) / terrain_step, 0.0, float(terrain_cells))
	var gz := clampf((world_z + world_half) / terrain_step, 0.0, float(terrain_cells))
	var ix := mini(floori(gx), terrain_cells - 1)
	var iz := mini(floori(gz), terrain_cells - 1)
	var fx := gx - float(ix)
	var fz := gz - float(iz)
	var h00 := _terrain_grid_height(ix, iz)
	var h10 := _terrain_grid_height(ix + 1, iz)
	var h01 := _terrain_grid_height(ix, iz + 1)
	var h11 := _terrain_grid_height(ix + 1, iz + 1)

	# Match the exact diagonal used by the rendered/collidable mesh:
	# p00,p10,p11 and p00,p11,p01.
	if fx >= fz:
		return h00 + fx * (h10 - h00) + fz * (h11 - h10)
	return h00 + fz * (h01 - h00) + fx * (h11 - h01)

func _terrain_grid_height(x: int, z: int) -> float:
	var stride := terrain_cells + 1
	return float(terrain_heights[z * stride + x])

func biome_at(world_x: float, world_z: float) -> StringName:
	return world_plan.sample_biome(world_x, world_z)

func is_water_at(world_x: float, world_z: float) -> bool:
	if absf(world_x) < WATER_GAP_AT_MAIN_ROAD:
		return false
	if Vector2(world_x + 235.0, world_z + 205.0).length() < 64.0:
		return false
	return world_plan.water_kind_at(world_x, world_z) != &"none"

func water_kind_at(world_x: float, world_z: float) -> StringName:
	return world_plan.water_kind_at(world_x, world_z) if is_water_at(world_x, world_z) else &"none"

func water_surface_y_at(_world_x: float, _world_z: float) -> float:
	return WATER_Y

func get_hydrology_stats_for_test() -> Dictionary:
	return {
		"water_nodes": hydrology_nodes.size(),
		"river_center_at_zero": world_plan.primary_river_center_z(0.0),
		"lake_center": world_plan.lake_center(),
		"lake_radius": world_plan.lake_radius(),
	}

func _base_height_at(world_x: float, world_z: float) -> float:
	var p := Vector2(world_x, world_z)
	var broad := world_plan.fbm(world_x, world_z, 4, 0.0032, 901)
	var detail := world_plan.fbm(world_x, world_z, 3, 0.0125, 902)
	var base := maxf(0.0, (broad - 0.46) * 11.0)
	base += maxf(0.0, (detail - 0.53) * 4.0)

	var north := _north_pass_height(world_x, world_z)
	var west := _west_ridge_height(world_x, world_z)
	var south := _south_valley_height(world_x, world_z)
	var height := base + maxf(north, maxf(west, south))

	# Keep the authored sandbox and cross-roads as usable lowland corridors.
	var central_distance := p.length()
	height *= _smoothstep(102.0, 168.0, central_distance)

	var main_road_distance := minf(absf(world_x), absf(world_z))
	height *= _smoothstep(16.0, 72.0, main_road_distance)

	# Existing diagonal roads get the same broad, drivable shoulders.
	var forest_a := Vector2(-286.0, -86.0)
	var forest_b := Vector2(-74.0, -154.0)
	var quarry_a := Vector2(77.0, 82.0)
	var quarry_b := Vector2(293.0, 208.0)
	height *= _smoothstep(8.0, 34.0, _distance_to_segment(p, forest_a, forest_b))
	height *= _smoothstep(8.0, 38.0, _distance_to_segment(p, quarry_a, quarry_b))

	# Preserve authored sites and ENG-003's editable voxel slice as distinct spaces.
	height *= _radial_clear_factor(p, Vector2(55.0, 55.0), 78.0, 118.0)
	height *= _radial_clear_factor(p, Vector2(-95.0, 72.0), 68.0, 105.0)
	height *= _radial_clear_factor(p, Vector2(-235.0, -205.0), 58.0, 92.0)
	height *= _rect_clear_factor(p, Vector2(312.0, 282.0), Vector2(72.0, 70.0), 48.0)

	# Blend down before the hard world boundary so there are no vertical skirt walls.
	var border_distance := minf(world_half - absf(world_x), world_half - absf(world_z))
	height *= _smoothstep(8.0, 62.0, border_distance)
	return height

func _hydrology_influence_at(world_x: float, world_z: float) -> float:
	var influence := world_plan.hydrology_influence(world_x, world_z)
	# The north-south road crosses the river through a dry culvert/bridge gap.
	influence *= _smoothstep(8.0, WATER_GAP_AT_MAIN_ROAD + 6.0, absf(world_x))
	# Preserve the authored plaza and its approach.
	influence *= _radial_clear_factor(
		Vector2(world_x, world_z), Vector2(-235.0, -205.0), 62.0, 94.0)
	return influence

func region_name_at(world_x: float, world_z: float) -> String:
	var north := _north_pass_height(world_x, world_z)
	var west := _west_ridge_height(world_x, world_z)
	var south := _south_valley_height(world_x, world_z)
	var strongest := maxf(north, maxf(west, south))
	if strongest < 5.0:
		return "RollingLowlands"
	if north >= west and north >= south:
		return "NorthMountainPass"
	if west >= north and west >= south:
		return "WestRidge"
	return "SouthValley"

func _north_pass_height(world_x: float, world_z: float) -> float:
	var band := exp(-pow((world_z + 350.0) / 112.0, 2.0))
	var side := _smoothstep(30.0, 118.0, absf(world_x))
	var normalized_side := clampf(absf(world_x) / 250.0, 0.0, 1.0)
	var ridge := 13.0 + 24.0 * pow(normalized_side, 0.78)
	var irregular := (world_plan.fbm(world_x, world_z, 4, 0.0075, 911) - 0.5) * 12.0
	return maxf(0.0, band * side * (ridge + irregular))

func _west_ridge_height(world_x: float, world_z: float) -> float:
	var band := exp(-pow((world_x + 350.0) / 108.0, 2.0))
	var pass_clear := _smoothstep(30.0, 108.0, absf(world_z))
	var normalized_z := clampf(absf(world_z) / 310.0, 0.0, 1.0)
	var ridge := 15.0 + 21.0 * pow(normalized_z, 0.72)
	var shoulder := 8.0 * exp(-pow((world_z + 150.0) / 95.0, 2.0))
	var irregular := (world_plan.fbm(world_x, world_z, 4, 0.0068, 912) - 0.5) * 10.0
	return maxf(0.0, band * pass_clear * (ridge + shoulder + irregular))

func _south_valley_height(world_x: float, world_z: float) -> float:
	var band := exp(-pow((world_z - 360.0) / 112.0, 2.0))
	var side := _smoothstep(34.0, 125.0, absf(world_x))
	var normalized_side := clampf(absf(world_x) / 245.0, 0.0, 1.0)
	var wall := 11.0 + 27.0 * pow(normalized_side, 0.90)
	var irregular := (world_plan.fbm(world_x, world_z, 4, 0.0071, 913) - 0.5) * 9.0
	return maxf(0.0, band * side * (wall + irregular))

func _build_world_terrain() -> void:
	var extent := world_half
	var cells := maxi(8, ceili((extent * 2.0) / TERRAIN_CELL_M))
	var step := (extent * 2.0) / float(cells)
	terrain_cells = cells
	terrain_step = step
	terrain_heights.resize((cells + 1) * (cells + 1))

	# Evaluate each shared grid vertex once and retain the exact grid used by
	# the visible mesh so props, eggs, NPCs, and recovery use the same surface.
	for z in range(cells + 1):
		var world_z := -extent + float(z) * step
		for x in range(cells + 1):
			var world_x := -extent + float(x) * step
			terrain_heights[z * (cells + 1) + x] = height_at(world_x, world_z)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in range(cells):
		var z0 := -extent + float(z) * step
		var z1 := z0 + step
		for x in range(cells):
			var x0 := -extent + float(x) * step
			var x1 := x0 + step
			var p00 := Vector3(x0, _terrain_grid_height(x, z), z0)
			var p10 := Vector3(x1, _terrain_grid_height(x + 1, z), z0)
			var p01 := Vector3(x0, _terrain_grid_height(x, z + 1), z1)
			var p11 := Vector3(x1, _terrain_grid_height(x + 1, z + 1), z1)

			_add_vertex(surface, p00)
			_add_vertex(surface, p10)
			_add_vertex(surface, p11)
			_add_vertex(surface, p00)
			_add_vertex(surface, p11)
			_add_vertex(surface, p01)

	# Index shared vertices before normal generation so adjacent triangles use
	# continuous lighting instead of reading as separate faceted slabs.
	surface.index()
	surface.generate_normals()
	var mesh := surface.commit() as ArrayMesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	mesh.surface_set_material(0, material)

	terrain_body = StaticBody3D.new()
	terrain_body.name = "WorldTerrain"
	terrain_body.add_to_group("macro_terrain")
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 1

	var visual := MeshInstance3D.new()
	visual.name = "TerrainMesh"
	visual.mesh = mesh
	terrain_body.add_child(visual)

	var collision := CollisionShape3D.new()
	collision.name = "TerrainCollision"
	collision.shape = mesh.create_trimesh_shape()
	terrain_body.add_child(collision)

	add_child(terrain_body)

func _build_hydrology_surfaces() -> void:
	_build_primary_river()
	_build_tributary(0)
	_build_tributary(1)
	_build_marsh_lake()

func _build_primary_river() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 8.0
	var x := -world_half + 18.0
	while x < world_half - 18.0:
		var x1 := minf(x + step, world_half - 18.0)
		if not (x < WATER_GAP_AT_MAIN_ROAD and x1 > -WATER_GAP_AT_MAIN_ROAD):
			var z0 := world_plan.primary_river_center_z(x)
			var z1 := world_plan.primary_river_center_z(x1)
			var w0 := world_plan.primary_river_half_width(x)
			var w1 := world_plan.primary_river_half_width(x1)
			_add_water_quad(
				surface,
				Vector3(x, WATER_Y, z0 - w0),
				Vector3(x1, WATER_Y, z1 - w1),
				Vector3(x1, WATER_Y, z1 + w1),
				Vector3(x, WATER_Y, z0 + w0)
			)
		x = x1
	_add_water_mesh("PrimaryRiverWater", surface.commit() as ArrayMesh, Color(0.17, 0.36, 0.46, 0.86))

func _build_tributary(branch: int) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start_z := -220.0
	var end_z := 75.0 if branch == 0 else -55.0
	var step := 6.0
	var z := start_z
	while z < end_z:
		var z1 := minf(z + step, end_z)
		var x0 := world_plan.tributary_center_x(z, branch)
		var x1 := world_plan.tributary_center_x(z1, branch)
		var width := 4.8 if branch == 0 else 4.2
		_add_water_quad(
			surface,
			Vector3(x0 - width, WATER_Y + 0.01, z),
			Vector3(x1 - width, WATER_Y + 0.01, z1),
			Vector3(x1 + width, WATER_Y + 0.01, z1),
			Vector3(x0 + width, WATER_Y + 0.01, z)
		)
		z = z1
	_add_water_mesh(
		"TributaryWater_%d" % branch,
		surface.commit() as ArrayMesh,
		Color(0.19, 0.38, 0.45, 0.80)
	)

func _build_marsh_lake() -> void:
	var center := world_plan.lake_center()
	var radius := world_plan.lake_radius()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.08
	mesh.radial_segments = 36
	var visual := MeshInstance3D.new()
	visual.name = "MarshLakeWater"
	visual.mesh = mesh
	visual.position = Vector3(center.x, WATER_Y - 0.02, center.y)
	visual.material_override = _water_material(Color(0.16, 0.31, 0.29, 0.82))
	visual.add_to_group("hydrology")
	add_child(visual)
	hydrology_nodes.append(visual)

func _add_water_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3
) -> void:
	for point in [a, b, c, a, c, d]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(point)

func _add_water_mesh(label: String, mesh: ArrayMesh, color: Color) -> void:
	if mesh == null:
		return
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = _water_material(color)
	visual.add_to_group("hydrology")
	add_child(visual)
	hydrology_nodes.append(visual)

func _water_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.18
	material.metallic = 0.05
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _add_vertex(surface: SurfaceTool, point: Vector3) -> void:
	surface.set_color(_terrain_color(point))
	surface.add_vertex(point)

func _terrain_color(point: Vector3) -> Color:
	# Surface tint is intentionally classified on a coarse 48 m ecological grid.
	# This keeps biome identity deterministic while avoiding tens of thousands
	# of full climate/fBm classifications during mesh construction.
	var biome_cell := Vector2i(floori(point.x / 48.0), floori(point.z / 48.0))
	var biome: StringName
	if biome_color_cache.has(biome_cell):
		biome = biome_color_cache[biome_cell]
	else:
		var sample_x := (float(biome_cell.x) + 0.5) * 48.0
		var sample_z := (float(biome_cell.y) + 0.5) * 48.0
		biome = biome_at(sample_x, sample_z)
		biome_color_cache[biome_cell] = biome
	var base := _biome_color(biome)
	var height_t := clampf(point.y / MAX_HEIGHT_M, 0.0, 1.0)
	var noise := world_plan.fbm(point.x, point.z, 2, 0.020, 922)
	var shade := lerpf(0.90, 1.10, noise)
	var color := Color(
		clampf(base.r * shade, 0.0, 1.0),
		clampf(base.g * shade, 0.0, 1.0),
		clampf(base.b * shade, 0.0, 1.0)
	)
	if height_t > 0.58:
		color = color.lerp(Color(0.42, 0.43, 0.42), (height_t - 0.58) / 0.42)
	return color

func _biome_color(biome: StringName) -> Color:
	match biome:
		&"riverlands":
			return Color(0.15, 0.33, 0.24)
		&"marsh":
			return Color(0.18, 0.29, 0.20)
		&"alpine_highlands":
			return Color(0.36, 0.38, 0.36)
		&"rocky_scree":
			return Color(0.39, 0.37, 0.33)
		&"cedar_swamp":
			return Color(0.13, 0.27, 0.18)
		&"badlands":
			return Color(0.43, 0.34, 0.23)
		&"dry_meadow":
			return Color(0.39, 0.43, 0.22)
		&"pine_forest":
			return Color(0.15, 0.31, 0.19)
		&"birch_grove":
			return Color(0.27, 0.43, 0.24)
		_:
			return Color(0.22, 0.38, 0.22)

func _radial_clear_factor(
	p: Vector2,
	center: Vector2,
	flat_radius: float,
	full_radius: float
) -> float:
	return _smoothstep(flat_radius, full_radius, p.distance_to(center))

func _rect_clear_factor(
	p: Vector2,
	center: Vector2,
	half_size: Vector2,
	fade: float
) -> float:
	var dx := absf(p.x - center.x) - half_size.x
	var dz := absf(p.y - center.y) - half_size.y
	var outside := Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()
	if dx <= 0.0 and dz <= 0.0:
		return 0.0
	return _smoothstep(0.0, fade, outside)

func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 0.0
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
