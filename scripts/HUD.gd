extends CanvasLayer

var game: Node
var player: CharacterBody3D

var root: Control
var header_panel: Panel
var move_base: Panel
var move_knob: Panel
var spawn_panel: Panel
var map_panel: Panel
var map_chart: Control
var encounter_panel: Panel
var spawn_button: Button
var map_button: Button
var tool_button: Button
var inventory_button: Button
var inventory_panel: Panel
var quickbar: Control
var tool_icon: TextureRect
var equipped_label: Label
var controls_label: Label
var noclip_button: Button
var use_button: Button
var jump_button: Button
var down_button: Button
var view_button: Button
var menu_button: Button
var status_label: Label
var inventory_label: Label
var spiral_label: Label
var guidance_label: Label
var vitals_label: Label
var crosshair: Label
var encounter_title: Label
var encounter_hint: Label
var encounter_buttons: Array[Button] = []

var toast_time := 0.0
var vehicle_active := false
var mobile_ui := false
var developer_ui := false
var encounter_target: Object
var encounter_actions: Array[String] = []

var move_touch_id := -1
var look_touch_id := -1
var move_center := Vector2.ZERO
var noclip_active := false
var interactive_controls: Array[Control] = []
var reset_armed := false
var reset_button: Button
var player_health := 100.0
var player_max_health := 100.0
var threat_count := 0
var boss_active := false
var boss_health_ratio := 1.0

func _ready() -> void:
	layer = 20
	mobile_ui = _is_mobile_platform()
	developer_ui = OS.get_environment("SPIRAL_DEV_UI") == "1"

	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_header()
	tool_icon = TextureRect.new()
	tool_icon.name = "EquippedToolIcon"
	tool_icon.position = Vector2(16, 122)
	tool_icon.size = Vector2(34, 34)
	tool_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tool_icon)
	equipped_label = Label.new()
	equipped_label.position = Vector2(58, 129)
	equipped_label.add_theme_font_size_override("font_size", 13)
	equipped_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(equipped_label)
	controls_label = Label.new()
	controls_label.position = Vector2(20, 168)
	controls_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_label.add_theme_font_size_override("font_size", 11)
	controls_label.add_theme_constant_override("outline_size", 4)
	controls_label.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(controls_label)
	_build_crosshair()
	_build_joystick()
	_build_action_buttons()
	_build_spawn_menu()
	_build_map_menu()
	_build_inventory_menu()
	_build_quickbar()
	_build_encounter_panel()
	for panel in [spawn_panel, map_panel, inventory_panel, encounter_panel]:
		panel.visibility_changed.connect(sync_modal_input)

	root.resized.connect(_layout_for_viewport)
	call_deferred("_layout_for_viewport")
	call_deferred("_apply_mode_visibility")
	if player != null:
		player.call("_sync_tool_label")
	set_noclip(false)
	flash(
		"LMB uses tools // E interacts // Esc pauses" if not mobile_ui
		else "Find the two Spirals // drag RIGHT side to look",
		2.8
	)

func set_tool_icon(texture: Texture2D) -> void:
	if tool_icon != null:
		tool_icon.texture = texture

func _is_mobile_platform() -> bool:
	# Android and iOS are authoritative export tags. Keep the broader mobile
	# tag as a compatibility fallback for editor/device configurations that add it.
	return (
		OS.has_feature("android")
		or OS.has_feature("ios")
		or OS.has_feature("mobile")
	)

