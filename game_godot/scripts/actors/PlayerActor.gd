class_name PlayerActor
extends CharacterBody2D

# Protagonist Actor with strictly grounded Foot Anchor at (0, 0).

@export var speed: float = 240.0

var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var pending_callback: Callable = Callable()

var step_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	y_sort_enabled = true
	target_position = global_position


func _physics_process(delta: float) -> void:
	if is_moving:
		var diff = target_position - global_position
		var dist = diff.length()
		if dist > 6.0:
			var dir = diff.normalized()
			velocity = dir * speed
			move_and_slide()

			# Flip sprite facing direction
			if abs(dir.x) > 0.1:
				sprite.flip_h = dir.x < 0

			# Subtle walking bob
			step_timer += delta * 12.0
			sprite.position.y = -88.0 + sin(step_timer) * 3.0

			# Periodic footsteps
			if int(step_timer) % 4 == 0:
				AudioManager.play_footstep()
		else:
			# Arrived at destination
			global_position = target_position
			is_moving = false
			velocity = Vector2.ZERO
			sprite.position.y = -88.0 # Reset idle vertical position
			if pending_callback.is_valid():
				var cb = pending_callback
				pending_callback = Callable()
				cb.call()


func walk_to(destination: Vector2, on_arrived: Callable = Callable()) -> void:
	target_position = destination
	pending_callback = on_arrived
	is_moving = true
	step_timer = 0.0


func stop() -> void:
	is_moving = false
	velocity = Vector2.ZERO
	pending_callback = Callable()
