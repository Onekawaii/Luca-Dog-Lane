extends VoxelGeneratorScript

const WORLD_SEED := 6060
var world_plan := KimiWorldPlan.new(WORLD_SEED)

const CHANNEL_TYPE := 0
const AIR := 0
const STONE := 1
const SURFACE := 2
const BRICK := 3

const CENTER_X := 310.0
const CENTER_Z := 282.0
const RADIUS := 48.0

func _get_used_channels_mask() -> int:
	return 1 << CHANNEL_TYPE

func _generate_block(buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	buffer.fill(AIR, CHANNEL_TYPE)
	if lod != 0:
		return

	var size := buffer.get_size()
	for z in range(size.z):
		var gz := float(origin.z + z)
		for x in range(size.x):
			var gx := float(origin.x + x)
			var nx := (gx - CENTER_X) / RADIUS
			var nz := (gz - CENTER_Z) / RADIUS
			var radial := sqrt(nx * nx + nz * nz)
			if radial > 1.03:
				continue

			var envelope := pow(maxf(0.0, 1.0 - radial), 1.32)
			var ridge := sin(gx * 0.115) * cos(gz * 0.083) * 2.6 * envelope
			var shoulder := sin((gx + gz) * 0.047) * 1.4 * envelope
			var kimi_macro := clampf(world_plan.terrain_height(gx, gz) * 0.025, -2.0, 5.0)
			var surface_y := 1.0 + (33.0 + kimi_macro) * envelope + ridge + shoulder

			for y in range(size.y):
				var gy := float(origin.y + y)
				if gy < 0.0 or gy > surface_y:
					continue
				if _is_cave(gx, gy, gz):
					continue

				var voxel_type := STONE
				if gy >= surface_y - 1.25:
					voxel_type = SURFACE
				buffer.set_voxel(voxel_type, x, y, z, CHANNEL_TYPE)

func _is_cave(gx: float, gy: float, gz: float) -> bool:
	if gx >= CENTER_X - 43.0 and gx <= CENTER_X + 31.0:
		var tunnel_z := CENTER_Z + sin((gx - CENTER_X) * 0.115) * 3.5
		var tunnel_y := 8.0 + sin((gx - CENTER_X) * 0.071) * 1.4
		var dz := gz - tunnel_z
		var dy := gy - tunnel_y
		if dz * dz + dy * dy <= 15.2:
			return true

	var chamber := Vector3(gx - (CENTER_X + 5.0), gy - 10.0, gz - (CENTER_Z + 1.0))
	if chamber.length_squared() <= 46.0:
		return true

	var chimney_dx := gx - (CENTER_X + 7.0)
	var chimney_dz := gz - (CENTER_Z + 1.0)
	if gy >= 9.0 and gy <= 18.0 and chimney_dx * chimney_dx + chimney_dz * chimney_dz <= 5.2:
		return true

	return false
