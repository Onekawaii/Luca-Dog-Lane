# Uploaded Engine Integration Notes

These notes record what was actually incorporated from the user-supplied engine bundles in the first v0.7 development slice.

## Character Lab MVP 1→4

Source-supported concepts used:

- layered paper-doll composition;
- palette-controlled/tintable parts;
- fixed component slots (`body`, `head`, `eyes`, `mouth`, `accessory`);
- compact procedural DNA as a future option;
- idle movement as a presentation concern.

Hive adaptation: named campaign characters get canonical fixed identities in `campaigns/strawberry_omen/game/character_identities.json`. The procedural DNA concept is reserved for incidental NPC generation rather than replacing named-character art direction.

## Emotional Collapse Engine

Source-supported mechanics used:

- eight-dimensional state vector;
- coupled linear dynamics matrix;
- small nonlinear correction;
- bounded state values;
- state/pressure classification.

Hive adaptation: `engine/actor_dynamics.py` is a pure-Python fictional-actor runtime. Numpy was deliberately removed to preserve the existing lightweight Termux dependency profile. Random noise was replaced with deterministic hash-derived bounded noise so identical game state/seed/action remains reproducible.

## Not yet integrated

The Color Recursive Forge, Overcast Diffusion renderer, Metameric Engine, terrain mapper, audio analyzer and deterministic Codex generator remain source material for later visual/world-authoring passes. They are not silently bundled into the runtime in this slice.
