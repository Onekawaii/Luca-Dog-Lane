class_name KimiChunkDescriptor
extends RefCounted

const SIZE_M := 128.0
const HASH_SCHEMA_VERSION := 1

var coord := Vector2i.ZERO
var generator_version := 1
var biome: StringName = &"meadow"
var corner_heights: Array[float] = []
var vegetation_candidates: Array = []
var rock_candidates: Array = []
var generation_hash := 0

func compute_hash() -> int:
	var h := KimiDeterministic.hash2i(0x5EED, coord.x, coord.y)
	h = KimiDeterministic.mix_value(h, HASH_SCHEMA_VERSION)
	h = KimiDeterministic.mix_value(h, generator_version)
	h = KimiDeterministic.mix_value(h, String(biome))
	h = KimiDeterministic.mix_value(h, corner_heights)
	h = KimiDeterministic.mix_value(h, vegetation_candidates)
	h = KimiDeterministic.mix_value(h, rock_candidates)
	return h