func _build_header() -> void:
	header_panel = Panel.new()
	header_panel.name = "HeaderBackdrop"
	header_panel.position = Vector2(18, 16)
	header_panel.size = Vector2(470, 110)
	header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_panel.add_theme_stylebox_override(
		"panel",
		_round_style(Color(0.025, 0.025, 0.035, 0.78), Color(0.46, 0.18, 0.52, 0.75), 12, 2)
	)
	root.add_child(header_panel)

	var title := Label.new()
	title.name = "Title"
	title.position = Vector2(14, 6)
	title.size = Vector2(438, 26)
	title.text = "SPIRAL FIELD  //  v0.2.2"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.96, 0.91, 1.0))
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.07, 0.95))
	header_panel.add_child(title)

	var hint := Label.new()
	hint.name = "Hint"
	hint.position = Vector2(14, 30)
	hint.size = Vector2(438, 18)
	var map_label := str(game.call("get_active_map_label")) if game != null else "THE FIRST FIELD"
	hint.text = map_label + "  //  FIND WHAT IS WATCHING"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.84, 0.80, 0.86))
	header_panel.add_child(hint)

	spiral_label = Label.new()
	spiral_label.name = "SpiralStatus"
	spiral_label.position = Vector2(14, 49)
	spiral_label.size = Vector2(438, 18)
	spiral_label.text = "THE FIELD IS DORMANT"
	spiral_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spiral_label.add_theme_font_size_override("font_size", 12)
	spiral_label.add_theme_color_override("font_color", Color(1.0, 0.54, 0.30))
	header_panel.add_child(spiral_label)

	guidance_label = Label.new()
	guidance_label.name = "FieldGuidance"
	guidance_label.position = Vector2(14, 67)
	guidance_label.size = Vector2(438, 17)
	guidance_label.text = "WITNESSING --  //  WAILING --"
	guidance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guidance_label.add_theme_font_size_override("font_size", 10)
	guidance_label.add_theme_color_override("font_color", Color(0.74, 0.70, 0.78))
	header_panel.add_child(guidance_label)

	vitals_label = Label.new()
	vitals_label.name = "VitalsAndThreats"
	vitals_label.position = Vector2(14, 86)
	vitals_label.size = Vector2(438, 18)
	vitals_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_label.add_theme_font_size_override("font_size", 11)
	vitals_label.add_theme_color_override("font_color", Color(1.0, 0.70, 0.66))
	header_panel.add_child(vitals_label)
	_refresh_vitals()

	inventory_label = Label.new()
	inventory_label.name = "InventoryStatus"
	inventory_label.position = Vector2(20, 148)
	inventory_label.size = Vector2(520, 26)
	inventory_label.text = "STONE 0  //  BRICK 0"
	inventory_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_label.add_theme_font_size_override("font_size", 11)
	inventory_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.83))
	root.add_child(inventory_label)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.size = Vector2(600, 44)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_constant_override("outline_size", 8)
	status_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.96))
	status_label.visible = false
	root.add_child(status_label)

func _build_crosshair() -> void:
	crosshair = Label.new()
	crosshair.name = "Crosshair"
	crosshair.text = "+"
	crosshair.size = Vector2(32, 32)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color(0.95, 0.90, 1.0, 0.82))
	crosshair.add_theme_constant_override("outline_size", 3)
	crosshair.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.06, 0.9))
	root.add_child(crosshair)

func _build_joystick() -> void:
	move_base = Panel.new()
	move_base.name = "MoveStick"
	move_base.size = Vector2(150, 150)
	move_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_base.add_theme_stylebox_override(
		"panel",
		_round_style(Color(0.04, 0.03, 0.06, 0.52), Color(0.64, 0.30, 0.72), 75, 3)
	)
	root.add_child(move_base)

	move_knob = Panel.new()
	move_knob.name = "MoveKnob"
	move_knob.position = Vector2(50, 50)
	move_knob.size = Vector2(50, 50)
	move_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_knob.add_theme_stylebox_override(
		"panel",
		_round_style(Color(0.55, 0.26, 0.64, 0.42), Color(0.86, 0.60, 0.94), 25, 2)
	)
	move_base.add_child(move_knob)

