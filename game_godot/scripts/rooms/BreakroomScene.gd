class_name BreakroomScene
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
