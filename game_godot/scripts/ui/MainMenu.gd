extends Control

const GAME_SCENE := "res://scenes/bootstrap/FirstPersonBootstrap.tscn"

@onready var continue_button: Button = $Center/VBox/ContinueButton
@onready var new_button: Button = $Center/VBox/NewGameButton
@onready var slot_buttons: Array[Button] = [
	$Center/VBox/Slots/Slot1,
	$Center/VBox/Slots/Slot2,
	$Center/VBox/Slots/Slot3,
]
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var status_label: Label = $Center/VBox/StatusLabel


func _ready() -> void:
	AtmosphereDirector.enter_menu()
	continue_button.pressed.connect(_continue_latest)
	new_button.pressed.connect(func(): _start_new("slot_1"))
	quit_button.pressed.connect(get_tree().quit)
	for i in slot_buttons.size():
		var slot := "slot_%d" % (i + 1)
		slot_buttons[i].pressed.connect(func(s := slot): _activate_slot(s))
	quit_button.visible = not OS.has_feature("android")
	_refresh_slots()

func _refresh_slots() -> void:
	var newest_slot := ""
	var newest_stamp := ""
	for i in slot_buttons.size():
		var slot := "slot_%d" % (i + 1)
		var meta: Dictionary = GameRuntime.save_system.get_slot_metadata(slot)
		if bool(meta.get("exists", false)):
			var stamp := str(meta.get("timestamp", "unknown"))
			var turns := int(meta.get("turn_count", 0))
			slot_buttons[i].text = "LOAD %s  •  %s  •  TURN %d" % [slot.to_upper(), _short_stamp(stamp), turns]
			slot_buttons[i].disabled = false
			if newest_stamp == "" or stamp > newest_stamp:
				newest_stamp = stamp
				newest_slot = slot
		else:
			slot_buttons[i].text = "%s  •  EMPTY" % slot.to_upper()
			slot_buttons[i].disabled = true
	continue_button.disabled = newest_slot == ""
	continue_button.set_meta("newest_slot", newest_slot)
	status_label.text = "Luca remembers the trail." if newest_slot != "" else "No previous journey found."


func _short_stamp(value: String) -> String:
	if value.length() >= 16:
		return value.substr(0, 16).replace("T", " ")
	return value


func _activate_slot(slot: String) -> void:
	var meta: Dictionary = GameRuntime.save_system.get_slot_metadata(slot)
	if bool(meta.get("exists", false)):
		_load_slot(slot)
	else:
		_start_new(slot)

func _continue_latest() -> void:
	var slot := str(continue_button.get_meta("newest_slot", ""))
	if slot != "":
		_load_slot(slot)


func _start_new(slot: String) -> void:
	GameRuntime.new_game()
	GameRuntime.world_state.world_state["active_save_slot"] = slot
	status_label.text = "Starting a new journey with Luca..."
	_enter_game()


func _load_slot(slot: String) -> void:
	if GameRuntime.load_slot(slot):
		GameRuntime.world_state.world_state["active_save_slot"] = slot
		status_label.text = "Restoring %s..." % slot
		_enter_game()
	else:
		status_label.text = "That save could not be restored."


func _enter_game() -> void:
	AtmosphereDirector.enter_gameplay()
	get_tree().change_scene_to_file(GAME_SCENE)
