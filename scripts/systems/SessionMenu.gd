extends CanvasLayer
# Single-player menu owns session pause and pointer capture, not world/save data.
var game: Node
var hud: CanvasLayer
var player: CharacterBody3D
var screen := ""
var options_return := "pause"
var overlay: ColorRect
var column: VBoxContainer
var status: Label
var sensitivity_slider: HSlider
var volume_slider: HSlider

func _ready() -> void:
	name = "SessionMenu"
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.03, 0.025, 0.86)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = 460
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	overlay.hide()
	# Test harnesses/headless probes opt out; ordinary desktop launches get a title.
	if OS.get_environment("SPIRAL_SKIP_TITLE") != "1" and DisplayServer.get_name() != "headless" and not "--script" in OS.get_cmdline_args():
		call_deferred("open", "title")
	if OS.get_environment("SPIRAL_TITLE_STARTUP_PROBE") == "1":
		call_deferred("_verify_title_startup")

func _verify_title_startup() -> void:
	for i in range(5):
		await get_tree().process_frame
	var passed: bool = screen == "title" and get_tree().paused and not hud.root.visible and player.gameplay_blocked
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var folder := OS.get_environment("SPIRAL_PC_CAPTURE_DIR")
		if folder.is_empty():
			folder = ProjectSettings.globalize_path("res://dist/pc-review-20261008")
		DirAccess.make_dir_recursive_absolute(folder)
		passed = passed and get_viewport().get_texture().get_image().save_png(folder.path_join("ordinary-title-startup.png")) == OK
	print("[ORDINARY TITLE STARTUP PASSED]" if passed else "[ORDINARY TITLE STARTUP FAILED]")
	get_tree().quit(0 if passed else 1)

func is_open() -> bool:
	return not screen.is_empty()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if screen == "options":
			open(options_return)
		elif screen == "pause":
			resume()
		elif screen == "title":
			return # Play is intentional; Escape does not silently start the world.
		elif hud.call("has_modal"):
			hud.call("close_modals")
		else:
			open("pause")
		get_viewport().set_input_as_handled()
	elif is_open() and (event is InputEventKey or event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()

func open(kind: String) -> void:
	if kind == "options":
		options_return = screen if screen in ["title", "pause"] else "pause"
	screen = kind
	hud.call("close_modals", false)
	hud.root.hide()
	player.call("set_gameplay_blocked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	overlay.show()
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	_heading("SPIRAL FIELD" if kind == "title" else ("OPTIONS" if kind == "options" else "GAME PAUSED"))
	if kind == "options":
		_heading("Mouse sensitivity", 16)
		sensitivity_slider = _slider(0.001, 0.008, player.look_sensitivity)
		sensitivity_slider.value_changed.connect(func(value: float): player.look_sensitivity = value)
		_heading("Master volume", 16)
		var master := AudioServer.get_bus_index("Master")
		volume_slider = _slider(0.0, 1.0, db_to_linear(AudioServer.get_bus_volume_db(master)))
		volume_slider.value_changed.connect(func(value: float): AudioServer.set_bus_volume_db(master, linear_to_db(maxf(value, 0.0001))))
		_button("Toggle fullscreen", func():
			var mode := DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
		_button("Done", func(): open(options_return))
	else:
		_button("Play / Continue World" if kind == "title" else "Back to Game", resume)
		_button("Options...", func(): open("options"))
		_button("Controls", _controls)
		if kind == "pause":
			_button("Save and Return to Title", _save_to_title)
		else:
			_button("Save and Quit", _save_and_quit)
	status = _heading("Existing world retained. No reset or new-world action here.", 14)
	if kind == "pause":
		status.text = "Single player paused // world simulation stopped"

func resume() -> void:
	screen = ""
	overlay.hide()
	get_tree().paused = false
	hud.root.show()
	hud.call("sync_modal_input")

func _save_to_title() -> void:
	if game.call("save_session"):
		open("title")
	else:
		status.text = "Save failed. World retained; return to game and try again."

func _save_and_quit() -> void:
	if game.call("save_session"):
		get_tree().quit()
	else:
		status.text = "Save failed. Not quitting."

func _controls() -> void:
	status.text = "WASD move | Space jump | Shift sprint\nLMB use | E interact / car exit | Wheel / 1-9,0 equip\nI inventory | M map | L lantern | V noclip\nR / F5 car view | Esc pause / close"

func _heading(value: String, font_size := 30) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)
	return label

func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.30, 0.32, 0.29)
	style.border_color = Color(0.65, 0.68, 0.60)
	style.set_border_width_all(3)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.43, 0.46, 0.38)
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(action)
	column.add_child(button)
	return button

func _slider(low: float, high: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 100.0
	slider.value = value
	slider.custom_minimum_size.y = 32
	column.add_child(slider)
	return slider
