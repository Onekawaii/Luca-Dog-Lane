class_name LucaChunkRenderer
extends Node3D

const Config = preload("res://scripts/luca/LucaWorldConfig.gd")

var _materialized: Dictionary = {}

func materialize_chunk(coords: Vector2i, descriptor: Dictionary, mode: String) -> void:
	var key := Config.chunk_key(coords)
	if not _materialized.has(key):
		var root := Node3D.new()
		root.name = "LucaChunk_" + key.replace(":", "_")
		root.position = Vector3(coords.x * Config.CHUNK_SIZE, 0.0, coords.y * Config.CHUNK_SIZE)
		root.set_meta("descriptor_hash", descriptor.get("descriptor_hash", ""))
		root.set_meta("biome", descriptor.get("biome", ""))
		add_child(root)
		_materialized[key] = root
	var chunk_root: Node3D = _materialized[key]
	chunk_root.set_meta("stream_mode", mode)
	chunk_root.visible = mode in ["render", "physics"]

func dematerialize_chunk(coords: Vector2i, mode: String) -> void:
	var key := Config.chunk_key(coords)
	if not _materialized.has(key):
		return
	var root: Node3D = _materialized[key]
	if mode == "preload":
		root.queue_free()
		_materialized.erase(key)
	elif mode == "render":
		root.visible = false
	elif mode == "physics":
		root.set_meta("stream_mode", "render")

func materialized_count() -> int:
	return _materialized.size()
