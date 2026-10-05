class_name MacroTerrain
extends Node3D

const TERRAIN_CELL_M := 12.0
const MAX_HEIGHT_M := 54.0

var world_plan: KimiWorldPlan
var world_half := 480.0
var height_scale := 1.0
var terrain_body: StaticBody3D

func _ready() -> void:
	if world_plan == null:
		world_plan = KimiWorldPlan.new(6060)
	_build_world_terrain()
	print(
		"MACRO_TERRAIN_READY continuous=true cells=",
		ceili((world_half * 2.0) / TERRAIN_CELL_M),
		" seed=", world_plan.seed
	)

func height_at(world_x: float, world_z: float) -> float:
	if absf(world_x) > world_half or absf(world_z) > world_half:
		return 0.0

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

	return clampf(height * height_scale, 0.0, MAX_HEIGHT_M * maxf(height_scale, 1.0))

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

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in range(cells):
		var z0 := -extent + float(z) * step
		var z1 := z0 + step
		for x in range(cells):
			var x0 := -extent + float(x) * step
			var x1 := x0 + step
			var p00 := Vector3(x0, height_at(x0, z0), z0)
			var p10 := Vector3(x1, height_at(x1, z0), z0)
			var p01 := Vector3(x0, height_at(x0, z1), z1)
			var p11 := Vector3(x1, height_at(x1, z1), z1)

			_add_vertex(surface, p00)
			_add_vertex(surface, p10)
			_add_vertex(surface, p11)
			_add_vertex(surface, p00)
			_add_vertex(surface, p11)
			_add_vertex(surface, p01)

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

func _add_vertex(surface: SurfaceTool, point: Vector3) -> void:
	surface.set_color(_terrain_color(point))
	surface.add_vertex(point)

func _terrain_color(point: Vector3) -> Color:
	var height := point.y
	var moisture := world_plan.fbm(point.x, point.z, 3, 0.0042, 921)
	var low := Color(0.17, 0.30, 0.17)
	var grass := Color(0.24, 0.37, 0.21)
	var scrub := Color(0.31, 0.36, 0.24)
	var rock := Color(0.35, 0.35, 0.32)

	if moisture > 0.62:
		low = Color(0.16, 0.31, 0.20)
		grass = Color(0.22, 0.39, 0.23)
	elif moisture < 0.38:
		low = Color(0.24, 0.31, 0.17)
		grass = Color(0.34, 0.38, 0.21)

	if height < 7.0:
		return low.lerp(grass, clampf(height / 7.0, 0.0, 1.0))
	if height < 28.0:
		return grass.lerp(scrub, clampf((height - 7.0) / 21.0, 0.0, 1.0))
	return scrub.lerp(rock, clampf((height - 28.0) / 26.0, 0.0, 1.0))

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
