class_name LucaWorldStreamer
extends Node

const Config = preload("res://scripts/luca/LucaWorldConfig.gd")

signal stream_changed(snapshot: Dictionary)

var player: Node3D
var chunk_database: RefCounted
var persistence: RefCounted
var renderer: Node
var preload_chunks: Dictionary = {}
var render_chunks: Dictionary = {}
var physics_chunks: Dictionary = {}
var _last_center := Vector2i(2147483647, 2147483647)
var _pending: Array = []
var _flight_suspended := false

func configure(
	player_node: Node3D,
	database: RefCounted,
	persistence_store: RefCounted,
	renderer_node: Node = null
) -> void:
	player = player_node
	chunk_database = database
	persistence = persistence_store
	renderer = renderer_node
	refresh(true)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	refresh(false)
	_drain_budget()

func refresh(force: bool = false) -> void:
	if not is_instance_valid(player):
		return
	var center := Config.world_to_chunk(player.global_position)
	var free_fly := bool(player.get("free_fly_enabled"))
	_flight_suspended = free_fly and player.global_position.y > Config.FLIGHT_SUSPEND_HEIGHT
	if not force and center == _last_center:
		return
	_last_center = center
	var rings := Config.ring_sets(center)
	_update_set("preload", preload_chunks, rings["preload"])
	_update_set("render", render_chunks, rings["render"])
	if not _flight_suspended:
		_update_set("physics", physics_chunks, rings["physics"])
	else:
		physics_chunks.clear()
	emit_signal("stream_changed", snapshot())

func snapshot() -> Dictionary:
	return {
		"center": {"x": _last_center.x, "y": _last_center.y},
		"preload_count": preload_chunks.size(),
		"render_count": render_chunks.size(),
		"physics_count": physics_chunks.size(),
		"flight_suspended": _flight_suspended,
		"pending": _pending.size(),
	}

func _update_set(mode: String, current: Dictionary, desired_coords: Array) -> void:
	var desired := {}
	for coords in desired_coords:
		var key := Config.chunk_key(coords)
		desired[key] = coords
		if not current.has(key):
			current[key] = coords
			_pending.append({"op": "enter", "mode": mode, "coords": coords})
	for key in current.keys():
		if desired.has(key):
			continue
		var coords: Vector2i = current[key]
		if _within_hysteresis(coords, _last_center):
			continue
		current.erase(key)
		_pending.append({"op": "exit", "mode": mode, "coords": coords})

func _within_hysteresis(coords: Vector2i, center: Vector2i) -> bool:
	return maxi(abs(coords.x - center.x), abs(coords.y - center.y)) <= Config.PRELOAD_RADIUS + Config.HYSTERESIS_CELLS

func _drain_budget() -> void:
	var budget := Config.STREAM_BUDGET_PER_TICK
	while budget > 0 and not _pending.is_empty():
		var job: Dictionary = _pending.pop_front()
		_apply_job(job)
		budget -= 1

func _apply_job(job: Dictionary) -> void:
	if chunk_database == null:
		return
	var coords: Vector2i = job["coords"]
	if str(job.get("op", "")) == "enter":
		var descriptor: Dictionary = chunk_database.call("get_chunk", coords)
		if persistence != null:
			descriptor = persistence.call("apply_to_descriptor", descriptor)
		if is_instance_valid(renderer) and renderer.has_method("materialize_chunk"):
			renderer.call("materialize_chunk", coords, descriptor, str(job["mode"]))
	elif is_instance_valid(renderer) and renderer.has_method("dematerialize_chunk"):
		renderer.call("dematerialize_chunk", coords, str(job["mode"]))
