extends "res://tests/phase8_multi_seed_smoke_test.gd"
## Execute the existing 120-generation assertions after SceneTree initialization.
## Historical _initialize runs before children can safely call get_tree().


func _initialize() -> void:
	call_deferred("_run_generation")


func _run_generation() -> void:
	super._initialize()
