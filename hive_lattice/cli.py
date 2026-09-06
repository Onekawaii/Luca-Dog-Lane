"""Hive-Lattice CLI — formal command-line interface for campaign modules.

Usage:
    python -m hive_lattice.cli <command> <campaign_id>

Commands:
    play <campaign>         Launch the interactive campaign runner
    validate <campaign>     Run campaign + visual-asset validation
    generate-assets <campaign>  Generate deterministic visual assets
    asset-summary <campaign>    Print visual asset summary
    saves <campaign>            List available save files
    web <campaign>              Start local mobile web app
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import List

CAMPAIGNS = {
    "strawberry_omen": Path("campaigns/strawberry_omen"),
}

USAGE = """\
usage: python -m hive_lattice.cli <command> <campaign>

commands:
  play <campaign>              Launch the interactive campaign runner
  validate <campaign>          Run campaign + visual-asset validation
  generate-assets <campaign>   Generate deterministic visual assets
  asset-summary <campaign>     Print visual asset summary
  saves <campaign>             List available save files
  web <campaign>               Start local mobile web app

supported campaigns:
  strawberry_omen
"""


def _resolve_campaign(campaign_id: str) -> Path | None:
    return CAMPAIGNS.get(campaign_id)


def _cmd_play(campaign_id: str) -> int:
    path = _resolve_campaign(campaign_id)
    if path is None:
        print(f"error: unsupported campaign '{campaign_id}'")
        print(f"supported campaigns: {', '.join(CAMPAIGNS)}")
        return 1

    if campaign_id == "strawberry_omen":
        import importlib
        mod = importlib.import_module("play_strawberry")
        mod.main()
        return 0

    print(f"error: no runner configured for '{campaign_id}'")
    return 1


def _cmd_validate(campaign_id: str) -> int:
    path = _resolve_campaign(campaign_id)
    if path is None:
        print(f"error: unsupported campaign '{campaign_id}'")
        print(f"supported campaigns: {', '.join(CAMPAIGNS)}")
        return 1

    from tools.validate_campaign_module import validate
    from tools.validate_visual_assets import validate_visual_assets

    errors: List[str] = []
    errors.extend(validate(path))
    errors.extend(validate_visual_assets(path))

    if errors:
        print("Campaign module validation FAILED")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"Campaign module validation PASSED: {path}")
    return 0


def _cmd_generate_assets(campaign_id: str) -> int:
    path = _resolve_campaign(campaign_id)
    if path is None:
        print(f"error: unsupported campaign '{campaign_id}'")
        print(f"supported campaigns: {', '.join(CAMPAIGNS)}")
        return 1

    from tools.generate_visual_assets import VisualAssetGenerator

    generator = VisualAssetGenerator(campaign_path=str(path))
    generator.generate_all_assets()
    generator.update_visual_manifest()
    print(f"\nGenerated assets: {path / 'assets' / 'generated'}")
    return 0


def _cmd_asset_summary(campaign_id: str) -> int:
    path = _resolve_campaign(campaign_id)
    if path is None:
        print(f"error: unsupported campaign '{campaign_id}'")
        print(f"supported campaigns: {', '.join(CAMPAIGNS)}")
        return 1

    from tools.visual_assets_summary import find_visual_assets

    find_visual_assets(path)
    return 0


def _cmd_saves(campaign_id: str) -> int:
    path = _resolve_campaign(campaign_id)
    if path is None:
        print(f"error: unsupported campaign '{campaign_id}'")
        print(f"supported campaigns: {', '.join(CAMPAIGNS)}")
        return 1

    from engine.module_runtime import CampaignModule
    from engine.module_save_system import ModuleSaveSystem

    module = CampaignModule(str(path))
    saves = ModuleSaveSystem(module)
    available = saves.list_saves()

    if not available:
        print(f"No save files found for {campaign_id}.")
    else:
        print(f"\n=== SAVE FILES ({campaign_id}) ===")
        for s in available:
            print(f"  [{s['slot']}] {s['file']}  scene={s['current_scene']}  time={s['timestamp']}")
        print()

    return 0


def _cmd_web(campaign_id: str) -> int:
    path = _resolve_campaign(campaign_id)
    if path is None:
        print(f"error: unsupported campaign '{campaign_id}'")
        print(f"supported campaigns: {', '.join(CAMPAIGNS)}")
        return 1

    try:
        from hive_lattice.web_app.server import run_server
    except ImportError as exc:
        print(f"error: web app dependencies missing ({exc})")
        print("install with: pip install flask")
        return 1

    run_server(path)
    return 0


SUBCOMMAND_HELP = """\
usage: python -m hive_lattice.cli {command} <campaign>

{caption}

supported campaigns:
  strawberry_omen
"""

SUBCOMMAND_HELP_TEXT = {
    "play": "Launch the interactive campaign runner",
    "validate": "Run campaign + visual-asset validation",
    "generate-assets": "Generate deterministic visual assets",
    "asset-summary": "Print visual asset summary",
    "saves": "List available save files",
    "web": "Start local mobile web app",
}

COMMANDS = {
    "play": _cmd_play,
    "validate": _cmd_validate,
    "generate-assets": _cmd_generate_assets,
    "asset-summary": _cmd_asset_summary,
    "saves": _cmd_saves,
    "web": _cmd_web,
}


def _print_subcommand_help(command: str) -> int:
    caption = SUBCOMMAND_HELP_TEXT.get(command, "Run the specified command.")
    print(SUBCOMMAND_HELP.format(command=command, caption=caption))
    return 0


def main(argv: List[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]

    if not args or args[0] in ("-h", "--help", "help"):
        print(USAGE)
        return 0

    command = args[0]
    if command in ("-h", "--help", "help"):
        print(USAGE)
        return 0

    handler = COMMANDS.get(command)
    if handler is None:
        print(f"error: unknown command '{command}'")
        print()
        print(USAGE)
        return 1

    if len(args) < 2 or args[1] in ("-h", "--help", "help"):
        return _print_subcommand_help(command)

    return handler(args[1])


if __name__ == "__main__":
    raise SystemExit(main())
