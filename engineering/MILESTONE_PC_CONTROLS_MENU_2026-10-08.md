# M-PC-03 — PC input, vehicle views and session menu

Status at start: IN PROGRESS, not qualified. Base branch
`feat/spiral-lantern-hotbar-terrain-20261008`, clean HEAD
`93b71e9d0c3db2db8cf3e79babb7bc5ed446a9de`; working branch
`feat/pc-controls-menu-milestone`. Godot 4.7.2, existing pinned Voxel Tools 1.7;
no engine/plugin/dependency upgrade. Earlier candidates are immutable rollback artifacts.

## Player-facing requirements / acceptance

- Captured left mouse press invokes exactly one equipped/contextual action;
  release and keyboard echo do not repeat it. Uncaptured click only recaptures.
- E remains the alternate interaction/vehicle-exit key; driving LMB never ejects.
- R/F5 cycle DRIVER, CHASE, HOOD, OVERHEAD; PC and mobile show VIEW and EXIT.
- Original block-button title, pause and options screens follow familiar
  single-player sandbox navigation without copying Minecraft art/branding.
- Escape closes a gameplay panel first, otherwise pauses/resumes. Pause stops
  simulation and exposes the pointer. Resume-button click cannot become tool use.
- Inventory/map/encounter panels release pointer and block world controls; these
  panels do not pause the continuing encounter simulation. Numbered encounter
  choices retain precedence over hotbar selection. Wheel/1–9/0 select hotbar.
- Options control actual sensitivity, master volume and fullscreen; settings
  are session-only in this pass. No fictitious multiplayer/world-slot options.
- A persistent PC controls label identifies noclip/driving, and MENU gives
  touch users an entry point without requiring Escape.
- Save/return-to-title flushes existing terrain/inventory and Spiral schemas.
  It retains the loaded session; continuing does not reset/reload. Existing
  schemas do NOT persist player position, props, NPC/car damage or camera mode.
- Mining drops become compact object-textured cubes, merge like-material nearby
  drops, and cap at 64 physics bodies without resource loss (overflow credited).
  Drops escaping below -20 credit inventory rather than silently disappearing.

## Ownership / risk / rollback

Player owns gameplay input and the blocked gate. HUD owns contextual panel
visibility/cursor synchronization. SessionMenu owns tree pause/title/options;
Game delegates flush to existing persistence owners. No save-schema migration.
Pause/menu processing is bounded and remains live while world processing stops.
Tests use unique terrain and Spiral save namespaces, never normal saves.
Rollback is the clean base commit and unchanged prior candidate folders.

## Falsifiers

Actual input-event dispatch must change target HP on one LMB; GUI clicks and
paused input must not. Throttled car and moving NPC must freeze during pause.
All four camera identities must be current after wrap/pause/resume. Save failures
must prevent return/quit. Resource-count conservation must hold under >64 drops.
Rendered screenshots must show menu, inventory and PC vehicle controls on-screen.
Exact exported Windows artifact must exercise the same probe after commit.

## Recording review

See `PC_RECORDING_BUG_REVIEW_2026-10-08.md`. Observable vs code-confirmed vs
unproven hypotheses stay separate. Current review is systematic five-second
contact sheets plus targeted frames, not every encoded frame.
