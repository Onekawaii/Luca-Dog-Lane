extends Panel
# Player-facing inventory, material palette, and recipe surface.
# Reads the authoritative TerrainSlice inventory through Game; never caches counts.

var game: Node
var stock_list: VBoxContainer
var recipe_list: VBoxContainer
var selected_label: Label

func _ready() -> void:
	name = "InventoryPanel"
	size = Vector2(600, 476)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.02, 0.04, 0.97)
	style.border_color = Color(0.67, 0.32, 0.73)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	add_theme_stylebox_override("panel", style)

	var title := Label.new()
	title.text = "INVENTORY  //  MATERIALS & CRAFTING"
	title.position = Vector2(20, 12)
	title.add_theme_font_size_override("font_size", 21)
	add_child(title)

	selected_label = Label.new()
	selected_label.position = Vector2(22, 48)
	selected_label.size = Vector2(540, 26)
	add_child(selected_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 84)
	scroll.size = Vector2(560, 324)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 9)
	scroll.add_child(column)

	var stocks_title := Label.new()
	stocks_title.text = "MATERIALS / FOUND IN WORLD"
	column.add_child(stocks_title)
	stock_list = VBoxContainer.new()
	column.add_child(stock_list)

	var recipe_title := Label.new()
	recipe_title.text = "RECIPES / CRAFT WITH COLLECTED MATERIALS"
	column.add_child(recipe_title)
	recipe_list = VBoxContainer.new()
	column.add_child(recipe_list)

	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(222, 425)
	close.size = Vector2(154, 38)
	close.pressed.connect(func(): visible = false)
	add_child(close)
	refresh()

func refresh() -> void:
	if game == null or stock_list == null:
		return
	for child in stock_list.get_children():
		stock_list.remove_child(child)
		child.queue_free()
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.queue_free()

	var inventory: Dictionary = game.call("get_inventory_snapshot_for_ui")
	var items: Dictionary = game.call("get_item_catalog_for_ui")
	var selected := str(game.call("get_selected_build_material"))
	selected_label.text = "SELECTED FOR PLACE: " + selected.replace("_", " ").to_upper()
	var keys := items.keys()
	keys.sort()
	for entry in keys:
		var item_id := str(entry)
		var spec: Dictionary = items[item_id]
		var amount := int(inventory.get(item_id, 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		stock_list.add_child(row)
		var label := Label.new()
		label.custom_minimum_size = Vector2(328, 35)
		label.text = "%s  x%d" % [str(spec.get("label", item_id)).to_upper(), amount]
		label.tooltip_text = str(spec.get("description", ""))
		row.add_child(label)
		if item_id in ["stone", "grass_block", "stone_brick"]:
			var select := Button.new()
			select.text = "SELECTED" if item_id == selected else "PLACE"
			select.disabled = item_id == selected
			select.custom_minimum_size = Vector2(130, 36)
			select.pressed.connect(_select_material.bind(item_id))
			row.add_child(select)

	var recipes: Dictionary = game.call("get_recipe_catalog_for_ui")
	var recipe_ids := recipes.keys()
	recipe_ids.sort()
	for key in recipe_ids:
		var recipe_id := str(key)
		var recipe: Dictionary = recipes[recipe_id]
		var ingredients: Dictionary = recipe.get("ingredients", {})
		var requirement_parts: Array[String] = []
		var can_craft := true
		for item in ingredients:
			var needed := int(ingredients[item])
			requirement_parts.append("%s %d/%d" % [str(item).replace("_", " "), int(inventory.get(item, 0)), needed])
			if int(inventory.get(item, 0)) < needed:
				can_craft = false
		var button := Button.new()
		button.text = "CRAFT %s // %s" % [str(recipe.get("label", recipe_id)).to_upper(), ", ".join(requirement_parts)]
		button.disabled = not can_craft
		button.custom_minimum_size = Vector2(540, 40)
		button.pressed.connect(_craft.bind(recipe_id))
		recipe_list.add_child(button)

func _select_material(item_id: String) -> void:
	if bool(game.call("select_build_material", item_id)):
		refresh()

func _craft(recipe_id: String) -> void:
	var result := str(game.call("terrain_craft_recipe", recipe_id))
	get_parent().get_parent().call("flash", result, 2.0)
	refresh()