func _build_action_buttons() -> void:
	spawn_button = _button("SPAWN", Vector2.ZERO, Vector2(118, 38))
	spawn_button.pressed.connect(_toggle_spawn_menu)
	_register_interactive(spawn_button)

	map_button = _button("MAP", Vector2.ZERO, Vector2(118, 38))
	map_button.pressed.connect(_toggle_map_menu)
	_register_interactive(map_button)

	tool_button = _button("TOOL", Vector2.ZERO, Vector2(118, 38))
	tool_button.pressed.connect(func(): player.call("cycle_tool"))
	_register_interactive(tool_button)

	inventory_button = _button("INVENTORY", Vector2.ZERO, Vector2(118, 38))
	inventory_button.pressed.connect(_toggle_inventory_menu)
	_register_interactive(inventory_button)

	noclip_button = _button("NOCLIP", Vector2.ZERO, Vector2(118, 38))
	noclip_button.pressed.connect(func(): player.call("toggle_noclip"))
	_register_interactive(noclip_button)

	use_button = _button("USE", Vector2.ZERO, Vector2(170, 68))
	use_button.pressed.connect(func(): player.call("use_tool"))
	_register_interactive(use_button)

	jump_button = _button("JUMP", Vector2.ZERO, Vector2(104, 62))
	jump_button.button_down.connect(_jump_or_up_pressed)
	jump_button.button_up.connect(_jump_or_up_released)
	_register_interactive(jump_button)

	down_button = _button("DOWN", Vector2.ZERO, Vector2(104, 62))
	down_button.button_down.connect(func(): player.call("set_vertical_input", -1.0))
	down_button.button_up.connect(func(): player.call("set_vertical_input", 0.0))
	_register_interactive(down_button)

	view_button = _button("VIEW: DRIVER", Vector2.ZERO, Vector2(150, 56))
	view_button.pressed.connect(func(): player.call("toggle_vehicle_view"))
	_register_interactive(view_button)
	menu_button = _button("MENU", Vector2.ZERO, Vector2(118, 38))
	menu_button.pressed.connect(func(): game.session_menu.call("open", "pause"))
	_register_interactive(menu_button)

func _build_spawn_menu() -> void:
	spawn_panel = Panel.new()
	spawn_panel.name = "SpawnPanel"
	spawn_panel.size = Vector2(330, 546)
	spawn_panel.add_theme_stylebox_override(
		"panel",
		_round_style(Color(0.03, 0.02, 0.04, 0.96), Color(0.55, 0.24, 0.63), 18, 2)
	)
	root.add_child(spawn_panel)
	spawn_panel.visible = false

	var header := Label.new()
	header.position = Vector2(20, 16)
	header.size = Vector2(290, 36)
	header.text = "DEVELOPER SPAWN"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.94, 0.82, 1.0))
	spawn_panel.add_child(header)

	var kinds := [
		["CRATE", "crate"], ["BARREL", "barrel"], ["BALL", "ball"], ["CONE", "cone"],
		["RAMP", "ramp"], ["NPC", "npc"], ["BUGGY", "buggy"]
	]
	for i in range(kinds.size()):
		var col := i % 2
		var row := int(i / 2)
		var button := _button(
			kinds[i][0],
			Vector2(20 + col * 150, 65 + row * 78),
			Vector2(138, 62),
			spawn_panel
		)
		button.pressed.connect(_spawn_pressed.bind(kinds[i][1]))
		interactive_controls.append(button)

	var clean := _button("CLEAN SPAWNED", Vector2(20, 374), Vector2(290, 38), spawn_panel)
	clean.pressed.connect(func(): flash("CLEANUP // removed %d" % int(game.call("cleanup_spawned"))))
	interactive_controls.append(clean)
	var day := _button("DAY", Vector2(20, 427), Vector2(138, 38), spawn_panel)
	day.pressed.connect(func(): game.call("set_daytime", 12))
	interactive_controls.append(day)
	var night := _button("NIGHT", Vector2(172, 427), Vector2(138, 38), spawn_panel)
	night.pressed.connect(func(): game.call("set_daytime", 0))
	interactive_controls.append(night)
	var close := _button("CLOSE", Vector2(94, 487), Vector2(142, 42), spawn_panel)
	close.pressed.connect(_toggle_spawn_menu)
	interactive_controls.append(close)

