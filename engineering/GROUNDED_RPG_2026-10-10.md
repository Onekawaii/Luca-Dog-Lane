# Grounded scenery and road journal — 2026-10-10

Status: PARTIAL, source candidate only. Follow-on to the world-support/seed-generation fixes. User explicitly requested both richer scenery and RPG dialogue/lore/quests in both editions. Crossover remains future work.

## Invariants and ownership

The journal owns a bounded three-record exploration quest. Duplicate/unknown reads cannot fabricate progress. Reading all records still requires returning to a resident; completion grants an earned title, not a fabricated inventory reward. Catalogs own authored lore; world adapters own surface placement, save identity and UI integration. Terrain materials cannot change terrain collision or conceal the authoritative ground when no distance mesh exists.

## Verification and demolition

Native Godot4.6.3 RPG acceptance: zero failures. Actual resident interaction, record reads, return/completion, saved title restoration and static ground placement are exercised. World-support/generation acceptance: zero failures after this pass. No SCRIPT ERROR, SHADER ERROR, parse or compile failures in final acceptance logs. Hive logs retain baseline absent splash/audio assets; Spiral corrupt-journal fixture deliberately emits a JSON/invalid-save diagnostic. Source/log hashes are in GROUNDED_RPG_RECEIPT_2026-10-10.json.

Independent Demander caught a shared colour/roughness sampler compilation failure, live Hive journal stale after loading an older save, and corrupt Spiral journal blocking startup and session saving. All were repaired and regression-tested. The first Hive harness preloaded autoload-dependent classes too early; loading those classes after startup repaired the harness without changing production singletons. The journal model configures transactionally so a rejected reconfiguration preserves existing state.

## Limits and next gates

This workspace has text source only: upstream PBR images/audio/model assets cannot be fetched through the available connector. Existing texture paths and normal/roughness fallbacks are used; no new binary asset claims. Shader compilation and material bindings are verified, not rendered art quality, FPS, exported gameplay or physical Android usability. Three records and an earned title form a first authored quest, not a complete RPG or Skyrim-quality scenery. No smooth SDF terrain rewrite, crossover portal, cross-edition save conversion, release or main promotion.

Next: restore upstream binary assets, use each project's pinned engine (Spiral Godot4.7.2 + Voxel Tools1.7), run the RPG and world-support harnesses, inspect rendered ground under camera rotation and sunlight, exercise J/PDA and touch record/dialogue interactions, export both platform candidates and test on the physical target phone. Keep active collision/streaming receipts alongside visual captures. Rollback is reverting this follow-on while retaining the preceding world-support fixes; journal data stays nested in the Hive save or in separate seed/map-scoped Spiral files.

## Spiral implementation

Six named residents offer local history and explicit work dialogue. Three road records complete “The road that remembers”; J and the Map journal button open the text, with dialogue taking modal player input and pausing the resident's wandering. Existing wounds/combat remain available. Seed/map-scoped atomic sidecars persist quest/title; failed writes roll back progress, and corrupt files are retained while world startup, session save and New Generated World remain available.

Legacy mesh-mode terrain gains layered triplanar grass/rock colour, nearby normal/roughness detail and restrained variation. Default voxel mode gains block-face normal/roughness bindings and the distance_preview_active visibility guard; it does not use the legacy layered mesh shader. No additional distance mesh is built. Nearby detail is bounded at40m; texture fallback is one pixel, catalogue/quest entries are bounded, and there are only3 record actors. Mobile frame/memory costs require real-device measurement. Godot4.7.2/Voxel Tools1.7 pins unchanged. Python46 PASS. Current source is publishedv0.2.5; suppliedv0.2.7 screenshots do not establish that this snapshot is the same APK.
