class_name LucaWorldConfig
extends RefCounted

const GENERATOR_VERSION := "luca-world-v1"
const CHUNK_SIZE := 128.0
const SUBCELL_SIZE := 32.0
const PRELOAD_RADIUS := 3
const RENDER_RADIUS := 2
const PHYSICS_RADIUS := 1
const HYSTERESIS_CELLS := 2
const STREAM_BUDGET_PER_TICK := 2
const FLIGHT_SUSPEND_HEIGHT := 220.0
const DELTA_CATEGORIES := ["removed", "moved", "collected", "spawned"]
const BIOMES := [
	"sunmeadow_fields", "whisperpine_woods", "creekglass_wetlands",
	"redclay_badlands", "mirror_lakes", "cloudstep_highlands",
	"starlight_range", "old_orchard_country", "firefly_marsh",
	"riverstone_valley",
]

static func chunk_key(coords: Vector2i) -> String:
	return "%d:%d" % [coords.x, coords.y]

static func world_to_chunk(position: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(position.x / CHUNK_SIZE)),
		int(floor(position.z / CHUNK_SIZE))
	)

static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			out.append(Vector2i(x, z))
	return out

static func ring_sets(center: Vector2i) -> Dictionary:
	return {
		"preload": ring(center, PRELOAD_RADIUS),
		"render": ring(center, RENDER_RADIUS),
		"physics": ring(center, PHYSICS_RADIUS),
	}
