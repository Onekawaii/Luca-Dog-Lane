#!/usr/bin/env python3
"""Build authored retro-adventure visual RPG assets for Hive-Lattice v0.7.

Generates:
- Breakroom illustrated background (room.breakroom.illustrated.png, room.breakroom.central_table.png)
- Character dialogue portraits for Keith, Darla, Tammy (neutral, annoyed, engaged, procedural)
- Item icons for Evidence Bag of Not My Business, Bagged Wetberry, Wetberry, Damp Napkin, etc.
- Static assets copies for web server and PWA cache
"""

from __future__ import annotations

import json
import math
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


def create_room_system_files() -> None:
    # 1. Base Room Script (scripts/rooms/RoomBase.gd)
    room_base_code = """class_name RoomBase
extends Node2D

# Base Room Controller for Native Multi-Room Adventure World.

@export var room_id: String = ""
@export var location_id: String = ""
@export var default_camera_pos: Vector2 = Vector2(640, 360)
@export var default_camera_zoom: Vector2 = Vector2(1.0, 1.0)

@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var ysort_container: Node2D = get_node_or_null("YSortContainer")
@onready var player: PlayerActor = get_node_or_null("YSortContainer/Player")
@onready var nav_region: NavigationRegion2D = get_node_or_null("NavigationRegion2D")
@onready var debug_draw: Node2D = get_node_or_null("DebugDraw")

var is_in_dialogue: bool = false
var target_camera_pos: Vector2 = Vector2(640, 360)
var target_camera_zoom: Vector2 = Vector2(1.0, 1.0)


func _ready() -> void:
	EventBus.action_requested.connect(_on_action_requested)
	EventBus.world_state_changed.connect(_on_world_state_changed)
	EventBus.dialogue_closed.connect(_on_dialogue_closed)
	EventBus.debug_toggled.connect(_on_debug_toggled)
	EventBus.camera_focus_requested.connect(_on_camera_focus_requested)
	EventBus.camera_reset_requested.connect(_on_camera_reset_requested)

	if camera:
		target_camera_pos = camera.global_position
		target_camera_zoom = camera.zoom

	_update_room_visuals()


func _process(delta: float) -> void:
	if camera:
		camera.global_position = camera.global_position.lerp(target_camera_pos, delta * 4.0)
		camera.zoom = camera.zoom.lerp(target_camera_zoom, delta * 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if is_in_dialogue or not player or not player.can_move:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_world = get_global_mouse_position()
		if _is_point_walkable(click_world):
			player.walk_to(click_world)
	elif event is InputEventScreenTouch and event.pressed:
		var touch_world = get_global_mouse_position()
		if _is_point_walkable(touch_world):
			player.walk_to(touch_world)


func _is_point_walkable(pos: Vector2) -> bool:
	return pos.y >= 350.0 and pos.y <= 680.0 and pos.x >= 80.0 and pos.x <= 1200.0


func set_player_spawn(entrance_name: String) -> void:
	var marker = find_child("Entrance_" + entrance_name, true, false)
	if not marker:
		marker = find_child("Entrance_Default", true, false)
	if marker and player:
		player.global_position = marker.global_position
		player.velocity = Vector2.ZERO
		player.stop()


func _on_action_requested(act_data: Dictionary) -> void:
	var act_type = act_data.get("type", "")

	if act_type == "approach_and_interact_actor":
		var app_pos = act_data.get("approach_pos", Vector2.ZERO)
		var actor = act_data.get("actor")
		var scene_id = act_data.get("scene_id", "")
		if actor:
			actor.set_focus(true)

		if player:
			player.walk_to(app_pos, func():
				_trigger_actor_dialogue(actor, scene_id)
			)

	elif act_type == "approach_and_interact_hotspot":
		var app_pos = act_data.get("approach_pos", Vector2.ZERO)
		var hotspot = act_data.get("hotspot")
		var hotspot_id = act_data.get("hotspot_id", "")
		var scene_id = act_data.get("scene_id", "")
		var is_exit = act_data.get("is_exit", false)
		var target_room = act_data.get("target_room", "")
		var target_entrance = act_data.get("target_entrance", "Default")
		if hotspot:
			hotspot.set_selected(true)

		if player:
			player.walk_to(app_pos, func():
				if is_exit and target_room != "":
					EventBus.room_change_requested.emit(target_room, target_entrance)
					if hotspot:
						hotspot.set_selected(false)
				else:
					_trigger_hotspot_dialogue(hotspot, hotspot_id, scene_id)
			)


func _trigger_actor_dialogue(actor: ActorBase, scene_id: String) -> void:
	is_in_dialogue = true
	var state = GameRuntime.world_state
	if scene_id != "":
		GameRuntime.action_resolver.enter_scene(state, scene_id)

	var scene_meta = GameRuntime.loader.get_encounter(state.current_scene)
	var choices = GameRuntime.action_resolver.choice_views(state)

	if player:
		var mid_point = (player.global_position + actor.global_position) * 0.5 + Vector2(0, -60)
		target_camera_pos = mid_point
		target_camera_zoom = Vector2(1.15, 1.15)

	var bubble = get_tree().root.find_child("DialogueBubble", true, false)
	if bubble:
		bubble.target_actor = actor

	EventBus.dialogue_started.emit(
		actor.actor_id,
		actor.display_name,
		scene_meta.get("read_aloud", "..."),
		choices
	)


func _trigger_hotspot_dialogue(hotspot: Hotspot, hotspot_id: String, scene_id: String) -> void:
	is_in_dialogue = true
	var state = GameRuntime.world_state
	if scene_id != "":
		GameRuntime.action_resolver.enter_scene(state, scene_id)

	var scene_meta = GameRuntime.loader.get_encounter(state.current_scene)
	var choices = GameRuntime.action_resolver.choice_views(state)

	var bubble = get_tree().root.find_child("DialogueBubble", true, false)
	if bubble:
		bubble.target_actor = hotspot

	EventBus.dialogue_started.emit(
		hotspot_id,
		hotspot.display_name,
		scene_meta.get("read_aloud", "..."),
		choices
	)


func _on_dialogue_closed() -> void:
	is_in_dialogue = false
	target_camera_pos = default_camera_pos
	target_camera_zoom = default_camera_zoom
	if ysort_container:
		for child in ysort_container.get_children():
			if child is ActorBase:
				child.set_focus(false)
			elif child is Hotspot:
				child.set_selected(false)


func _on_world_state_changed(_delta: Dictionary) -> void:
	_update_room_visuals()


func _update_room_visuals() -> void:
	pass


func _on_debug_toggled(is_enabled: bool) -> void:
	if debug_draw:
		debug_draw.visible = is_enabled


func _on_camera_focus_requested(target_pos: Vector2, zoom_level: float) -> void:
	target_camera_pos = target_pos
	target_camera_zoom = Vector2(zoom_level, zoom_level)


func _on_camera_reset_requested() -> void:
	target_camera_pos = default_camera_pos
	target_camera_zoom = default_camera_zoom
"""
    Path("game_godot/scripts/rooms/RoomBase.gd").write_text(room_base_code, encoding="utf-8")

    # 2. RoomManager Script (scripts/runtime/RoomManager.gd)
    room_mgr_code = """class_name RoomManager
extends Node

# Authoritative Room Transition and World Management Controller.

var current_room_node: RoomBase = null
var current_room_id: String = "breakroom"

var room_scenes: Dictionary = {
	"breakroom": "res://scenes/rooms/Breakroom.tscn",
	"hallway": "res://scenes/rooms/Hallway.tscn",
	"fridge_labyrinth": "res://scenes/rooms/FridgeLabyrinth.tscn"
}

var room_locations: Dictionary = {
	"breakroom": "location.breakroom",
	"hallway": "location.breakroom.hallway",
	"fridge_labyrinth": "location.fridge_labyrinth"
}


func _ready() -> void:
	EventBus.room_change_requested.connect(change_room)
	# Connect to existing initial room if present in tree
	var initial_room = get_parent().find_child("Breakroom", true, false)
	if initial_room:
		current_room_node = initial_room
		current_room_id = "breakroom"


func change_room(room_id: String, entrance_name: String = "Default") -> void:
	if not room_scenes.has(room_id):
		push_error("Unknown room_id: " + room_id)
		return

	var scene_path = room_scenes[room_id]
	if not ResourceLoader.exists(scene_path):
		push_error("Room scene not found: " + scene_path)
		return

	# Update WorldState location
	var state = GameRuntime.world_state
	state.current_location = room_locations.get(room_id, "location.breakroom")

	# Instantiate new room scene
	var room_res = load(scene_path)
	var new_room: RoomBase = room_res.instantiate()

	var world_root = get_parent().find_child("WorldRoot", true, false)
	if not world_root:
		world_root = get_parent()

	if is_instance_valid(current_room_node):
		current_room_node.queue_free()

	world_root.add_child(new_room)
	current_room_node = new_room
	current_room_id = room_id

	new_room.set_player_spawn(entrance_name)
	EventBus.room_entered.emit(room_id)
	EventBus.world_state_changed.emit({})
	AudioManager.play_ui_click()
"""
    Path("game_godot/scripts/runtime/RoomManager.gd").write_text(room_mgr_code, encoding="utf-8")

    # 3. BreakroomScene.gd (scripts/rooms/BreakroomScene.gd)
    breakroom_script_code = """class_name BreakroomScene
extends RoomBase

# Breakroom Scene Controller.

@onready var keith: KeithActor = $YSortContainer/Keith
@onready var darla: DarlaActor = $YSortContainer/Darla
@onready var tammy: TammyActor = $YSortContainer/Tammy
@onready var kevin: KevinActor = $YSortContainer/Kevin
@onready var wetberry_prop: Sprite2D = $YSortContainer/CentralTableHotspot/WetberrySprite


func _ready() -> void:
	room_id = "breakroom"
	location_id = "location.breakroom"
	super._ready()


func _update_room_visuals() -> void:
	var state = GameRuntime.world_state
	var is_contained = state.get_flag("wetberry_contained", false) == true or state.room_memory().get("wetberry_status") == "contained"
	if wetberry_prop:
		wetberry_prop.visible = not is_contained
"""
    Path("game_godot/scripts/rooms/BreakroomScene.gd").write_text(breakroom_script_code, encoding="utf-8")

    # 4. Breakroom.tscn (scenes/rooms/Breakroom.tscn)
    breakroom_tscn_code = """[gd_scene load_steps=18 format=3 uid="uid://j9k0l1m2n3o4p"]

[ext_resource type="Script" path="res://scripts/rooms/BreakroomScene.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/rooms/breakroom.png" id="2_bg"]
[ext_resource type="PackedScene" path="res://scenes/actors/Player.tscn" id="3_player"]
[ext_resource type="PackedScene" path="res://scenes/actors/Keith.tscn" id="4_keith"]
[ext_resource type="PackedScene" path="res://scenes/actors/Darla.tscn" id="5_darla"]
[ext_resource type="PackedScene" path="res://scenes/actors/Tammy.tscn" id="6_tammy"]
[ext_resource type="PackedScene" path="res://scenes/actors/Kevin.tscn" id="7_kevin"]
[ext_resource type="Script" path="res://scripts/interaction/Hotspot.gd" id="8_hotspot"]
[ext_resource type="Texture2D" path="res://assets/props/central_table.png" id="9_table"]
[ext_resource type="Texture2D" path="res://assets/props/wetberry_idle.png" id="10_wetberry"]
[ext_resource type="Texture2D" path="res://assets/props/counter_appliances.png" id="11_appliances"]
[ext_resource type="Texture2D" path="res://assets/props/mop_bucket.png" id="12_mop"]

[sub_resource type="NavigationPolygon" id="NavigationPolygon_breakroom"]
vertices = PackedVector2Array(80, 370, 1200, 370, 1200, 680, 80, 680, 560, 430, 720, 430, 720, 560, 560, 560, 260, 370, 520, 370, 520, 430, 260, 430, 960, 480, 1120, 480, 1120, 580, 960, 580)
polygons = Array[PackedInt32Array]([PackedInt32Array(0, 1, 2, 3)])
outlines = Array[PackedVector2Array]([PackedVector2Array(80, 370, 1200, 370, 1200, 680, 80, 680)])

[sub_resource type="CircleShape2D" id="CircleShape2D_table"]
radius = 45.0

[sub_resource type="RectangleShape2D" id="RectangleShape2D_counter"]
size = Vector2(160, 40)

[sub_resource type="CircleShape2D" id="CircleShape2D_utility"]
radius = 35.0

[sub_resource type="RectangleShape2D" id="RectangleShape2D_exit"]
size = Vector2(60, 120)

[node name="Breakroom" type="Node2D"]
script = ExtResource("1_script")

[node name="Background" type="Sprite2D" parent="."]
position = Vector2(640, 360)
texture = ExtResource("2_bg")

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(640, 360)

[node name="NavigationRegion2D" type="NavigationRegion2D" parent="."]
navigation_polygon = SubResource("NavigationPolygon_breakroom")

[node name="StaticBodies" type="Node2D" parent="."]

[node name="TableBody" type="StaticBody2D" parent="StaticBodies"]
position = Vector2(640, 500)

[node name="CollisionShape2D" type="CollisionShape2D" parent="StaticBodies/TableBody"]
shape = SubResource("CircleShape2D_table")

[node name="CounterBody" type="StaticBody2D" parent="StaticBodies"]
position = Vector2(400, 400)

[node name="CollisionShape2D" type="CollisionShape2D" parent="StaticBodies/CounterBody"]
shape = SubResource("RectangleShape2D_counter")

[node name="UtilityBody" type="StaticBody2D" parent="StaticBodies"]
position = Vector2(1040, 540)

[node name="CollisionShape2D" type="CollisionShape2D" parent="StaticBodies/UtilityBody"]
shape = SubResource("CircleShape2D_utility")

[node name="Entrance_Default" type="Marker2D" parent="."]
position = Vector2(640, 600)

[node name="Entrance_Hallway" type="Marker2D" parent="."]
position = Vector2(1100, 480)

[node name="YSortContainer" type="Node2D" parent="."]
y_sort_enabled = true

[node name="CentralTableHotspot" type="Area2D" parent="YSortContainer"]
position = Vector2(640, 500)
script = ExtResource("8_hotspot")
hotspot_id = "relic.wetberry"
display_name = "Wetberry on Central Table"
scene_id = "scene.act1.first_sighting"
approach_position = Vector2(640, 570)

[node name="TableSprite" type="Sprite2D" parent="YSortContainer/CentralTableHotspot"]
position = Vector2(0, -30)
texture = ExtResource("9_table")

[node name="WetberrySprite" type="Sprite2D" parent="YSortContainer/CentralTableHotspot"]
position = Vector2(0, -52)
texture = ExtResource("10_wetberry")

[node name="CollisionShape2D" type="CollisionShape2D" parent="YSortContainer/CentralTableHotspot"]
position = Vector2(0, -20)
shape = SubResource("CircleShape2D_table")

[node name="CoffeeCounterHotspot" type="Area2D" parent="YSortContainer"]
position = Vector2(400, 390)
script = ExtResource("8_hotspot")
hotspot_id = "location.breakroom.coffee_counter"
display_name = "Coffee Counter & Microwave"
scene_id = "scene.act1.coffee_counter"
approach_position = Vector2(400, 445)

[node name="AppliancesSprite" type="Sprite2D" parent="YSortContainer/CoffeeCounterHotspot"]
position = Vector2(0, -35)
texture = ExtResource("11_appliances")

[node name="CollisionShape2D" type="CollisionShape2D" parent="YSortContainer/CoffeeCounterHotspot"]
position = Vector2(0, -20)
shape = SubResource("RectangleShape2D_counter")

[node name="UtilityCornerHotspot" type="Area2D" parent="YSortContainer"]
position = Vector2(1040, 530)
script = ExtResource("8_hotspot")
hotspot_id = "location.breakroom.utility_corner"
display_name = "Utility Corner & Mop Bucket"
scene_id = "scene.act1.keith_corner"
approach_position = Vector2(980, 540)

[node name="MopSprite" type="Sprite2D" parent="YSortContainer/UtilityCornerHotspot"]
position = Vector2(0, -30)
texture = ExtResource("12_mop")

[node name="CollisionShape2D" type="CollisionShape2D" parent="YSortContainer/UtilityCornerHotspot"]
position = Vector2(0, -15)
shape = SubResource("CircleShape2D_utility")

[node name="ExitHotspot" type="Area2D" parent="YSortContainer"]
position = Vector2(1180, 460)
script = ExtResource("8_hotspot")
hotspot_id = "exit.breakroom.hallway"
display_name = "Exit to Forgotten Hallway"
is_exit = true
target_room = "hallway"
target_entrance = "Breakroom"
approach_position = Vector2(1120, 460)

[node name="CollisionShape2D" type="CollisionShape2D" parent="YSortContainer/ExitHotspot"]
shape = SubResource("RectangleShape2D_exit")

[node name="Darla" parent="YSortContainer" instance=ExtResource("5_darla")]
position = Vector2(490, 410)

[node name="Keith" parent="YSortContainer" instance=ExtResource("4_keith")]
position = Vector2(960, 520)

[node name="Tammy" parent="YSortContainer" instance=ExtResource("6_tammy")]
position = Vector2(820, 470)

[node name="Kevin" parent="YSortContainer" instance=ExtResource("7_kevin")]
position = Vector2(330, 430)

[node name="Player" parent="YSortContainer" instance=ExtResource("3_player")]
position = Vector2(640, 590)

[node name="DebugDraw" type="Node2D" parent="."]
visible = false
"""
    Path("game_godot/scenes/rooms/Breakroom.tscn").write_text(breakroom_tscn_code, encoding="utf-8")

    # 5. HallwayScene.gd (scripts/rooms/HallwayScene.gd)
    hallway_script_code = """class_name HallwayScene
extends RoomBase

# Hallway Scene Controller.

func _ready() -> void:
	room_id = "hallway"
	location_id = "location.breakroom.hallway"
	super._ready()
"""
    Path("game_godot/scripts/rooms/HallwayScene.gd").write_text(hallway_script_code, encoding="utf-8")

    # 6. Hallway.tscn (scenes/rooms/Hallway.tscn)
    hallway_tscn_code = """[gd_scene load_steps=10 format=3 uid="uid://h4l1w2a3y4s5c"]

[ext_resource type="Script" path="res://scripts/rooms/HallwayScene.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/rooms/hallway.png" id="2_bg"]
[ext_resource type="PackedScene" path="res://scenes/actors/Player.tscn" id="3_player"]
[ext_resource type="Script" path="res://scripts/interaction/Hotspot.gd" id="4_hotspot"]

[sub_resource type="NavigationPolygon" id="NavigationPolygon_hallway"]
vertices = PackedVector2Array(80, 360, 1200, 360, 1200, 680, 80, 680)
polygons = Array[PackedInt32Array]([PackedInt32Array(0, 1, 2, 3)])
outlines = Array[PackedVector2Array]([PackedVector2Array(80, 360, 1200, 360, 1200, 680, 80, 680)])

[sub_resource type="RectangleShape2D" id="RectangleShape2D_door"]
size = Vector2(80, 140)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_cabinet"]
size = Vector2(180, 80)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_cab_static"]
size = Vector2(180, 40)

[node name="Hallway" type="Node2D"]
script = ExtResource("1_script")

[node name="Background" type="Sprite2D" parent="."]
position = Vector2(640, 360)
texture = ExtResource("2_bg")

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(640, 360)

[node name="NavigationRegion2D" type="NavigationRegion2D" parent="."]
navigation_polygon = SubResource("NavigationPolygon_hallway")

[node name="StaticBodies" type="Node2D" parent="."]

[node name="CabinetBody" type="StaticBody2D" parent="StaticBodies"]
position = Vector2(640, 370)

[node name="CollisionShape2D" type="CollisionShape2D" parent="StaticBodies/CabinetBody"]
shape = SubResource("RectangleShape2D_cab_static")

[node name="Entrance_Default" type="Marker2D" parent="."]
position = Vector2(200, 480)

[node name="Entrance_Breakroom" type="Marker2D" parent="."]
position = Vector2(180, 480)

[node name="Entrance_Fridge" type="Marker2D" parent="."]
position = Vector2(1080, 480)

[node name="YSortContainer" type="Node2D" parent="."]
y_sort_enabled = true

[node name="DoorToBreakroom" type="Area2D" parent="YSortContainer"]
position = Vector2(100, 450)
script = ExtResource("4_hotspot")
hotspot_id = "door.hallway.breakroom"
display_name = "Return to Breakroom"
is_exit = true
target_room = "breakroom"
target_entrance = "Hallway"
approach_position = Vector2(160, 470)

[node name="CollisionShape2D" type="CollisionShape2D" parent="YSortContainer/DoorToBreakroom"]
shape = SubResource("RectangleShape2D_door")

[node name="DoorToFridge" type="Area2D" parent="YSortContainer"]
position = Vector2(1160, 450)
script = ExtResource("4_hotspot")
hotspot_id = "door.hallway.fridge"
display_name = "Proceed to Fridge Labyrinth"
is_exit = true
target_room = "fridge_labyrinth"
target_entrance = "Hallway"
approach_position = Vector2(1100, 470)

[node name="CollisionShape2D" type="CollisionShape2D" parent="YSortContainer/DoorToFridge"]
shape = SubResource("RectangleShape2D_door")

[node name="FilingCabinetHotspot" type="Area2D" parent="YSortContainer"]
position = Vector2(640, 380)
script = ExtResource("4_hotspot")
hotspot_id = "location.breakroom.hallway.archives"
display_name = "Mildred Archive Filing Cabinets"
scene_id = "scene.act3.hallway_discovery"
approach_position = Vector2(640, 440)

[node name="CollisionShape2D" type="CollisionShape2D" parent="YSortContainer/FilingCabinetHotspot"]
shape = SubResource("RectangleShape2D_cabinet")

[node name="Player" parent="YSortContainer" instance=ExtResource("3_player")]
position = Vector2(200, 480)

[node name="DebugDraw" type="Node2D" parent="."]
visible = false
"""
    Path("game_godot/scenes/rooms/Hallway.tscn").write_text(hallway_tscn_code, encoding="utf-8")

    # 7. FridgeLabyrinthScene.gd (scripts/rooms/FridgeLabyrinthScene.gd)
    fridge_script_code = """class_name FridgeLabyrinthScene
extends RoomBase

# Fridge Labyrinth Scene Controller.

func _ready() -> void:
	room_id = "fridge_labyrinth"
	location_id = "location.fridge_labyrinth"
	super._ready()
"""
    Path("game_godot/scripts/rooms/FridgeLabyrinthScene.gd").write_text(fridge_script_code, encoding="utf-8")

    # 8. FridgeLabyrinth.tscn (scenes/rooms/FridgeLabyrinth.tscn)
    fridge_tscn_code = """[gd_scene load_steps=10 format=3 uid="uid://f7l8r9i0d1g2e"]

[ext_resource type="Script" path="res://scripts/rooms/FridgeLabyrinthScene.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/rooms/fridge_labyrinth.png" id="2_bg"]
[ext_resource type="PackedScene" path="res://scenes/actors/Player.tscn" id="3_player"]
[ext_resource type="Script" path="res://scripts/interaction/Hotspot.gd" id="4_hotspot"]

[sub_resource type="NavigationPolygon" id="NavigationPolygon_fridge"]
vertices = PackedVector2Array(80, 350, 1200, 350, 1200, 680, 80, 680)
polygons = Array[PackedInt32Array]([PackedInt32Array(0, 1, 2, 3)])
outlines = Array[PackedVector2Array]([PackedVector2Array(80, 350, 1200, 350, 1200, 680, 80, 680)])

[sub_resource type="RectangleShape2D" id="RectangleShape2D_door"]
size = Vector2(80, 140)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_gate"]
size = Vector2(180, 90)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_gate_static"]
size = Vector2(180, 40)

[node name="FridgeLabyrinth" type="Node2D"]
script = ExtResource("1_script")

[node name="Background" type="Sprite2D" parent="."]
position = Vector2(640, 360)
texture = ExtResource("2_bg")

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(640, 360)

[node name="NavigationRegion2D" type="NavigationRegion2D" parent="."]
navigation_polygon = SubResource("NavigationPolygon_fridge")

[node name="StaticBodies" type="Node2D" parent="."]

[node name="GateBody" type="StaticBody2D" parent="StaticBodies"]
position = Vector2(650, 350)

[node name="CollisionShape2D" type="CollisionShape2D" parent="StaticBodies/GateBody"]
shape = SubResource("RectangleShape2D_gate_static")

[node name="Entrance_Default" type="Marker2D" parent="."]
position = Vector2(200, 480)

[node name="Entrance_Hallway" type="Marker2D" parent="."]
position = Vector2(180, 480)

[node name="YSortContainer" type="Node2D" parent="."]
y_sort_enabled = true

[node name="DoorToHallway" type="Area2D" parent="YSortContainer"]
position = Vector2(100, 450)
script = ExtResource("4_hotspot")
hotspot_id = "door.fridge.hallway"
display_name = "Return to Hallway"
is_exit = true
target_room = "hallway"
target_entrance = "Fridge"
approach_position = Vector2(160, 470)

[node name="CollisionShape2D" type="CollisionShape2D" parent="YSortContainer/DoorToHallway"]
shape = SubResource("RectangleShape2D_door")

[node name="CondimentGateHotspot" type="Area2D" parent="YSortContainer"]
position = Vector2(650, 370)
script = ExtResource("4_hotspot")
hotspot_id = "location.fridge_labyrinth.condiment_gate"
display_name = "The Condiment Gate"
scene_id = "scene.act4.condiment_gate"
approach_position = Vector2(650, 440)

[node name="CollisionShape2D" type="CollisionShape2D" parent="YSortContainer/CondimentGateHotspot"]
shape = SubResource("RectangleShape2D_gate")

[node name="Player" parent="YSortContainer" instance=ExtResource("3_player")]
position = Vector2(200, 480)

[node name="DebugDraw" type="Node2D" parent="."]
visible = false
"""
    Path("game_godot/scenes/rooms/FridgeLabyrinth.tscn").write_text(fridge_tscn_code, encoding="utf-8")


