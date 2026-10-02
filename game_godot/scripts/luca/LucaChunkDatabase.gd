class_name LucaChunkDatabase
extends RefCounted

const GeneratorClass = preload("res://scripts/luca/LucaWorldGenerator.gd")

var world_seed: int = 6060
var generator: RefCounted
var _cache: Dictionary = {}

func configure(seed_value: int) -> void:
	world_seed = seed_value
	generator = GeneratorClass.new()
	_cache.clear()

func get_chunk(coords: Vector2i) -> Dictionary:
	var key := "%d:%d" % [coords.x, coords.y]
	if not _cache.has(key):
		if generator == null:
			generator = GeneratorClass.new()
		_cache[key] = generator.describe_chunk(world_seed, coords)
	return (_cache[key] as Dictionary).duplicate(true)

func descriptor_hash(coords: Vector2i) -> String:
	return str(get_chunk(coords).get("descriptor_hash", ""))

func prewarm(coords_list: Array) -> void:
	for coords in coords_list:
		if coords is Vector2i:
			get_chunk(coords)

func cached_count() -> int:
	return _cache.size()

func clear() -> void:
	_cache.clear()
