extends Panel
# Dedicated nine-slot loadout editor; inventory quantities never live here.
var game: Node
var selected_slot:=0
var summary: Label
var choices: VBoxContainer
var slot_buttons: Array[Button]=[]

func _ready()->void:
    name="LoadoutPanel"
    size=Vector2(540,490)
    mouse_filter=Control.MOUSE_FILTER_STOP
    var shell:=StyleBoxFlat.new()
    shell.bg_color=Color(0.035,0.032,0.048,0.975)
    shell.border_color=Color(0.62,0.35,0.72)
    shell.set_border_width_all(2)
    shell.set_corner_radius_all(14)
    add_theme_stylebox_override("panel",shell)
    var title:=Label.new()
    title.position=Vector2(19,12)
    title.size=Vector2(500,35)
    title.text="LOADOUT  //  ASSIGN HOTKEYS 1–9"
    title.add_theme_font_size_override("font_size",20)
    add_child(title)
    summary=Label.new()
    summary.position=Vector2(19,48)
    summary.size=Vector2(500,24)
    summary.add_theme_font_size_override("font_size",11)
    add_child(summary)
    for i in range(9):
        var button:=Button.new()
        button.position=Vector2(18+(i%3)*169,84+int(i/3)*40)
        button.size=Vector2(162,35)
        button.pressed.connect(_select_slot.bind(i))
        add_child(button)
        slot_buttons.append(button)
    var list_label:=Label.new()
    list_label.text="ASSIGN TO SELECTED SLOT  //  TOOL OR DISCOVERED MATERIAL"
    list_label.position=Vector2(18,214)
    list_label.size=Vector2(504,22)
    list_label.add_theme_font_size_override("font_size",10)
    add_child(list_label)
    var scroll:=ScrollContainer.new()
    scroll.position=Vector2(18,242)
    scroll.size=Vector2(504,188)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    choices=VBoxContainer.new()
    choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    scroll.add_child(choices)
    var close:=Button.new()
    close.text="RETURN"
    close.position=Vector2(407,446)
    close.size=Vector2(115,33)
    close.pressed.connect(func():visible=false)
    add_child(close)
    refresh()

func _select_slot(index:int)->void:
    selected_slot=index
    refresh()

func refresh()->void:
    if game==null or choices==null:return
    var assigned:Array[Dictionary]=game.call("get_hotbar_slots")
    if assigned.size()!=9:return
    var items:Dictionary=game.call("get_item_catalog_for_ui")
    var tools:Dictionary=game.call("get_tool_catalog_for_ui")
    var known:Array[String]=game.call("get_discovered_items")
    for i in range(9):
        var row:Dictionary=assigned[i]
        var id:=str(row.get("id",""))
        var info:Dictionary=items.get(id,{}) if str(row.get("type",""))=="item" else tools.get(id,{})
        slot_buttons[i].text="%d: %s" % [i+1,str(info.get("label",id.replace("_"," "))).to_upper()]
        slot_buttons[i].disabled=false
        slot_buttons[i].modulate=Color(1.0,0.72,0.86) if i==selected_slot else Color.WHITE
    summary.text="SELECT SLOT %d, THEN CHOOSE AN ASSIGNMENT BELOW. SAVED PER WORLD." % (selected_slot+1)
    for child in choices.get_children():
        choices.remove_child(child)
        child.queue_free()
    var tool_ids:=tools.keys()
    tool_ids.sort()
    for id in tool_ids:
        _choice("TOOL / "+str(tools[id].get("label",id)).to_upper(),"tool",str(id))
    for id in known:
        if not items.has(id):continue
        var kind:=str(items[id].get("kind",""))
        if kind!="building" and id!="stone":continue
        _choice("MATERIAL / "+str(items[id].get("label",id)).to_upper(),"item",id)

func _choice(text_value:String,kind:String,id:String)->void:
    var button:=Button.new()
    button.custom_minimum_size.y=35
    button.text=text_value
    button.pressed.connect(_assign.bind(kind,id))
    choices.add_child(button)

func _assign(kind:String,id:String)->void:
    if bool(game.call("assign_hotbar_slot",selected_slot,kind,id)):
        refresh()
    else:
        var hud=get_parent().get_parent()
        if hud!=null and hud.has_method("flash"):
            hud.call("flash","Cannot assign undiscovered or invalid item",1.6)
