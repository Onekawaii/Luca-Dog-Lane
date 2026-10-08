extends Control
# True top-down terrain chart. Height samples come from the active map terrain.
const EXTENT := 480.0
const GRID := 28
var game: Node
var cached_heights: PackedFloat32Array = PackedFloat32Array()
var refresh_time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(454, 438)
	custom_minimum_size = size

func _process(delta: float) -> void:
	if not visible or not is_visible_in_tree():
		return
	refresh_time += delta
	if refresh_time >= 0.3:
		refresh_time = 0.0
		queue_redraw()

func _world_to_map(x: float, z: float) -> Vector2:
	return Vector2(
		clampf((x + EXTENT) / (EXTENT * 2.0), 0.0, 1.0) * size.x,
		clampf((z + EXTENT) / (EXTENT * 2.0), 0.0, 1.0) * size.y
	)

func _ensure_heights() -> void:
	if not cached_heights.is_empty() or game == null:
		return
	for z in range(GRID):
		for x in range(GRID):
			var world_x := (float(x) + 0.5) / GRID * EXTENT * 2.0 - EXTENT
			var world_z := (float(z) + 0.5) / GRID * EXTENT * 2.0 - EXTENT
			cached_heights.append(float(game.call("_surface_height", world_x, world_z)))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.10, 0.13), true)
	if game == null:
		return
	_ensure_heights()
	var step := Vector2(size.x / GRID, size.y / GRID)
	for z in range(GRID):
		for x in range(GRID):
			var elevation := cached_heights[z * GRID + x]
			var ratio := clampf((elevation + 8.0) / 88.0, 0.0, 1.0)
			var tint := Color(0.18, 0.32, 0.25).lerp(Color(0.75, 0.76, 0.59), ratio)
			draw_rect(Rect2(Vector2(x, z) * step, step + Vector2.ONE), tint, true)
	for mark in range(5):
		var k := float(mark) / 4.0
		draw_line(Vector2(k * size.x, 0), Vector2(k * size.x, size.y), Color(0.84, 0.90, 0.81, 0.15), 1.0)
		draw_line(Vector2(0, k * size.y), Vector2(size.x, k * size.y), Color(0.84, 0.90, 0.81, 0.15), 1.0)
	_draw_marker(Vector2(-155, -132), "EYE", Color(0.99, 0.51, 0.85))
	_draw_marker(Vector2(176, 148), "WAIL", Color(1.0, 0.40, 0.63))
	_draw_marker(Vector2(54, -42), "CAT", Color(0.98, 0.86, 0.43))
	var player = game.get("player")
	if player != null and is_instance_valid(player):
		_draw_marker(Vector2(player.global_position.x, player.global_position.z), "YOU", Color(0.99, 1.0, 0.98))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.68, 0.39, 0.74), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(8, 20), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _draw_marker(world_xz: Vector2, label_text: String, color: Color) -> void:
	var point := _world_to_map(world_xz.x, world_xz.y)
	draw_circle(point, 7.5, Color(0.05, 0.03, 0.07, 0.9))
	draw_circle(point, 4.5, color)
	draw_string(ThemeDB.fallback_font, point + Vector2(10, -7), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
