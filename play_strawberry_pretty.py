#!/usr/bin/env python3
from __future__ import annotations

"""
THE STRAWBERRY OMEN - Cursed Horror Terminal Runner

A Shadowgate-filtered-through-DOOM presentation of the Strawberry Omen
campaign module. Each turn is rendered as a boxed adventure-game screen
with narration, environment, numbered actions, and player state.

Usage:
    python play_strawberry_pretty.py
"""

import re
import textwrap
from pathlib import Path

from engine.module_runtime import CampaignModule
from engine.module_save_system import ModuleSaveSystem

_ANSI_RE = re.compile(r"\033\[[0-9;]*m")


def visible_len(s: str) -> int:
    """Length of string excluding ANSI escape sequences."""
    return len(_ANSI_RE.sub("", s))


def _truncate_ansi(s: str, max_visible: int) -> str:
    """Truncate string to max_visible visible chars, preserving ANSI codes."""
    result: list[str] = []
    vis = 0
    i = 0
    while i < len(s) and vis < max_visible:
        if s[i] == "\033":
            end = s.find("m", i)
            if end != -1:
                result.append(s[i : end + 1])
                i = end + 1
                continue
        result.append(s[i])
        vis += 1
        i += 1
    return "".join(result)

# ── Palette ──────────────────────────────────────────────────────────────

RED = "\033[1;31m"
DIM_RED = "\033[2;31m"
BOLD_RED = "\033[1;91m"
GREEN = "\033[1;32m"
DIM_GREEN = "\033[2;32m"
YELLOW = "\033[1;33m"
DIM_YELLOW = "\033[2;33m"
CYAN = "\033[1;36m"
DIM_CYAN = "\033[2;36m"
WHITE = "\033[1;37m"
DIM = "\033[2m"
BOLD = "\033[1m"
RESET = "\033[0m"
BG_RED = "\033[41m"
FG_BLACK = "\033[30m"

ACT_NAMES = {
    1: "The Upright Omen",
    2: "The Fridge of Forgotten Things",
    3: "The Vending Machine That Eats Names",
    4: "The Fridge Labyrinth of Forgotten Leftovers",
}

SCENE_TYPE_LABELS = {
    "social_hazard": f"{RED}<< SOCIAL HAZARD >>{RESET}",
    "npc_scene": f"{CYAN}<< ENCOUNTER >>{RESET}",
    "boss_social_encounter": f"{BOLD_RED}<< DANGER >>{RESET}",
    "combat_encounter": f"{RED}<< HOSTILE ENCOUNTER >>{RESET}",
    "social_encounter": f"{CYAN}<< ENCOUNTER >>{RESET}",
    "completion_encounter": f"{YELLOW}<< COMPLETION >>{RESET}",
}

ATMOSPHERE = {
    "social_hazard": f"{DIM_RED}The air is wrong. Something watches.{RESET}",
    "boss_social_encounter": f"{DIM_RED}The room contracts. Ancient patience fills the space.{RESET}",
    "combat_encounter": f"{RED}Threat detected. The breakroom does not forgive.{RESET}",
    "npc_scene": f"{DIM_CYAN}A presence makes itself known.{RESET}",
    "social_encounter": f"{DIM_CYAN}Something stirs in the fluorescent dark.{RESET}",
    "completion_encounter": f"{DIM_YELLOW}A threshold awaits your final choice.{RESET}",
}

W = 78


# ── Helpers ──────────────────────────────────────────────────────────────

def wrap(text: str, width: int = W - 4) -> list[str]:
    """Word-wrap text, preserving intentional blank lines."""
    out: list[str] = []
    for para in text.split("\n"):
        if not para.strip():
            out.append("")
        else:
            out.extend(textwrap.wrap(para, width=width))
    return out


def hline(ch: str = "\u2500") -> str:
    return ch * W


def vbox(lines: list[str], title: str = "", color: str = WHITE) -> str:
    """Render a box with optional colored title tab, ANSI-aware padding."""
    parts: list[str] = []
    if title:
        tag = f" {title} "
        pad = W - 4 - visible_len(tag)
        parts.append(
            f"{color}\u250c{tag}{'─' * max(pad, 1)}{RESET}"
        )
    else:
        parts.append(f"{color}\u250c{'─' * (W - 2)}{RESET}")
    for line in lines:
        vlen = visible_len(line)
        clip = W - 4
        if vlen > clip:
            # Truncate visible text, keeping ANSI intact
            trimmed = _truncate_ansi(line, clip)
            line = trimmed
            vlen = visible_len(trimmed)
        pad = max(0, W - 4 - vlen)
        parts.append(
            f"{color}\u2502{RESET} {line}{' ' * pad}{color}\u2502{RESET}"
        )
    parts.append(f"{color}\u2514{'─' * (W - 2)}{RESET}")
    return "\n".join(parts)


