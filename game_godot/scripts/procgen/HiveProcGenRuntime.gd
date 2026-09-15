class_name HiveProcGenRuntime
extends Node

const EngineClass = preload("res://scripts/procgen/HiveProcGenEngine.gd")
const ChunkRendererClass = preload("res://scripts/procgen/HiveProcGenChunkRenderer.gd")
const MEMORY_CATALOG_PATH := "res://data/procgen/memory_catalog.json"
const FALL_RECOVERY_Y := -6.0
const SAFE_FLOOR_Y := -1.0

@export var simulate_streaming := true
@export var streaming_interval := 0.35

var engine: HiveProcGenEngine
var world_plan: Dictionary = {}
var active_cells: Array = []
var _player: Node3D
var _stream_timer := 0.0
var chunk_renderer: HiveProcGenChunkRenderer
var _current_level_index: int = -99
var _last_safe_transform := Transform3D.IDENTITY
var _has_safe_transform := false
var _breakroom: Node3D


func _ready() -> void:
	engine = EngineClass.new()
	_initialize.call_deferred()
func _initialize() -> void:
	if not is_inside_tree():
		return
	if GameRuntime.world_state == null:
		return
	var catalog := _load_memory_catalog()
	var hive_state := _current_hive_state()
	world_plan = engine.generate(GameRuntime.world_state.rng_seed, hive_state, catalog)
	var persistent: Dictionary = GameRuntime.world_state.world_state.get("procedural_world", {})
	persistent["schema"] = world_plan.get("schema")
	persistent["seed"] = world_plan.get("seed")
	persistent["receipt"] = world_plan.get("receipt", {}).duplicate(true)
	if not persistent.has("active_site"):
		persistent["active_site"] = "site.breakroom"
	GameRuntime.world_state.world_state["procedural_world"] = persistent
	var bootstrap := get_parent()
	_player = bootstrap.find_child("Player", true, false) as Node3D if bootstrap != null else null
	_breakroom = bootstrap.find_child("FirstPersonBreakroom", true, false) as Node3D if bootstrap != null else null
	if is_instance_valid(_player):
		_restore_player_position()
		_last_safe_transform = _player.global_transform
	if is_instance_valid(_player) and is_instance_valid(_breakroom):
		chunk_renderer = ChunkRendererClass.new()
		chunk_renderer.name = "HiveProcGenChunkRenderer"
		bootstrap.add_child(chunk_renderer)
		chunk_renderer.configure(world_plan, _player, _breakroom)
	AtmosphereDirector.enter_gameplay()
	_update_level_state(true)
	EventBus.procgen_world_ready.emit(world_plan.get("receipt", {}))


func regenerate_for_hive_state(hive_state: Dictionary) -> void:
	if GameRuntime.world_state == null:
		return
	world_plan = engine.generate(GameRuntime.world_state.rng_seed, hive_state, _load_memory_catalog())
	GameRuntime.world_state.world_state["procedural_world"]["receipt"] = world_plan.get("receipt", {}).duplicate(true)
	EventBus.procgen_world_ready.emit(world_plan.get("receipt", {}))
func _process(delta: float) -> void:
	if not is_inside_tree() or not simulate_streaming or world_plan.is_empty():
		return
	_update_fall_recovery()
	_stream_timer += delta
	if _stream_timer < streaming_interval:
		return
	_stream_timer = 0.0
	if not is_instance_valid(_player):
		var bootstrap := get_parent()
		_player = bootstrap.find_child("Player", true, false) as Node3D if bootstrap != null else null
	if not is_instance_valid(_player):
		return
	if is_instance_valid(chunk_renderer):
		chunk_renderer.update_streaming()
		_update_level_state()
	var site := site_by_id("site.breakroom")
	if site.is_empty():
		return
	var origin := Vector2(float(site["position"]["x"]), float(site["position"]["y"]))
	var plan_pos := origin + Vector2(_player.global_position.x, _player.global_position.z)
	var next_cells := engine.active_cells_for_position(world_plan, plan_pos, 1)
	if next_cells != active_cells:
		active_cells = next_cells
		EventBus.procgen_streaming_changed.emit(active_cells.duplicate())


