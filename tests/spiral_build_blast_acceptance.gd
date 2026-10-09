extends SceneTree

var failures: Array[String] = []
var terrain_path := "user://qa_spiral_build_%d.json" % Time.get_ticks_usec()
var spiral_path := "user://qa_spiral_build_state_%d.json" % Time.get_ticks_usec()

func check(ok: bool, label: String) -> void:
    print("[PASS] " if ok else "[FAIL] ", label)
    if not ok:
        failures.append(label)

func _initialize() -> void:
    OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", terrain_path)
    OS.set_environment("SPIRAL_STATE_SAVE_PATH", spiral_path)
    OS.set_environment("SPIRAL_SKIP_TITLE", "1")
    call_deferred("_run")

func _run() -> void:
    var world := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var slice = world.get("terrain_slice")
    var player = world.get("player")
    var tool = slice.get("voxel_tool")
    var inventory = slice.get("inventory")
    var all_materials: Array = slice.get("BUILD_PALETTE") if false else ["stone", "grass_block", "stone_brick", "wood_plank", "glass_block", "metal_block", "concrete_block"]
    check(world.call("get_selected_build_material") == "stone_brick", "v0.2.2 selected material default preserved")
    check(str(world.call("toggle_build_mode")).contains("ON"), "creative building mode enables")
    var all_seen: Dictionary = {}
    for _i in range(7):
        var material: String = str(world.call("get_selected_build_material"))
        all_seen[material] = true
        world.call("cycle_build_material")
    check(all_seen.size() == 7 and all_seen.has("wood_plank") and all_seen.has("metal_block"), "seven unique materials cycle")
    check(str(world.call("get_selected_build_material")) == "stone_brick", "palette wraps back to selection")
    check(world.call("get_item_catalog_for_ui").has("glass_block"), "inventory catalog exposes glass")
    check(world.call("get_recipe_catalog_for_ui").has("concrete_block"), "crafting catalog exposes concrete")
    player.global_position = Vector3(10.5, 3.0, 23.5)
    var position := Vector3i(19, 2, 28)
    var ready := false
    for _i in range(650):
        await physics_frame
        if slice.call("_is_editable", position):
            ready = true
            break
    check(ready, "game streamed construction site")
    if not ready:
        _finish()
        return
    # Previously the acceptance suite only demolished blocks it had just authored.
    # This regression starts on pristine generator output with no saved edit key.
    var native := Vector3i(31, -1, 31)
    player.global_position = Vector3(26.5, 3.5, 31.5)
    player.velocity = Vector3.ZERO
    var native_ready := false
    for _stream_tick in range(500):
        await physics_frame
        if bool(slice.call("_is_editable", native)):
            native_ready = true
            break
    check(native_ready, "pristine ground chunk is loaded before blasting")
    var native_before := int(tool.call("get_voxel", native)) if native_ready else 0
    var edits_before: Dictionary = slice.get("persistence").call("get_voxel_deltas")
    var native_key := "31,-1,31"
    check(native_before != 0 and not edits_before.has(native_key), "target is untouched generated terrain, not player-built voxels")
    if native_before != 0 and native_ready:
        var ray := PhysicsRayQueryParameters3D.create(Vector3(31.5, 7.0, 31.5), Vector3(31.5, -8, 31.5), 1)
        var collision_before: Dictionary = {}
        for _collision_tick in range(140):
            await physics_frame
            collision_before = player.get_world_3d().direct_space_state.intersect_ray(ray)
            if not collision_before.is_empty():
                break
        var ground_barrel = world.call("spawn_prop", "explosive_barrel", Vector3(31.5, 1.0, 31.5))
        ground_barrel.call("take_damage", 25.0, Vector3.ZERO, player.global_position)
        var native_after := int(tool.call("get_voxel", native))
        var native_delta: Dictionary = slice.get("persistence").call("get_voxel_deltas")
        check(native_after == 0 and native_delta.has(native_key) and int(native_delta[native_key]) == 0, "barrel carves crater in untouched generated ground")
        var native_air := 0
        for x in range(29, 34):
            for z in range(29, 34):
                if native_before != 0 and int(tool.call("get_voxel", Vector3i(x,-1,z))) == 0:
                    native_air += 1
        check(native_air >= 8, "explosion carves a visible multi-cell ground crater, not an FX overlay")
        for _frame in range(180):
            await physics_frame
        var collision_after: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(ray)
        print("CRATER_COLLISION_DEBUG before=", collision_before, " after=", collision_after)
        check(not collision_before.is_empty() and not collision_after.is_empty() and float(collision_after.position.y) < float(collision_before.position.y) - 0.75, "terrain collision rebuild follows destruction")
        slice.get("persistence").call("save_now")
        var disk = JSON.parse_string(FileAccess.get_file_as_string(slice.get("persistence").get("save_path")))
        check(typeof(disk) == TYPE_DICTIONARY and int(disk.get("edits", {}).get(native_key, -1)) == 0, "pristine terrain crater persists in world save")
    check(str(world.get("hud").get("header_panel").get_node("Title").text).contains(str(ProjectSettings.get_setting("application/config/version"))), "HUD release version agrees with installed build")
    var spawned := 0
    for x in range(16, 22):
        for z in range(25, 31):
            for y in range(1, 5):
                var edge := x == 16 or x == 21 or z == 25 or z == 30
                var roof := y == 4
                var doorway := z == 25 and x == 18 and y <= 2
                if (edge or roof) and not doorway:
                    var block: int = 4 if y < 4 else 7
                    if x == 17 and z == 25:
                        block = 5
                    if x == 20 and z == 30:
                        block = 6
                    if slice.call("apply_voxel_for_test", Vector3i(x, y, z), block):
                        spawned += 1
    check(spawned > 75, "runtime house created with timber, glass, metal, concrete")
    world.call("select_build_material", "wood_plank")
    var placed := str(world.call("terrain_place", Vector3(18.5, 9.5, 28.5), Vector3.DOWN, 8.0, 0.75))
    check(placed.begins_with("PLACED") and int(tool.call("get_voxel", Vector3i(18, 5, 28))) == 4, "actual public build action places timber above roof")
    var untouched := Vector3i(23, 0, 34)
    var original: int = tool.call("get_voxel", untouched)
    var blast_barrel = world.call("spawn_prop", "explosive_barrel", Vector3(18.5, 2.0, 27.5))
    check(blast_barrel != null and blast_barrel.is_in_group("explosive_barrel"), "physical explosive barrel spawned")
    check(blast_barrel.has_method("take_damage"), "hammer can damage barrel")
    var before: Dictionary = slice.get("persistence").call("get_voxel_deltas")
    check(before.size() >= spawned, "house voxel edits entered authoritative save delta")
    var response := str(blast_barrel.call("take_damage", 25.0, Vector3.ZERO, player.global_position))
    check(response.contains("DETONATED"), "hammer impact detonates barrel once")
    check(bool(blast_barrel.get("detonated")), "barrel one-shot guard set")
    var after: Dictionary = slice.get("persistence").call("get_voxel_deltas")
    var blasted := 0
    for key in before:
        if int(before[key]) != 0 and int(after.get(key, -999)) == 0:
            blasted += 1
    check(blasted >= 6, "explosion removes multiple built voxels")
    check(int(tool.call("get_voxel", untouched)) == original, "native terrain outside damage envelope untouched")
    check(world.call("save_session"), "terrain and boss state save without schema mutation")
    var p = JSON.parse_string(FileAccess.get_file_as_string(slice.get("persistence").get("save_path")))
    check(int(p.get("schema_version", -1)) == 1 and int(p.get("generator_version", -1)) == 2, "existing v0.2.2 world save schema preserved")
    var preserved := false
    for key in after:
        if int(after[key]) == 0 and int(before.get(key, 0)) > 0:
            preserved = int(p.get("edits", {}).get(key, 1)) == 0
            break
    check(preserved, "exploded house edits persist on disk")
    check(str(world.call("toggle_build_mode")).contains("RESOURCE"), "creative mode disables without changing inventory")
    check(inventory.call("count_item", "wood_plank") == 0, "creative building does not fabricate survival inventory")
    world.queue_free()
    for _i in range(4):
        await process_frame
    var reloaded_world = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(reloaded_world)
    var reloaded_player = reloaded_world.get("player")
    reloaded_player.global_position = Vector3(26.5, 4.0, 31.5)
    var reloaded_slice = reloaded_world.get("terrain_slice")
    var reload_ready := false
    for _reload_tick in range(620):
        await physics_frame
        if bool(reloaded_slice.call("_is_editable", Vector3i(31,-1,31))):
            reload_ready = true
            break
    check(reload_ready and int(reloaded_slice.get("voxel_tool").call("get_voxel", Vector3i(31,-1,31))) == 0, "destroyed generated terrain stays destroyed after world reload")
    reloaded_world.queue_free()
    for _i in range(5):
        await process_frame
    _check_copy_migration()
    _finish()