def labeled_box(label: str, lines: list[str], color: str = DIM_CYAN) -> str:
    """A panel with a dim label above it."""
    out: list[str] = []
    out.append(f"{color}{BOLD}  {label}{RESET}")
    out.append(vbox(lines, color=color))
    return "\n".join(out)


def parse_act(scene_id: str) -> int | None:
    for i in range(1, 5):
        if f".act{i}." in scene_id:
            return i
    return None


def resolve_location(module: CampaignModule, location_id: str) -> dict | None:
    for loc_data in module.locations.values():
        for node in loc_data.get("nodes", []):
            if node["id"] == location_id:
                return {"parent": loc_data, "node": node}
    return None


def npcs_at_location(module: CampaignModule, location_id: str) -> list[dict]:
    return [
        npc for npc in module.npcs.values()
        if npc.get("location") == location_id
    ]


def reachable_exits(
    module: CampaignModule, state, location_id: str
) -> list[dict]:
    loc = resolve_location(module, location_id)
    if not loc:
        return []
    exits: list[dict] = []
    for node in loc["parent"].get("nodes", []):
        if node["id"] == location_id:
            continue
        locked = node.get("locked_by_flag")
        if locked and not state.flags.get(locked):
            continue
        exits.append({"id": node["id"], "name": node["name"]})
    return exits


def item_name(module: CampaignModule, item_id: str) -> str:
    item = module.items.get(item_id)
    return item["name"] if item else item_id


def scene_type_label(scene: dict) -> str:
    return SCENE_TYPE_LABELS.get(scene.get("type", ""), "")


def atmosphere(scene: dict) -> str:
    return ATMOSPHERE.get(scene.get("type", ""), "")


def format_stats(stats: dict) -> str:
    parts = [f"{k}:{v}" for k, v in stats.items()]
    # Wrap stats across multiple lines if needed
    lines: list[str] = []
    current = ""
    for part in parts:
        candidate = (current + "  " + part) if current else part
        if visible_len(candidate) > W - 6:
            if current:
                lines.append(current)
            current = part
        else:
            current = candidate
    if current:
        lines.append(current)
    return "\n    ".join(lines)


# ── Panel renderers ──────────────────────────────────────────────────────

def render_header(state, module: CampaignModule) -> str:
    act = parse_act(state.current_scene)
    scene = module.scene(state.current_scene)
    loc = resolve_location(module, state.current_location)

    lines: list[str] = []
    lines.append(f"{RED}{BOLD}{module.campaign['title']}{RESET}")
    if act:
        lines.append(
            f"{DIM_RED}Act {act}: {ACT_NAMES.get(act, 'Unknown')}{RESET}"
        )
    lines.append(f"{WHITE}Scene: {scene.get('title', '???')}{RESET}")
    if loc:
        lines.append(
            f"{CYAN}Location: {loc['node']['name']}{RESET}"
        )
    return vbox(lines, title="STATUS", color=RED)


def render_scene(scene: dict) -> str:
    read_aloud = scene.get("read_aloud", "")
    stype = scene_type_label(scene)
    atmo = atmosphere(scene)

    lines: list[str] = []
    if stype:
        lines.append(f"  {stype}")
        lines.append("")
    lines.extend(wrap(read_aloud))
    if atmo:
        lines.append("")
        lines.append(f"  {atmo}")
    return vbox(lines, title="SCENE", color=WHITE)


def render_actions(scene: dict) -> str:
    choices = scene.get("choices", [])
    if not choices:
        return ""
    lines: list[str] = []
    for i, c in enumerate(choices, 1):
        lines.append(
            f"{GREEN}{i:>2}.{RESET}  {c['label']}"
            f"  {DIM}({c['id']}){RESET}"
        )
    return vbox(lines, title="ACTIONS", color=GREEN)


def render_environment(module: CampaignModule, state) -> str:
    loc = resolve_location(module, state.current_location)
    if not loc:
        return vbox(["[location unknown]"], title="ENVIRONMENT", color=DIM_CYAN)

    lines: list[str] = []
    lines.append(f"{CYAN}{BOLD}{loc['node']['name']}{RESET}")
    desc = loc["node"].get("description", "")
    if desc:
        lines.extend(wrap(desc))

    npcs = npcs_at_location(module, state.current_location)
    if npcs:
        lines.append("")
        lines.append(f"  {YELLOW}Present:{RESET}")
        for npc in npcs:
            lines.append(
                f"    {YELLOW}*{RESET} {npc['name']}"
                f"  {DIM}({npc.get('role', '')}){RESET}"
            )

    exits = reachable_exits(module, state, state.current_location)
    if exits:
        lines.append("")
        lines.append(f"  {DIM_CYAN}Exits:{RESET}")
        for ex in exits:
            lines.append(f"    {DIM_CYAN}>{RESET} {ex['name']}")

    return vbox(lines, title="ENVIRONMENT", color=DIM_CYAN)


