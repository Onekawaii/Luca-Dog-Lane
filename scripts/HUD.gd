extends CanvasLayer

var game: Node
var player: CharacterBody3D

var root: Control
var move_base: Panel
var move_knob: Panel
var spawn_panel: Panel
var spawn_button: Button
var tool_button: Button
var noclip_button: Button
var use_button: Button
var jump_button: Button
var down_button: Button
var view_button: Button
var status_label: Label
var inventory_label: Label

var toast_time := 0.0
var vehicle_active := false

var move_touch_id := -1
var look_touch_id := -1
var move_center := Vector2.ZERO
var noclip_active := false
var interactive_controls: Array[Control] = []

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_header()
	_build_joystick()
	_build_action_buttons()
	_build_spawn_menu()

	root.resized.connect(_layout_for_viewport)
	call_deferred("_layout_for_viewport")
	set_tool_mode("GRAB")
	set_noclip(false)
	flash("FREE ROAM // left stick moves // drag RIGHT side to look")

func _build_header() -> void:
	var title := Label.new()
	title.name = "Title"
	title.position = Vector2(28, 22)
	title.size = Vector2(520, 42)
	title.text = "LUCA SANDBOX  //  v0.12.2"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.75, 1.0, 0.80))
	root.add_child(title)

	var hint := Label.new()
	hint.name = "Hint"
	hint.position = Vector2(30, 58)
	hint.size = Vector2(650, 36)
	hint.text = "OPEN WORLD // no missions required"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.74))
	root.add_child(hint)

	inventory_label = Label.new()
	inventory_label.name = "InventoryStatus"
	inventory_label.position = Vector2(30, 87)
	inventory_label.size = Vector2(650, 30)
	inventory_label.text = "STONE 0  //  BRICK 0"
	inventory_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_label.add_theme_font_size_override("font_size", 16)
	inventory_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.83))
	root.add_child(inventory_label)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.size = Vector2(620, 42)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(status_label)

func _build_joystick() -> void:
	move_base = Panel.new()
	move_base.name = "MoveStick"
	move_base.size = Vector2(150, 150)
	move_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_base.add_theme_stylebox_override(
		"panel",
		_round_style(Color(0.05, 0.08, 0.07, 0.42), Color(0.35, 0.86, 0.48), 75, 3)
	)
	root.add_child(move_base)

	move_knob = Panel.new()
	move_knob.name = "MoveKnob"
	move_knob.position = Vector2(50, 50)
	move_knob.size = Vector2(50, 50)
	move_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_knob.add_theme_stylebox_override(
		"panel",
		_round_style(Color(0.35, 0.86, 0.48, 0.32), Color(0.55, 1.0, 0.64), 25, 2)
	)
	move_base.add_child(move_knob)

func _build_action_buttons() -> void:
	spawn_button = _button("SPAWN", Vector2.ZERO, Vector2(172, 58))
	spawn_button.pressed.connect(_toggle_spawn_menu)
	_register_interactive(spawn_button)

	tool_button = _button("TOOL", Vector2.ZERO, Vector2(172, 58))
	tool_button.pressed.connect(func(): player.call("cycle_tool"))
	_register_interactive(tool_button)

	noclip_button = _button("NOCLIP", Vector2.ZERO, Vector2(172, 58))
	noclip_button.pressed.connect(func(): player.call("toggle_noclip"))
	_register_interactive(noclip_button)

	use_button = _button("USE", Vector2.ZERO, Vector2(190, 72))
	use_button.pressed.connect(func(): player.call("use_tool"))
	_register_interactive(use_button)

	jump_button = _button("JUMP", Vector2.ZERO, Vector2(106, 66))
	jump_button.button_down.connect(_jump_or_up_pressed)
	jump_button.button_up.connect(_jump_or_up_released)
	_register_interactive(jump_button)

	down_button = _button("DOWN", Vector2.ZERO, Vector2(106, 66))
	down_button.button_down.connect(func(): player.call("set_vertical_input", -1.0))
	down_button.button_up.connect(func(): player.call("set_vertical_input", 0.0))
	_register_interactive(down_button)
	down_button.visible = false

	view_button = _button("VIEW: DRIVER", Vector2.ZERO, Vector2(150, 60))
	view_button.pressed.connect(func(): player.call("toggle_vehicle_view"))
	_register_interactive(view_button)
	view_button.visible = false

func _build_spawn_menu() -> void:
	spawn_panel = Panel.new()
	spawn_panel.name = "SpawnPanel"
	spawn_panel.size = Vector2(330, 412)
	spawn_panel.add_theme_stylebox_override(
		"panel",
		_round_style(Color(0.035, 0.055, 0.05, 0.94), Color(0.35, 0.86, 0.48), 18, 2)
	)
	root.add_child(spawn_panel)
	spawn_panel.visible = false

	var header := Label.new()
	header.position = Vector2(20, 16)
	header.size = Vector2(290, 36)
	header.text = "SPAWN MENU"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		var col: int = i % 2
		var row: int = int(i / 2)
		var button := _button(
			kinds[i][0],
			Vector2(20 + col * 150, 65 + row * 78),
			Vector2(138, 62),
			spawn_panel
		)
		button.pressed.connect(_spawn_pressed.bind(kinds[i][1]))
		interactive_controls.append(button)

	var close := _button("CLOSE", Vector2(94, 355), Vector2(142, 42), spawn_panel)
	close.pressed.connect(_toggle_spawn_menu)
	interactive_controls.append(close)

