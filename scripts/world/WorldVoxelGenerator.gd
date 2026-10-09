extends "res://scripts/world/TerrainSliceGenerator.gd"

const ROAD := 8
const ROAD_LINE := 9
const CONCRETE := 7
const HALF := 480
const GRID_STEP := 8
const GRID_WIDTH := 121
var heights := PackedFloat32Array()

func configure_world(seed: int, scale_value: float) -> void:
	configure(seed)
	var source := MacroTerrain.new()
	source.world_plan = world_plan
	source.height_scale = scale_value
	heights.resize(GRID_WIDTH * GRID_WIDTH)
	for z in range(GRID_WIDTH):
		for x in range(GRID_WIDTH):
			heights[z * GRID_WIDTH + x] = source.height_at(x * GRID_STEP - HALF, z * GRID_STEP - HALF)
	source.free()

func height_at(x: float, z: float) -> float:
	var gx := clampf((x + HALF) / GRID_STEP, 0.0, float(GRID_WIDTH - 1) - 0.001)
	var gz := clampf((z + HALF) / GRID_STEP, 0.0, float(GRID_WIDTH - 1) - 0.001)
	var ix := floori(gx)
	var iz := floori(gz)
	var a := lerpf(heights[iz * GRID_WIDTH + ix], heights[iz * GRID_WIDTH + ix + 1], gx - ix)
	var b := lerpf(heights[(iz + 1) * GRID_WIDTH + ix], heights[(iz + 1) * GRID_WIDTH + ix + 1], gx - ix)
	return lerpf(a, b, gz - iz)

func _generate_block(buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	# Retain the authored quarry/cave generator verbatim before filling the rest.
	super._generate_block(buffer, origin, lod)
	if lod != 0:
		return
	var size := buffer.get_size()
	for z in range(size.z):
		var gz := origin.z + z
		for x in range(size.x):
			var gx := origin.x + x
			if abs(gx) >= HALF or abs(gz) >= HALF:
				continue
			var quarry := gx >= 256 and gx < 368 and gz >= 228 and gz < 336
			var terrace_height := _terrace_height(float(gx)+0.5,float(gz)+0.5)
			var top := ceili(maxf(height_at(gx, gz), terrace_height)) - 1
			for y in range(size.y):
				var gy := origin.y + y
				if gy < -16:
					continue
				if quarry and gy >= 0:
					continue
				if gy <= top:
					buffer.set_voxel(_top_surface_id(gx, gz) if gy == top else STONE, x, y, z, CHANNEL_TYPE)

# Surface pavement is part of the same 1m voxel terrain, never a non-colliding slab.
func _terrace_height(x:float,z:float)->float:
	var dx:=x-245.0
	var dz:=z+180.0
	if absf(dx)>68.0 or absf(dz)>68.0:
		return 0.0
	var radius:=Vector2(dx,dz).length()
	for i in range(4,-1,-1):
		if radius<68.0-float(i)*10.0:
			return float(i+1)*4.0
	return 0.0

func _top_surface_id(x: int, z: int) -> int:
	var p := Vector2(float(x) + 0.5, float(z) + 0.5)
	var on_ns := absf(p.x) < 8.0 and absf(p.y) < 380.0
	var on_ew := absf(p.y) < 8.0 and absf(p.x) < 380.0
	var forest := _inside_rotated_road(p, Vector2(-180.0, -120.0), 220.0, 10.0, -18.0)
	var quarry := _inside_rotated_road(p, Vector2(185.0, 145.0), 250.0, 11.0, 30.0)
	if _terrace_height(p.x,p.y) > 0.0:
		return CONCRETE
	if on_ns and absf(p.x) < 1.0 and posmod(z + 6, 30) < 7 and absf(p.y) > 12.0:
		return ROAD_LINE
	if on_ns or on_ew or forest or quarry:
		return ROAD
	if absf(p.x - 55.0) < 40.0 and absf(p.y - 55.0) < 35.0:
		return CONCRETE
	if absf(p.x + 95.0) < 50.0 and absf(p.y - 72.0) < 41.0:
		return CONCRETE
	if p.distance_to(Vector2(-235.0, -205.0)) < 42.0:
		return CONCRETE
	return SURFACE

func _inside_rotated_road(point: Vector2, center: Vector2, length: float, width: float, rotation_degrees: float) -> bool:
	var local := (point - center).rotated(deg_to_rad(-rotation_degrees))
	return absf(local.x) < length * 0.5 and absf(local.y) < width * 0.5
