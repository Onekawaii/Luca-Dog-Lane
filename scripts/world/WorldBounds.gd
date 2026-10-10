extends RefCounted

const MIN_VOXEL_Y := -16
const BEDROCK_TOP := -15.0
const FALL_RECOVERY_Y := -15.5

static func protected_voxel(pos: Vector3i, world_voxels: bool) -> bool:
	return world_voxels and pos.y <= MIN_VOXEL_Y
