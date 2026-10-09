extends Control
# Nine independently assigned actions/items. Counts come from the actual satchel.
var game: Node
var player: CharacterBody3D
var buttons: Array[Button] = []
var last_snapshot := ""
var refresh_clock := 0.0

func _ready() -> void:
    name = "PlayerQuickbar"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 3
    for i in range(9):
        var button := Button.new()
        button.name = "Slot%d" % (i+1)
        button.focus_mode = Control.FOCUS_NONE
        button.mouse_filter = Control.MOUSE_FILTER_STOP
        button.clip_text = true
        button.pressed.connect(_press.bind(i))
        add_child(button)
        buttons.append(button)
    refresh(true)

func _press(index: int) -> void:
    if player != null:
        player.call("select_hotbar_slot",index)

func layout_for_viewport(view_size: Vector2) -> void:
    var safe_width := maxf(400.0,view_size.x-488.0)
    var unit := clampf(floorf((safe_width-32.0)/9.0),38.0,70.0)
    var total := unit*9.0+32.0
    position = Vector2((view_size.x-total)*0.5,view_size.y-62.0)
    size = Vector2(total,50)
    for i in range(buttons.size()):
        buttons[i].position = Vector2(i*(unit+4.0),0)
        buttons[i].size = Vector2(unit,48)
        buttons[i].add_theme_font_size_override("font_size",9 if unit<58 else 10)

func _process(delta: float) -> void:
    refresh_clock -= delta
    if refresh_clock<=0.0:
        refresh_clock = 0.25
        refresh()

func refresh(force := false) -> void:
    if game == null or player == null or buttons.is_empty():
        return
    var items: Dictionary = game.call("get_item_catalog_for_ui")
    var tools: Dictionary = game.call("get_tool_catalog_for_ui")
    var counts: Dictionary = game.call("get_inventory_snapshot_for_ui")
    var slots: Array[Dictionary] = game.call("get_hotbar_slots")
    if slots.size()!=9:
        return
    var selected := int(player.get("hotbar_index"))
    var lights := bool(player.get("lantern_enabled"))
    var signature := str(slots)+str(counts)+str(selected)+str(lights)
    if not force and signature == last_snapshot:
        return
    last_snapshot = signature
    for i in range(9):
        var entry: Dictionary = slots[i]
        var kind := str(entry.get("type","tool"))
        var key := str(entry.get("id",""))
        var info: Dictionary = items.get(key,{}) if kind=="item" else tools.get(key,{})
        var label := str(info.get("label",key.replace("_"," "))).to_upper()
        var line := ""
        if kind=="item":
            line = "\nx%d" % int(counts.get(key,0))
        elif key=="lantern":
            line = "\nON" if lights else "\nOFF"
        buttons[i].text = "%d  %s%s" % [i+1,label,line]
        buttons[i].tooltip_text = "Slot %d: %s" % [i+1,label]
        var active := i==selected
        var box := StyleBoxFlat.new()
        box.bg_color = Color(0.20,0.11,0.24,0.94) if active else Color(0.025,0.028,0.036,0.90)
        box.border_color = Color(1.0,0.75,0.36) if active else Color(0.47,0.24,0.55,0.88)
        box.set_border_width_all(3 if active else 1)
        box.set_corner_radius_all(8)
        for state in ["normal","hover","pressed"]:
            buttons[i].add_theme_stylebox_override(state,box)
        buttons[i].add_theme_stylebox_override("focus",StyleBoxEmpty.new())
