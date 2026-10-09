extends SceneTree
func _initialize() -> void:
    OS.set_environment("LUCA_V013_SLICE_SAVE_PATH","user://qa_capture_%d_{seed}.json" % Time.get_ticks_usec())
    OS.set_environment("SPIRAL_LOADOUT_SAVE_PATH","user://qa_capture_slots_%d.json" % Time.get_ticks_usec())
    OS.set_environment("SPIRAL_SKIP_TITLE","1")
    OS.set_environment("SPIRAL_STATE_SAVE_PATH","user://qa_v025_visual_story_%d.json" % Time.get_ticks_usec())
    call_deferred("_capture")

func _capture()->void:
    root.size=Vector2i(1280,720)
    var world=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var player=world.get("player")
    player.call("toggle_noclip")
    player.global_position=Vector3(1.5,17.0,43.5)
    player.set("pitch",-0.80)
    player.call("add_look_delta",Vector2.ZERO)
    var terra=world.get("terrain_slice")
    for i in range(220):
        await physics_frame
        if terra.call("_is_editable",Vector3i(1,-1,25)):
            break
    for i in range(120):await process_frame
    var cam:Camera3D=player.get("camera")
    print("CAMERA_VIEW position=",cam.global_position," orientation=",cam.global_transform.basis.z," blast_projected=",cam.unproject_position(Vector3(1.5,0.0,25.5))," behind=",cam.is_position_behind(Vector3(1.5,0.0,25.5)))
    var before=get_root().get_texture().get_image()
    if before==null:
        printerr("FRAME_CAPTURE_UNAVAILABLE: no rendered viewport")
        world.queue_free()
        quit(2)
        return
    var rc1=before.save_png("res://dist/v025-road-before.png")
    print("SCREEN_BEFORE status=",rc1," resolution=",before.get_size())
    var barrel=world.call("spawn_prop","explosive_barrel",Vector3(1.5,1.1,25.5))
    barrel.call("take_damage",25.0,Vector3.ZERO,player.global_position)
    for i in range(120):await process_frame
    var after=get_root().get_texture().get_image()
    if after==null:
        printerr("FRAME_CAPTURE_UNAVAILABLE: no postblast viewport")
        world.queue_free()
        quit(2)
        return
    var rc2=after.save_png("res://dist/v025-road-after.png")
    print("SCREEN_AFTER status=",rc2," resolution=",after.get_size())
    var different:=false
    if before.get_size()==after.get_size():
        var changed:=0
        for y in range(170,710,8):
            for x in range(80,1160,8):
                if (Vector3(before.get_pixel(x,y).r,before.get_pixel(x,y).g,before.get_pixel(x,y).b)-Vector3(after.get_pixel(x,y).r,after.get_pixel(x,y).g,after.get_pixel(x,y).b)).length()>0.15:
                    changed+=1
        print("FRAME_CHANGED_PIXEL_SAMPLES=",changed)
        different=changed>10
    var blast_projection:Vector2=cam.unproject_position(Vector3(1.5,0.0,25.5))
    var local_differences:=0
    if not cam.is_position_behind(Vector3(1.5,0.0,25.5)):
        for y in range(maxi(1,int(blast_projection.y)-40),mini(719,int(blast_projection.y)+40)):
            for x in range(maxi(1,int(blast_projection.x)-40),mini(1279,int(blast_projection.x)+40)):
                var a:Color=before.get_pixel(x,y)
                var b:Color=after.get_pixel(x,y)
                if maxi(absi(int(255.0*(a.r-b.r))),maxi(absi(int(255.0*(a.g-b.g))),absi(int(255.0*(a.b-b.b)))))>35:
                    local_differences+=1
    print("CRATER_SCREEN_CHANGED_PIXELS=",local_differences," center=",blast_projection)
    var visible_crater:=rc1==OK and rc2==OK and local_differences>300
    print("[PASS] visible hole at the actual blast coordinates" if visible_crater else "[FAIL] no visible crater at detonation site")
    world.queue_free()
    quit(0 if different and visible_crater else 1)
