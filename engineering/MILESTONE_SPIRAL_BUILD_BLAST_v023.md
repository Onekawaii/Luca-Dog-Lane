# Spiral Field v0.2.3 — Build & Blast

## Player-facing design

**Build a house, place barrels inside it, strike one with the Field Hammer, and watch the walls rupture.**

The world remains Godot 4.7.2 + Voxel Tools 1.7, carrying forward Spiral Field v0.2.2 at commit `f6abd22b98a793016d56e5374a32875d8113a233`. No second terrain authority was introduced.

### Controls

- **F**: toggle creative construction (unlimited blocks; survival inventory remains untouched).
- **G**: cycle seven construction materials and select the existing PLACE tool.
- **H**: place a physics explosive barrel on nearby solid ground (creative construction required).
- **Left click / E** with PLACE: place selected voxel, using existing raycast + collision/streaming limits.
- **Hammer + left click**: strike explosive barrel to detonate it.
- **Right click** with terrain tool: cycle bounded brush radius.
- **I**: inventory, which includes three buttons for construction, block selection, and barrel placement (Android accessible).
- **1–0**: existing hotbar is preserved.

### Materials / IDs

Existing model IDs are immutable: AIR=0, STONE=1, SURFACE=2, BRICK=3. New model IDs are appended: WOOD=4, GLASS=5, METAL=6, CONCRETE=7. The new models use the same VoxelBlockyLibrary, VoxelTool, authoritative edit delta and resource inventory as v0.2.2. No generator or persistent dictionary schema keys change.

Recipes added for wood, glass, steel and concrete in survival mode. Building creative mode grants virtual supply but does not fabricate inventory records.

### Explosion contract

- ExplosiveBarrel is a real RigidBody3D prop with health/detonation guard, hammer damage, collision, and limited-distance chain reaction.
- Detonation affects nearby enemies, player vitals, rigid props and **only explicitly edited non-air voxels**. Generated geology/landmarks outside that edit ledger stay protected.
- Blast radius = 4.5 m; maximum terrain edits per detonation = 256; resistance by material (glass/wood fragile, metal/concrete tougher).
- Explosion feedback: flash, generated mono audio, HUD toast, logged destroyed voxel count.
- Destroyed voxel cells are saved as AIR (0) through the unchanged v0.2.2 persistence object.

### Backward safety

Default world saves now use `user://v023_world_voxels_<seed>.json`. On first launch, compatible v0.2.2 `v020_world_voxels_<seed>.json` (or older v0.16) data is **copied**, not moved or deleted. Save structure/schema stays 1 and world generator stays 2. Old v0.2.2 worlds remain available as rollback checkpoints. Explicit reset backs up saves before deleting.

### Tests and release gates

- `python -m unittest discover -s tests -p test_*.py`
- Godot editor import/parse
- `tests/spiral_build_blast_acceptance.gd` builds and detonates real voxels, tests public PLACE, verifies damage scope/persistence
- Existing Kimi, runtime playability, Spiral, v0.16, threat/terraform/HUD and world voxel regressions
- Packaged Windows runtime voxel probe
- Signed Android export and Voxel Tools native library/package verification
- Physical Android/Windows hands-on playtest remains a separate acceptance gate

### Honest limitations

Voxel blocks are individual static cells, not rigid-body structural chunks. An unsupported roof can remain floating after its supports explode. Barrel prop placement is not yet persisted through restart. Glass is presently pale glass-color voxel material rather than a production-grade refractive glass shader. These are distinct follow-on visual/physics work and must not be represented as already solved.

## Candidate acceptance

Construct a 6x6 house with roof, door opening, glass window and different wall/roof materials. Place a barrel, hit it with the hammer, require >=6 authored voxels destroyed and a saved replayable damage delta without modifying unedited geology. Confirm older state migration is copy-only.
