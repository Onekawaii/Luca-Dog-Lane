extends Panel
# Only objects physically on hand. Catalog, crafting and loadout are separate menus.
var game: Node
var stock_list: VBoxContainer
var summary_label: Label

func _ready() -> void:
    name="InventoryPanel"
    size=Vector2(540,468)
    mouse_filter=Control.MOUSE_FILTER_STOP
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(0.035,0.032,0.048,0.975)
    style.border_color=Color(0.62,0.35,0.72)
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    add_theme_stylebox_override("panel",style)
    _label("FIELD SATCHEL  //  WHAT YOU HAVE",Vector2(20,12),21)
    summary_label=_label("",Vector2(20,51),13)
    var scroll:=ScrollContainer.new()
    scroll.position=Vector2(18,93)
    scroll.size=Vector2(504,302)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    stock_list=VBoxContainer.new()
    stock_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    stock_list.add_theme_constant_override("separation",6)
    scroll.add_child(stock_list)
    _label("ZERO STOCK IS NOT INVENTORY. BUILD / CATALOG IS SEPARATE.",Vector2(20,400),10)
    var close:=Button.new()
    close.text="RETURN"
    close.position=Vector2(408,424)
    close.size=Vector2(112,34)
    close.pressed.connect(func(): visible=false)
    add_child(close)
    refresh()

func _label(content: String,at: Vector2,font_size: int)->Label:
    var label:=Label.new()
    label.position=at
    label.size=Vector2(505,35)
    label.text=content
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",Color(0.95,0.84,0.94))
    add_child(label)
    return label

func refresh() -> void:
    if game==null or stock_list==null:
        return
    for child in stock_list.get_children():
        stock_list.remove_child(child)
        child.queue_free()
    var bag:Dictionary=game.call("get_inventory_snapshot_for_ui")
    var catalog:Dictionary=game.call("get_item_catalog_for_ui")
    var ids:=bag.keys()
    ids.sort()
    var nonempty:=0
    var total:=0
    for value in ids:
        var amount:=int(bag[value])
        if amount<=0: continue
        nonempty+=1
        total+=amount
        var item_id:=str(value)
        var spec:Dictionary=catalog.get(item_id,{})
        var name_text:=str(spec.get("label",item_id.replace("_"," "))).to_upper()
        var line:=HBoxContainer.new()
        var label:=Label.new()
        label.text=name_text
        label.custom_minimum_size=Vector2(346,35)
        label.tooltip_text=str(spec.get("description",""))
        line.add_child(label)
        var quantity:=Label.new()
        quantity.text="× %d" % amount
        quantity.add_theme_font_size_override("font_size",16)
        quantity.add_theme_color_override("font_color",Color(1,0.82,0.50))
        line.add_child(quantity)
        stock_list.add_child(line)
    if nonempty==0:
        var empty:=Label.new()
        empty.text="SATCHEL EMPTY. Gather materials to fill it."
        stock_list.add_child(empty)
    summary_label.text="%d TYPES ON HAND   /   %d TOTAL UNITS" % [nonempty,total]
