class_name KimiWorldPlan
extends RefCounted

const GENERATOR_VERSION := 2
const BIOME_SCHEMA_VERSION := 1
const BIOME_IDS: Array[StringName] = [
	&"riverlands",
	&"marsh",
	&"alpine_highlands",
	&"rocky_scree",
	&"cedar_swamp",
	&"badlands",
	&"dry_meadow",
	&"pine_forest",
	&"birch_grove",
	&"mixed_forest",
]

var seed: int = 6060

func _init(world_seed: int = 6060) -> void:
	seed = world_seed

static func _fade(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

static func value_noise2(noise_seed: int, x: float, z: float) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x - float(ix)
	var fz := z - float(iz)
	var v00 := KimiDeterministic.randf_from_int(KimiDeterministic.hash2i(noise_seed, ix, iz))
	var v10 := KimiDeterministic.randf_from_int(KimiDeterministic.hash2i(noise_seed, ix + 1, iz))
	var v01 := KimiDeterministic.randf_from_int(KimiDeterministic.hash2i(noise_seed, ix, iz + 1))
	var v11 := KimiDeterministic.randf_from_int(KimiDeterministic.hash2i(noise_seed, ix + 1, iz + 1))
	var ux := _fade(fx)
	var uz := _fade(fz)
	return lerpf(lerpf(v00, v10, ux), lerpf(v01, v11, ux), uz)

func fbm(x: float, z: float, octaves: int, frequency: float, salt: int) -> float:
	var amplitude := 1.0
	var total := 0.0
	var norm := 0.0
	var f := frequency
	for _i in octaves:
		total += value_noise2(seed ^ salt, x * f, z * f) * amplitude
		norm += amplitude
		amplitude *= 0.5
		f *= 2.0
	return total / norm

func terrain_height(world_x: float, world_z: float) -> float:
	var continents := fbm(world_x, world_z, 4, 0.0016, 101)
	var hills := fbm(world_x, world_z, 4, 0.0080, 202)
	var mountains := pow(fbm(world_x, world_z, 5, 0.0035, 303), 3.0) * 4.0
	return (continents - 0.5) * 20.0 + (hills - 0.5) * 24.0 + mountains * 90.0

func temperature_at(world_x: float, world_z: float) -> float:
	var latitude := clampf((world_z + 900.0) / 1800.0, 0.0, 1.0)
	var noise := fbm(world_x, world_z, 3, 0.0009, 404)
	return clampf(noise * 0.78 + latitude * 0.22, 0.0, 1.0)

func moisture_at(world_x: float, world_z: float) -> float:
	var broad := fbm(world_x, world_z, 3, 0.0011, 505)
	var local := fbm(world_x, world_z, 2, 0.0060, 506)
	var hydro := hydrology_influence(world_x, world_z)
	return clampf(broad * 0.67 + local * 0.23 + hydro * 0.28, 0.0, 1.0)

func ruggedness_at(world_x: float, world_z: float) -> float:
	var a := fbm(world_x, world_z, 3, 0.0090, 707)
	var b := fbm(world_x + 11.0, world_z - 17.0, 3, 0.0150, 708)
	return clampf(absf(a - b) * 2.8, 0.0, 1.0)

func primary_river_center_z(world_x: float) -> float:
	var phase := KimiDeterministic.randf_from_int(seed ^ 0x51A7) * TAU
	var broad := sin(world_x * 0.0105 + phase) * 42.0
	var noise := (fbm(world_x, -260.0, 3, 0.0052, 611) - 0.5) * 72.0
	return -260.0 + broad + noise

func primary_river_half_width(world_x: float) -> float:
	var width_noise := fbm(world_x, -260.0, 2, 0.0065, 612)
	return 8.5 + width_noise * 5.5

func primary_river_distance(world_x: float, world_z: float) -> float:
	return absf(world_z - primary_river_center_z(world_x))

func tributary_center_x(world_z: float, branch: int) -> float:
	var phase_seed := seed ^ (0x7311 + branch * 97)
	var phase := KimiDeterministic.randf_from_int(phase_seed) * TAU
	if branch == 0:
		return -285.0 + sin(world_z * 0.014 + phase) * 28.0
	return 305.0 + sin(world_z * 0.016 + phase) * 24.0

func tributary_distance(world_x: float, world_z: float, branch: int) -> float:
	var river_z := primary_river_center_z(world_x)
	if branch == 0:
		if world_z < river_z - 12.0 or world_z > 85.0:
			return 9999.0
	else:
		if world_z < river_z - 10.0 or world_z > -55.0:
			return 9999.0
	return absf(world_x - tributary_center_x(world_z, branch))

func lake_center() -> Vector2:
	var jitter_x := (KimiDeterministic.randf_from_int(seed ^ 0x41C3) - 0.5) * 22.0
	var jitter_z := (KimiDeterministic.randf_from_int(seed ^ 0x41C4) - 0.5) * 18.0
	return Vector2(-365.0 + jitter_x, -338.0 + jitter_z)

func lake_radius() -> float:
	return 38.0 + KimiDeterministic.randf_from_int(seed ^ 0x41C5) * 12.0

func hydrology_influence(world_x: float, world_z: float) -> float:
	var river_width := primary_river_half_width(world_x)
	var river := 1.0 - _smoothstep(river_width, river_width + 22.0, primary_river_distance(world_x, world_z))
	var trib_a := 1.0 - _smoothstep(5.0, 18.0, tributary_distance(world_x, world_z, 0))
	var trib_b := 1.0 - _smoothstep(4.5, 16.0, tributary_distance(world_x, world_z, 1))
	var lake_dist := Vector2(world_x, world_z).distance_to(lake_center())
	var marsh := 1.0 - _smoothstep(lake_radius(), lake_radius() + 36.0, lake_dist)
	return clampf(maxf(river, maxf(trib_a, maxf(trib_b, marsh))), 0.0, 1.0)

func water_kind_at(world_x: float, world_z: float) -> StringName:
	var lake_dist := Vector2(world_x, world_z).distance_to(lake_center())
	if lake_dist <= lake_radius():
		return &"marsh"
	if primary_river_distance(world_x, world_z) <= primary_river_half_width(world_x):
		return &"river"
	if tributary_distance(world_x, world_z, 0) <= 5.5:
		return &"tributary"
	if tributary_distance(world_x, world_z, 1) <= 5.0:
		return &"tributary"
	return &"none"

func sample_biome(world_x: float, world_z: float) -> StringName:
	var water_kind := water_kind_at(world_x, world_z)
	if water_kind == &"marsh":
		return &"marsh"
	if water_kind == &"river" or water_kind == &"tributary":
		return &"riverlands"

	var temperature := temperature_at(world_x, world_z)
	var moisture := moisture_at(world_x, world_z)
	var height := terrain_height(world_x, world_z)
	var rugged := ruggedness_at(world_x, world_z)

	if height > 70.0:
		return &"alpine_highlands"
	if height > 42.0 or (height > 27.0 and rugged > 0.56):
		return &"rocky_scree"
	if moisture > 0.70 and temperature < 0.53:
		return &"cedar_swamp"
	if temperature > 0.64 and moisture < 0.47:
		return &"badlands"
	if moisture < 0.33:
		return &"dry_meadow"
	if temperature < 0.40:
		return &"pine_forest"
	if temperature < 0.53 and moisture > 0.53:
		return &"birch_grove"
	return &"mixed_forest"

func biome_ids() -> Array[StringName]:
	return BIOME_IDS.duplicate()

static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 0.0
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
