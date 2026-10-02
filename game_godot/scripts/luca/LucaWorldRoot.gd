class_name LucaWorldRoot
extends Node

const Config = preload("res://scripts/luca/LucaWorldConfig.gd")
const DatabaseClass = preload("res://scripts/luca/LucaChunkDatabase.gd")
const PersistenceClass = preload("res://scripts/luca/LucaWorldPersistence.gd")
const StreamerClass = preload("res://scripts/luca/LucaWorldStreamer.gd")
const ChunkRendererClass = preload("res://scripts/luca/LucaChunkRenderer.gd")
const ModManagerClass = preload("res://scripts/luca/LucaModManager.gd")
const EntityRegistryClass = preload("res://scripts/luca/LucaEntityRegistry.gd")
const ObjectTetherClass = preload("res://scripts/luca/LucaObjectTether.gd")
const ToolSystemClass = preload("res://scripts/luca/LucaToolSystem.gd")

var chunk_database: RefCounted
var persistence: RefCounted
var streamer: Node
var chunk_renderer: Node3D
var mod_manager: RefCounted
var entity_registry: RefCounted
var object_tether: Node
var tool_system: Node
var player: Node3D

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	player = get_parent().find_child("Player", true, false) as Node3D
	if not is_instance_valid(player):
		push_error("LUCA WORLD ROOT: Player not found")
		return
	var seed := 6060
	if GameRuntime.world_state != null:
		seed = GameRuntime.world_state.rng_seed
	chunk_database = DatabaseClass.new()
	chunk_database.configure(seed)
	persistence = PersistenceClass.new()
	_restore_persistence()
	mod_manager = ModManagerClass.new()
	var mod_scan: Dictionary = mod_manager.scan_user_mods()
	entity_registry = EntityRegistryClass.new()
	chunk_renderer = ChunkRendererClass.new()
	chunk_renderer.name = "LucaChunkRenderer"
	add_child(chunk_renderer)
	streamer = StreamerClass.new()
	streamer.name = "LucaWorldStreamer"
	add_child(streamer)
	streamer.stream_changed.connect(_on_stream_changed)
	streamer.configure(player, chunk_database, persistence, chunk_renderer)
	object_tether = ObjectTetherClass.new()
	object_tether.name = "LucaObjectTether"
	add_child(object_tether)
	var camera := player.find_child("Camera3D", true, false) as Node3D
	if is_instance_valid(camera):
		object_tether.configure(camera)
	tool_system = ToolSystemClass.new()
	tool_system.name = "LucaToolSystem"
	add_child(tool_system)
	tool_system.configure(object_tether)
	_publish_runtime_state()
	if GameRuntime.world_state != null:
		var luca_world: Dictionary = GameRuntime.world_state.world_state.get("luca_world", {})
		luca_world["modset_hash"] = str(mod_manager.get("modset_hash"))
		luca_world["loaded_mods"] = mod_scan.get("loaded", [])
		GameRuntime.world_state.world_state["luca_world"] = luca_world

func _on_stream_changed(snapshot: Dictionary) -> void:
	if GameRuntime.world_state == null:
		return
	var luca_world: Dictionary = GameRuntime.world_state.world_state.get("luca_world", {})
	luca_world["streaming"] = snapshot.duplicate(true)
	luca_world["generator_version"] = Config.GENERATOR_VERSION
	luca_world["chunk_size"] = Config.CHUNK_SIZE
	GameRuntime.world_state.world_state["luca_world"] = luca_world

func persist_world_deltas() -> void:
	if GameRuntime.world_state == null or persistence == null:
		return
	var luca_world: Dictionary = GameRuntime.world_state.world_state.get("luca_world", {})
	luca_world["deltas"] = persistence.to_dict()
	GameRuntime.world_state.world_state["luca_world"] = luca_world

func record_removed(chunk: Vector2i, entity_id: String) -> void:
	persistence.record_removed(chunk, entity_id)
	persist_world_deltas()

func record_collected(chunk: Vector2i, entity_id: String) -> void:
	persistence.record_collected(chunk, entity_id)
	persist_world_deltas()

func record_moved(chunk: Vector2i, entity_id: String, transform_data: Dictionary) -> void:
	persistence.record_moved(chunk, entity_id, transform_data)
	persist_world_deltas()

func record_spawned(chunk: Vector2i, entity: Dictionary) -> void:
	persistence.record_spawned(chunk, entity)
	persist_world_deltas()

func _restore_persistence() -> void:
	if GameRuntime.world_state == null:
		return
	var luca_world: Dictionary = GameRuntime.world_state.world_state.get("luca_world", {})
	var data: Variant = luca_world.get("deltas", {})
	if data is Dictionary and not (data as Dictionary).is_empty():
		persistence.from_dict(data)

func _publish_runtime_state() -> void:
	if GameRuntime.world_state == null:
		return
	var luca_world: Dictionary = GameRuntime.world_state.world_state.get("luca_world", {})
	luca_world["schema"] = "luca_world_runtime_v1"
	luca_world["generator_version"] = Config.GENERATOR_VERSION
	luca_world["chunk_size"] = Config.CHUNK_SIZE
	luca_world["subcell_size"] = Config.SUBCELL_SIZE
	luca_world["rings"] = {"preload": 7, "render": 5, "physics": 3}
	GameRuntime.world_state.world_state["luca_world"] = luca_world
