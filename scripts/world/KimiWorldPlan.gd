class_name KimiWorldPlan
extends RefCounted

const GENERATOR_VERSION := 1
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

func sample_biome(world_x: float, world_z: float) -> StringName:
	var temperature := fbm(world_x, world_z, 3, 0.0009, 404)
	var moisture := fbm(world_x, world_z, 3, 0.0011, 505)
	var height := terrain_height(world_x, world_z)
	if height > 55.0:
		return &"highlands"
	if moisture > 0.68:
		return &"wetlands"
	if temperature > 0.62:
		return &"badlands"
	if temperature < 0.38 and moisture < 0.5:
		return &"pine_forest"
	if moisture < 0.35:
		return &"meadow"
	return &"mixed_forest"
