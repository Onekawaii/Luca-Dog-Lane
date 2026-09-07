extends Node

# AcceptanceRunner project-scene script to execute tests in full autoload context.

const RunAcceptanceScript = preload("res://tests/run_acceptance.gd")


func _ready() -> void:
	print("[ACCEPTANCE RUNNER] Executing acceptance tests within project autoload context...")
	var test_suite = RunAcceptanceScript.new()
	# The test suite calls quit(0) or quit(1)
