# Release Notes — v0.6.0-lattice-alive

## Theme

**The Hive remembers.** v0.6.0 turns the accepted phone-playable Strawberry Omen
campaign from primarily scene branching into a persistent reactive game system.

## Major additions

- `strawberry_interactions_v1` campaign interaction layer;
- contextual hidden/locked routes;
- usable inventory actions;
- NPC and room memory;
- persistent conditions;
- deterministic event tables;
- stat checks and stat-gated alternate solutions;
- evidence/history-driven Act V verdict;
- save v2 with v1 compatibility;
- web HUD exposure of inventory actions, conditions and relationships.

## Preserved

- Acts I–V content and existing completion paths;
- v0.5.2 mobile-first UX contract;
- optional renderer behavior;
- frozen Bard v1 schemas.

## Automated receipt

- reactive acceptance: 24/24 PASS;
- inherited + reactive non-Flask suite: 305 cases executed successfully (1 intentional renderer-path skip reported);
- validators, Act IV smoke and Act V smoke: PASS;
- full source definition: 370 unittest cases; 65 Flask-dependent cases await an environment with Flask installed.
