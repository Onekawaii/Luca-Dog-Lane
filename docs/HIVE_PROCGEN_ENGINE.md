# HIVE-LATTICE PROCEDURAL WORLD ENGINE

**Schema:** `hive_procgen_world_v1`  
**Runtime:** Godot 4.3  
**Status:** Open-world foundation / deterministic simulation core

## Purpose

HiveProcGenEngine is a data-first procedural world planner for the first-person Hive-Lattice runtime. It does not replace authored spaces. It connects authored sites to generated regions, sites, room graphs, scatter fields, streaming partitions, Hive-state budgets, and memory-resonance metadata.

The central rule is: **randomness proposes; constraints decide; the seed makes the decision reproducible.**

## Generation stack

1. Stable world seed and salted deterministic RNG streams.
2. Macro region placement across a 4096-unit world domain.
3. Independent FastNoiseLite fields for pressure, contamination, archetype bias, and scatter density.
4. Connectivity spine using nearest-edge graph construction, then deterministic loop injection.
5. Site placement and archetype assignment inside regions.
6. Constraint-guided room grammar for each site.
7. Minimum-distance detail scattering driven by density fields.
8. Hierarchical 256-unit streaming partition.
9. Budgeted Hive director for threat, anomaly, and ambience pressure.
10. Memory Resonance selection from sanitized derived metadata.
11. Canonical SHA-256 generation receipt for replay/audit.
## Hive-specific control layer

The generator accepts four normalized Hive inputs:

- `pressure` — increases threat budget and biases hostile infrastructure.
- `instability` — increases anomaly budget and changes memory mutation from literal to recognizable to abstract.
- `observation` — records how strongly witnessed reality should resist mutation.
- `familiarity` — increases preference for familiar memory tags.

These values live under existing `WorldState.world_state`; save schema v3 is unchanged.

## Memory Resonance contract

The shipped catalog contains derived IDs and tags only. Raw photographs, EXIF, GPS, filesystem paths, and personal originals are not runtime inputs. A later ingestion tool may derive materials, palettes, embeddings/tags, and provenance outside the game repository, then export only approved derivatives.

`site.breakroom` is the first authored bridge. Its visual scene remains `FirstPersonBreakroom.tscn`; the procedural system generates its larger-world adjacency rather than regenerating the accepted room.

## Streaming model

Generated sites/details are indexed into fixed world cells. Runtime requests only nearby active cells; warm/cold radii are retained as policy metadata for future resource prefetch and eviction. This avoids keeping a STALKER-scale network simultaneously instantiated.
## Current boundary

This milestone implements the complete **planning/simulation pipeline**, not final content production. It already simulates macro geography, connectivity, room grammar, scatter, streaming, director budgets, persistence identity, and memory influence. The next renderer milestone will instantiate terrain/corridor/site scene chunks from these plans and bake navigation/collision only for active cells.

Do not confuse the procedural plan with finished art. Generated structure remains subject to authored scene modules, performance budgets, traversal validation, and physical playtesting.

## Verification contract

Native acceptance proves same-seed determinism, seed divergence, minimum world population, connected topology, Breakroom bridge preservation, resolved room constraints, scatter generation, bounded streaming activation, director budgeting, privacy-safe plans, and bootstrap integration.

Known headless baseline noise: 27 `data.tree` warnings exist on clean commit `998a795` and remain exactly 27 with this engine. They are not a procgen regression. New procgen SCRIPT ERROR count is zero.
