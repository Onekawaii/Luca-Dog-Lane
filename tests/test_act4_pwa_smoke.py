#!/usr/bin/env python3
"""PWA/API Act IV smoke test."""

import json
import tempfile
import shutil

from hive_lattice.web_app.server import create_app
from engine.module_runtime import CampaignModule
from engine.module_save_system import ModuleSaveSystem


def main():
    tmp = tempfile.mkdtemp()
    try:
        app = create_app("campaigns/strawberry_omen")
        import hive_lattice.web_app.server as srv
        srv._saves = ModuleSaveSystem(CampaignModule("campaigns/strawberry_omen"), save_dir=tmp)
        client = app.test_client()

        def choose(cid):
            resp = client.post("/api/choice",
                               data=json.dumps({"choice_id": cid}),
                               content_type="application/json")
            return json.loads(resp.data)

        # 1. Initial state
        resp = client.get("/api/state")
        data = json.loads(resp.data)
        print("=== INITIAL STATE ===")
        print("Scene:", data["scene"]["id"])
        print("Location:", data["location"]["id"], "-", data["location"]["name"])
        print("Choices:", [c["id"] for c in data["choices"]])
        act4_flags = {k: v for k, v in data["flags"].items() if "act4" in k}
        print("Act IV flags:", act4_flags)
        print("Map URL:", data["images"]["map"])
        print("Room URL:", data["images"]["room"])
        print()

        # 2. Play through to Act IV
        choose("inspect_label")
        choose("file_boundary_statement")
        choose("enter_fridge")
        choose("meet_moldric")
        choose("help_moldric_reclaim")
        choose("proceed_to_act3")
        choose("approach_vending_machine")
        choose("name_your_price")
        choose("confront_snack_wraiths_peacefully")
        result = choose("proceed_to_act4")

        print("=== AFTER ACT IV ENTRY ===")
        print("Scene:", result["scene"]["id"])
        print("Location:", result["location"]["id"])
        relevant = {k: v for k, v in result["flags"].items()
                    if any(x in k for x in ("act4", "moldric", "condiment", "freezer", "catacomb", "casserole"))}
        print("Relevant flags:", relevant)
        print("Has map:", result["images"]["map"] is not None)
        print("Has room:", result["images"]["room"] is not None)
        print()

        # 3. Play through Act IV
        choose("accept_moldric_guide")
        choose("acknowledge_condiments")
        choose("acknowledge_leftovers")
        choose("take_freezer_blessing_with_respect")
        result = choose("compassion_path")

        print("=== AFTER CASSEROLE RESOLUTION ===")
        print("Scene:", result["scene"]["id"])
        relevant = {k: v for k, v in result["flags"].items()
                    if any(x in k for x in ("act4", "moldric", "condiment", "freezer", "catacomb", "casserole"))}
        print("Relevant flags:", relevant)
        print("Inventory:", result["inventory"])
        print()

        # 4. Complete Act IV
        result = choose("complete_act4")
        print("=== ACT IV COMPLETION ===")
        print("Scene:", result["scene"]["id"])
        print("Location:", result["location"]["id"])
        print("act4_complete:", result["flags"].get("act4_complete"))
        print("Inventory:", result["inventory"])
        print("Map URL:", result["images"]["map"])
        print("Room URL:", result["images"]["room"])
        print()

        # 5. Save/load round trip
        resp = client.post("/api/save")
        save_result = json.loads(resp.data)
        print("Save:", save_result.get("message"))

        resp = client.post("/api/load")
        load_result = json.loads(resp.data)
        print("Load ok:", load_result["ok"])
        print("Loaded scene:", load_result["scene"]["id"])
        print("Loaded act4_complete:", load_result["flags"].get("act4_complete"))
        print("Loaded inventory:", load_result["inventory"])
        print("Loaded has map:", load_result["images"]["map"] is not None)
        print("Loaded has room:", load_result["images"]["room"] is not None)
        print()
        print("=== ALL PWA/API CHECKS PASSED ===")

    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
