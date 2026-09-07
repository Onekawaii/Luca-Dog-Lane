class_name PlayerActor
extends CharacterBody2D

# Protagonist Actor with strictly grounded Foot Anchor at (0, 0),
# Free-roam locomotion (WASD/Arrows/Mobile), acceleration/friction,
# and NavigationAgent2D click-to-walk approach.

@export var max_speed: float = 240.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0

var can_move: bool = true
var is_navigating: bool = false
var pending_callback: Callable = Callable()

var step_timer: float = 0.0
var virtual_input_vector: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")


func _ready() -> void:
	y_sort_enabled = true
	EventBus.virtual_move_input.connect(_on_virtual_move_input)


func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		_update_visuals(delta, false)
		return

	# 1. Check direct free movement input (WASD / Arrows / Mobile Virtual Stick)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if virtual_input_vector != Vector2.ZERO:
		input_dir = virtual_input_vector

	if input_dir != Vector2.ZERO:
		# Direct manual free-roam movement overrides click-to-walk navigation
		if is_navigating:
			stop_navigation()

		var target_vel = input_dir.normalized() * max_speed
		velocity = velocity.move_toward(target_vel, acceleration * delta)
		move_and_slide()
		_update_visuals(delta, true, input_dir)
		return

	# 2. Pathfinding click-to-walk navigation via NavigationAgent2D
	if is_navigating and is_instance_valid(nav_agent):
		if nav_agent.is_navigation_finished():
			stop_navigation(true)
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			move_and_slide()
			_update_visuals(delta, false)
		else:
			var next_path_pos = nav_agent.get_next_path_position()
			var diff = next_path_pos - global_position
			var dir = diff.normalized()
			var target_vel = dir * max_speed
			velocity = velocity.move_toward(target_vel, acceleration * delta)
			move_and_slide()
			_update_visuals(delta, true, dir)
			return

	# 3. Deceleration / Idle state
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	_update_visuals(delta, velocity.length() > 10.0, velocity.normalized())


func navigate_to(destination: Vector2, on_arrived: Callable = Callable()) -> void:
	pending_callback = on_arrived
	if is_instance_valid(nav_agent):
		nav_agent.target_position = destination
		is_navigating = true
	else:
		is_navigating = true


func walk_to(destination: Vector2, on_arrived: Callable = Callable()) -> void:
	navigate_to(destination, on_arrived)


func stop_navigation(trigger_callback: bool = false) -> void:
	is_navigating = false
	if trigger_callback and pending_callback.is_valid():
		var cb = pending_callback
		pending_callback = Callable()
		cb.call()
	else:
		pending_callback = Callable()


func stop() -> void:
	stop_navigation(false)
	velocity = Vector2.ZERO


func _on_virtual_move_input(input_vec: Vector2) -> void:
	virtual_input_vector = input_vec


func _update_visuals(delta: float, moving: bool, move_dir: Vector2 = Vector2.ZERO) -> void:
	if not sprite:
		return

	if moving and move_dir != Vector2.ZERO:
		if abs(move_dir.x) > 0.1:
			sprite.flip_h = move_dir.x < 0

		step_timer += delta * 12.0
		sprite.position.y = -88.0 + sin(step_timer) * 3.0

		if int(step_timer) % 4 == 0:
			AudioManager.play_footstep()
	else:
		step_timer = 0.0
		sprite.position.y = -88.0


func _draw() -> void:
	if GameRuntime.debug_mode:
		draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.9, 0.3, 0.8)) # Foot anchor at (0,0)
		draw_line(Vector2(-12, 0), Vector2(12, 0), Color(0.2, 0.9, 0.3, 1.0), 2.0)
		draw_line(Vector2(0, -12), Vector2(0, 12), Color(0.2, 0.9, 0.3, 1.0), 2.0)
