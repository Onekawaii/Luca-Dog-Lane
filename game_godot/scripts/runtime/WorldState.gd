class_name WorldState
extends RefCounted

# Authoritative WorldState container for Hive-Lattice (Save Schema v3 Parity).

var campaign_id: String = "strawberry_omen"
var current_scene: String = "scene.act1.first_sighting"
var current_location: String = "location.breakroom.central_table"
var flags: Dictionary = {}
var stats: Dictionary = {}
var inventory: Array = []
var log: Array = []
var room_state: Dictionary = {}
var npc_memory: Dictionary = {}
var conditions: Dictionary = {}
var event_history: Array = []
var turn_count: int = 0
var rng_seed: int = 6060
var last_outcome: Dictionary = {}
var world_state: Dictionary = {}
var actor_dynamics: Dictionary = {}


func init_from_campaign(campaign_data: Dictionary) -> void:
	campaign_id = campaign_data.get("id", "campaign.strawberry_omen")
	current_scene = campaign_data.get("entry_scene", "scene.act1.first_sighting")
	current_location = campaign_data.get("entry_location", "location.breakroom")
	flags = campaign_data.get("starting_flags", {}).duplicate(true)
	stats = campaign_data.get("starting_stats", {}).duplicate(true)
	inventory = campaign_data.get("starting_inventory", []).duplicate(true)
	rng_seed = int(campaign_data.get("rng_seed", 6060))
	turn_count = 0
	log.clear()
	room_state.clear()
	npc_memory.clear()
	conditions.clear()
	event_history.clear()
	last_outcome.clear()
	world_state.clear()
	actor_dynamics.clear()


func room_memory(location_id: String = "") -> Dictionary:
	var loc = location_id if location_id != "" else current_location
	if not room_state.has(loc):
		room_state[loc] = {}
	return room_state[loc]


func has_item(item_id: String) -> bool:
	return inventory.has(item_id)


func add_item(item_id: String) -> void:
	if not inventory.has(item_id):
		inventory.append(item_id)


func remove_item(item_id: String) -> void:
	while inventory.has(item_id):
		inventory.erase(item_id)


func get_flag(flag_name: String, default_val: Variant = null) -> Variant:
	return flags.get(flag_name, default_val)


func set_flag(flag_name: String, val: Variant) -> void:
	flags[flag_name] = val


func to_dict() -> Dictionary:
	return {
		"save_version": 3,
		"module_id": campaign_id,
		"current_scene": current_scene,
		"current_location": current_location,
		"flags": flags.duplicate(true),
		"stats": stats.duplicate(true),
		"inventory": inventory.duplicate(true),
		"log": log.duplicate(true),
		"room_state": room_state.duplicate(true),
		"npc_memory": npc_memory.duplicate(true),
		"conditions": conditions.duplicate(true),
		"event_history": event_history.duplicate(true),
		"turn_count": turn_count,
		"rng_seed": rng_seed,
		"last_outcome": last_outcome.duplicate(true),
		"world_state": world_state.duplicate(true),
		"actor_dynamics": actor_dynamics.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	campaign_id = data.get("module_id", data.get("campaign_id", "campaign.strawberry_omen"))
	current_scene = data.get("current_scene", "scene.act1.first_sighting")
	current_location = data.get("current_location", "location.breakroom")
	flags = data.get("flags", {}).duplicate(true)
	stats = data.get("stats", {}).duplicate(true)
	inventory = data.get("inventory", []).duplicate(true)
	log = data.get("log", []).duplicate(true)
	room_state = data.get("room_state", {}).duplicate(true)
	npc_memory = data.get("npc_memory", {}).duplicate(true)
	conditions = data.get("conditions", {}).duplicate(true)
	event_history = data.get("event_history", []).duplicate(true)
	turn_count = int(data.get("turn_count", 0))
	rng_seed = int(data.get("rng_seed", 6060))
	last_outcome = data.get("last_outcome", {}).duplicate(true)
	world_state = data.get("world_state", {}).duplicate(true)
	actor_dynamics = data.get("actor_dynamics", {}).duplicate(true)
