class_name MacroTerrain
extends Node3D

const TERRAIN_CELL_M := 8.0
const MAX_HEIGHT_M := 54.0

var world_plan: KimiWorldPlan
var world_half := 480.0
var height_scale := 1.0
var terrain_body: StaticBody3D
var voxel_preview := false

# Hide the smooth distance terrain only where a player can edit or has edited.
# A compact 2D column mask preserves all persistent edits without per-pixel loops.
const EDIT_MASK_SIDE := 960
var edit_mask_image: Image
var edit_mask_texture: ImageTexture
var preview_shader: ShaderMaterial
var voxel_materials: Array[ShaderMaterial] = []
var voxel_material_shader: Shader
var edit_mask_dirty := false
var edit_mask_timer := 0.0

func _process(delta: float) -> void:
	# Voxel face visibility is driven by the camera being genuinely underground,
	# not by proximity to the camera. Prevents z-fighting on untouched grass.
	var active_camera := get_viewport().get_camera_3d()
	if active_camera != null and not voxel_materials.is_empty():
		var point := active_camera.global_position
		var inside_terrain := point.y < height_at(point.x, point.z) - 0.65
		for material in voxel_materials:
			material.set_shader_parameter("underground_view", inside_terrain)
	if not edit_mask_dirty or edit_mask_texture == null:
		return
	edit_mask_timer -= delta
	if edit_mask_timer <= 0.0:
		edit_mask_texture.update(edit_mask_image)
		edit_mask_timer = 0.15
		edit_mask_dirty = false

func make_voxel_visibility_material(kind: String, tint: Color) -> ShaderMaterial:
	if voxel_material_shader == null:
		voxel_material_shader = Shader.new()
		voxel_material_shader.code = "shader_type spatial; render_mode cull_back, shadows_disabled; varying vec3 pworld; uniform sampler2D edited_columns : filter_nearest, repeat_disable; uniform sampler2D block_texture : source_color, filter_linear_mipmap; uniform vec4 block_tint : source_color = vec4(1.0); uniform bool underground_view = false; void vertex(){pworld=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){vec2 mask_uv=(pworld.xz+vec2(480.0))/960.0; bool quarry=pworld.x>254.0 && pworld.x<370.0 && pworld.z>226.0 && pworld.z<338.0; if(!underground_view && !quarry && texture(edited_columns,clamp(mask_uv,vec2(0.0),vec2(1.0))).r<0.5){discard;} ALBEDO=texture(block_texture,UV).rgb*block_tint.rgb; ROUGHNESS=0.94;}"
	var result := ShaderMaterial.new()
	result.shader = voxel_material_shader
	result.set_shader_parameter("edited_columns", edit_mask_texture)
	result.set_shader_parameter("block_texture", load("res://scripts/systems/ObjectMaterials.gd").texture(kind))
	result.set_shader_parameter("block_tint", tint)
	voxel_materials.append(result)
	return result

func sync_voxel_edit_columns(edits: Dictionary) -> void:
	if edit_mask_image == null:
		return
	edit_mask_image.fill(Color.BLACK)
	for key in edits:
		var parts := str(key).split(",")
		if parts.size() == 3:
			_stamp_voxel_edit(Vector3i(int(parts[0]), int(parts[1]), int(parts[2])))
	edit_mask_texture.update(edit_mask_image)
	edit_mask_dirty = false

func mark_voxel_edit(pos: Vector3i) -> void:
	if edit_mask_image == null:
		return
	_stamp_voxel_edit(pos)
	edit_mask_dirty = true

func _stamp_voxel_edit(pos: Vector3i) -> void:
	var x := pos.x + EDIT_MASK_SIDE / 2
	var z := pos.z + EDIT_MASK_SIDE / 2
	# Two-column margin hides smooth triangles which would otherwise cap a mined cavity.
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var px := x + dx
			var pz := z + dz
			if px >= 0 and px < EDIT_MASK_SIDE and pz >= 0 and pz < EDIT_MASK_SIDE:
				edit_mask_image.set_pixel(px, pz, Color.WHITE)

func _ready() -> void:
	if world_plan == null:
		world_plan = KimiWorldPlan.new(6060)
	if not voxel_preview:
		_build_world_terrain()  # Legacy mesh-only adapter; NEVER render over voxel terrain.
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

	# Share exact boundary vertices before generating normals. The previous order
	# left every 12 m triangle with an isolated flat normal, which made otherwise
	# continuous mountains read as broken facets during the v0.2.1 playthrough.
	surface.index()
	surface.generate_normals()
	var mesh := surface.commit() as ArrayMesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	mesh.surface_set_material(0, material)
	if voxel_preview:
		edit_mask_image = Image.create(EDIT_MASK_SIDE, EDIT_MASK_SIDE, false, Image.FORMAT_L8)
		edit_mask_image.fill(Color.BLACK)
		edit_mask_texture = ImageTexture.create_from_image(edit_mask_image)
		preview_shader = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode shadows_disabled; varying vec3 world_pos; uniform sampler2D edited_columns : filter_nearest, repeat_disable; void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){vec2 uv=(world_pos.xz+vec2(480.0))/960.0; if(texture(edited_columns,clamp(uv,vec2(0.0),vec2(1.0))).r>0.5){discard;} ALBEDO=COLOR.rgb; ROUGHNESS=0.98;}"
		preview_shader.shader = shader
		preview_shader.set_shader_parameter("edited_columns", edit_mask_texture)
		mesh.surface_set_material(0, preview_shader)

	terrain_body = StaticBody3D.new()
	terrain_body.name = "WorldTerrain"
	terrain_body.add_to_group("macro_terrain")
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 1

	var visual := MeshInstance3D.new()
	visual.name = "TerrainMesh"
	visual.mesh = mesh
	if voxel_preview:
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_body.add_child(visual)

	var collision := CollisionShape3D.new()
	collision.name = "TerrainCollision"
	collision.shape = mesh.create_trimesh_shape()
	terrain_body.add_child(collision)
	if voxel_preview:
		collision.disabled = true

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
