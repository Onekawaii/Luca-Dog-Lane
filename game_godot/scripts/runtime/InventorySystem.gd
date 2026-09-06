class_name InventorySystem
extends RefCounted

# Manages inventory interactions and armed item state for Godot client.

var loader: CampaignLoader
var state: WorldState
var armed_item_id: String = ""


func _init(p_loader: CampaignLoader, p_state: WorldState) -> void:
	loader = p_loader
	state = p_state


func get_items() -> Array:
	var list: Array = []
	for itm_id in state.inventory:
		var meta = loader.get_item(itm_id)
		list.append({
			"id": itm_id,
			"name": meta.get("name", itm_id),
			"description": meta.get("description", ""),
			"type": meta.get("type", "item"),
			"rarity": meta.get("rarity", "common"),
			"icon": _resolve_icon(itm_id)
		})
	return list


func _resolve_icon(item_id: String) -> String:
	var clean_id = item_id.replace("item.", "").replace("relic.", "")
	var paths = [
		"res://assets/items/item." + clean_id + ".png",
		"res://assets/items/" + clean_id + ".png",
		"res://assets/items/item.evidence_bag_not_my_business.png",
		"res://assets/props/wetberry_idle.png"
	]
	for p in paths:
		if ResourceLoader.exists(p):
			return p
	return "res://assets/ui/inventory_slot.png"


func arm_item(item_id: String) -> void:
	if state.has_item(item_id):
		armed_item_id = item_id
		EventBus.item_armed.emit(item_id)
		AudioManager.play_ui_click()


func disarm_item() -> void:
	if armed_item_id != "":
		armed_item_id = ""
		EventBus.item_disarmed.emit()
		AudioManager.play_ui_click()


func is_item_armed() -> bool:
	return armed_item_id != ""


func get_armed_item() -> String:
	return armed_item_id
