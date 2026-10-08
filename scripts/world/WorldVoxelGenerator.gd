extends "res://scripts/world/TerrainSliceGenerator.gd"

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
			var top := ceili(height_at(gx, gz)) - 1
			for y in range(size.y):
				var gy := origin.y + y
				if gy < -16:
					continue
				if quarry and gy >= 0:
					continue
				if gy <= top:
					buffer.set_voxel(SURFACE if gy == top else STONE, x, y, z, CHANNEL_TYPE)
