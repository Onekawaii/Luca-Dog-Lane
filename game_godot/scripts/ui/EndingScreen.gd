extends Control

const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const GAME_SCENE := "res://scenes/bootstrap/FirstPersonBootstrap.tscn"

@onready var summary_label: Label = $Center/VBox/Summary
@onready var detail_label: Label = $Center/VBox/Detail
@onready var return_button: Button = $Center/VBox/ReturnButton
@onready var revisit_button: Button = $Center/VBox/RevisitButton
@onready var quit_button: Button = $Center/VBox/QuitButton


func _ready() -> void:
	AtmosphereDirector.enter_menu()
	return_button.pressed.connect(_return_to_title)
	revisit_button.pressed.connect(_revisit_world)
	quit_button.pressed.connect(get_tree().quit)
	quit_button.visible = not OS.has_feature("android")
	_refresh_summary()


func _refresh_summary() -> void:
	var state := GameRuntime.world_state
	if state == null:
		summary_label.text = "JOURNEY COMPLETE"
		detail_label.text = "The journey exists, but the active state is unavailable."
		return
	var echoes: Dictionary = state.world_state.get("lattice_echoes", {})
	var visited := int(state.world_state.get("completion_visited_cells", 0))
	var stamp := str(state.world_state.get("completion_timestamp", "unknown time"))
	var slot := str(state.world_state.get("active_save_slot", "slot_1"))
	summary_label.text = "JOURNEY COMPLETE\nLUCA IS STILL WAITING ON THE OPEN ROAD"
	detail_label.text = "Save: %s\nSeed: %d\nTrail memories: %d / 24\nExplored stream cells: %d\nCompleted: %s" % [
		slot.to_upper(), state.rng_seed, echoes.size(), visited, stamp
	]


func _return_to_title() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _revisit_world() -> void:
	AtmosphereDirector.enter_gameplay()
	get_tree().change_scene_to_file(GAME_SCENE)
