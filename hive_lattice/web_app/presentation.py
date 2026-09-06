"""Pure presentation metadata for the Strawberry Omen web UI.

This module deliberately contains no Flask imports and does not mutate campaign
state.  It is the single source of truth for Act I-V display progression.
"""

from __future__ import annotations

from typing import Any, Mapping


_ACT_DEFS = (
    (1, "Act I", "Report Cursed reliquary box"),
    (2, "Act II", "Reclaim expired lunch shelf"),
    (3, "Act III", "Negotiate with Vendrick slot"),
    (4, "Act IV", "Exorcise Sentient Potluck Casserole"),
    (5, "Act V", "Face the Department of Adjudication"),
)


def derive_act_progression(flags: Mapping[str, Any] | None) -> dict[str, Any]:
    """Return derived, read-only Act I-V UI metadata.

    Completion cascades forward so an older save that has a later completion
    flag cannot make earlier acts appear active again.  ``entered_fridge`` is
    accepted as legacy evidence that Act I was crossed, while ``fridge_unlocked``
    remains the normal boundary.
    """

    f = flags or {}

    act5_done = bool(f.get("act5_complete"))
    act4_done = bool(f.get("act4_complete") or act5_done)
    act3_done = bool(f.get("act3_complete") or act4_done)
    act2_done = bool(f.get("act2_complete") or act3_done)
    act1_done = bool(f.get("fridge_unlocked") or f.get("entered_fridge") or act2_done)
    done = (act1_done, act2_done, act3_done, act4_done, act5_done)

    active_index = None
    for idx, is_done in enumerate(done):
        if not is_done:
            active_index = idx
            break

    acts = []
    for idx, (number, label, objective) in enumerate(_ACT_DEFS):
        acts.append(
            {
                "number": number,
                "label": label,
                "name": f"{label}: {objective}",
                "objective": objective,
                "done": done[idx],
                "active": active_index == idx,
            }
        )

    if active_index is None:
        current_number = 5
        current_label = "Act V Complete"
        complete = True
    else:
        current_number = _ACT_DEFS[active_index][0]
        current_label = _ACT_DEFS[active_index][1]
        complete = False

    return {
        "current_number": current_number,
        "current_label": current_label,
        "complete": complete,
        "acts": acts,
    }