func _build_map_menu() -> void:
	map_panel = Panel.new()
	map_panel.name = "MapPanel"
	map_panel.size = Vector2(700, 470)
	map_panel.add_theme_stylebox_override(
		"panel",
		_round_style(Color(0.03, 0.02, 0.04, 0.96), Color(0.55, 0.24, 0.63), 18, 2)
	)
	root.add_child(map_panel)
	map_panel.visible = false

	var header := Label.new()
	header.position = Vector2(20, 14)
	header.size = Vector2(660, 30)
	header.text = "FIELD SURVEY  //  WORLD MAP & TRANSITIONS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color(0.94, 0.82, 1.0))
	map_panel.add_child(header)

	map_chart = Control.new()
	map_chart.set_script(load("res://scripts/systems/WorldMapChart.gd"))
	map_chart.set("game", game)
	map_chart.position = Vector2(20, 62)
	map_chart.scale = Vector2(0.78, 0.78)
	map_panel.add_child(map_chart)

	var options: Array = game.call("get_map_options") if game != null else []
	for i in range(options.size()):
		var option: Dictionary = options[i]
		var label := str(option.get("label", option.get("id", "FIELD")))
		var map_id := str(option.get("id", ""))
		var button := _button(
			label,
			Vector2(390, 52 + i * 54),
			Vector2(286, 42),
			map_panel
		)
		button.pressed.connect(_map_pressed.bind(map_id, label))
		interactive_controls.append(button)

	var restart := _button("RESTART FIELD", Vector2(390, 222), Vector2(286, 34), map_panel)
	restart.pressed.connect(func(): game.call("restart_field"))
	interactive_controls.append(restart)
	var reset := _button("NEW WORLD (BACKUP)", Vector2(390, 264), Vector2(286, 34), map_panel)
	reset.pressed.connect(_reset_pressed.bind(reset))
	reset_button = reset
	interactive_controls.append(reset)
	var companion := _button("LUCA: STAY / FOLLOW", Vector2(390, 356), Vector2(286, 34), map_panel)
	companion.pressed.connect(func(): flash(str(game.call("toggle_companion_stay")), 2.0))
	interactive_controls.append(companion)
	var close := _button("CLOSE", Vector2(462, 410), Vector2(142, 34), map_panel)
	close.pressed.connect(_toggle_map_menu)
	interactive_controls.append(close)

func _build_quickbar() -> void:
	quickbar = Control.new()
	quickbar.set_script(load("res://scripts/systems/PlayerQuickbar.gd"))
	quickbar.set("game", game)
	quickbar.set("player", player)
	root.add_child(quickbar)
	for button in quickbar.get("buttons"):
		_register_interactive(button)

func _build_inventory_menu() -> void:
	inventory_panel = Panel.new()
	inventory_panel.set_script(load("res://scripts/systems/PlayerInventoryPanel.gd"))
	inventory_panel.set("game", game)
	root.add_child(inventory_panel)
	inventory_panel.visible = false

func _toggle_inventory_menu() -> void:
	inventory_panel.visible = not inventory_panel.visible
	if inventory_panel.visible:
		spawn_panel.visible = false
		map_panel.visible = false
		inventory_panel.call("refresh")

func _build_encounter_panel() -> void:
	encounter_panel = Panel.new()
	encounter_panel.name = "EncounterPanel"
	encounter_panel.size = Vector2(620, 144)
	encounter_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	encounter_panel.add_theme_stylebox_override(
		"panel",
		_round_style(Color(0.025, 0.015, 0.035, 0.96), Color(0.82, 0.42, 0.82), 18, 2)
	)
	root.add_child(encounter_panel)
	encounter_panel.visible = false

	encounter_title = Label.new()
	encounter_title.position = Vector2(18, 10)
	encounter_title.size = Vector2(584, 28)
	encounter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encounter_title.add_theme_font_size_override("font_size", 17)
	encounter_title.add_theme_color_override("font_color", Color(1.0, 0.86, 1.0))
	encounter_panel.add_child(encounter_title)

	encounter_hint = Label.new()
	encounter_hint.position = Vector2(18, 38)
	encounter_hint.size = Vector2(584, 22)
	encounter_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encounter_hint.text = "Choose what you do. The field remembers."
	encounter_hint.add_theme_font_size_override("font_size", 11)
	encounter_hint.add_theme_color_override("font_color", Color(0.72, 0.66, 0.76))
	encounter_panel.add_child(encounter_hint)

	for i in range(4):
		var button := _button(
			"--",
			Vector2(16 + i * 150, 72),
			Vector2(140, 52),
			encounter_panel
		)
		button.pressed.connect(_encounter_button_pressed.bind(i))
		encounter_buttons.append(button)
		interactive_controls.append(button)

