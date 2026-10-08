extends Panel
# Field satchel: stores actual resources and recipes. The hotbar handles equips.
# No duplicate selection state and no "PLACE" buttons in the inventory.

var game: Node
var stock_list: VBoxContainer
var recipe_list: VBoxContainer
var summary_label: Label

func _ready() -> void:
	name = "InventoryPanel"
	size = Vector2(636, 504)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.035, 0.032, 0.048, 0.975)
	shell.border_color = Color(0.62, 0.35, 0.72)
	shell.set_border_width_all(2)
	shell.set_corner_radius_all(14)
	add_theme_stylebox_override("panel", shell)

	_label(self, "FIELD SATCHEL", Vector2(24, 16), Vector2(570, 38), 26, Color(1, 0.88, 0.98))
	_label(self, "FOUND MATERIALS  /  RECIPES  /  CRAFTING", Vector2(24, 54), Vector2(570, 26), 13, Color(0.7, 0.64, 0.76))
	summary_label = _label(self, "", Vector2(24, 82), Vector2(590, 28), 13, Color(0.92, 0.79, 0.57))

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(22, 122)
	scroll.size = Vector2(592, 316)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)

	var resources := Label.new()
	resources.text = "MATERIALS  -  CLOSE INVENTORY TO EQUIP FROM HOTBAR"
	resources.add_theme_font_size_override("font_size", 14)
	column.add_child(resources)
	stock_list = VBoxContainer.new()
	stock_list.add_theme_constant_override("separation", 6)
	column.add_child(stock_list)

	var recipes := Label.new()
	recipes.text = "CRAFTING BENCH  —  RECIPES USE ACTUAL INVENTORY"
	recipes.add_theme_font_size_override("font_size", 14)
	column.add_child(recipes)
	recipe_list = VBoxContainer.new()
	recipe_list.add_theme_constant_override("separation", 7)
	column.add_child(recipe_list)
	_label(self, "ESC / RETURN = CLOSE   |   RECIPES USE REAL STOCK", Vector2(24, 448), Vector2(430, 33), 13, Color(0.72, 0.65, 0.77))
	var close := Button.new()
	close.text = "RETURN"
	close.position = Vector2(488, 450)
	close.size = Vector2(126, 38)
	close.pressed.connect(func(): visible = false)
	add_child(close)
	refresh()

func _label(parent: Node, text_value: String, at: Vector2, dimensions: Vector2, font_size: int, color_value: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color_value)
	parent.add_child(label)
	return label

func _clear_rows(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func refresh() -> void:
	if game == null or stock_list == null:
		return
	_clear_rows(stock_list)
	_clear_rows(recipe_list)
	var inventory: Dictionary = game.call("get_inventory_snapshot_for_ui")
	var items: Dictionary = game.call("get_item_catalog_for_ui")
	var stone := int(inventory.get("stone", 0))
	var grass := int(inventory.get("grass_block", 0))
	var brick := int(inventory.get("stone_brick", 0))
	summary_label.text = "STONE %d   •   TURF %d   •   BRICK %d" % [stone, grass, brick]
	var ids := items.keys()
	ids.sort()
	for key in ids:
		var item_id := str(key)
		var spec: Dictionary = items[item_id]
		var kind := str(spec.get("kind", "resource"))
		var count := int(inventory.get(item_id, 0))
		if kind == "tool_item" or (kind == "utility" and count <= 0):
			continue
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.095, 0.094, 0.12, 0.98)
		row_style.set_corner_radius_all(7)
		row_style.content_margin_left = 12
		row_style.content_margin_right = 12
		row_style.content_margin_top = 7
		row_style.content_margin_bottom = 7
		row.add_theme_stylebox_override("panel", row_style)
		stock_list.add_child(row)
		var line := HBoxContainer.new()
		row.add_child(line)
		var icon_box := ColorRect.new()
		icon_box.custom_minimum_size = Vector2(28, 28)
		icon_box.color = Color(0.42, 0.44, 0.41)
		if item_id == "grass_block":
			icon_box.color = Color(0.35, 0.62, 0.31)
		elif item_id == "stone_brick":
			icon_box.color = Color(0.62, 0.52, 0.43)
		line.add_child(icon_box)
		var spacer := Control.new()
		spacer.custom_minimum_size.x = 12
		line.add_child(spacer)
		var name_label := Label.new()
		name_label.text = str(spec.get("label", item_id)).to_upper()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.tooltip_text = str(spec.get("description", ""))
		line.add_child(name_label)
		var qty := Label.new()
		qty.text = "× %d" % count
		qty.add_theme_font_size_override("font_size", 19)
		qty.add_theme_color_override("font_color", Color(1, 0.81, 0.47))
		line.add_child(qty)
	var recipe_catalog: Dictionary = game.call("get_recipe_catalog_for_ui")
	var recipe_ids := recipe_catalog.keys()
	recipe_ids.sort()
	for key in recipe_ids:
		var recipe_id := str(key)
		var recipe: Dictionary = recipe_catalog[recipe_id]
		var ingredients: Dictionary = recipe.get("ingredients", {})
		var requirements: Array[String] = []
		var can_craft := true
		for ingredient in ingredients:
			var need := int(ingredients[ingredient])
			var available := int(inventory.get(ingredient, 0))
			requirements.append("%s %d/%d" % [str(ingredient).replace("_", " "), available, need])
			if available < need:
				can_craft = false
		var button := Button.new()
		button.custom_minimum_size.y = 46
		button.text = "MAKE %s   •   %s" % [str(recipe.get("label", recipe_id)).to_upper(), "  |  ".join(requirements)]
		button.disabled = not can_craft
		button.pressed.connect(_craft.bind(recipe_id))
		recipe_list.add_child(button)

func _craft(recipe_id: String) -> void:
	var response := str(game.call("terrain_craft_recipe", recipe_id))
	get_parent().get_parent().call("flash", response, 2.0)
	refresh()
