class_name LucaWorldPersistence
extends RefCounted

const Config = preload("res://scripts/luca/LucaWorldConfig.gd")

var _deltas: Dictionary = {}

func record_removed(chunk: Vector2i, entity_id: String) -> void:
	_append_unique(chunk, "removed", entity_id)

func record_collected(chunk: Vector2i, entity_id: String) -> void:
	_append_unique(chunk, "collected", entity_id)

func record_moved(chunk: Vector2i, entity_id: String, transform_data: Dictionary) -> void:
	var delta := _ensure_chunk(chunk)
	delta["moved"][entity_id] = transform_data.duplicate(true)

func record_spawned(chunk: Vector2i, entity: Dictionary) -> void:
	var delta := _ensure_chunk(chunk)
	var entity_id := str(entity.get("id", ""))
	if entity_id.is_empty():
		return
	delta["spawned"][entity_id] = entity.duplicate(true)

func delta_for_chunk(chunk: Vector2i) -> Dictionary:
	return _ensure_chunk(chunk).duplicate(true)

func apply_to_descriptor(descriptor: Dictionary) -> Dictionary:
	var out := descriptor.duplicate(true)
	var coords_dict: Dictionary = out.get("coords", {})
	var coords := Vector2i(int(coords_dict.get("x", 0)), int(coords_dict.get("y", 0)))
	var delta := delta_for_chunk(coords)
	var removed: Array = delta.get("removed", [])
	var collected: Array = delta.get("collected", [])
	var moved: Dictionary = delta.get("moved", {})
	var objects: Array = []
	for raw in out.get("objects", []):
		var obj: Dictionary = raw
		var entity_id := str(obj.get("id", ""))
		if removed.has(entity_id) or collected.has(entity_id):
			continue
		var copy := obj.duplicate(true)
		if moved.has(entity_id):
			copy["persistent_transform"] = moved[entity_id].duplicate(true)
		objects.append(copy)
	for entity in (delta.get("spawned", {}) as Dictionary).values():
		objects.append((entity as Dictionary).duplicate(true))
	out["objects"] = objects
	out["persistent_delta"] = delta
	return out

func to_dict() -> Dictionary:
	return {
		"schema": "luca_world_deltas_v1",
		"categories": Config.DELTA_CATEGORIES.duplicate(),
		"chunks": _deltas.duplicate(true),
	}

func from_dict(data: Dictionary) -> void:
	_deltas.clear()
	var chunks: Variant = data.get("chunks", {})
	if chunks is Dictionary:
		_deltas = (chunks as Dictionary).duplicate(true)

func _append_unique(chunk: Vector2i, category: String, entity_id: String) -> void:
	if entity_id.is_empty():
		return
	var delta := _ensure_chunk(chunk)
	var values: Array = delta[category]
	if not values.has(entity_id):
		values.append(entity_id)

func _ensure_chunk(chunk: Vector2i) -> Dictionary:
	var key := Config.chunk_key(chunk)
	if not _deltas.has(key):
		_deltas[key] = {
			"removed": [], "moved": {}, "collected": [], "spawned": {},
		}
	return _deltas[key]
