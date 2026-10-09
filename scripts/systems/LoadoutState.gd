extends Node
# Sidecar schema isolates loadout/discovery from frozen world save schema.
const SCHEMA := 1
const DEFAULT_SLOTS := [
    {"type":"tool","id":"grab"},
    {"type":"tool","id":"inspect"},
    {"type":"tool","id":"mine"},
    {"type":"item","id":"stone"},
    {"type":"item","id":"grass_block"},
    {"type":"item","id":"stone_brick"},
    {"type":"tool","id":"field_hammer"},
    {"type":"tool","id":"lantern"},
    {"type":"tool","id":"place"}
]
var world_seed := 6060
var save_path := ""
var slots: Array[Dictionary] = []
var discovered: Dictionary = {}
var inventory: Node
var items: Dictionary = {}
var tools: Dictionary = {}

func configure(seed: int, inventory_node: Node, item_catalog: Dictionary, tool_catalog: Dictionary, override_path := "") -> void:
    world_seed = seed
    save_path = override_path if not override_path.is_empty() else "user://v025_loadout_%d.json" % seed
    inventory = inventory_node
    items = item_catalog.duplicate(true)
    tools = tool_catalog.duplicate(true)
    slots.clear()
    for value in DEFAULT_SLOTS:
        slots.append(value.duplicate(true))
    discovered.clear()
    if FileAccess.file_exists(save_path):
        var stored = JSON.parse_string(FileAccess.get_file_as_string(save_path))
        if typeof(stored) == TYPE_DICTIONARY and int(stored.get("schema_version",-1)) == SCHEMA and int(stored.get("world_seed",-1)) == seed:
            for item_id in stored.get("discovered", []):
                if items.has(str(item_id)):
                    discovered[str(item_id)] = true
            var restored: Array = stored.get("slots", [])
            if restored.size() == 9:
                for i in range(9):
                    var choice = restored[i]
                    if typeof(choice) == TYPE_DICTIONARY and _valid_choice(choice):
                        slots[i] = {"type":str(choice.type),"id":str(choice.id)}
    var callback := Callable(self,"_inventory_changed")
    if inventory != null and not inventory.is_connected("changed",callback):
        inventory.connect("changed",callback)
    _scan_discoveries()

func _inventory_changed(_summary: String) -> void:
    _scan_discoveries()

func _scan_discoveries() -> void:
    if inventory == null:
        return
    var changed := false
    var counts: Dictionary = inventory.call("snapshot")
    for item_id in counts:
        if int(counts[item_id]) > 0 and items.has(str(item_id)) and not discovered.has(str(item_id)):
            discovered[str(item_id)] = true
            changed = true
    if changed:
        save_now()

func _valid_choice(choice: Dictionary) -> bool:
    var kind := str(choice.get("type",""))
    var item_id := str(choice.get("id",""))
    return (kind == "tool" and tools.has(item_id)) or (kind == "item" and items.has(item_id) and (str(items[item_id].get("kind","")) == "building" or item_id == "stone"))

func assign(index: int, kind: String, item_id: String) -> bool:
    if index < 0 or index >= 9 or not _valid_choice({"type":kind, "id":item_id}):
        return false
    if kind == "item" and not discovered.has(item_id):
        return false
    slots[index] = {"type":kind,"id":item_id}
    return save_now()

func slot(index: int) -> Dictionary:
    if index < 0 or index >= slots.size():
        return {}
    return slots[index].duplicate(true)

func get_slots() -> Array[Dictionary]:
    return slots.duplicate(true)

func get_discovered() -> Array[String]:
    var known: Array[String] = []
    for key in discovered:
        known.append(str(key))
    known.sort()
    return known

func save_now() -> bool:
    if save_path.is_empty():
        return false
    var file := FileAccess.open(save_path,FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify({"schema_version":SCHEMA,"world_seed":world_seed,"slots":slots,"discovered":get_discovered()}))
    file.flush()
    return file.get_error() == OK
