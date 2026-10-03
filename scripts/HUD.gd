extends CanvasLayer

var game: Node
var player: CharacterBody3D
var root: Control
var move_base: Panel
var move_knob: Panel
var spawn_panel: Panel
var tool_button: Button
var noclip_button: Button
var status_label: Label
var move_touch_id := -1
var look_touch_id := -1
var move_center := Vector2(125, 595)

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_build_header()
	_build_joystick()
	_build_action_buttons()
	_build_spawn_menu()
	set_tool_mode("GRAB")
	set_noclip(false)
	flash("FREE ROAM // spawn stuff, grab it, break the rules")

func _build_header() -> void:
	var title := Label.new()
	title.position = Vector2(28, 22)
	title.size = Vector2(520, 70)
	title.text = "LUCA SANDBOX  //  v0.12"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.75, 1.0, 0.80))
	root.add_child(title)

	var hint := Label.new()
	hint.position = Vector2(30, 58)
	hint.size = Vector2(650, 60)
	hint.text = "OPEN WORLD // no missions required"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.74))
	root.add_child(hint)

	status_label = Label.new()
	status_label.position = Vector2(330, 660)
	status_label.size = Vector2(620, 42)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(status_label)

func _build_joystick() -> void:
	move_base = Panel.new()
	move_base.position = Vector2(50, 520)
	move_base.size = Vector2(150, 150)
	move_base.add_theme_stylebox_override("panel", _round_style(Color(0.05, 0.08, 0.07, 0.42), Color(0.35, 0.86, 0.48), 75, 3))
	root.add_child(move_base)

	move_knob = Panel.new()
	move_knob.position = Vector2(50, 50)
	move_knob.size = Vector2(50, 50)
	move_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_knob.add_theme_stylebox_override("panel", _round_style(Color(0.35, 0.86, 0.48, 0.32), Color(0.55, 1.0, 0.64), 25, 2))
	move_base.add_child(move_knob)

func _build_action_buttons() -> void:
	var spawn_button := _button("SPAWN", Vector2(1080, 22), Vector2(160, 58))
	spawn_button.pressed.connect(_toggle_spawn_menu)
	root.add_child(spawn_button)

	tool_button = _button("TOOL", Vector2(1080, 88), Vector2(160, 58))
	tool_button.pressed.connect(func(): player.call("cycle_tool"))
	root.add_child(tool_button)

	noclip_button = _button("NOCLIP", Vector2(1080, 154), Vector2(160, 58))
	noclip_button.pressed.connect(func(): player.call("toggle_noclip"))
	root.add_child(noclip_button)

	var use_button := _button("USE", Vector2(1050, 604), Vector2(190, 72))
	use_button.pressed.connect(func(): player.call("use_tool"))
	root.add_child(use_button)

	var up_button := _button("▲", Vector2(950, 552), Vector2(78, 58))
	up_button.button_down.connect(func(): player.call("set_vertical_input", 1.0))
	up_button.button_up.connect(func(): player.call("set_vertical_input", 0.0))
	root.add_child(up_button)

	var down_button := _button("▼", Vector2(950, 618), Vector2(78, 58))
	down_button.button_down.connect(func(): player.call("set_vertical_input", -1.0))
	down_button.button_up.connect(func(): player.call("set_vertical_input", 0.0))
	root.add_child(down_button)

func _build_spawn_menu() -> void:
	spawn_panel = Panel.new()
	spawn_panel.position = Vector2(720, 118)
	spawn_panel.size = Vector2(330, 412)
	spawn_panel.add_theme_stylebox_override("panel", _round_style(Color(0.035, 0.055, 0.05, 0.94), Color(0.35, 0.86, 0.48), 18, 2))
	root.add_child(spawn_panel)
	spawn_panel.visible = false

	var header := Label.new()
	header.position = Vector2(20, 16)
	header.size = Vector2(290, 36)
	header.text = "SPAWN MENU"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 21)
	header.add_theme_color_override("font_color", Color(0.75, 1.0, 0.80))
	spawn_panel.add_child(header)

	var kinds := [
		["CRATE", "crate"],
		["BARREL", "barrel"],
		["BALL", "ball"],
		["CONE", "cone"],
		["RAMP", "ramp"],
		["NPC", "npc"],
		["BUGGY", "buggy"]
	]
	for i in range(kinds.size()):
		var col := i % 2
		var row := i / 2
		var b := _button(kinds[i][0], Vector2(20 + col * 150, 65 + row * 78), Vector2(138, 62))
		b.pressed.connect(_spawn_pressed.bind(kinds[i][1]))
		spawn_panel.add_child(b)

	var close := _button("CLOSE", Vector2(94, 355), Vector2(142, 42))
	close.pressed.connect(_toggle_spawn_menu)
	spawn_panel.add_child(close)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < 290 and event.position.y > 430:
				move_touch_id = event.index
				_update_move(event.position)
			elif not _touch_in_ui(event.position):
				look_touch_id = event.index
		else:
			if event.index == move_touch_id:
				move_touch_id = -1
				player.call("set_touch_move", Vector2.ZERO)
				move_knob.position = Vector2(50, 50)
			if event.index == look_touch_id:
				look_touch_id = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch_id:
			_update_move(event.position)
		elif event.index == look_touch_id:
			player.call("add_look_delta", event.relative)

func _update_move(position: Vector2) -> void:
	var delta := position - move_center
	var radius := 62.0
	if delta.length() > radius:
		delta = delta.normalized() * radius
	move_knob.position = Vector2(50, 50) + delta
	player.call("set_touch_move", delta / radius)

func _touch_in_ui(position: Vector2) -> bool:
	if position.x > 900:
		return true
	if spawn_panel.visible and Rect2(spawn_panel.position, spawn_panel.size).has_point(position):
		return true
	return false

func _toggle_spawn_menu() -> void:
	spawn_panel.visible = not spawn_panel.visible
	flash("Spawn menu open" if spawn_panel.visible else "Spawn menu closed")

func _spawn_pressed(kind: String) -> void:
	game.call("spawn_from_menu", kind)
	flash("Spawned " + kind.to_upper())

func set_tool_mode(mode: String) -> void:
	if tool_button != null:
		tool_button.text = "TOOL: " + mode

func set_noclip(enabled: bool) -> void:
	if noclip_button != null:
		noclip_button.text = "NOCLIP: ON" if enabled else "NOCLIP"

func flash(message: String) -> void:
	if status_label != null:
		status_label.text = message

func _button(text_value: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.92, 0.95, 0.93))
	button.add_theme_stylebox_override("normal", _round_style(Color(0.04, 0.07, 0.065, 0.88), Color(0.25, 0.50, 0.32), 13, 2))
	button.add_theme_stylebox_override("hover", _round_style(Color(0.08, 0.16, 0.11, 0.94), Color(0.40, 0.92, 0.55), 13, 2))
	button.add_theme_stylebox_override("pressed", _round_style(Color(0.18, 0.42, 0.25, 0.98), Color(0.58, 1.0, 0.68), 13, 3))
	return button

func _round_style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
