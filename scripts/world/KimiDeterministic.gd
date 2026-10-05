class_name KimiDeterministic
extends RefCounted

const MASK32: int = 0xFFFFFFFF
const MASK64: int = 0x7FFFFFFFFFFFFFFF

static func mix32(x: int) -> int:
	x &= MASK32
	x ^= x >> 16
	x = (x * 0x85EBCA6B) & MASK32
	x ^= x >> 13
	x = (x * 0xC2B2AE35) & MASK32
	x ^= x >> 16
	return x

static func mix64(h: int, x: int) -> int:
	var lo: int = (h ^ x) & MASK32
	var hi: int = ((h >> 32) ^ (x >> 32)) & MASK32
	lo = mix32(lo)
	hi = mix32(hi)
	return ((hi << 32) | lo) & MASK64

static func hash2i(seed: int, x: int, y: int) -> int:
	return mix64(mix64(seed & MASK64, x), y)

static func randf_from_int(h: int) -> float:
	return mix32(h & MASK32) * (1.0 / 4294967296.0)

static func hash_string(value: String) -> int:
	var h: int = 0x1D0CAFE
	for i in value.length():
		h = mix64(h, value.unicode_at(i))
	return h

static func mix_value(h: int, value: Variant) -> int:
	match typeof(value):
		TYPE_NIL:
			return mix64(h, 0x6E756C6C)
		TYPE_BOOL:
			return mix64(h, 0xB001 if value else 0xB000)
		TYPE_INT:
			return mix64(h, value)
		TYPE_FLOAT:
			return mix64(h, hash_string("%.6f" % value))
		TYPE_STRING, TYPE_STRING_NAME:
			return mix64(h, hash_string(str(value)))
		TYPE_VECTOR2:
			return mix_value(mix_value(h, value.x), value.y)
		TYPE_VECTOR2I:
			return mix_value(mix_value(h, value.x), value.y)
		TYPE_VECTOR3:
			return mix_value(mix_value(mix_value(h, value.x), value.y), value.z)
		TYPE_ARRAY:
			for item in value:
				h = mix_value(h, item)
			return mix64(h, value.size())
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort()
			for key in keys:
				h = mix64(h, hash_string(str(key)))
				h = mix_value(h, value[key])
			return mix64(h, value.size())
	return mix64(h, 0xBAD)

class RNG:
	var _state: int

	func _init(seed_int: int) -> void:
		_state = seed_int & MASK64

	func next() -> int:
		_state = (_state * 6364136223846793005 + 1442695040888963407) & MASK64
		return _state

	func randf() -> float:
		return KimiDeterministic.randf_from_int(next())

	func randi_range(min_v: int, max_v: int) -> int:
		assert(max_v >= min_v)
		return min_v + int(next() % (max_v - min_v + 1))
