class_name LucaWeatherSystem
extends Node3D

const WEATHER_STATES := ["clear", "overcast", "rain", "storm", "fog", "snow"]

var current_weather := "clear"
var current_biome := "sunmeadow_fields"
var _environment: Environment
var _sun: DirectionalLight3D
var _sky_material: ProceduralSkyMaterial
var _player: Node3D
var _rng := RandomNumberGenerator.new()
var _weather_timer := 0.0
var _lightning_timer := 0.0
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _outdoor_active := true

func configure(player: Node3D, environment: Environment, sun: DirectionalLight3D, sky_material: ProceduralSkyMaterial, seed_value: int) -> void:
	_player = player
	_environment = environment
	_sun = sun
	_sky_material = sky_material
	_rng.seed = seed_value + 77441
	_build_precipitation()
	_apply_weather("clear", false)
	_schedule_weather()
func set_biome(biome: String) -> void:
	current_biome = biome

func set_outdoor_active(active: bool) -> void:
	_outdoor_active = active
	if is_instance_valid(_rain):
		_rain.emitting = active and current_weather in ["rain", "storm"]
	if is_instance_valid(_snow):
		_snow.emitting = active and current_weather == "snow"
	if active:
		_apply_weather(current_weather, false)

func _process(delta: float) -> void:
	if is_instance_valid(_player):
		global_position = _player.global_position + Vector3(0.0, 16.0, 0.0)
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_apply_weather(_choose_weather(), true)
		_schedule_weather()
	if current_weather == "storm":
		_lightning_timer -= delta
		if _lightning_timer <= 0.0:
			_flash_lightning()
			_lightning_timer = _rng.randf_range(4.0, 11.0)

func _schedule_weather() -> void:
	_weather_timer = _rng.randf_range(55.0, 125.0)
	_lightning_timer = _rng.randf_range(4.0, 10.0)

func _choose_weather() -> String:
	var roll := _rng.randf()
	if current_biome in ["cloudstep_highlands", "moonfrost_basin", "starlight_range"] and roll < 0.30:
		return "snow"
	if current_biome in ["creekglass_wetlands", "firefly_marsh"] and roll < 0.48:
		return "rain"
	if roll < 0.13:
		return "storm"
	if roll < 0.30:
		return "rain"
	if roll < 0.47:
		return "overcast"
	if roll < 0.58:
		return "fog"
	return "clear"
func _apply_weather(next_weather: String, announce: bool) -> void:
	current_weather = next_weather if next_weather in WEATHER_STATES else "clear"
	if is_instance_valid(_rain):
		_rain.emitting = _outdoor_active and current_weather in ["rain", "storm"]
	if is_instance_valid(_snow):
		_snow.emitting = _outdoor_active and current_weather == "snow"
	if not _outdoor_active:
		return
	if _environment != null:
		_environment.fog_enabled = current_weather != "clear"
		_environment.fog_density = _fog_density(current_weather)
		_environment.fog_light_energy = 0.58 if current_weather in ["storm", "fog"] else 0.78
	if is_instance_valid(_sun):
		_sun.light_energy = _sun_energy(current_weather)
	if _sky_material != null:
		_apply_sky_palette(current_weather)
	if announce:
		EventBus.notification_posted.emit("WEATHER // " + current_weather.to_upper())

func _fog_density(weather: String) -> float:
	match weather:
		"clear": return 0.0015
		"overcast": return 0.0040
		"rain": return 0.0060
		"storm": return 0.0100
		"fog": return 0.0180
		"snow": return 0.0075
	return 0.0035
func _sun_energy(weather: String) -> float:
	match weather:
		"clear": return 1.35
		"overcast": return 0.78
		"rain": return 0.62
		"storm": return 0.32
		"fog": return 0.48
		"snow": return 0.95
	return 1.0

func _apply_sky_palette(weather: String) -> void:
	match weather:
		"storm":
			_sky_material.sky_top_color = Color(0.055, 0.075, 0.10)
			_sky_material.sky_horizon_color = Color(0.18, 0.21, 0.23)
		"rain", "overcast":
			_sky_material.sky_top_color = Color(0.20, 0.27, 0.33)
			_sky_material.sky_horizon_color = Color(0.48, 0.52, 0.52)
		"fog":
			_sky_material.sky_top_color = Color(0.42, 0.46, 0.46)
			_sky_material.sky_horizon_color = Color(0.62, 0.64, 0.61)
		"snow":
			_sky_material.sky_top_color = Color(0.39, 0.50, 0.62)
			_sky_material.sky_horizon_color = Color(0.76, 0.79, 0.77)
		_:
			_sky_material.sky_top_color = Color(0.18, 0.39, 0.67)
			_sky_material.sky_horizon_color = Color(0.72, 0.78, 0.72)
func _flash_lightning() -> void:
	if not is_instance_valid(_sun):
		return
	var original := _sun.light_energy
	_sun.light_energy = 3.8
	var tree := get_tree()
	if tree != null:
		tree.create_timer(0.10).timeout.connect(func():
			if is_instance_valid(_sun):
				_sun.light_energy = original
		)

func _build_precipitation() -> void:
	_rain = _make_particles("Rain", false)
	_snow = _make_particles("Snow", true)
	add_child(_rain)
	add_child(_snow)

func _make_particles(node_name: String, snow_mode: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = 520 if snow_mode else 900
	particles.lifetime = 3.4 if snow_mode else 1.3
	particles.visibility_aabb = AABB(Vector3(-30, -28, -30), Vector3(60, 56, 60))
	particles.emitting = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(26.0, 2.0, 26.0)
	process.direction = Vector3(0.18, -1.0, 0.06)
	process.spread = 8.0 if snow_mode else 3.0
	process.initial_velocity_min = 2.5 if snow_mode else 22.0
	process.initial_velocity_max = 5.0 if snow_mode else 31.0
	process.gravity = Vector3(0.8, -0.8, 0.3) if snow_mode else Vector3(3.0, -18.0, 1.0)
	particles.process_material = process

	var quad := QuadMesh.new()
	quad.size = Vector2(0.10, 0.10) if snow_mode else Vector2(0.035, 0.72)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(0.92, 0.96, 1.0, 0.78) if snow_mode else Color(0.62, 0.76, 0.90, 0.52)
	quad.material = material
	particles.draw_pass_1 = quad
	return particles
