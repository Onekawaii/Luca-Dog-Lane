class_name HUD
extends Control

# Top HUD with menu shortcuts, room title, notification banner, and mobile virtual stick.

@onready var room_title_label: Label = $TopBar/HBoxContainer/RoomTitleLabel
@onready var status_btn: Button = $TopBar/HBoxContainer/StatusButton
@onready var journal_btn: Button = $TopBar/HBoxContainer/JournalButton
@onready var pause_btn: Button = $TopBar/HBoxContainer/PauseButton
@onready var notify_banner: PanelContainer = $NotificationBanner
@onready var notify_label: Label = $NotificationBanner/MarginContainer/NotifyLabel
@onready var mobile_stick: Control = get_node_or_null("MobileStick")
@onready var stick_knob: Control = get_node_or_null("MobileStick/StickBase/StickKnob")

var notify_timer: float = 0.0
var is_dragging_stick: bool = false
var stick_center: Vector2 = Vector2.ZERO
var stick_radius: float = 48.0


func _ready() -> void:
	notify_banner.visible = false
	status_btn.pressed.connect(func(): EventBus.overlay_opened.emit("status"))
	journal_btn.pressed.connect(func(): EventBus.overlay_opened.emit("journal"))
	pause_btn.pressed.connect(func(): EventBus.overlay_opened.emit("pause"))

	EventBus.notification_posted.connect(show_notification)
	EventBus.world_state_changed.connect(_on_world_state_changed)
	EventBus.room_entered.connect(_on_room_entered)
	_update_hud()

	# Mobile virtual control presentation
	var is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("touchscreen")
	if mobile_stick:
		mobile_stick.visible = is_mobile
	if is_mobile:
		status_btn.text = "Status"
		journal_btn.text = "Journal"
		pause_btn.text = "Menu"


func _process(delta: float) -> void:
	if notify_timer > 0.0:
		notify_timer -= delta
		if notify_timer <= 0.0:
			notify_banner.visible = false


func show_notification(msg: String) -> void:
	notify_label.text = msg
	notify_banner.visible = true
	notify_timer = 4.0


func _on_world_state_changed(_delta: Dictionary) -> void:
	_update_hud()


func _on_room_entered(_room_id: String) -> void:
	_update_hud()


func _update_hud() -> void:
	var loc_id = GameRuntime.world_state.current_location
	var loc_meta = GameRuntime.loader.get_location(loc_id)
	room_title_label.text = loc_meta.get("name", "Breakroom of Inappropriate Discovery")

