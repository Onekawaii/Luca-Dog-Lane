# Spiral Field v0.2 Android Recording Review — 2026-10-08

## Evidence

- `20261008-1155-33.0674158.mp4` — 160.6 s, 1920×1032, 30 FPS.
- `20261008-1200-49.4056543.mp4` — 143.0 s, 1920×1032, 30 FPS.
- Review method: complete two-second contact-sheet sampling followed by targeted frame and source inspection. This is a systematic visual review, not a claim that all 9,108 encoded frames were inspected individually.
- Audio transcription was unavailable because the local transcription API credential is not configured. The observations below are visual evidence only.

## Observable defects and reproduction

### SF-AND-001 — Android touch controls are absent (critical)

**Evidence:** Both recordings, continuously from 00:00 to end. The title/status HUD renders, but the move stick, USE, JUMP, MAP, TOOL, and vehicle VIEW controls never render.

**Reproduction:** Launch the v0.2 Android build in landscape. Observe the HUD immediately after world load and again after entering the buggy.

**Root cause:** `HUD.gd` selected mobile mode only through the generic `mobile` feature tag. The Android export tag was not used as an authoritative fallback, leaving `mobile_ui` false in the recorded runtime.

**Repair:** Mobile detection now accepts `android`, `ios`, or `mobile`.

### SF-CAM-002 — Buggy driver view is inside the cab mesh (critical)

**Evidence:** `1155` recording approximately 00:34–01:34. A flat blue vehicle surface occupies roughly the lower third of the screen throughout the driver-view segment and sharply limits terrain visibility.

**Reproduction:** Approach the sandbox buggy, enter it, and remain in the initial DRIVER camera.

**Root cause:** Driver camera `(y=1.78, z=-0.42)` overlapped the cab volume, whose top is `y=1.79` and front is `z=-0.49`.

**Repair:** Driver eye moved above and ahead of the cab to `(y=2.42, z=-0.72)`. Runtime acceptance now rejects camera placement inside the cab envelope.

### SF-CAM-003 — Spiral geometry engulfs the first-person view (high)

**Evidence:** `1155` approximately 02:16–02:36 at the Wailing spiral; `1200` approximately 02:06–02:20 at the Witnessing spiral. Bright torus geometry fills most or all of the viewport at interaction distance.

**Reproduction:** Walk directly toward either large spiral until its interaction panel opens; continue forward against its collider and rotate the camera.

**Root cause:** The collider radius (5.5 m) only barely exceeded the outer ring radius (about 5.1 m), leaving insufficient first-person camera clearance.

**Repair:** Landmark stand-off radius increased to 7.5 m while remaining within the 9.5 m encounter ray range.

### SF-CAM-004 — Close-up actors/props can heavily occlude the view (medium, not changed)

**Evidence:** `1155` approximately 00:00–00:10 (Tabby'tulhu), 00:24–00:30 (Luca), and 02:04–02:10 (NPC); `1200` approximately 00:28–00:34 (Luca) and 01:36–01:50 (Tabby'tulhu).

**Reproduction:** Walk directly into a companion, NPC, or Tabby'tulhu and rotate toward its center.

**Assessment:** NPC/player non-blocking is an explicit existing gameplay decision. Changing collision ownership would affect navigation, pickups, and vehicle impacts, so this pass does not silently reverse that design. A later pass should choose between actor fade, camera-near clipping treatment, or dedicated player-only stand-off layers.

### SF-VIS-005 — Steep terrain/large world geometry can fully occlude the frame (medium, needs device reproduction)

**Evidence:** `1200` approximately 00:48–01:04, where the frame becomes almost entirely terrain/sky while moving along steep relief.

**Reproduction:** Traverse directly into steep mountain shoulders and pitch the camera toward the slope.

**Assessment:** The recording alone cannot distinguish intended close-range slope viewing from a camera/collision mismatch. Existing underworld recovery and continuous-terrain runtime gates pass. Preserve current terrain until reproduced with state coordinates on a device.

## Preserved behavior

- Four buggy camera modes and camera cycling remain intact.
- Encounter interaction ray range and verbs remain unchanged.
- Desktop HUD/debug separation remains intact.
- Terrain, save schema, map transitions, NPC collision policy, and world generation are unchanged.
