# World in Motion Contract — v0.7 Development

This is the first post-`v0.6.0-lattice-alive` gameplay boundary. It preserves the accepted mobile shell and moves reality out of scene-name heuristics.

## Contract

`GameAction -> GameEvent -> authoritative ModuleState -> hive_world_snapshot_v1`

The client renders what the server says exists. It must not infer an NPC from a scene-name substring.

### GameAction v1

Current kinds:

- `move`: absolute normalized world coordinates (`x`, `y`), clamped and anti-teleport limited server-side.
- `interact`: requires `target_id` and proximity to an available server-authored NPC/hotspot.

Movement does **not** advance the narrative turn counter in this first slice. Story choices, item actions, conditions and deterministic encounter tables keep their existing semantics.

## First vertical slice

`world.breakroom.main` spans the Central Table, Coffee Counter and Utility Corner. On phone, tap the floor to walk. On desktop, WASD/arrow keys also work. E/Enter or the large interaction button interacts with the nearest valid target.

The initial world contains:

- Wetberry as a persistent hotspot;
- Keith as a fixed canonical actor at the Utility Corner;
- Darla at the Coffee Counter;
- Tammy only after her existing alert flag is set.

Interacting with those actors/hotspots enters the existing authored Strawberry scenes instead of duplicating dialogue logic.

## Character identity

Named actors use `game/character_identities.json`. The layering grammar is adapted from the uploaded Character Lab MVP: body, head, eyes, mouth, accessory/prop and palette. Named characters are fixed canonical identities; future incidental NPCs may use compact procedural DNA.

Keith's first identity deliberately encodes his existing canon: tired, competent containment ally; maintenance cap; workwear; Evidence Bag of Not My Business; Mop of Minor Exorcism.

## Actor dynamics

`engine/actor_dynamics.py` adapts the eight-dimensional coupling model from the uploaded Emotional Collapse Engine into a fictional game-actor system. It is dependency-free, deterministic and not diagnostic. Signals can alter an actor's activation, depletion, coherence, fixation, social openness, bodily load, memory pressure and recovery potential.

The state is summarized into game-facing behavior labels such as `steady`, `agitated`, `withdrawn` or `reintegrating`. These are presentation/AI inputs, not claims about real people.

## Save compatibility

Save schema v3 adds:

- `world_state`
- `actor_dynamics`

v1 and v2 saves remain loadable. Missing v3 state is populated lazily by the world runtime.

## Renderer boundary

The first slice uses a local dependency-free Canvas2D client so the project remains offline-first and does not need a third-party package download to prove the contract. The snapshot protocol is intentionally renderer-agnostic. Phaser can consume the same `hive_world_snapshot_v1` payload in the next rendering pass without rewriting campaign rules.