func site_by_id(site_id: String) -> Dictionary:
	for site in world_plan.get("sites", []):
		if site.get("id") == site_id:
			return site
	return {}
func _current_hive_state() -> Dictionary:
	var saved: Dictionary = GameRuntime.world_state.world_state.get("hive_state", {})
	return {
		"pressure": clamp(float(saved.get("pressure", 0.35)), 0.0, 1.0),
		"instability": clamp(float(saved.get("instability", 0.25)), 0.0, 1.0),
		"observation": clamp(float(saved.get("observation", 0.50)), 0.0, 1.0),
		"familiarity": clamp(float(saved.get("familiarity", 0.40)), 0.0, 1.0),
	}


func _load_memory_catalog() -> Array:
	if not FileAccess.file_exists(MEMORY_CATALOG_PATH):
		return []
	var file := FileAccess.open(MEMORY_CATALOG_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var rows: Variant = parsed.get("memories", [])
		if rows is Array:
			return rows.duplicate(true)
	return []


func _restore_player_position() -> void:
	if GameRuntime.world_state == null or not is_instance_valid(_player):
		return
	var runtime: Dictionary = GameRuntime.world_state.world_state.get("runtime", {})
	var saved: Dictionary = runtime.get("player_position", {})
	if saved.is_empty():
		return
	var saved_y := float(saved.get("y", 1.0))
	# Never restore a save made after the player had already left supported space.
	if saved_y < SAFE_FLOOR_Y:
		return
	_player.global_position = Vector3(
		float(saved.get("x", 0.0)),
		saved_y,
		float(saved.get("z", 0.0))
	)
	_player.rotation.y = float(runtime.get("player_rotation_y", _player.rotation.y))


func _update_level_state(force: bool = false) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(chunk_renderer):
		return
	var cell_x := int(floor(_player.global_position.x / chunk_renderer.LOCAL_CELL_SIZE))
	var level_index := chunk_renderer.level_index_for_cell_x(cell_x)
	if not force and level_index == _current_level_index:
		return
	_current_level_index = level_index
	var title := chunk_renderer.level_title(level_index)
	_set_breakroom_audio_active(level_index < 0)
	AtmosphereDirector.set_level(maxi(level_index, 0), title)
	if level_index >= 0:
		EventBus.notification_posted.emit("LEVEL %02d // %s" % [level_index + 1, title])
		EventBus.first_person_objective_changed.emit("Traverse %s. Follow the threshold lights deeper into the Lattice." % title)


func _set_breakroom_audio_active(active: bool) -> void:
	if is_instance_valid(_breakroom) and _breakroom.has_method("set_breakroom_audio_active"):
		_breakroom.call("set_breakroom_audio_active", active)
	if AudioManager.has_method("set_breakroom_ambience_active"):
		AudioManager.set_breakroom_ambience_active(active)


func _update_fall_recovery() -> void:
	if not is_instance_valid(_player):
		return
	var body := _player as CharacterBody3D
	if body != null and body.is_on_floor() and body.global_position.y > SAFE_FLOOR_Y:
		_last_safe_transform = body.global_transform
		_has_safe_transform = true
		return
	if _player.global_position.y >= FALL_RECOVERY_Y:
		return
	var recovery := _last_safe_transform if _has_safe_transform else Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	# Lift slightly so the character capsule resolves cleanly onto the recovered floor.
	recovery.origin.y += 0.35
	_player.global_transform = recovery
	if body != null:
		body.velocity = Vector3.ZERO
	EventBus.notification_posted.emit("The Lattice caught you and returned you to stable ground.")
	if GameRuntime.world_state != null:
		var runtime: Dictionary = GameRuntime.world_state.world_state.get("runtime", {})
		runtime["player_position"] = {
			"x": recovery.origin.x,
			"y": recovery.origin.y,
			"z": recovery.origin.z,
		}
		GameRuntime.world_state.world_state["runtime"] = runtime
