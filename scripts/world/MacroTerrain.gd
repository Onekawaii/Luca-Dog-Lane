class_name MacroTerrain
extends Node3D

var world_plan: KimiWorldPlan
var world_half := 480.0
var patch_bodies: Array[StaticBody3D] = []

func _ready() -> void:
	if world_plan == null:
		world_plan = KimiWorldPlan.new(6060)
	for spec in _patch_specs():
		_build_patch(spec)
	print("MACRO_TERRAIN_READY patches=", patch_bodies.size(), " seed=", world_plan.seed)

func _patch_specs() -> Array:
	return [
		{
			"name": "NorthMountainPass",
			"kind": "north_pass",
			"center": Vector2(0.0, -350.0),
			"size": Vector2(520.0, 220.0),
			"cell": 14.0,
		},
		{
			"name": "WestRidge",
			"kind": "west_ridge",
			"center": Vector2(-350.0, 15.0),
			"size": Vector2(220.0, 560.0),
			"cell": 14.0,
		},
		{
			"name": "SouthValley",
			"kind": "south_valley",
			"center": Vector2(-20.0, 360.0),
			"size": Vector2(500.0, 200.0),
			"cell": 14.0,
		},
	]

func height_at(world_x: float, world_z: float) -> float:
	var result := 0.0
	for spec in _patch_specs():
		if _contains(spec, world_x, world_z):
			result = maxf(result, _height_for_spec(spec, world_x, world_z))
	return result

func region_name_at(world_x: float, world_z: float) -> String:
	for spec in _patch_specs():
		if _contains(spec, world_x, world_z):
			return str(spec["name"])
	return "Flatlands"

func _contains(spec: Dictionary, world_x: float, world_z: float) -> bool:
	var center: Vector2 = spec["center"]
	var size: Vector2 = spec["size"]
	return (
		absf(world_x - center.x) <= size.x * 0.5
		and absf(world_z - center.y) <= size.y * 0.5
	)

func _height_for_spec(spec: Dictionary, world_x: float, world_z: float) -> float:
	var center: Vector2 = spec["center"]
	var size: Vector2 = spec["size"]
	var nx := (world_x - center.x) / (size.x * 0.5)
	var nz := (world_z - center.y) / (size.y * 0.5)
	if absf(nx) > 1.0 or absf(nz) > 1.0:
		return 0.0

	var edge_distance := 1.0 - maxf(absf(nx), absf(nz))
	var edge := _smoothstep(0.0, 0.18, edge_distance)
	edge = pow(edge, 1.35)
	var kimi := world_plan.terrain_height(world_x, world_z)
	var micro := (world_plan.fbm(world_x, world_z, 3, 0.018, 909) - 0.5) * 8.0
	var height := 0.0

	match str(spec["kind"]):
		"north_pass":
			var road_clear := _smoothstep(15.0, 62.0, absf(world_x))
			var twin_peaks := (
				34.0 * exp(-pow((nx - 0.48) / 0.30, 2.0))
				+ 31.0 * exp(-pow((nx + 0.46) / 0.32, 2.0))
			)
			var backbone := 13.0 + maxf(0.0, kimi) * 0.40 + micro
			height = (backbone + twin_peaks) * road_clear
		"west_ridge":
			var road_clear := _smoothstep(14.0, 58.0, absf(world_z))
			var long_ridge := 28.0 + 22.0 * pow(absf(nz), 0.72)
			var shoulder := 18.0 * exp(-pow((nz + 0.44) / 0.24, 2.0))
			height = (long_ridge + shoulder + maxf(0.0, kimi) * 0.34 + micro) * road_clear
		"south_valley":
			var road_clear := _smoothstep(14.0, 54.0, absf(world_x))
			var valley_walls := 17.0 + 42.0 * pow(absf(nx), 1.35)
			var far_rise := 10.0 * _smoothstep(-0.15, 0.78, nz)
			height = (valley_walls + far_rise + maxf(0.0, kimi) * 0.22 + micro * 0.65) * road_clear

	return maxf(0.0, height * edge)

func _build_patch(spec: Dictionary) -> void:
	var center: Vector2 = spec["center"]
	var size: Vector2 = spec["size"]
	var cell: float = spec["cell"]
	var cells_x := maxi(2, ceili(size.x / cell))
	var cells_z := maxi(2, ceili(size.y / cell))
	var actual_step_x := size.x / float(cells_x)
	var actual_step_z := size.y / float(cells_z)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(cells_z):
		for x in range(cells_x):
			var x0 := -size.x * 0.5 + float(x) * actual_step_x
			var x1 := x0 + actual_step_x
			var z0 := -size.y * 0.5 + float(z) * actual_step_z
			var z1 := z0 + actual_step_z
			var p00 := _vertex(spec, center, x0, z0)
			var p10 := _vertex(spec, center, x1, z0)
			var p01 := _vertex(spec, center, x0, z1)
			var p11 := _vertex(spec, center, x1, z1)
			_add_vertex(surface, p00, str(spec["kind"]))
			_add_vertex(surface, p10, str(spec["kind"]))
			_add_vertex(surface, p11, str(spec["kind"]))
			_add_vertex(surface, p00, str(spec["kind"]))
			_add_vertex(surface, p11, str(spec["kind"]))
			_add_vertex(surface, p01, str(spec["kind"]))

	surface.generate_normals()
	var mesh := surface.commit() as ArrayMesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	mesh.surface_set_material(0, material)

	var body := StaticBody3D.new()
	body.name = str(spec["name"])
	body.position = Vector3(center.x, 0.0, center.y)
	body.add_to_group("macro_terrain")

	var visual := MeshInstance3D.new()
	visual.name = "TerrainMesh"
	visual.mesh = mesh
	body.add_child(visual)

	var collision := CollisionShape3D.new()
	collision.name = "TerrainCollision"
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)

	add_child(body)
	patch_bodies.append(body)

func _vertex(spec: Dictionary, center: Vector2, local_x: float, local_z: float) -> Vector3:
	var world_x := center.x + local_x
	var world_z := center.y + local_z
	return Vector3(local_x, _height_for_spec(spec, world_x, world_z), local_z)

func _add_vertex(surface: SurfaceTool, point: Vector3, kind: String) -> void:
	surface.set_color(_terrain_color(point.y, kind))
	surface.add_vertex(point)

func _terrain_color(height: float, kind: String) -> Color:
	var low := Color(0.18, 0.31, 0.17)
	var mid := Color(0.32, 0.39, 0.25)
	var high := Color(0.42, 0.42, 0.37)
	var stone := Color(0.54, 0.54, 0.51)
	if kind == "south_valley":
		low = Color(0.20, 0.34, 0.18)
		mid = Color(0.38, 0.40, 0.24)
	if height < 12.0:
		return low.lerp(mid, clampf(height / 12.0, 0.0, 1.0))
	if height < 38.0:
		return mid.lerp(high, clampf((height - 12.0) / 26.0, 0.0, 1.0))
	return high.lerp(stone, clampf((height - 38.0) / 34.0, 0.0, 1.0))

func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 0.0
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
