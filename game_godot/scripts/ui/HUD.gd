class_name HUD
extends Control

# Top HUD with menu shortcuts, room title, and notification banner.

@onready var room_title_label: Label = $TopBar/HBoxContainer/RoomTitleLabel
@onready var status_btn: Button = $TopBar/HBoxContainer/StatusButton
@onready var journal_btn: Button = $TopBar/HBoxContainer/JournalButton
@onready var pause_btn: Button = $TopBar/HBoxContainer/PauseButton
@onready var notify_banner: PanelContainer = $NotificationBanner
@onready var notify_label: Label = $NotificationBanner/MarginContainer/NotifyLabel

var notify_timer: float = 0.0


func _ready() -> void:
	notify_banner.visible = false
	status_btn.pressed.connect(func(): EventBus.overlay_opened.emit("status"))
	journal_btn.pressed.connect(func(): EventBus.overlay_opened.emit("journal"))
	pause_btn.pressed.connect(func(): EventBus.overlay_opened.emit("pause"))

	EventBus.notification_posted.connect(show_notification)
	EventBus.world_state_changed.connect(_on_world_state_changed)
	_update_hud()


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


func _update_hud() -> void:
	var loc_id = GameRuntime.world_state.current_location
	var loc_meta = GameRuntime.loader.get_location(loc_id)
	room_title_label.text = loc_meta.get("name", "Breakroom of Inappropriate Discovery")