def create_kevin_files() -> None:
    kevin_actor_path = Path("game_godot/scripts/actors/KevinActor.gd")
    kevin_actor_path.parent.mkdir(parents=True, exist_ok=True)
    kevin_actor_code = """class_name KevinActor
extends ActorBase

# Kevin from Marketing - Conditionally present at Coffee Counter/Breakroom.

func _ready() -> void:
	actor_id = "npc.kevin_marketing"
	display_name = "Kevin from Marketing"
	portrait_path = "res://assets/portraits/kevin_neutral.png"
	approach_offset = Vector2(0, 50)
	super._ready()

	EventBus.world_state_changed.connect(_on_world_state_changed)
	_check_presence()


func _on_world_state_changed(_delta: Dictionary) -> void:
	_check_presence()


func _check_presence() -> void:
	var state = GameRuntime.world_state
	var is_present = (
		state.get_flag("kevin_present", true) == true and
		not state.get_flag("kevin_departed", false)
	)
	visible = is_present
	process_mode = Node.PROCESS_MODE_INHERIT if is_present else Node.PROCESS_MODE_DISABLED


func _handle_interaction() -> void:
	if not visible:
		return
	if GameRuntime.inventory_system.is_item_armed():
		GameRuntime.use_armed_item_on(actor_id)
		return

	EventBus.action_requested.emit({
		"type": "approach_and_interact_actor",
		"actor": self,
		"actor_id": actor_id,
		"scene_id": "scene.act1.coffee_counter",
		"approach_pos": get_approach_position()
	})
"""
    kevin_actor_path.write_text(kevin_actor_code, encoding="utf-8")

    kevin_scene_path = Path("game_godot/scenes/actors/Kevin.tscn")
    kevin_scene_path.parent.mkdir(parents=True, exist_ok=True)
    kevin_scene_code = """[gd_scene load_steps=4 format=3 uid="uid://k3v1n4m5a6r7k"]

[ext_resource type="Script" path="res://scripts/actors/KevinActor.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/actors/kevin.png" id="2_tex"]

[sub_resource type="CapsuleShape2D" id="CapsuleShape2D_kevin"]
radius = 16.0
height = 38.0

[node name="Kevin" type="CharacterBody2D"]
y_sort_enabled = true
input_pickable = true
script = ExtResource("1_script")

[node name="Sprite2D" type="Sprite2D" parent="."]
position = Vector2(0, -88)
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
rotation = 1.5708
shape = SubResource("CapsuleShape2D_kevin")
"""
    kevin_scene_path.write_text(kevin_scene_code, encoding="utf-8")