func _register_interactive(control: Control) -> void:
	interactive_controls.append(control)

func _layout_for_viewport() -> void:
	if root == null:
		return
	var size := root.size
	if size.x <= 1.0 or size.y <= 1.0:
		size = get_viewport().get_visible_rect().size

	move_base.position = Vector2(42.0, maxf(110.0, size.y - 196.0))
	move_center = move_base.position + move_base.size * 0.5

	var right_x := maxf(880.0, size.x - 130.0)
	if mobile_ui:
		menu_button.position = Vector2(right_x, 12.0)
		map_button.position = Vector2(right_x, 54.0)
		tool_button.position = Vector2(right_x, 96.0)
		inventory_button.position = Vector2(right_x, 138.0)
		noclip_button.position = Vector2(right_x, 180.0)
	else:
		spawn_button.position = Vector2(right_x, 12.0)
		map_button.position = Vector2(right_x, 54.0)
		tool_button.position = Vector2(right_x, 96.0)
		inventory_button.position = Vector2(right_x, 54.0 if not developer_ui else 138.0)
		noclip_button.position = Vector2(right_x, 180.0)
		menu_button.position = Vector2(right_x, 12.0 if not developer_ui else 222.0)

	use_button.position = Vector2(maxf(790.0, size.x - 198.0), maxf(500.0, size.y - 88.0))
	jump_button.position = Vector2(maxf(680.0, size.x - 318.0), maxf(420.0, size.y - 164.0))
	down_button.position = Vector2(maxf(680.0, size.x - 318.0), maxf(500.0, size.y - 88.0))
	view_button.position = Vector2(maxf(680.0, size.x - 318.0), maxf(420.0, size.y - 164.0))

	# Don't render gameplay toasts through the ten-slot hotbar.
	status_label.position = Vector2(size.x * 0.5 - 300.0, maxf(280.0, size.y - 124.0))
	crosshair.position = Vector2(size.x * 0.5 - 16.0, size.y * 0.5 - 16.0)
	encounter_panel.position = Vector2(size.x * 0.5 - 310.0, maxf(300.0, size.y - 224.0))
	spawn_panel.position = Vector2(maxf(500.0, size.x - 540.0), 100.0)
	map_panel.position = Vector2(maxf(0.0, size.x * 0.5 - 350.0), maxf(0.0, size.y * 0.5 - 235.0))
	inventory_panel.position = Vector2(maxf(0.0, size.x * 0.5 - 270.0), maxf(8.0, size.y * 0.5 - 210.0))
	if quickbar != null:
		quickbar.call("layout_for_viewport", size)

func _apply_mode_visibility() -> void:
	if move_base == null:
		return
	# The UI mode can change at runtime in QA and on platform handoff; keep the
	# compact right rail spatially exclusive before exposing its controls.
	_layout_for_viewport()
	move_base.visible = mobile_ui
	use_button.visible = mobile_ui or vehicle_active
	jump_button.visible = mobile_ui and not vehicle_active
	down_button.visible = mobile_ui and noclip_active and not vehicle_active
	view_button.visible = vehicle_active
	map_button.visible = mobile_ui or developer_ui
	tool_button.visible = mobile_ui or developer_ui
	spawn_button.visible = developer_ui and not vehicle_active
	menu_button.visible = true
	noclip_button.visible = (mobile_ui or developer_ui) and not vehicle_active
	inventory_button.visible = true
	inventory_label.visible = developer_ui
	crosshair.visible = not mobile_ui
	if quickbar != null:
		quickbar.visible = not vehicle_active
	tool_icon.visible = not vehicle_active
	equipped_label.visible = not vehicle_active
	_update_controls_label()
	if not developer_ui:
		spawn_panel.visible = false

