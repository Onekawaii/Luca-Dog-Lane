class_name LucaEntityRegistry
extends RefCounted

var _factories: Dictionary = {}

func register_entity(entity_type: String, factory: Callable) -> bool:
	if entity_type.is_empty() or not factory.is_valid():
		return false
	_factories[entity_type] = factory
	return true

func unregister_entity(entity_type: String) -> void:
	_factories.erase(entity_type)

func can_spawn(entity_type: String) -> bool:
	return _factories.has(entity_type)

func spawn(entity_type: String, spec: Dictionary = {}) -> Variant:
	if not _factories.has(entity_type):
		return null
	var factory: Callable = _factories[entity_type]
	return factory.call(spec.duplicate(true))

func registered_types() -> Array:
	var out := _factories.keys()
	out.sort()
	return out