def create_breakroom_background(width: int = 1024, height: int = 768) -> Image.Image:
    """Render a 1990s-style illustrated point-and-click breakroom background."""
    img = Image.new("RGBA", (width, height), (15, 18, 26, 255))
    draw = ImageDraw.Draw(img)

    # 1. Back Wall — dirty institutional greenish-grey plaster / acoustic tile
    wall_h = int(height * 0.52)
    draw.rectangle([0, 0, width, wall_h], fill=(22, 28, 36, 255))

    # Wall horizontal molding / wainscoting
    for y in range(0, wall_h, 32):
        shade = 20 + (y % 6)
        draw.line([0, y, width, y], fill=(shade, shade + 5, shade + 10, 80), width=1)

    molding_y = int(wall_h * 0.7)
    draw.rectangle([0, molding_y, width, molding_y + 8], fill=(38, 48, 58, 255))
    draw.rectangle([0, molding_y + 8, width, wall_h], fill=(18, 22, 30, 255))

    # 2. Fluorescent Ceiling Fixtures
    fixture_y = int(height * 0.04)
    # Left fixture
    draw.rectangle([int(width * 0.18), fixture_y, int(width * 0.45), fixture_y + 16], fill=(50, 60, 70, 255))
    draw.rectangle([int(width * 0.20), fixture_y + 4, int(width * 0.43), fixture_y + 12], fill=(230, 255, 240, 255))
    # Right fixture
    draw.rectangle([int(width * 0.55), fixture_y, int(width * 0.82), fixture_y + 16], fill=(50, 60, 70, 255))
    draw.rectangle([int(width * 0.57), fixture_y + 4, int(width * 0.80), fixture_y + 12], fill=(230, 255, 240, 255))

    # Fluorescent glow beam overlay
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.polygon([
        (int(width * 0.15), fixture_y + 16),
        (int(width * 0.48), fixture_y + 16),
        (int(width * 0.60), height),
        (int(width * 0.05), height)
    ], fill=(40, 90, 70, 35))
    glow_draw.polygon([
        (int(width * 0.52), fixture_y + 16),
        (int(width * 0.85), fixture_y + 16),
        (int(width * 0.95), height),
        (int(width * 0.40), height)
    ], fill=(40, 90, 70, 35))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # 3. Compliance Signs on the Back Wall
    # Sign 1: "HONESTY TASTES BETTER HOT" (above coffee counter)
    sign1_x, sign1_y = int(width * 0.32), int(wall_h * 0.18)
    draw.rectangle([sign1_x, sign1_y, sign1_x + 190, sign1_y + 45], fill=(210, 195, 160, 255), outline=(90, 80, 60, 255), width=2)
    draw.rectangle([sign1_x + 4, sign1_y + 4, sign1_x + 186, sign1_y + 41], fill=(235, 225, 195, 255))
    draw.text((sign1_x + 10, sign1_y + 8), "NOTICE: HONESTY", fill=(120, 30, 30, 255))
    draw.text((sign1_x + 10, sign1_y + 24), "TASTES BETTER HOT", fill=(30, 35, 45, 255))

    # Sign 2: "MICROWAVE JUDGES, NOT HEATS" (above microwave)
    sign2_x, sign2_y = int(width * 0.54), int(wall_h * 0.18)
    draw.rectangle([sign2_x, sign2_y, sign2_x + 200, sign2_y + 45], fill=(200, 210, 215, 255), outline=(50, 70, 80, 255), width=2)
    draw.rectangle([sign2_x + 4, sign2_y + 4, sign2_x + 196, sign2_y + 41], fill=(225, 235, 240, 255))
    draw.text((sign2_x + 10, sign2_y + 8), "CAUTION: UNIT JUDGES", fill=(160, 50, 20, 255))
    draw.text((sign2_x + 10, sign2_y + 24), "DO NOT OVER-EXPECT", fill=(20, 30, 40, 255))

    # Sign 3: "SAME CHAOS, DIFFERENT CUP"
    sign3_x, sign3_y = int(width * 0.08), int(wall_h * 0.35)
    draw.rectangle([sign3_x, sign3_y, sign3_x + 160, sign3_y + 35], fill=(180, 175, 165, 255), outline=(60, 55, 50, 255), width=1)
    draw.text((sign3_x + 8, sign3_y + 10), "SAME CHAOS, DIFF CUP", fill=(40, 40, 45, 255))

    # 4. Linoleum Tile Floor with Perspective Grid & Wear
    tile_colors = [(18, 24, 34, 255), (14, 19, 28, 255)]
    grid_color = (28, 38, 52, 255)

    floor_poly = [(0, wall_h), (width, wall_h), (width, height), (0, height)]
    draw.polygon(floor_poly, fill=(16, 22, 30, 255))

    # Draw isometric/perspective floor tile lines
    num_x_lines = 24
    for i in range(num_x_lines + 1):
        x_top = int((i / num_x_lines) * width)
        x_bot = int(((i - num_x_lines / 2) * 1.5 + num_x_lines / 2) / num_x_lines * width)
        draw.line([x_top, wall_h, x_bot, height], fill=grid_color, width=1)

    num_y_lines = 16
    for j in range(num_y_lines + 1):
        t = (j / num_y_lines) ** 1.6
        y_pos = int(wall_h + t * (height - wall_h))
        draw.line([0, y_pos, width, y_pos], fill=grid_color, width=1)

    # 5. Background Furniture & Stations

    # Left: Vending Machine / Implied Hallway Exit (x: 4% to 22%)
    vend_x, vend_y, vend_w, vend_h = int(width * 0.04), int(wall_h * 0.45), int(width * 0.16), int(height * 0.42)
    draw.rectangle([vend_x, vend_y, vend_x + vend_w, vend_y + vend_h], fill=(30, 42, 58, 255), outline=(15, 22, 32, 255), width=3)
    # Vending glass / illuminated snack rows
    draw.rectangle([vend_x + 10, vend_y + 15, vend_x + vend_w - 10, vend_y + int(vend_h * 0.65)], fill=(12, 24, 38, 255), outline=(60, 90, 120, 255), width=2)
    for r in range(3):
        ry = vend_y + 25 + r * 30
        draw.line([vend_x + 12, ry, vend_x + vend_w - 12, ry], fill=(70, 100, 130, 255), width=2)
        for c in range(4):
            cx = vend_x + 18 + c * 22
            col = [(180, 60, 60), (60, 160, 120), (200, 160, 40), (140, 80, 180)][(r + c) % 4]
            draw.rectangle([cx, ry - 16, cx + 14, ry - 2], fill=(*col, 255))
    # Vending slot
    draw.rectangle([vend_x + 20, vend_y + int(vend_h * 0.75), vend_x + vend_w - 20, vend_y + int(vend_h * 0.90)], fill=(10, 14, 20, 255), outline=(40, 50, 65, 255), width=2)

    # Center-Top: Coffee Counter & Microwave Station (x: 28% to 72%)
    counter_x, counter_y = int(width * 0.28), int(wall_h * 0.55)
    counter_w, counter_h = int(width * 0.44), int(height * 0.22)
    # Counter front
    draw.rectangle([counter_x, counter_y + 18, counter_x + counter_w, counter_y + counter_h], fill=(42, 32, 28, 255), outline=(20, 15, 12, 255), width=2)
    # Cabinet panels
    draw.rectangle([counter_x + 10, counter_y + 28, counter_x + int(counter_w * 0.46), counter_y + counter_h - 10], fill=(54, 42, 36, 255), outline=(30, 24, 20, 255), width=1)
    draw.rectangle([counter_x + int(counter_w * 0.54), counter_y + 28, counter_x + counter_w - 10, counter_y + counter_h - 10], fill=(54, 42, 36, 255), outline=(30, 24, 20, 255), width=1)
    # Countertop surface (laminate with highlight)
    draw.polygon([
        (counter_x - 8, counter_y + 18),
        (counter_x + counter_w + 8, counter_y + 18),
        (counter_x + counter_w, counter_y),
        (counter_x, counter_y)
    ], fill=(95, 80, 72, 255), outline=(130, 115, 105, 255))

    # Coffee Maker Appliance
    cm_x, cm_y = counter_x + 25, counter_y - 48
    draw.rectangle([cm_x, cm_y, cm_x + 42, cm_y + 58], fill=(30, 32, 38, 255), outline=(15, 16, 20, 255), width=2)
    draw.rectangle([cm_x + 6, cm_y + 18, cm_x + 36, cm_y + 50], fill=(180, 140, 100, 180), outline=(200, 200, 200, 220), width=1)
    draw.rectangle([cm_x + 8, cm_y + 32, cm_x + 34, cm_y + 48], fill=(50, 25, 15, 240))
    draw.ellipse([cm_x + 12, cm_y - 8, cm_x + 30, cm_y + 4], fill=(20, 22, 26, 255))

    # The Microwave (with glowing judgment display)
    mw_x, mw_y = counter_x + int(counter_w * 0.55), counter_y - 42
    draw.rectangle([mw_x, mw_y, mw_x + 85, mw_y + 52], fill=(45, 52, 60, 255), outline=(20, 25, 30, 255), width=2)
    draw.rectangle([mw_x + 8, mw_y + 8, mw_x + 58, mw_y + 44], fill=(15, 20, 26, 255), outline=(30, 40, 50, 255), width=1)
    draw.rectangle([mw_x + 63, mw_y + 10, mw_x + 80, mw_y + 22], fill=(10, 30, 15, 255))
    draw.text((mw_x + 65, mw_y + 11), "88:88", fill=(57, 255, 20, 255))
    for k in range(3):
        draw.rectangle([mw_x + 64, mw_y + 26 + k * 6, mw_x + 79, mw_y + 30 + k * 6], fill=(70, 80, 90, 255))

    # Right: Utility Corner (x: 74% to 96%)
    util_x, util_y = int(width * 0.74), int(wall_h * 0.60)
    util_w, util_h = int(width * 0.22), int(height * 0.35)
    draw.rectangle([util_x, util_y, util_x + util_w, util_y + util_h], fill=(24, 36, 48, 255), outline=(12, 18, 25, 255), width=2)
    # Drain grill on floor
    drain_cx, drain_cy = util_x + int(util_w * 0.5), util_y + int(util_h * 0.7)
    draw.ellipse([drain_cx - 24, drain_cy - 12, drain_cx + 24, drain_cy + 12], fill=(10, 14, 20, 255), outline=(60, 75, 90, 255), width=2)
    for d in range(-16, 17, 8):
        draw.line([drain_cx + d, drain_cy - 8, drain_cx + d, drain_cy + 8], fill=(40, 50, 60, 255), width=2)
    # Wall Pipes
    pipe_x = util_x + int(util_w * 0.75)
    draw.rectangle([pipe_x, 0, pipe_x + 14, util_y + int(util_h * 0.4)], fill=(65, 75, 85, 255), outline=(35, 42, 50, 255), width=1)
    draw.rectangle([pipe_x - 3, wall_h - 20, pipe_x + 17, wall_h - 10], fill=(85, 95, 105, 255))

    # Keith's Mop Bucket & Wringer
    bucket_x, bucket_y = util_x + 25, util_y + int(util_h * 0.4)
    draw.rectangle([bucket_x, bucket_y, bucket_x + 40, bucket_y + 35], fill=(210, 180, 40, 255), outline=(130, 105, 20, 255), width=2)
    draw.rectangle([bucket_x + 4, bucket_y + 6, bucket_x + 36, bucket_y + 20], fill=(40, 80, 100, 200))
    draw.ellipse([bucket_x + 2, bucket_y + 32, bucket_x + 10, bucket_y + 40], fill=(20, 20, 20, 255))
    draw.ellipse([bucket_x + 30, bucket_y + 32, bucket_x + 38, bucket_y + 40], fill=(20, 20, 20, 255))
    draw.line([bucket_x + 32, bucket_y + 8, bucket_x + 48, bucket_y - 12], fill=(160, 160, 160, 255), width=3)

    # 6. Central Table (The focal centerpiece where Wetberry rests)
    tbl_cx, tbl_cy = int(width * 0.50), int(height * 0.64)
    tbl_rx, tbl_ry = int(width * 0.18), int(height * 0.11)

    shadow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(shadow)
    sh_draw.ellipse([tbl_cx - tbl_rx - 10, tbl_cy + 15, tbl_cx + tbl_rx + 10, tbl_cy + tbl_ry + 45], fill=(5, 8, 12, 160))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)

    # Table legs
    leg_w = 12
    draw.rectangle([tbl_cx - tbl_rx + 30, tbl_cy, tbl_cx - tbl_rx + 30 + leg_w, tbl_cy + 55], fill=(45, 52, 62, 255), outline=(20, 25, 30, 255))
    draw.rectangle([tbl_cx + tbl_rx - 42, tbl_cy, tbl_cx + tbl_rx - 42 + leg_w, tbl_cy + 55], fill=(45, 52, 62, 255), outline=(20, 25, 30, 255))
    draw.rectangle([tbl_cx - leg_w // 2, tbl_cy + 10, tbl_cx + leg_w // 2, tbl_cy + 58], fill=(35, 42, 50, 255), outline=(15, 20, 25, 255))

    # Tabletop Oval
    draw.ellipse([tbl_cx - tbl_rx, tbl_cy - tbl_ry + 8, tbl_cx + tbl_rx, tbl_cy + tbl_ry + 8], fill=(35, 42, 52, 255), outline=(20, 25, 32, 255), width=2)
    draw.ellipse([tbl_cx - tbl_rx, tbl_cy - tbl_ry, tbl_cx + tbl_rx, tbl_cy + tbl_ry], fill=(56, 68, 82, 255), outline=(100, 118, 138, 255), width=3)
    draw.ellipse([tbl_cx - tbl_rx + 6, tbl_cy - tbl_ry + 4, tbl_cx + tbl_rx - 6, tbl_cy + tbl_ry - 4], outline=(75, 90, 108, 255), width=1)

    # Table Stain / Wetberry Moisture Ring
    stain = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    stain_draw = ImageDraw.Draw(stain)
    stain_draw.ellipse([tbl_cx - 35, tbl_cy - 18, tbl_cx + 35, tbl_cy + 18], fill=(255, 30, 100, 70))
    stain_draw.ellipse([tbl_cx - 22, tbl_cy - 12, tbl_cx + 22, tbl_cy + 12], fill=(255, 60, 130, 95))
    img = Image.alpha_composite(img, stain)

    return img


def create_portrait(name: str, emotion: str, size: int = 256) -> Image.Image:
    """Generate a retro adventure dialog portrait (Keith, Darla, Tammy)."""
    img = Image.new("RGBA", (size, size), (12, 15, 22, 255))
    draw = ImageDraw.Draw(img)

    # Frame border
    draw.rectangle([2, 2, size - 3, size - 3], outline=(40, 52, 70, 255), width=2)
    draw.rectangle([6, 6, size - 7, size - 7], outline=(24, 32, 45, 255), width=1)

    # Background
    bg_col = (20, 26, 38, 255)
    if name == "keith":
        bg_col = (18, 32, 42, 255)
    elif name == "darla":
        bg_col = (36, 22, 38, 255)
    elif name == "tammy":
        bg_col = (38, 18, 28, 255)
    draw.rectangle([8, 8, size - 9, size - 9], fill=bg_col)

    cx, cy = size // 2, int(size * 0.52)

    if name == "keith":
        shirt_col = (47, 102, 120, 255)
        draw.polygon([(cx - 75, size - 8), (cx + 75, size - 8), (cx + 55, cy + 50), (cx - 55, cy + 50)], fill=shirt_col)
        draw.polygon([(cx - 25, cy + 50), (cx + 25, cy + 50), (cx, cy + 75)], fill=(23, 55, 70, 255))

        skin = (216, 168, 124, 255)
        draw.rectangle([cx - 18, cy + 20, cx + 18, cy + 55], fill=(195, 145, 105, 255))
        draw.ellipse([cx - 42, cy - 45, cx + 42, cy + 35], fill=skin, outline=(150, 105, 75, 255), width=2)

        cap_col = (23, 55, 70, 255)
        draw.polygon([(cx - 45, cy - 35), (cx + 45, cy - 35), (cx + 38, cy - 68), (cx - 38, cy - 68)], fill=cap_col, outline=(15, 35, 45, 255), width=2)
        draw.polygon([(cx - 48, cy - 36), (cx + 52, cy - 36), (cx + 62, cy - 28), (cx - 40, cy - 28)], fill=(15, 35, 45, 255))
        draw.rectangle([cx - 12, cy - 58, cx + 12, cy - 44], fill=(241, 196, 79, 255))

        brow_y = cy - 14
        if emotion == "annoyed":
            draw.line([cx - 32, brow_y - 2, cx - 10, brow_y + 4], fill=(70, 45, 30, 255), width=3)
            draw.line([cx + 10, brow_y + 4, cx + 32, brow_y - 2], fill=(70, 45, 30, 255), width=3)
        elif emotion == "engaged":
            draw.line([cx - 32, brow_y - 4, cx - 10, brow_y - 6], fill=(70, 45, 30, 255), width=3)
            draw.line([cx + 10, brow_y - 6, cx + 32, brow_y - 4], fill=(70, 45, 30, 255), width=3)
        else:
            draw.line([cx - 32, brow_y, cx - 10, brow_y], fill=(70, 45, 30, 255), width=3)
            draw.line([cx + 10, brow_y, cx + 32, brow_y], fill=(70, 45, 30, 255), width=3)

        eye_y = cy - 4
        draw.arc([cx - 30, eye_y - 2, cx - 12, eye_y + 12], 0, 180, fill=(160, 115, 85, 255), width=2)
        draw.arc([cx + 12, eye_y - 2, cx + 30, eye_y + 12], 0, 180, fill=(160, 115, 85, 255), width=2)
        draw.ellipse([cx - 28, eye_y - 3, cx - 14, eye_y + 5], fill=(240, 240, 235, 255))
        draw.ellipse([cx + 14, eye_y - 3, cx + 28, eye_y + 5], fill=(240, 240, 235, 255))
        draw.ellipse([cx - 23, eye_y - 2, cx - 18, eye_y + 3], fill=(35, 45, 55, 255))
        draw.ellipse([cx + 19, eye_y - 2, cx + 24, eye_y + 3], fill=(35, 45, 55, 255))
        draw.line([cx - 30, eye_y - 2, cx - 12, eye_y - 2], fill=(130, 90, 60, 255), width=2)
        draw.line([cx + 12, eye_y - 2, cx + 30, eye_y - 2], fill=(130, 90, 60, 255), width=2)

        draw.line([cx, cy - 6, cx - 4, cy + 12], fill=(170, 120, 85, 255), width=2)
        draw.line([cx - 4, cy + 12, cx + 4, cy + 12], fill=(170, 120, 85, 255), width=2)

        mouth_y = cy + 22
        if emotion == "annoyed":
            draw.line([cx - 16, mouth_y + 3, cx + 16, mouth_y - 2], fill=(110, 65, 45, 255), width=3)
        elif emotion == "engaged":
            draw.line([cx - 14, mouth_y, cx + 14, mouth_y], fill=(110, 65, 45, 255), width=3)
            draw.arc([cx - 14, mouth_y - 6, cx + 14, mouth_y + 4], 0, 180, fill=(110, 65, 45, 255), width=2)
        else:
            draw.line([cx - 16, mouth_y, cx + 16, mouth_y], fill=(110, 65, 45, 255), width=3)

    elif name == "darla":
        cardigan_col = (127, 75, 134, 255)
        draw.polygon([(cx - 75, size - 8), (cx + 75, size - 8), (cx + 50, cy + 50), (cx - 50, cy + 50)], fill=cardigan_col)
        draw.polygon([(cx - 20, cy + 50), (cx + 20, cy + 50), (cx, cy + 70)], fill=(60, 38, 68, 255))

        skin = (201, 143, 103, 255)
        draw.ellipse([cx - 48, cy - 55, cx + 48, cy + 20], fill=(45, 30, 25, 255))
        draw.ellipse([cx - 38, cy - 40, cx + 38, cy + 35], fill=skin, outline=(160, 105, 75, 255), width=2)
        draw.arc([cx - 44, cy - 58, cx + 44, cy - 20], 180, 360, fill=(45, 30, 25, 255), width=14)
        draw.ellipse([cx - 44, cy - 35, cx - 32, cy + 10], fill=(45, 30, 25, 255))
        draw.ellipse([cx + 32, cy - 35, cx + 44, cy + 10], fill=(45, 30, 25, 255))

        eye_y = cy - 6
        draw.ellipse([cx - 26, eye_y - 4, cx - 12, eye_y + 4], fill=(245, 245, 245, 255))
        draw.ellipse([cx + 12, eye_y - 4, cx + 26, eye_y + 4], fill=(245, 245, 245, 255))
        pupil_x_off = 3 if emotion != "annoyed" else -3
        draw.ellipse([cx - 20 + pupil_x_off, eye_y - 3, cx - 15 + pupil_x_off, eye_y + 3], fill=(30, 20, 35, 255))
        draw.ellipse([cx + 18 + pupil_x_off, eye_y - 3, cx + 23 + pupil_x_off, eye_y + 3], fill=(30, 20, 35, 255))

        brow_y = cy - 16
        if emotion == "annoyed":
            draw.arc([cx - 28, brow_y - 6, cx - 10, brow_y + 6], 180, 360, fill=(45, 30, 25, 255), width=3)
            draw.line([cx + 10, brow_y + 4, cx + 28, brow_y - 4], fill=(45, 30, 25, 255), width=3)
        else:
            draw.arc([cx - 28, brow_y - 4, cx - 10, brow_y + 4], 180, 360, fill=(45, 30, 25, 255), width=3)
            draw.arc([cx + 10, brow_y - 8, cx + 28, brow_y + 4], 180, 360, fill=(45, 30, 25, 255), width=3)

        draw.line([cx, cy - 6, cx + 2, cy + 10], fill=(165, 110, 80, 255), width=2)
        mouth_y = cy + 20
        if emotion == "annoyed":
            draw.line([cx - 14, mouth_y + 2, cx + 14, mouth_y], fill=(140, 50, 60, 255), width=3)
        else:
            draw.arc([cx - 12, mouth_y - 6, cx + 16, mouth_y + 6], 10, 170, fill=(160, 50, 70, 255), width=3)

        mug_x, mug_y = cx + 38, size - 50
        draw.rectangle([mug_x, mug_y, mug_x + 28, mug_y + 35], fill=(239, 143, 77, 255), outline=(180, 90, 40, 255), width=2)
        draw.arc([mug_x + 22, mug_y + 6, mug_x + 36, mug_y + 26], 270, 90, fill=(239, 143, 77, 255), width=3)

    elif name == "tammy":
        blazer_col = (142, 54, 93, 255)
        draw.polygon([(cx - 75, size - 8), (cx + 75, size - 8), (cx + 45, cy + 45), (cx - 45, cy + 45)], fill=blazer_col)
        draw.polygon([(cx - 18, cy + 45), (cx + 18, cy + 45), (cx, cy + 68)], fill=(232, 224, 206, 255))

        skin = (224, 173, 134, 255)
        draw.polygon([(cx - 46, cy - 55), (cx + 46, cy - 55), (cx + 48, cy + 15), (cx - 48, cy + 15)], fill=(35, 20, 28, 255))
        draw.polygon([(cx - 36, cy - 40), (cx + 36, cy - 40), (cx + 28, cy + 35), (cx, cy + 42), (cx - 28, cy + 35)], fill=skin, outline=(170, 120, 90, 255))

        glass_y = cy - 8
        draw.rectangle([cx - 30, glass_y - 6, cx - 8, glass_y + 8], outline=(180, 30, 60, 255), width=2)
        draw.rectangle([cx + 8, glass_y - 6, cx + 30, glass_y + 8], outline=(180, 30, 60, 255), width=2)
        draw.line([cx - 8, glass_y, cx + 8, glass_y], fill=(180, 30, 60, 255), width=2)

        draw.ellipse([cx - 24, glass_y - 2, cx - 14, glass_y + 4], fill=(240, 240, 240, 255))
        draw.ellipse([cx + 14, glass_y - 2, cx + 24, glass_y + 4], fill=(240, 240, 240, 255))
        draw.ellipse([cx - 20, glass_y - 1, cx - 17, glass_y + 2], fill=(30, 20, 25, 255))
        draw.ellipse([cx + 18, glass_y - 1, cx + 21, glass_y + 2], fill=(30, 20, 25, 255))

        draw.line([cx - 15, cy + 22, cx + 15, cy + 22], fill=(140, 60, 75, 255), width=2)

        cb_x, cb_y = cx - 65, size - 60
        draw.rectangle([cb_x, cb_y, cb_x + 35, cb_y + 50], fill=(210, 180, 140, 255), outline=(120, 90, 60, 255), width=2)
        draw.rectangle([cb_x + 10, cb_y - 6, cb_x + 25, cb_y + 4], fill=(180, 190, 200, 255))

    elif name == "kevin":
        draw.polygon([(cx - 75, size - 8), (cx + 75, size - 8), (cx + 50, cy + 50), (cx - 50, cy + 50)], fill=(231, 111, 81, 255))
        draw.polygon([(cx - 15, cy + 50), (cx + 15, cy + 50), (cx, cy + 70)], fill=(255, 255, 255, 255))
        draw.line([cx - 20, cy + 50, cx, cy + 90], fill=(56, 189, 248, 255), width=4)
        draw.line([cx + 20, cy + 50, cx, cy + 90], fill=(56, 189, 248, 255), width=4)
        draw.rectangle([cx - 18, cy + 20, cx + 18, cy + 52], fill=(210, 160, 120, 255))
        draw.ellipse([cx - 38, cy - 40, cx + 38, cy + 35], fill=(235, 190, 150, 255), outline=(170, 125, 85, 255), width=2)
        draw.polygon([(cx - 42, cy - 20), (cx - 44, cy - 50), (cx + 38, cy - 58), (cx + 46, cy - 22), (cx + 32, cy - 35), (cx - 28, cy - 32)], fill=(90, 55, 30, 255))
        eye_y = cy - 6
        draw.ellipse([cx - 28, eye_y - 8, cx - 8, eye_y + 8], fill=(255, 255, 255, 255), outline=(100, 70, 50, 255), width=2)
        draw.ellipse([cx + 8, eye_y - 8, cx + 28, eye_y + 8], fill=(255, 255, 255, 255), outline=(100, 70, 50, 255), width=2)
        draw.ellipse([cx - 20, eye_y - 4, cx - 14, eye_y + 2], fill=(30, 20, 10, 255))
        draw.ellipse([cx + 14, eye_y - 4, cx + 20, eye_y + 2], fill=(30, 20, 10, 255))
        draw.ellipse([cx + 32, cy - 22, cx + 40, cy - 10], fill=(125, 211, 252, 255))
        draw.line([cx - 28, eye_y - 14, cx - 10, eye_y - 20], fill=(90, 55, 30, 255), width=3)
        draw.line([cx + 10, eye_y - 20, cx + 28, eye_y - 14], fill=(90, 55, 30, 255), width=3)
        draw.line([cx - 16, cy + 22, cx + 16, cy + 22], fill=(150, 70, 50, 255), width=3)

    return img


def create_item_icon(item_id: str, size: int = 128) -> Image.Image:
    """Generate pixel/retro adventure item icons."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = size // 2, size // 2
    draw.rounded_rectangle([4, 4, size - 5, size - 5], radius=8, fill=(18, 24, 34, 230), outline=(50, 70, 95, 255), width=2)

    if "evidence_bag" in item_id:
        bx, by, bw, bh = cx - 36, cy - 42, 72, 84
        draw.rectangle([bx, by, bx + bw, by + bh], fill=(220, 235, 245, 170), outline=(160, 200, 230, 240), width=2)
        draw.rectangle([bx, by, bx + bw, by + 10], fill=(180, 40, 40, 255))
        draw.rectangle([bx + 6, by + 25, bx + bw - 6, by + 55], fill=(245, 205, 50, 255), outline=(120, 90, 10, 255), width=1)
        draw.text((bx + 10, by + 30), "EVIDENCE", fill=(20, 20, 20, 255))
        draw.text((bx + 8, by + 42), "NOT MY BIZ", fill=(160, 20, 20, 255))

    elif "bagged_wetberry" in item_id:
        bx, by, bw, bh = cx - 36, cy - 42, 72, 84
        draw.rectangle([bx, by, bx + bw, by + bh], fill=(220, 235, 245, 170), outline=(160, 200, 230, 240), width=2)
        draw.rectangle([bx, by, bx + bw, by + 10], fill=(180, 40, 40, 255))
        draw.ellipse([cx - 20, cy - 8, cx + 20, cy + 28], fill=(255, 62, 138, 230), outline=(255, 180, 210, 255), width=2)
        draw.polygon([(cx - 12, cy - 12), (cx, cy - 4), (cx + 12, cy - 12), (cx, cy - 8)], fill=(125, 255, 145, 255))
        draw.rectangle([bx + 6, by + 58, bx + bw - 6, by + 76], fill=(245, 205, 50, 255))
        draw.text((bx + 8, by + 61), "CONTAINED", fill=(20, 20, 20, 255))

    elif "wetberry" in item_id:
        draw.ellipse([cx - 28, cy - 24, cx + 28, cy + 32], fill=(255, 62, 138, 255), outline=(255, 190, 220, 255), width=3)
        draw.polygon([(cx - 20, cy - 32), (cx - 4, cy - 20), (cx, cy - 38), (cx + 4, cy - 20), (cx + 20, cy - 32), (cx, cy - 18)], fill=(125, 255, 145, 255), outline=(50, 180, 80, 255))
        for sx, sy in [(-12, -4), (6, -2), (-6, 12), (10, 16), (0, 22)]:
            draw.ellipse([cx + sx - 2, cy + sy - 2, cx + sx + 2, cy + sy + 2], fill=(255, 240, 160, 255))

    elif "damp_napkin" in item_id:
        nx, ny = cx - 30, cy - 30
        draw.polygon([(nx, ny + 10), (nx + 20, ny), (nx + 58, ny + 8), (nx + 62, ny + 55), (nx + 10, ny + 62), (nx - 4, ny + 40)], fill=(235, 235, 230, 255), outline=(170, 170, 160, 255), width=2)
        draw.ellipse([cx - 14, cy - 10, cx + 18, cy + 18], fill=(255, 80, 140, 180))

    elif "accountability_token" in item_id:
        draw.ellipse([cx - 36, cy - 36, cx + 36, cy + 36], fill=(212, 175, 55, 255), outline=(130, 100, 20, 255), width=3)
        draw.ellipse([cx - 28, cy - 28, cx + 28, cy + 28], outline=(160, 130, 30, 255), width=2)
        draw.text((cx - 18, cy - 10), "ACC-1", fill=(60, 45, 10, 255))

    elif "freezer_blessing" in item_id:
        draw.polygon([(cx, cy - 38), (cx + 32, cy), (cx, cy + 38), (cx - 32, cy)], fill=(120, 220, 255, 220), outline=(220, 250, 255, 255), width=2)
        draw.line([cx, cy - 38, cx, cy + 38], fill=(255, 255, 255, 255), width=2)
        draw.line([cx - 32, cy, cx + 32, cy], fill=(255, 255, 255, 255), width=2)

    elif "casserole_lid" in item_id:
        draw.polygon([(cx - 32, cy - 25), (cx + 28, cy - 35), (cx + 36, cy + 20), (cx - 15, cy + 38), (cx - 35, cy + 10)], fill=(200, 215, 225, 190), outline=(240, 250, 255, 255), width=2)
        draw.line([cx - 10, cy - 20, cx + 12, cy + 15], fill=(255, 100, 50, 200), width=2)

    elif "ancient_mayonnaise" in item_id:
        jx, jy = cx - 24, cy - 32
        draw.rectangle([jx, jy + 14, jx + 48, jy + 70], fill=(240, 235, 190, 240), outline=(120, 115, 80, 255), width=2)
        draw.rectangle([jx + 6, jy, jx + 42, jy + 14], fill=(180, 60, 50, 255))
        draw.rectangle([jx + 6, jy + 28, jx + 42, jy + 52], fill=(220, 210, 160, 255))
        draw.text((jx + 10, jy + 34), "MAYO", fill=(40, 35, 20, 255))

    elif "evidence_ledger" in item_id:
        lx, ly = cx - 32, cy - 40
        draw.rectangle([lx, ly, lx + 64, ly + 80], fill=(90, 30, 40, 255), outline=(50, 15, 20, 255), width=2)
        draw.rectangle([lx + 6, ly + 10, lx + 58, ly + 70], fill=(230, 220, 195, 255))
        draw.line([lx + 6, ly + 25, lx + 58, ly + 25], fill=(160, 40, 40, 255), width=1)
        draw.line([lx + 6, ly + 40, lx + 58, ly + 40], fill=(160, 40, 40, 255), width=1)
        draw.line([lx + 6, ly + 55, lx + 58, ly + 55], fill=(160, 40, 40, 255), width=1)

    elif "verdict_seal" in item_id or "summons" in item_id:
        draw.rectangle([cx - 30, cy - 38, cx + 30, cy + 38], fill=(240, 230, 200, 255), outline=(160, 140, 100, 255), width=2)
        draw.ellipse([cx - 18, cy - 10, cx + 18, cy + 26], fill=(170, 30, 40, 255), outline=(110, 15, 20, 255), width=2)
        draw.text((cx - 10, cy + 2), "HIVE", fill=(255, 230, 180, 255))

    else:
        draw.ellipse([cx - 25, cy - 25, cx + 25, cy + 25], fill=(100, 160, 200, 255), outline=(200, 230, 255, 255), width=2)

    return img


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    campaign_gen = root / "campaigns" / "strawberry_omen" / "assets" / "generated"
    static_assets = root / "hive_lattice" / "web_app" / "static" / "assets"

    for d in [
        campaign_gen / "rooms",
        campaign_gen / "portraits",
        campaign_gen / "items",
        campaign_gen / "tokens",
        campaign_gen / "maps",
        static_assets / "rooms",
        static_assets / "portraits",
        static_assets / "items",
        static_assets / "tokens",
    ]:
        d.mkdir(parents=True, exist_ok=True)

    print("Building Breakroom illustrated room background...")
    breakroom_bg = create_breakroom_background(1024, 768)
    breakroom_bg.save(campaign_gen / "rooms" / "room.breakroom.central_table.png", "PNG")
    breakroom_bg.save(campaign_gen / "rooms" / "room.breakroom.png", "PNG")
    breakroom_bg.save(campaign_gen / "rooms" / "room.breakroom.illustrated.png", "PNG")
    breakroom_bg.save(static_assets / "rooms" / "room.breakroom.central_table.png", "PNG")
    breakroom_bg.save(static_assets / "rooms" / "room.breakroom.png", "PNG")

    print("Building character dialogue portraits...")
    portraits = [
        ("keith", "neutral"),
        ("keith", "annoyed"),
        ("keith", "engaged"),
        ("darla", "neutral"),
        ("darla", "annoyed"),
        ("darla", "engaged"),
        ("tammy", "procedural"),
        ("kevin", "neutral"),
    ]
    for char, emo in portraits:
        filename = f"{char}_{emo}.png"
        p_img = create_portrait(char, emo, 256)
        p_img.save(campaign_gen / "portraits" / filename, "PNG")
        p_img.save(static_assets / "portraits" / filename, "PNG")
        p_img.save(campaign_gen / "tokens" / f"token.{char}.png", "PNG")
        p_img.save(static_assets / "tokens" / f"token.{char}.png", "PNG")

    print("Building tactical inventory item icons...")
    items = [
        "item.evidence_bag_not_my_business",
        "item.bagged_wetberry_evidence",
        "item.wetberry",
        "item.damp_napkin",
        "item.accountability_token",
        "item.freezer_blessing",
        "item.casserole_lid_fragment",
        "item.ancient_mayonnaise",
        "item.condiment_sigil",
        "item.evidence_ledger",
        "item.writ_of_summons",
        "item.verdict_seal",
    ]
    for item_id in items:
        filename = f"{item_id}.png"
        icon_img = create_item_icon(item_id, 128)
        icon_img.save(campaign_gen / "items" / filename, "PNG")
        icon_img.save(static_assets / "items" / filename, "PNG")

    print("Updating generated_manifest.json...")
    gen_manifest_path = campaign_gen / "generated_manifest.json"
    
    # Load existing generated_manifest if available to keep previous mappings
    existing_assets = []
    if gen_manifest_path.exists():
        try:
            with gen_manifest_path.open("r", encoding="utf-8") as f:
                data = json.load(f)
                existing_assets = data.get("generated_assets", [])
        except Exception:
            pass

    existing_by_id = {a["asset_id"]: a for a in existing_assets}
    existing_by_id["room.breakroom.central_table"] = {"asset_id": "room.breakroom.central_table", "category": "rooms", "path": "assets/generated/rooms/room.breakroom.central_table.png"}
    existing_by_id["room.breakroom"] = {"asset_id": "room.breakroom", "category": "rooms", "path": "assets/generated/rooms/room.breakroom.png"}
    existing_by_id["room.breakroom.illustrated"] = {"asset_id": "room.breakroom.illustrated", "category": "rooms", "path": "assets/generated/rooms/room.breakroom.illustrated.png"}

    for char, emo in portraits:
        existing_by_id[f"portrait.{char}.{emo}"] = {
            "asset_id": f"portrait.{char}.{emo}",
            "category": "portraits",
            "path": f"assets/generated/portraits/{char}_{emo}.png"
        }
        existing_by_id[f"token.{char}"] = {
            "asset_id": f"token.{char}",
            "category": "tokens",
            "path": f"assets/generated/tokens/token.{char}.png"
        }

    for item_id in items:
        existing_by_id[item_id] = {
            "asset_id": item_id,
            "category": "items",
            "path": f"assets/generated/items/{item_id}.png"
        }

    manifest_data = {
        "version": "1.2.0",
        "generated_assets": list(existing_by_id.values())
    }
    with gen_manifest_path.open("w", encoding="utf-8") as f:
        json.dump(manifest_data, f, indent=2)

    create_room_system_files()
    create_kevin_files()

    print("Visual assets successfully generated and synced.")


if __name__ == "__main__":
    main()