func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time = maxf(0.0, toast_time - delta)
		if toast_time <= 0.0 and status_label != null:
			status_label.visible = false

func has_modal() -> bool:
	return spawn_panel.visible or map_panel.visible or inventory_panel.visible or encounter_panel.visible

func _update_controls_label() -> void:
	if controls_label == null:
		return
	controls_label.text = "NOCLIP ON // V WALK" if noclip_active else "LMB USE / HOLD TERRAIN // RMB BRUSH // I PACK // ESC"
	if vehicle_active:
		controls_label.text = "CAR " + str(player.riding.call("get_camera_mode_name")) + " // R / F5 VIEW // E EXIT // ESC MENU"
	controls_label.visible = not mobile_ui

func close_modals(sync := true) -> void:
	spawn_panel.hide()
	map_panel.hide()
	inventory_panel.hide()
	close_encounter()
	if sync:
		sync_modal_input()

func sync_modal_input() -> void:
	var menu = game.get("session_menu") if game != null else null
	var blocked: bool = has_modal() or (menu != null and menu.call("is_open"))
	if player != null:
		player.call("set_gameplay_blocked", blocked)
	if quickbar != null:
		for button in quickbar.buttons:
			button.disabled = blocked
	move_touch_id = -1
	look_touch_id = -1
	if not mobile_ui:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if blocked else Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			developer_ui = not developer_ui
			_apply_mode_visibility()
			flash("DEVELOPER UI ON" if developer_ui else "DEVELOPER UI OFF", 1.2)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_I or event.keycode == KEY_B:
			_toggle_inventory_menu()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_M:
			_toggle_map_menu()
			get_viewport().set_input_as_handled()
			return
		if encounter_panel.visible and event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_encounter_button_pressed(int(event.keycode - KEY_1))
			get_viewport().set_input_as_handled()
			return
		if encounter_panel.visible and event.keycode == KEY_ESCAPE:
			close_encounter()
			get_viewport().set_input_as_handled()
			return

	if has_modal():
		if event is InputEventMouseMotion or event is InputEventKey:
			get_viewport().set_input_as_handled()
		return

	if not mobile_ui:
		return

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
	if inventory_panel.visible and inventory_panel.get_global_rect().has_point(position):
		return true
	if map_panel.visible and map_panel.get_global_rect().has_point(position):
		return true
	if encounter_panel.visible and encounter_panel.get_global_rect().has_point(position):
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
	if not developer_ui:
		flash("Developer tools are hidden. F3 toggles them.", 1.5)
		return
	spawn_panel.visible = not spawn_panel.visible
	if spawn_panel.visible:
		map_panel.visible = false
		inventory_panel.visible = false

func _toggle_map_menu() -> void:
	reset_armed = false
	if reset_button != null:
		reset_button.text = "NEW WORLD (BACKUP)"
	map_panel.visible = not map_panel.visible
	if map_panel.visible:
		spawn_panel.visible = false
		inventory_panel.visible = false
		if map_chart != null:
			map_chart.queue_redraw()

func _reset_pressed(button: Button) -> void:
	if not reset_armed:
		reset_armed = true
		button.text = "CONFIRM // RESET & BACKUP"
		flash("Tap again to reset this world. Existing save will be backed up.", 4.0)
		return
	reset_armed = false
	button.text = "NEW WORLD (BACKUP)"
	flash(str(game.call("reset_field", false)), 3.0)

func _map_pressed(map_id: String, label: String) -> void:
	flash("Crossing into " + label + "...", 2.0)
	if not bool(game.call("request_map", map_id)):
		flash("The field refuses that transition.", 2.0)

