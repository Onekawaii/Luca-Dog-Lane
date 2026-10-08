extends Control
# Ten always-visible equipment slots. Rendering/UI only: authoritative actions
# belong to Player, authoritative counts live in TerrainSlice/SandboxInventory.

const SLOT_LABELS := [
	"GRAB", "LOOK", "MINE", "STONE", "GRASS",
	"BRICK", "HAMMER", "LANTERN", "CRAFT", "REMOVE"
]
const MATERIAL_IDS := {3:"stone", 4:"grass_block", 5:"stone_brick"}

var game: Node
var player: CharacterBody3D
var buttons: Array[Button] = []
var last_snapshot := ""
var refresh_clock := 0.0

func _ready() -> void:
	name = "PlayerQuickbar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3
	for i in range(10):
		var slot := Button.new()
		slot.name = "Slot%d" % (i + 1)
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.clip_text = true
		slot.add_theme_font_size_override("font_size", 12)
		slot.pressed.connect(_slot_pressed.bind(i))
		add_child(slot)
		buttons.append(slot)
	refresh(true)

func _slot_pressed(index: int) -> void:
	if player != null:
		player.call("select_hotbar_slot", index)

func layout_for_viewport(viewport_size: Vector2) -> void:
	# Leave independent touch zones clear: move stick <230, USE starts at W-198.
	var safe_width := maxf(460.0, viewport_size.x - 488.0)
	var width_per := clampf(floorf((safe_width - 9.0 * 4.0) / 10.0), 38.0, 66.0)
	var total := width_per * 10.0 + 4.0 * 9.0
	var left := (viewport_size.x - total) * 0.5
	position = Vector2(left, viewport_size.y - 62.0)
	size = Vector2(total, 50)
	for i in range(buttons.size()):
		buttons[i].position = Vector2(i * (width_per + 4.0), 0)
		buttons[i].size = Vector2(width_per, 48)
		buttons[i].add_theme_font_size_override("font_size", 9 if width_per < 58 else 10)

func _process(delta: float) -> void:
	refresh_clock -= delta
	if refresh_clock <= 0.0:
		refresh_clock = 0.2
		refresh()

func refresh(force := false) -> void:
	if game == null or player == null or buttons.is_empty():
		return
	var counts: Dictionary = game.call("get_inventory_snapshot_for_ui")
	var selected := int(player.get("hotbar_index"))
	var light_on := bool(player.get("lantern_enabled"))
	var signature := str(counts) + "|" + str(selected) + "|" + str(light_on)
	if not force and signature == last_snapshot:
		return
	last_snapshot = signature
	for i in range(10):
		var slot := buttons[i]
		var amount := ""
		if MATERIAL_IDS.has(i):
			amount = "\nx%d" % int(counts.get(MATERIAL_IDS[i], 0))
		elif i == 7:
			amount = "\nON" if light_on else "\nOFF"
		elif i == 8:
			amount = "\nRECIPES"
		var number := "0" if i == 9 else str(i + 1)
		slot.text = "%s  %s%s" % [number, SLOT_LABELS[i], amount]
		slot.tooltip_text = SLOT_LABELS[i] + " — keyboard " + number
		var active := i == selected
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.20, 0.11, 0.24, 0.94) if active else Color(0.025, 0.028, 0.036, 0.90)
		style.border_color = Color(1.0, 0.75, 0.36) if active else Color(0.47, 0.24, 0.55, 0.88)
		style.set_border_width_all(3 if active else 1)
		style.set_corner_radius_all(8)
		slot.add_theme_stylebox_override("normal", style)
		slot.add_theme_stylebox_override("hover", style)
		slot.add_theme_stylebox_override("pressed", style)
		slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		slot.add_theme_color_override("font_color", Color(1, 0.90, 0.72) if active else Color(0.91, 0.88, 0.94))