func _register_interactive(control: Control) -> void:
	interactive_controls.append(control)

func _layout_for_viewport() -> void:
	if root == null:
		return
	var size := root.size
	if size.x <= 1.0 or size.y <= 1.0:
		size = get_viewport().get_visible_rect().size

	move_base.position = Vector2(48.0, maxf(110.0, size.y - 200.0))
	move_center = move_base.position + move_base.size * 0.5

	var right_x: float = maxf(880.0, size.x - 200.0)
	spawn_button.position = Vector2(right_x, 22.0)
	tool_button.position = Vector2(right_x, 88.0)
	noclip_button.position = Vector2(right_x, 154.0)

	use_button.position = Vector2(maxf(790.0, size.x - 230.0), maxf(500.0, size.y - 102.0))
	jump_button.position = Vector2(maxf(680.0, size.x - 350.0), maxf(420.0, size.y - 178.0))
	down_button.position = Vector2(maxf(680.0, size.x - 350.0), maxf(500.0, size.y - 102.0))
	view_button.position = Vector2(maxf(680.0, size.x - 350.0), maxf(420.0, size.y - 178.0))

	status_label.position = Vector2(size.x * 0.5 - 310.0, maxf(560.0, size.y - 56.0))

	spawn_panel.position = Vector2(maxf(500.0, size.x - 565.0), 112.0)

func _process(delta: float) -> void:
	if toast_time <= 0.0:
		return
	toast_time = maxf(0.0, toast_time - delta)
	if toast_time <= 0.0 and status_label != null:
		status_label.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if move_touch_id == -1 and _point_in_move_zone(event.position):
				move_touch_id = event.index
				_update_move(event.position)
			elif (
				look_touch_id == -1
				and _point_in_look_zone(event.position)
				and not _touch_in_ui(event.position)
			):
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

func _point_in_move_zone(position: Vector2) -> bool:
	return position.distance_to(move_center) <= 115.0

func _point_in_look_zone(position: Vector2) -> bool:
	var size := root.size
	if size.x <= 1.0:
		size = get_viewport().get_visible_rect().size
	return position.x >= size.x * 0.5

func _touch_in_ui(position: Vector2) -> bool:
	if spawn_panel.visible and spawn_panel.get_global_rect().has_point(position):
		return true
	for control in interactive_controls:
		if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		if control.get_global_rect().has_point(position):
			return true
	return false

func _update_move(position: Vector2) -> void:
	var delta := position - move_center
	var radius := 62.0
	if delta.length() > radius:
		delta = delta.normalized() * radius
	move_knob.position = Vector2(50, 50) + delta
	player.call("set_touch_move", delta / radius)

func _jump_or_up_pressed() -> void:
	if noclip_active:
		player.call("set_vertical_input", 1.0)
	else:
		player.call("request_jump")

func _jump_or_up_released() -> void:
	if noclip_active:
		player.call("set_vertical_input", 0.0)

func _toggle_spawn_menu() -> void:
	spawn_panel.visible = not spawn_panel.visible
	flash("Spawn menu open" if spawn_panel.visible else "Spawn menu closed")

func _spawn_pressed(kind: String) -> void:
	game.call("spawn_from_menu", kind)
	flash("Spawned " + kind.to_upper())

func set_tool_mode(mode: String) -> void:
	if tool_button != null:
		tool_button.text = "TOOL: " + mode

func set_inventory_status(summary: String) -> void:
	if inventory_label != null:
		inventory_label.text = summary

func set_noclip(enabled: bool) -> void:
	noclip_active = enabled
	if noclip_button != null:
		noclip_button.text = "NOCLIP: ON" if enabled else "NOCLIP"
	if jump_button != null:
		jump_button.text = "UP" if enabled else "JUMP"
	if down_button != null:
		down_button.visible = enabled and not vehicle_active

func set_vehicle_mode(enabled: bool, camera_name := "DRIVER") -> void:
	vehicle_active = enabled
	spawn_button.visible = not enabled
	tool_button.visible = not enabled
	noclip_button.visible = not enabled
	jump_button.visible = not enabled
	down_button.visible = noclip_active and not enabled
	view_button.visible = enabled
	use_button.text = "EXIT" if enabled else "USE"
	if enabled:
		set_vehicle_camera(camera_name)

func set_vehicle_camera(camera_name: String) -> void:
	if view_button != null:
		view_button.text = "VIEW: " + camera_name

func flash(message: String, seconds := 1.6) -> void:
	if status_label != null:
		status_label.text = message
		status_label.visible = true
		toast_time = maxf(0.25, seconds)

func _button(
	text_value: String,
	at: Vector2,
	button_size: Vector2,
	parent: Control = root
) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.92, 0.95, 0.93))
	button.add_theme_stylebox_override(
		"normal",
		_round_style(Color(0.04, 0.07, 0.065, 0.88), Color(0.25, 0.50, 0.32), 13, 2)
	)
	button.add_theme_stylebox_override(
		"hover",
		_round_style(Color(0.08, 0.16, 0.11, 0.94), Color(0.40, 0.92, 0.55), 13, 2)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_round_style(Color(0.18, 0.42, 0.25, 0.98), Color(0.58, 1.0, 0.68), 13, 3)
	)
	parent.add_child(button)
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