def render_state(module: CampaignModule, state) -> str:
    lines: list[str] = []
    for sline in format_stats(state.stats).split("\n"):
        lines.append(f"  {sline}")
    lines.append("")
    inv = state.inventory
    if inv:
        lines.append(f"  {YELLOW}Inventory:{RESET}")
        for iid in inv:
            lines.append(f"    {YELLOW}*{RESET} {item_name(module, iid)}")
    else:
        lines.append(f"  {DIM}(empty hands){RESET}")

    important = [
        k for k, v in state.flags.items()
        if v is True
        and k not in ("entered_fridge",)
    ]
    if important:
        lines.append("")
        lines.append(f"  {DIM_YELLOW}Notable flags:{RESET}")
        for flag in important:
            lines.append(f"    {DIM_YELLOW}>{RESET} {flag}")

    return vbox(lines, title="PLAYER STATE", color=YELLOW)


def render_footer() -> str:
    lines = [
        f"{DIM}help{RESET}  {DIM}state{RESET}  {DIM}map{RESET}"
        f"  {DIM}room{RESET}  {DIM}assets{RESET}"
        f"  {DIM}save{RESET}  {DIM}load{RESET}"
        f"  {DIM}saves{RESET}  {DIM}delete save{RESET}"
        f"  {DIM}quit{RESET}",
        "",
        f"{RED}{BOLD}Choice / command >{RESET} ",
    ]
    return "\n".join(lines)


def render_turn(module: CampaignModule, state) -> str:
    scene = module.scene(state.current_scene)
    panels: list[str] = []
    panels.append(render_header(state, module))
    panels.append(render_scene(scene))
    panels.append(render_actions(scene))
    panels.append(render_environment(module, state))
    panels.append(render_state(module, state))
    return "\n\n".join(panels)


def render_result(result: str, module: CampaignModule, state) -> str:
    parts: list[str] = []
    parts.append(f"{RED}\u250c{'─' * (W - 2)}{RESET}")
    label = f" {YELLOW}{BOLD}OUTCOME{RESET}"
    lvis = 8  # "OUTCOME" visible length + leading space
    pad = max(0, W - 4 - lvis)
    parts.append(f"{RED}\u2502{RESET} {YELLOW}{BOLD}OUTCOME{RESET}{' ' * pad}{RED}\u2502{RESET}")
    parts.append(f"{RED}\u251c{'─' * (W - 2)}{RESET}")
    for line in wrap(result):
        vlen = visible_len(line)
        p = max(0, W - 4 - vlen)
        parts.append(f"{RED}\u2502{RESET} {WHITE}{line}{RESET}{' ' * p}{RED}\u2502{RESET}")
    parts.append(f"{RED}\u2514{'─' * (W - 2)}{RESET}")
    return "\n".join(parts)


# ── Commands ─────────────────────────────────────────────────────────────

def cmd_state(module: CampaignModule, state) -> None:
    print()
    print(render_state(module, state))
    print()
    print(render_turn(module, state))


def cmd_map(module: CampaignModule, state) -> None:
    loc = resolve_location(module, state.current_location)
    lines: list[str] = []
    lines.append(f"  Current location ID: {state.current_location}")
    if loc:
        lines.append(f"  Location: {CYAN}{loc['node']['name']}{RESET}")
        lines.append(f"  Parent: {loc['parent']['name']}")
        if loc["parent"].get("map"):
            lines.append(f"  Map: {DIM}{loc['parent']['map']}{RESET}")
    print()
    print(vbox(lines, title="MAP", color=DIM_CYAN))


def cmd_room(module: CampaignModule, state) -> None:
    loc = resolve_location(module, state.current_location)
    lines: list[str] = []
    lines.append(f"  Current location ID: {state.current_location}")
    if loc:
        lines.append(f"  Room: {CYAN}{loc['node']['name']}{RESET}")
        desc = loc["node"].get("description", "")
        if desc:
            lines.extend(wrap(desc))
    print()
    print(vbox(lines, title="ROOM", color=DIM_CYAN))


def cmd_assets(module: CampaignModule, state) -> None:
    from play_strawberry import get_visual_metadata
    metadata = get_visual_metadata(module, state)
    lines: list[str] = []
    lines.append(
        f"  Map: {metadata['generated']['map']['asset_id'] if metadata['generated']['map'] else 'None'}"
    )
    lines.append(
        f"  Room: {metadata['generated']['room']['asset_id'] if metadata['generated']['room'] else 'None'}"
    )
    if metadata["generated"]["textures"]:
        lines.append(f"  Textures: {', '.join(metadata['generated']['textures'].keys())}")
    if metadata["generated"]["items"]:
        lines.append(f"  Items: {', '.join(metadata['generated']['items'].keys())}")
    if metadata["generated"]["tokens"]:
        lines.append(f"  Tokens: {', '.join(metadata['generated']['tokens'].keys())}")
    print()
    print(vbox(lines, title="ASSETS", color=DIM_CYAN))


