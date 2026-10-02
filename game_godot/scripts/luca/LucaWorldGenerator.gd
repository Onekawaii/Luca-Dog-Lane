class_name LucaWorldGenerator
extends RefCounted

const Config = preload("res://scripts/luca/LucaWorldConfig.gd")

const PASS_NAMES := [
	"seed", "region", "biome", "terrain",
	"hydrology", "sites", "ecology", "objects",
]

func describe_chunk(world_seed: int, coords: Vector2i) -> Dictionary:
	var chunk := {
		"schema": "luca_chunk_v1",
		"generator_version": Config.GENERATOR_VERSION,
		"world_seed": world_seed,
		"coords": {"x": coords.x, "y": coords.y},
		"chunk_key": Config.chunk_key(coords),
		"passes": [],
		"immutable": true,
	}
	_pass_seed(chunk, world_seed, coords)
	_pass_region(chunk, world_seed, coords)
	_pass_biome(chunk, world_seed, coords)
	_pass_terrain(chunk, world_seed, coords)
	_pass_hydrology(chunk, world_seed, coords)
	_pass_sites(chunk, world_seed, coords)
	_pass_ecology(chunk, world_seed, coords)
	_pass_objects(chunk, world_seed, coords)
	chunk["descriptor_hash"] = JSON.stringify(_sorted_variant(chunk)).sha256_text()
	return chunk

func _pass_seed(chunk: Dictionary, world_seed: int, coords: Vector2i) -> void:
	chunk["chunk_seed"] = _stable_seed("%d:%d:%d:%s" % [
		world_seed, coords.x, coords.y, Config.GENERATOR_VERSION
	])
	chunk["passes"].append(PASS_NAMES[0])

func _pass_region(chunk: Dictionary, world_seed: int, coords: Vector2i) -> void:
	var region := Vector2i(floori(float(coords.x) / 8.0), floori(float(coords.y) / 8.0))
	chunk["region"] = {
		"key": "region.%d.%d" % [region.x, region.y],
		"coords": {"x": region.x, "y": region.y},
		"seed": _stable_seed("%d:region:%d:%d" % [world_seed, region.x, region.y]),
	}
	chunk["passes"].append(PASS_NAMES[1])

func _pass_biome(chunk: Dictionary, world_seed: int, _coords: Vector2i) -> void:
	var region: Dictionary = chunk["region"]
	var biome_index := posmod(_stable_seed("%d:biome:%s" % [world_seed, region["key"]]), Config.BIOMES.size())
	chunk["biome"] = Config.BIOMES[biome_index]
	chunk["passes"].append(PASS_NAMES[2])

func _pass_terrain(chunk: Dictionary, world_seed: int, coords: Vector2i) -> void:
	var rng := _rng(_stable_seed("%d:terrain:%d:%d" % [world_seed, coords.x, coords.y]))
	var base := rng.randf_range(-4.0, 18.0)
	var relief := rng.randf_range(4.0, 32.0)
	if chunk["biome"] in ["cloudstep_highlands", "starlight_range"]:
		base += rng.randf_range(80.0, 240.0)
		relief += rng.randf_range(90.0, 260.0)
	chunk["terrain"] = {
		"base_height": snappedf(base, 0.01),
		"relief": snappedf(relief, 0.01),
		"roughness": snappedf(rng.randf_range(0.18, 0.92), 0.001),
		"slope_bias": snappedf(rng.randf_range(-0.35, 0.35), 0.001),
	}
	chunk["passes"].append(PASS_NAMES[3])

func _pass_hydrology(chunk: Dictionary, world_seed: int, coords: Vector2i) -> void:
	var rng := _rng(_stable_seed("%d:water:%d:%d" % [world_seed, coords.x, coords.y]))
	var wet := rng.randf()
	chunk["hydrology"] = {
		"wetness": snappedf(wet, 0.001),
		"river": wet > 0.71,
		"spring": wet > 0.86,
		"flow_angle": snappedf(rng.randf_range(-PI, PI), 0.001),
	}
	chunk["passes"].append(PASS_NAMES[4])

func _pass_sites(chunk: Dictionary, world_seed: int, coords: Vector2i) -> void:
	var rng := _rng(_stable_seed("%d:sites:%d:%d" % [world_seed, coords.x, coords.y]))
	var count := rng.randi_range(0, 3)
	var sites: Array = []
	for i in range(count):
		sites.append({
			"id": "%s.site.%02d" % [chunk["chunk_key"], i],
			"archetype": _site_archetype(rng.randi()),
			"u": snappedf(rng.randf_range(0.12, 0.88), 0.001),
			"v": snappedf(rng.randf_range(0.12, 0.88), 0.001),
		})
	chunk["sites"] = sites
	chunk["passes"].append(PASS_NAMES[5])

func _pass_ecology(chunk: Dictionary, world_seed: int, coords: Vector2i) -> void:
	var rng := _rng(_stable_seed("%d:ecology:%d:%d" % [world_seed, coords.x, coords.y]))
	chunk["ecology"] = {
		"vegetation_density": snappedf(rng.randf_range(0.15, 0.92), 0.001),
		"wildlife_density": snappedf(rng.randf_range(0.05, 0.72), 0.001),
		"npc_budget": rng.randi_range(0, 3),
	}
	chunk["passes"].append(PASS_NAMES[6])

func _pass_objects(chunk: Dictionary, world_seed: int, coords: Vector2i) -> void:
	var rng := _rng(_stable_seed("%d:objects:%d:%d" % [world_seed, coords.x, coords.y]))
	var objects: Array = []
	var object_count := rng.randi_range(3, 11)
	for i in range(object_count):
		objects.append({
			"id": "%s.object.%03d" % [chunk["chunk_key"], i],
			"kind": _object_kind(rng.randi()),
			"u": snappedf(rng.randf(), 0.001),
			"v": snappedf(rng.randf(), 0.001),
			"yaw": snappedf(rng.randf_range(-PI, PI), 0.001),
		})
	chunk["objects"] = objects
	chunk["passes"].append(PASS_NAMES[7])

func _site_archetype(value: int) -> String:
	var names := [
		"trail_shelter", "roadside_garage", "ranger_cache", "farmstead",
		"creek_crossing", "forest_cabin", "old_foundation", "lookout",
	]
	return names[posmod(value, names.size())]

func _object_kind(value: int) -> String:
	var names := ["tree", "rock", "log", "sign", "crate", "wildflower", "fence", "scrap"]
	return names[posmod(value, names.size())]

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _stable_seed(text: String) -> int:
	var h: int = 2166136261
	for i in text.length():
		h = int(((h ^ text.unicode_at(i)) * 16777619) & 0x7fffffff)
	return maxi(1, h)

func _sorted_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			out[key] = _sorted_variant(value[key])
		return out
	if value is Array:
		var out_array: Array = []
		for item in value:
			out_array.append(_sorted_variant(item))
		return out_array
	return value