func _check_copy_migration() -> void:
    var seed := 1000000 + int(Time.get_ticks_usec() % 700000000)
    var old_path := "user://v020_world_voxels_%d.json" % seed
    var new_path := "user://v023_world_voxels_%d.json" % seed
    var old_snapshot := {"schema_version": 1, "generator_version": 2, "world_seed": seed, "edits": {"11,2,11": 3}, "inventory": {"stone_brick": 18}}
    var original := JSON.stringify(old_snapshot)
    var file := FileAccess.open(old_path, FileAccess.WRITE)
    if file == null:
        check(false, "isolated legacy save fixture writable")
        return
    file.store_string(original)
    file.close()
    OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", "")
    var probe: Node3D = load("res://scripts/world/TerrainSlice.gd").new()
    probe.set("world_voxels", true)
    probe.set("world_seed", seed)
    probe.call("_setup_persistence")
    check(FileAccess.file_exists(new_path), "v0.2.2 world copied to isolated v0.2.3 save")
    var copied = JSON.parse_string(FileAccess.get_file_as_string(new_path)) if FileAccess.file_exists(new_path) else {}
    check(typeof(copied) == TYPE_DICTIONARY and int(copied.get("edits", {}).get("11,2,11", 0)) == 3 and int(copied.get("inventory", {}).get("stone_brick", 0)) == 18, "migration retains world edits and inventory")
    check(FileAccess.get_file_as_string(old_path) == original, "v0.2.2 original save bytes remain untouched")
    probe.free()
    OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", terrain_path)
    for path in [old_path, new_path]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
    for path in [terrain_path.replace("{seed}", "6060"), spiral_path]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    if failures.is_empty():
        print("[ALL SPIRAL BUILD + BLAST GATES PASSED]")
        quit(0)
    else:
        print("[SPIRAL BUILD + BLAST FAILURES] ", failures)
        quit(1)
