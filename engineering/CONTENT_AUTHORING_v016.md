# Luca Dog World v0.16 Content Authoring Contract

v0.16 separates content definitions from engine code. Runtime content lives in versioned JSON catalogs under `data/` and is validated by `ContentRegistry.gd`.

## Items

Edit `data/items_v016.json`.

Required per item:
- `label`
- `kind`
- `stack_max`
- `description`

Item IDs are stable keys. Recipes and tools should reference IDs, never display labels.

## Tools

Edit `data/tools_v016.json`.

The `order` array controls tool-belt order. Every listed tool must exist in `tools`.

Required per tool:
- `label`
- `action`
- `range`

Supported v0.16 actions:
- `grab`
- `inspect`
- `strike`
- `mine`
- `place`
- `craft`
- `duplicate`
- `remove`

Action-specific fields are data. For example, `strike` supports `damage` and `knockback`.

## Recipes

Edit `data/recipes_v016.json`.

Each recipe has:
- `label`
- `ingredients` dictionary of item ID -> count
- `outputs` dictionary of item ID -> count

Every referenced item must exist in `items_v016.json`; registry validation rejects unknown IDs.

## Maps

Edit `data/maps_v016.json`.

Required map fields:
- `label`
- `seed`
- `terrain_scale`
- `spawn` as [x, y, z]
- `sky_top`
- `sky_horizon`
- `fog_color`
- `fog_density`

The mobile MAP panel is generated from this catalog. A selected map becomes the authority for:
- Kimi world seed
- macro terrain amplitude
- wilderness generation
- player/Luca spawn
- sky/fog
- ENG-003 voxel generator seed
- seed-scoped voxel/inventory persistence

v0.16 ships:
- `lucas_field` / seed 6060
- `red_pine_highlands` / seed 7719
- `quarry_basin` / seed 3184

## Schema law

Do not silently change a catalog's meaning while keeping the same `schema_version`.

If a persistent/content contract changes incompatibly:
1. increment its schema version,
2. update `ContentRegistry.gd` validation,
3. add/migrate tests,
4. preserve or intentionally migrate old saves.

## Verification

Run:

```powershell
python -m unittest discover -s tests -p "test_*.py" -v
python tools\verify.py
```

A release is not valid unless the v0.16 runtime gate proves vehicle physics, Luca formation behavior, NPC damage/anatomy, and map isolation in Godot.
