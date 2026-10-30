extends SceneTree
## Run after import using --headless --path . --script and this resource path.
## Casa Jhon house stages 0-3: every stage has its room art and light layer, the
## presentation picks the one of MetaProgression.house_stage and clamps bad values.

const PRESENTATION := preload("res://scene/casa_jhon_presentation.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(PRESENTATION.STAGE_ART.size() == 4 and PRESENTATION.STAGE_LIGHTS.size() == 4)
	for stage in 4:
		var art := load(PRESENTATION.STAGE_ART[stage]) as Texture2D
		var lights := load(PRESENTATION.STAGE_LIGHTS[stage]) as Texture2D
		assert(art != null and art.get_size() == Vector2(1280, 384))
		assert(lights != null and lights.get_size() == Vector2(1280, 384))
		var presentation: Node2D = PRESENTATION.new()
		presentation.set_progression_state({"house_stage": stage})
		assert(presentation.visual_stage_id == StringName("hub_stage_%02d" % stage))
		presentation.free()
	assert(PRESENTATION.house_stage_of({"house_stage": 9}) == 3)
	assert(PRESENTATION.house_stage_of({"house_stage": -2}) == 0)
	assert(PRESENTATION.house_stage_of({}) == 0)
	print("HUB_HOUSE_STAGES_SMOKE_TEST_OK")
	quit()
