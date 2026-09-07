class_name InventoryDock
extends Control

# Bottom Inventory Dock for native point-and-click interaction.

@onready var slots_container: HBoxContainer = $MarginContainer/PanelContainer/HBoxContainer/ScrollContainer/SlotsContainer
@onready var armed_label: Label = $MarginContainer/PanelContainer/HBoxContainer/ArmedStatusLabel
@onready var disarm_button: Button = $MarginContainer/PanelContainer/HBoxContainer/DisarmButton

var slot_buttons: Array[Button] = []


func _ready() -> void:
	disarm_button.pressed.connect(func(): GameRuntime.inventory_system.disarm_item())
	EventBus.inventory_changed.connect(refresh_inventory)
	EventBus.item_armed.connect(_on_item_armed)
	EventBus.item_disarmed.connect(_on_item_disarmed)

	refresh_inventory()
	_update_armed_display()


func refresh_inventory() -> void:
	for child in slots_container.get_children():
		child.queue_free()
	slot_buttons.clear()

	var items = GameRuntime.inventory_system.get_items()
	if items.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "(Inventory empty)"
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slots_container.add_child(empty_lbl)
		return

	for item in items:
		var item_id = item.get("id", "")
		var item_name = item.get("name", item_id)
		var btn = Button.new()
		btn.text = item_name
		btn.custom_minimum_size = Vector2(100, 52)
		btn.add_theme_font_size_override("font_size", 14)
		var current_armed = GameRuntime.inventory_system.get_armed_item()
		if item_id == current_armed:
			btn.modulate = Color(1.2, 0.8, 0.2, 1.0)
		btn.pressed.connect(func(): _on_slot_clicked(item_id))
		slots_container.add_child(btn)
		slot_buttons.append(btn)

	_update_armed_display()


func _on_slot_clicked(item_id: String) -> void:
	if GameRuntime.inventory_system.get_armed_item() == item_id:
		# Disarm if clicked again
		GameRuntime.inventory_system.disarm_item()
	else:
		# Arm item for use on targets
		GameRuntime.inventory_system.arm_item(item_id)


func _on_item_armed(item_id: String) -> void:
	_update_armed_display()


func _on_item_disarmed() -> void:
	_update_armed_display()


func _update_armed_display() -> void:
	var armed_id = GameRuntime.inventory_system.get_armed_item()
	if armed_id != "":
		var meta = GameRuntime.loader.get_item(armed_id)
		var item_name = meta.get("name", armed_id)
		armed_label.text = "USE: " + item_name + " (CLICK TARGET)"
		armed_label.visible = true
		disarm_button.visible = true
	else:
		armed_label.visible = false
		disarm_button.visible = false
