class_name LucaWorldBootstrap
extends Node

func _ready() -> void:
	if name != "FirstPersonBootstrap":
		push_warning("LucaWorldBootstrap is running under unexpected root: " + name)
	call_deferred("_verify_runtime")

func _verify_runtime() -> void:
	var world_root := find_child("LucaWorldRoot", true, false)
	if world_root == null:
		push_error("LUCA WORLD BOOTSTRAP: LucaWorldRoot missing")
