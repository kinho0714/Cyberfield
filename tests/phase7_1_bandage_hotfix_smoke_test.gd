extends SceneTree

const BANDAGE_SCRIPT := preload("res://scene/interactables/bandage_pickup.gd")
const PLAYER_SCENE := preload("res://entities/player.tscn")


func _initialize() -> void:
	var bandage := BANDAGE_SCRIPT.new()
	bandage._ready()
	assert(bandage.is_in_group("interactable"))
	assert(bandage.has_method("interact"))
	var p1 := PLAYER_SCENE.instantiate()
	p1.input_profile = "p1"
	var p2 := PLAYER_SCENE.instantiate()
	p2.input_profile = "p2"
	assert(p1._action(&"interact") == &"interact")
	assert(p2._action(&"interact") == &"p2_interact")
	var source := FileAccess.get_file_as_string("res://scene/interactables/bandage_pickup.gd")
	assert(not source.contains("player.is_action_just_pressed"))
	bandage.free()
	p1.free()
	p2.free()
	print("PHASE7_1_BANDAGE_HOTFIX_SMOKE_TEST_OK")
	quit()
