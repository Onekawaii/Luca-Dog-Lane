extends PanelContainer

var game: Node3D
var hud: CanvasLayer
var heading: Label
var body: RichTextLabel
var history_button: Button
var work_button: Button
var resident_id := ""
var speaker := ""
var resident: Node3D

func _ready() -> void:
	name = "RoadJournalPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.052, 0.049, 0.97)
	style.border_color = Color(0.49, 0.43, 0.31)
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	heading = Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 20)
	column.add_child(heading)
	body = RichTextLabel.new()
	body.bbcode_enabled = false
	body.scroll_active = true
	body.custom_minimum_size = Vector2(0, 230)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 17)
	column.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	history_button = _button("Local history", buttons)
	history_button.pressed.connect(_choose.bind("history"))
	work_button = _button("The missing records", buttons)
	work_button.pressed.connect(_choose.bind("work"))
	var close := _button("Leave", buttons)
	close.pressed.connect(_close)
	visibility_changed.connect(func():
		if not visible:
			_release_resident())
	get_viewport().size_changed.connect(_fit)
	_fit()
	hide()

func _button(text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button

func _fit() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var wanted := Vector2(minf(660, viewport_size.x - 32), minf(430, viewport_size.y - 32))
	body.custom_minimum_size.y = maxf(80, wanted.y - 132)
	size = wanted
	position = (viewport_size - wanted) * 0.5

func show_text(title: String, text: String, id := "", npc: Node3D = null) -> void:
	_release_resident()
	speaker = title
	resident_id = id
	resident = npc
	if is_instance_valid(resident):
		resident.set("is_talking", true)
	heading.text = title
	body.text = text
	body.scroll_to_line(0)
	history_button.visible = is_instance_valid(npc)
	work_button.visible = is_instance_valid(npc)
	show()
	_fit()
	hud.call("sync_modal_input")

func _choose(topic: String) -> void:
	if not is_instance_valid(resident) or not resident.call("is_alive_for_test"):
		_close()
		return
	var lines: Array = game.story_director.converse(resident_id, topic)
	body.text = "\n\n".join(lines)
	body.scroll_to_line(0)

func _release_resident() -> void:
	if is_instance_valid(resident):
		resident.set("is_talking", false)
	resident = null

func _close() -> void:
	hide()
	hud.call("sync_modal_input")
