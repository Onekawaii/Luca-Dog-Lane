extends Node

# Authoritative Room Transition and World Management Controller.

var current_room_node: Node2D = null
var current_room_id: String = "breakroom"

var room_scenes: Dictionary = {
	"breakroom": "res://scenes/rooms/Breakroom.tscn",
	"hallway": "res://scenes/rooms/Hallway.tscn",
	"fridge_labyrinth": "res://scenes/rooms/FridgeLabyrinth.tscn"
}

var room_locations: Dictionary = {
	"breakroom": "location.breakroom",
	"hallway": "location.breakroom.hallway",
	"fridge_labyrinth": "location.fridge_labyrinth"
}


func _ready() -> void:
	EventBus.room_change_requested.connect(change_room)


func _get_world_root() -> Node:
	var tree = get_tree()
	if not tree or not tree.root:
		return null
	var root_scene = tree.current_scene
	if root_scene:
		var wr = root_scene.find_child("WorldRoot", true, false)
		if wr:
			return wr
		return root_scene
	return tree.root.find_child("WorldRoot", true, false)


func change_room(room_id: String, entrance_name: String = "Default") -> void:
	if not room_scenes.has(room_id):
		push_error("Unknown room_id: " + room_id)
		return

	var scene_path = room_scenes[room_id]
	if not ResourceLoader.exists(scene_path):
		push_error("Room scene not found: " + scene_path)
		return

	# Update WorldState location
	var state = GameRuntime.world_state
	state.current_location = room_locations.get(room_id, "location.breakroom")

	# Instantiate new room scene
	var room_res = load(scene_path)
	var new_room: Node2D = room_res.instantiate()

	var world_root = _get_world_root()
	if not world_root:
		push_error("WorldRoot not found")
		return

	# Clear previous rooms in world_root
	for child in world_root.get_children():
		if child is RoomBase or child.name in ["Breakroom", "Hallway", "FridgeLabyrinth"]:
			child.queue_free()

	world_root.add_child(new_room)
	current_room_node = new_room
	current_room_id = room_id

	new_room.set_player_spawn(entrance_name)
	EventBus.room_entered.emit(room_id)
	EventBus.world_state_changed.emit({})
	AudioManager.play_ui_click()