def cmd_help() -> None:
    lines = [
        f"  {WHITE}story commands:{RESET}",
        f"    {GREEN}<number>{RESET} or {GREEN}<choice id>{RESET}  Make a story choice",
        f"",
        f"  {WHITE}system commands:{RESET}",
        f"    {DIM}state{RESET}      Show player flags, stats, inventory",
        f"    {DIM}map{RESET}        Show current map location",
        f"    {DIM}room{RESET}       Show current room description",
        f"    {DIM}assets{RESET}     List visual assets for current location",
        f"    {DIM}save{RESET}       Save current game",
        f"    {DIM}load{RESET}       Load saved game",
        f"    {DIM}saves{RESET}      List save files",
        f"    {DIM}delete save{RESET} Delete saved game",
        f"    {DIM}help{RESET}       Show this help",
        f"    {DIM}quit{RESET}       Exit the game",
    ]
    print()
    print(vbox(lines, title="HELP", color=DIM_CYAN))


# ── Main loop ────────────────────────────────────────────────────────────

def main() -> None:
    module = CampaignModule("campaigns/strawberry_omen")
    state = module.new_state()
    module.enter_scene(state)
    saves = ModuleSaveSystem(module)

    print()
    print(f"{RED}{BG_RED}{FG_BLACK}  THE STRAWBERRY OMEN  {RESET}")
    print(
        f"{DIM_RED}  A Breakroom Campaign of Moist Corporate Horror{RESET}"
    )
    print(
        f"{DIM}  Cursed Horror Terminal v1.0  "
        f"|  {module.campaign['title']}{RESET}"
    )
    print()
    print(render_turn(module, state))

    while True:
        print()
        raw = input(f"{RED}{BOLD}Choice / command >{RESET} ").strip()

        if not raw:
            print(render_turn(module, state))
            continue

        low = raw.lower()

        if low in {"quit", "q", "exit"}:
            print()
            print(
                f"{RED}The breakroom returns to plausible deniability.{RESET}"
            )
            print(
                f"{DIM_RED}The fluorescent lights click off, one by one.{RESET}"
            )
            return

        if low in {"help", "h", "?"}:
            cmd_help()
            continue

        if low == "state":
            cmd_state(module, state)
            continue

        if low == "map":
            cmd_map(module, state)
            continue

        if low == "room":
            cmd_room(module, state)
            continue

        if low == "assets":
            cmd_assets(module, state)
            continue

        if low == "save":
            print()
            print(f"{GREEN}{saves.save_game(state)}{RESET}")
            continue

        if low == "load":
            loaded = saves.load_game()
            if loaded is not None:
                state = loaded
                module.enter_scene(state)
                print()
                print(f"{GREEN}Game loaded. Resumed at: {state.current_scene}{RESET}")
                print()
                print(render_turn(module, state))
            else:
                print(f"{DIM_RED}No save found.{RESET}")
            continue

        if low == "saves":
            available = saves.list_saves()
            print()
            if not available:
                print(f"{DIM}(no save files){RESET}")
            else:
                print(vbox(
                    [
                        f"{s['slot']}  {s['file']}  {DIM}scene={s['current_scene']}{RESET}  {DIM}{s['timestamp']}{RESET}"
                        for s in available
                    ],
                    title="SAVES",
                    color=DIM_CYAN,
                ))
            continue

        if low == "delete save":
            print()
            print(f"{YELLOW}{saves.delete_save()}{RESET}")
            continue

        # ── Story choice ────────────────────────────────────────────────
        scene = module.scene(state.current_scene)
        choices = scene.get("choices", [])
        choice_id = raw

        if raw.isdigit():
            idx = int(raw) - 1
            if 0 <= idx < len(choices):
                choice_id = choices[idx]["id"]
            else:
                print(f"{RED}No choice number {raw}.{RESET}")
                continue

        try:
            prev_scene = state.current_scene
            result = module.choose(state, choice_id)
            print()
            print(render_result(result, module, state))
            # Completion-loop guard: if the scene did not change after a
            # choice in a completion_encounter, the game is over.
            if state.current_scene == prev_scene and scene.get("type") == "completion_encounter":
                print()
                print(f"{YELLOW}{BOLD}THE GAME IS COMPLETE.{RESET}")
                print(f"{DIM}The breakroom has nothing left to show you.{RESET}")
                return
            print()
            print(render_turn(module, state))
        except KeyError:
            print(f"{RED}No such choice: '{choice_id}'{RESET}")


if __name__ == "__main__":
    main()
