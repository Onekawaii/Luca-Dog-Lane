extends SceneTree

var failures:Array[String]=[]
var save_root:="user://qa_v025_%d_{seed}.json" % Time.get_ticks_usec()
var loadout_path:="user://qa_v025_loadout_%d.json" % Time.get_ticks_usec()

func check(ok:bool, what:String)->void:
    print(("[PASS] " if ok else "[FAIL] ")+what)
    if not ok:failures.append(what)

func _initialize()->void:
    OS.set_environment("LUCA_V013_SLICE_SAVE_PATH",save_root)
    OS.set_environment("SPIRAL_LOADOUT_SAVE_PATH",loadout_path)
    OS.set_environment("SPIRAL_STATE_SAVE_PATH","user://qa_v025_spiral_%d.json" % Time.get_ticks_usec())
    OS.set_environment("SPIRAL_SKIP_TITLE","1")
    call_deferred("_run")

func _run()->void:
    var game:Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var terrain=game.get("terrain_slice")
    var macro=game.get("macro_terrain")
    var player=game.get("player")
    var hud=game.get("hud")
    check(game.call("uses_world_voxels"),"voxel world enabled")
    check(macro.get("terrain_body")==null,"no parallel smooth visible or collision macro mesh")
    for name in ["MainRoadNS","MainRoadEW","ForestRoad","QuarryRoad","SandboxPad","SkateFloor","RoundPlaza","PlazaBridge"]:
        check(game.get_node_or_null(name)==null,"no duplicate floating surface: "+name)
    check(terrain.get("voxel_tool")!=null,"VoxelTool is sole road/ground authority")
    var pos:=Vector3i(1,-1,25)
    var loaded:=false
    for i in range(560):
        await physics_frame
        if terrain.call("_is_editable",pos):
            loaded=true
            break
    check(loaded,"road voxel chunk streams with visuals and collision")
    if not loaded:
        _done(game)
        return
    var voxel_tool=terrain.get("voxel_tool")
    check(int(voxel_tool.call("get_voxel",pos))==8,"main road is actual asphalt voxel ID 8, not mesh")
    check(int(voxel_tool.call("get_voxel",Vector3i(0,-1,30)))==9,"road marking is a voxel material, not painted mesh")
    var collision_query:=PhysicsRayQueryParameters3D.create(Vector3(1.5,8.0,25.5),Vector3(1.5,-12.0,25.5),1)
    var before:Dictionary={}
    for i in range(110):
        await physics_frame
        before=player.get_world_3d().direct_space_state.intersect_ray(collision_query)
        if not before.is_empty():break
    check(not before.is_empty(),"road has real physics contact before blast")
    var explosive=game.call("spawn_prop","explosive_barrel",Vector3(1.5,1.0,25.5))
    check(explosive.has_method("take_damage"),"actual barrel can take hammer strike")
    explosive.call("take_damage",25.0,Vector3.ZERO,player.global_position)
    check(int(voxel_tool.call("get_voxel",pos))==0,"explosion removes road render voxel rather than hiding collisions only")
    for i in range(130):
        await physics_frame
    var after:Dictionary=player.get_world_3d().direct_space_state.intersect_ray(collision_query)
    check(not before.is_empty() and not after.is_empty() and float(after.position.y)<float(before.position.y)-0.75,"road visual geometry and physics changed together")
    var bag=terrain.get("inventory")
    bag.call("add_item","apple",20)
    for id in ["stone","grass_block","stone_brick","wood_plank","metal_block"]:
        bag.call("add_item",id,10)
    var snapshot:Dictionary=game.call("get_inventory_snapshot_for_ui")
    check(int(snapshot.get("apple",0))==20 and int(snapshot.get("wood_plank",0))==10,"inventory holds 20 apples + five materials x10")
    var panel=hud.get("inventory_panel")
    panel.call("refresh")
    check(panel.get("stock_list").get_child_count()==6,"satchel only shows six actually owned item categories")
    check(panel.get("summary_label").text.contains("70 TOTAL UNITS"),"satchel totals exact owned quantity")
    check(not panel.get("summary_label").text.contains("RECIPES"),"recipes not mixed with bag stock")
    var build=hud.get("build_panel")
    var loadout=hud.get("loadout_panel")
    check(build!=null and loadout!=null and build!=panel and loadout!=panel,"three distinct menus exist")
    hud.call("_toggle_build_menu")
    check(build.visible and not panel.visible and not loadout.visible,"build catalog independently opens")
    hud.call("_toggle_loadout_menu")
    check(loadout.visible and not build.visible and not panel.visible,"nine-slot assignments independently open")
    var known:Array[String]=game.call("get_discovered_items")
    check(known.has("apple") and known.has("wood_plank") and not known.has("concrete_block"),"discovery tracks actual acquisitions (even outside build menu)")
    check(game.call("get_hotbar_slots").size()==9,"exactly nine assignable slots")
    check(game.call("assign_hotbar_slot",0,"item","wood_plank"),"discovered material can be assigned to slot 1")
    player.call("select_hotbar_slot",0)
    check(game.call("get_selected_build_material")=="wood_plank" and player.call("_current_tool_id")=="place","assigned hotkey selects chosen build material")
    check(not game.call("assign_hotbar_slot",1,"item","concrete_block"),"undiscovered material rejected for loadout")
    check(game.get("loadout").call("save_now"),"loadout and discoveries save as sidecar")
    var sidecar=JSON.parse_string(FileAccess.get_file_as_string(loadout_path))
    check(int(sidecar.get("schema_version",-1))==1 and sidecar.get("slots",[]).size()==9,"loadout sidecar versioned without altering world save")
    var collected:Dictionary=game.get("loadout").get("discovered")
    check(collected.has("apple"),"discovery entry survives leaving inventory")
    game.call("save_session")
    var saved=JSON.parse_string(FileAccess.get_file_as_string(terrain.get("persistence").get("save_path")))
    check(int(saved.get("schema_version",-1))==1 and int(saved.get("edits",{}).get("1,-1,25",-1))==0,"road damage persists in unchanged terrain schema")
    game.queue_free()
    for i in range(5):await process_frame
    var replay=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(replay)
    var new_tool=replay.get("terrain_slice").get("voxel_tool")
    var load_ready:=false
    for i in range(560):
        await physics_frame
        if replay.get("terrain_slice").call("_is_editable",pos):
            load_ready=true
            break
    check(load_ready and int(new_tool.call("get_voxel",pos))==0,"road crater stays visually and physically absent after reload")
    var slots:Array[Dictionary]=replay.call("get_hotbar_slots")
    check(slots.size()==9 and slots[0].get("id","")=="wood_plank","slot assignment survives world reload")
    check(replay.call("get_discovered_items").has("apple"),"apple discovery survives world reload")
    _done(replay)

func _done(world:Node)->void:
    world.queue_free()
    for path in [loadout_path,save_root.replace("{seed}","6060")]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    if failures.is_empty():
        print("[ALL UNIFIED VOXEL + SATCHEL + CATALOG + LOADOUT GATES PASSED]")
        quit(0)
    else:
        print("[UNIFIED VOXEL/LOADOUT FAILURES] "+str(failures))
        quit(1)
