extends Panel
# All registered building choices / recipes / discovered items, NOT bag contents.
var game: Node
var results: VBoxContainer
var status: Label

func _ready()->void:
    name="BuildCatalogPanel"
    size=Vector2(540,490)
    mouse_filter=Control.MOUSE_FILTER_STOP
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(0.035,0.032,0.048,0.975)
    style.border_color=Color(0.62,0.35,0.72)
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    add_theme_stylebox_override("panel",style)
    _label("BUILD LIBRARY  /  DISCOVERY",Vector2(18,12),21)
    status=_label("",Vector2(18,44),11)
    var scroll:=ScrollContainer.new()
    scroll.position=Vector2(18,80)
    scroll.size=Vector2(504,300)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    results=VBoxContainer.new()
    results.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    results.add_theme_constant_override("separation",7)
    scroll.add_child(results)
    var actions=["CREATIVE / SURVIVAL","NEXT BLOCK","PLACE BARREL"]
    var methods=["toggle_build_mode","cycle_build_material","place_explosive_barrel"]
    for i in range(3):
        var action:=Button.new()
        action.text=actions[i]
        action.position=Vector2(18+168*i,394)
        action.size=Vector2(162,39)
        action.pressed.connect(_action.bind(methods[i]))
        add_child(action)
    _label("Materials may be selected even when out of stock; survival still consumes inventory.",Vector2(18,440),10)
    var close:=Button.new()
    close.text="RETURN"
    close.position=Vector2(405,451)
    close.size=Vector2(116,30)
    close.pressed.connect(func():visible=false)
    add_child(close)
    refresh()

func _label(message:String, at:Vector2, font_size:int)->Label:
    var label:=Label.new()
    label.text=message
    label.position=at
    label.size=Vector2(503,30)
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",Color(0.94,0.83,0.95))
    add_child(label)
    return label

func _text_row(message:String)->void:
    var label:=Label.new()
    label.text=message
    label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    results.add_child(label)

func refresh()->void:
    if game==null or results==null:return
    for c in results.get_children():
        results.remove_child(c)
        c.queue_free()
    var inventory:Dictionary=game.call("get_inventory_snapshot_for_ui")
    var items:Dictionary=game.call("get_item_catalog_for_ui")
    var recipes:Dictionary=game.call("get_recipe_catalog_for_ui")
    var known:Array[String]=game.call("get_discovered_items")
    var terrain=game.get("terrain_slice")
    var creative:=terrain!=null and bool(terrain.get("creative_build"))
    status.text="MODE: %s   /   EQUIPPED: %s   /   DISCOVERED: %d" % [
        "CREATIVE" if creative else "SURVIVAL",
        str(game.call("get_selected_build_material")).replace("_"," ").to_upper(),known.size()
    ]
    _text_row("BUILD MATERIALS // CHOOSE WHAT TO PLACE")
    var ids:=items.keys()
    ids.sort()
    for item in ids:
        var item_id:=str(item)
        var spec:Dictionary=items[item_id]
        if str(spec.get("kind",""))!="building" and item_id!="stone":continue
        var button:=Button.new()
        button.custom_minimum_size.y=34
        var owned:=int(inventory.get(item_id,0))
        var found:=known.has(item_id)
        button.text="%s  //  ON HAND %d  //  %s" % [
            str(spec.get("label",item_id)).to_upper(),owned,"FOUND" if found else "BLUEPRINT"
        ]
        button.pressed.connect(_select.bind(item_id))
        results.add_child(button)
    _text_row("RECIPES // CRAFT USING SATCHEL STOCK")
    var recipe_ids:=recipes.keys()
    recipe_ids.sort()
    for key in recipe_ids:
        var recipe_id:=str(key)
        var recipe:Dictionary=recipes[recipe_id]
        var ingredients:Dictionary=recipe.get("ingredients",{})
        var requirements:Array[String]=[]
        var allowed:=true
        for ingredient in ingredients:
            var have:=int(inventory.get(ingredient,0))
            var need:=int(ingredients[ingredient])
            if have<need:allowed=false
            requirements.append("%s %d/%d"%[str(ingredient).replace("_"," "),have,need])
        var craft:=Button.new()
        craft.custom_minimum_size.y=36
        craft.text="MAKE %s // %s" % [str(recipe.get("label",recipe_id)).to_upper()," | ".join(requirements)]
        craft.disabled=not allowed
        craft.pressed.connect(_craft.bind(recipe_id))
        results.add_child(craft)
    _text_row("DISCOVERED ITEM TYPES // %d TOTAL" % known.size())
    for name in known:
        var spec:Dictionary=items.get(name,{})
        _text_row("• "+str(spec.get("label",name.replace("_"," "))).to_upper())

func _select(id:String)->void:
    game.call("select_build_material",id)
    _message("BUILD MATERIAL // "+id.replace("_"," ").to_upper())
    refresh()

func _craft(id:String)->void:
    _message(str(game.call("terrain_craft_recipe",id)))
    refresh()

func _action(method:String)->void:
    _message(str(game.call(method)))
    refresh()

func _message(value:String)->void:
    var hud=get_parent().get_parent()
    if hud!=null and hud.has_method("flash"):
        hud.call("flash",value,1.8)