func _spawn_pressed(kind: String) -> void:
	if not developer_ui:
		return
	game.call("spawn_from_menu", kind)
	flash("DEV SPAWN // " + kind.to_upper())

func open_encounter(target: Object, title_text: String, options: Array) -> void:
	encounter_target = target
	encounter_actions.clear()
	encounter_title.text = title_text
	for i in range(encounter_buttons.size()):
		var button := encounter_buttons[i]
		if i < options.size():
			var entry: Dictionary = options[i]
			var label := str(entry.get("label", "ACT"))
			var action := str(entry.get("action", label.to_lower()))
			button.text = "%d  %s" % [i + 1, label]
			button.visible = true
			encounter_actions.append(action)
		else:
			button.visible = false
	encounter_panel.visible = true
	status_label.visible = false

func close_encounter() -> void:
	encounter_panel.visible = false
	encounter_target = null
	encounter_actions.clear()

func _encounter_button_pressed(index: int) -> void:
	if index < 0 or index >= encounter_actions.size() or encounter_target == null:
		return
	var action := encounter_actions[index]
	var target := encounter_target
	close_encounter()
	player.call("spiral_choice", target, action)

func set_tool_mode(mode: String) -> void:
	if equipped_label != null:
		equipped_label.text = mode
	if tool_button != null:
		tool_button.text = "TOOL: " + mode

func set_inventory_status(summary: String) -> void:
	if inventory_label != null:
		inventory_label.text = "MATERIALS // " + summary
	if inventory_panel != null and inventory_panel.visible:
		inventory_panel.call("refresh")
	if quickbar != null:
		quickbar.call("refresh", true)

func set_spiral_status(summary: String) -> void:
	if spiral_label != null:
		spiral_label.text = summary

func set_field_guidance(summary: String) -> void:
	if guidance_label != null:
		guidance_label.text = summary

func set_player_health(current: float, maximum: float) -> void:
	player_health = current
	player_max_health = maximum
	_refresh_vitals()

func set_threat_status(alive: int, boss_is_active: bool, boss_ratio := 1.0) -> void:
	threat_count = alive
	boss_active = boss_is_active
	boss_health_ratio = boss_ratio
	_refresh_vitals()

func _refresh_vitals() -> void:
	if vitals_label == null:
		return
	var boss_text := "COIL %.0f%%" % (boss_health_ratio * 100.0) if boss_active else "COIL DORMANT"
	vitals_label.text = "VITAL %.0f/%.0f  //  THREATS %d  //  %s" % [player_health, player_max_health, threat_count, boss_text]

func set_noclip(enabled: bool) -> void:
	noclip_active = enabled
	if noclip_button != null:
		noclip_button.text = "NOCLIP: ON" if enabled else "NOCLIP"
	if jump_button != null:
		jump_button.text = "UP" if enabled else "JUMP"
	_apply_mode_visibility()

func developer_mode_enabled() -> bool:
	return developer_ui

func set_vehicle_mode(enabled: bool, camera_name := "DRIVER") -> void:
	vehicle_active = enabled
	if use_button != null:
		use_button.text = "EXIT" if enabled else "USE"
	_apply_mode_visibility()
	if enabled:
		set_vehicle_camera(camera_name)

func set_vehicle_camera(camera_name: String) -> void:
	if view_button != null:
		view_button.text = "VIEW: " + camera_name
	_update_controls_label()

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
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.94, 0.91, 0.96))
	button.add_theme_stylebox_override(
		"normal",
		_round_style(Color(0.035, 0.025, 0.045, 0.90), Color(0.40, 0.18, 0.48), 12, 2)
	)
	button.add_theme_stylebox_override(
		"hover",
		_round_style(Color(0.10, 0.045, 0.13, 0.96), Color(0.72, 0.38, 0.80), 12, 2)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_round_style(Color(0.26, 0.10, 0.30, 0.98), Color(0.94, 0.62, 1.0), 12, 3)
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
