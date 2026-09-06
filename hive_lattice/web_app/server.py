"""Flask-based local web server for playing Strawberry Omen on a phone browser.

Usage:
    python -m hive_lattice.cli web strawberry_omen

Endpoints:
    GET  /                    Mobile UI
    GET  /api/state           Current scene, choices, flags, stats, inventory, visuals
    POST /api/choice          Apply a choice by id
    POST /api/save            Save current state
    POST /api/item/use        Use an available inventory action
    POST /api/load            Load the default save
    GET  /api/saves           List available saves
    POST /api/delete-save     Delete the default save
    GET  /api/assets/<path>   Serve generated PNG assets safely
"""

from __future__ import annotations

import json
import os
import socket
from pathlib import Path
from typing import Optional

from flask import Flask, jsonify, render_template, request, send_from_directory

from engine.module_runtime import CampaignModule, ModuleState
from engine.module_save_system import ModuleSaveSystem
from hive_lattice.web_app.presentation import derive_act_progression

# Closure-scoped state — populated inside create_app()
_state: Optional[ModuleState] = None
_module: Optional[CampaignModule] = None
_saves: Optional[ModuleSaveSystem] = None


def _get_ip() -> str:
    """Best-effort LAN IP detection."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def create_app(campaign_path: str | Path) -> Flask:
    """Create and configure the Flask app for a given campaign.

    Each call creates a *new* Flask instance so routes are never re-registered.
    """
    global _module, _state, _saves

    campaign_root = Path(campaign_path)
    _module = CampaignModule(str(campaign_root))
    _state = _module.new_state()
    _module.enter_scene(_state)
    _saves = ModuleSaveSystem(_module)

    generated_dir = (campaign_root / "assets" / "generated").resolve()
    generated_dir.mkdir(parents=True, exist_ok=True)

    app = Flask(
        __name__,
        template_folder=str(Path(__file__).parent / "templates"),
        static_folder=str(Path(__file__).parent / "static"),
    )

    # ----- routes --------------------------------------------------------

    @app.route("/")
    def index():
        return render_template("index.html")

    @app.route("/api/state")
    def api_state():
        return jsonify(_build_state_response())

    @app.route("/api/choice", methods=["POST"])
    def api_choice():
        global _state
        data = request.get_json(force=True)
        choice_id = data.get("choice_id", "").strip()
        if not choice_id:
            return jsonify({"error": "choice_id is required"}), 400
        try:
            result = _module.choose(_state, choice_id)
            return jsonify({"ok": True, "result": result, **_build_state_response()})
        except (KeyError, PermissionError) as exc:
            return jsonify({"error": str(exc)}), 400

    @app.route("/api/item/use", methods=["POST"])
    def api_item_use():
        data = request.get_json(force=True)
        action_id = data.get("action_id", "").strip()
        if not action_id:
            return jsonify({"error": "action_id is required"}), 400
        try:
            result = _module.use_item(_state, action_id)
            return jsonify({"ok": True, "result": result, **_build_state_response()})
        except (KeyError, PermissionError) as exc:
            return jsonify({"error": str(exc)}), 400

    @app.route("/api/save", methods=["POST"])
    def api_save():
        msg = _saves.save_game(_state)
        return jsonify({"ok": True, "message": msg})

    @app.route("/api/load", methods=["POST"])
    def api_load():
        global _state
        loaded = _saves.load_game()
        if loaded is None:
            return jsonify({"ok": False, "error": "No save file found."}), 404
        _state = loaded
        return jsonify({"ok": True, "message": "Game loaded.", **_build_state_response()})

    @app.route("/api/saves")
    def api_saves():
        return jsonify({"saves": _saves.list_saves()})

    @app.route("/api/delete-save", methods=["POST"])
    def api_delete_save():
        msg = _saves.delete_save()
        return jsonify({"ok": True, "message": msg})

    @app.route("/api/arena/render")
    def api_arena_render():
        scene = _module.scene(_state.current_scene)
        if scene.get("type") != "arena_encounter":
            return jsonify({"error": "No active arena scene."}), 404
        try:
            from engine.render_bridge import render_arena_png, RendererUnavailableError
            png_bytes = render_arena_png(_state, size=256, engine="real", device="cpu")
        except RendererUnavailableError as exc:
            return jsonify({
                "error": "Arena renderer unavailable (optional dependency not installed).",
                "detail": str(exc),
            }), 503
        except Exception as exc:  # noqa: BLE001 - surface renderer failures to the client
            return jsonify({"error": "Arena render failed.", "detail": str(exc)}), 500
        return app.response_class(png_bytes, mimetype="image/png")

    @app.route("/api/assets/<path:asset_path>")
    def api_assets(asset_path: str):
        if ".." in asset_path or asset_path.startswith("/"):
            return jsonify({"error": "Invalid path"}), 403
        safe = generated_dir / asset_path
        if not safe.exists() or not safe.is_file():
            return jsonify({"error": "Asset not found"}), 404
        if not asset_path.endswith((".png", ".jpg", ".jpeg", ".gif")):
            return jsonify({"error": "Forbidden"}), 403
        return send_from_directory(str(generated_dir), asset_path)

    return app


def _asset_url(asset: dict) -> str | None:
    """Convert a generated asset dict to a browser-safe URL relative to /api/assets/.

    The generated_manifest.json paths look like:
        assets/generated/maps/map.breakroom.png
    The /api/assets/ route serves from the generated/ directory, so the URL must
    be relative to that directory:
        /api/assets/maps/map.breakroom.png
    """
    if not asset:
        return None
    path = asset.get("path", "")
    prefix = "assets/generated/"
    if path.startswith(prefix):
        return f"/api/assets/{path[len(prefix):]}"
    return None


def _renderer_available() -> bool:
    try:
        from engine.render_bridge import is_renderer_available
        return is_renderer_available()
    except Exception:
        return False


def _build_state_response() -> dict:
    """Build the JSON payload for /api/state."""
    scene = _module.scene(_state.current_scene)
    choices = _module.choice_views(_state)

    try:
        from play_strawberry import get_visual_metadata
        visual = get_visual_metadata(_module, _state)
    except Exception:
        visual = {}

    map_url = _asset_url(visual.get("generated", {}).get("map"))
    room_url = _asset_url(visual.get("generated", {}).get("room"))

    is_arena_scene = scene.get("type") == "arena_encounter"

    return {
        "scene": {
            "id": scene["id"],
            "title": scene.get("title", ""),
            "read_aloud": scene.get("read_aloud", ""),
            "type": scene.get("type", "encounter"),
        },
        "choices": choices,
        "location": {
            "id": _state.current_location,
            "name": visual.get("location_name", _state.current_location),
        },
        "flags": dict(_state.flags),
        "stats": dict(_state.stats),
        "inventory": list(_state.inventory),
        "inventory_details": _module.item_details(_state),
        "conditions": dict(_state.conditions),
        "npc_memory": dict(_state.npc_memory),
        "room_state": dict(_state.room_state.get(_state.current_location, {})),
        "system": {
            "turn_count": _state.turn_count,
            "last_outcome": dict(_state.last_outcome),
            "last_event": (_state.event_history[-1] if _state.event_history else None),
            "department_verdict": _state.flags.get("department_verdict"),
        },
        "log": _state.log[-8:] if _state.log else [],
        "progression": derive_act_progression(_state.flags),
        "images": {
            "map": map_url,
            "room": room_url,
        },
        "arena": {
            "active": is_arena_scene,
            "render_url": "/api/arena/render" if is_arena_scene else None,
            "renderer_available": _renderer_available() if is_arena_scene else None,
        },
    }


def _detect_urls(port: int) -> tuple[str, str]:
    """Return (desktop_url, lan_url)."""
    desktop = f"http://127.0.0.1:{port}"
    lan_ip = _get_ip()
    lan = f"http://{lan_ip}:{port}"
    return desktop, lan


def run_server(campaign_path: str | Path, port: int = 8000) -> None:
    """Create and run the web server (blocking)."""
    app_obj = create_app(campaign_path)
    desktop, lan = _detect_urls(port)
    print()
    print("  ============================================")
    print("   Strawberry Omen — Reactive Lattice (v0.6.0)")
    print("  ============================================")
    print()
    print(f"  Local (desktop): {desktop}")
    print(f"  LAN (phone):     {lan}")
    print()
    print("  Make sure your phone is on the same Wi-Fi network.")
    print("  If prompted by Windows Firewall, allow Python on")
    print("  private networks.")
    print()
    print("  To install as an app: open the LAN URL on your phone,")
    print("  then use your browser's 'Add to Home Screen' option.")
    print()
    print("  Press Ctrl+C to stop.")
    print()
    app_obj.run(host="0.0.0.0", port=port, debug=False)
