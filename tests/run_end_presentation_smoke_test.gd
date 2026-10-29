extends SceneTree
## 29/10: the run end overlay is restyled by ui/run_end_presentation.gd.
## Checks that the adapter keeps the legacy nodes, buttons and data intact.

const PRESENTATION := preload("res://ui/run_end_presentation.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay := ColorRect.new()
	root.add_child(overlay)
	var center := MarginContainer.new()
	overlay.add_child(center)
	var vbox := VBoxContainer.new()
	center.add_child(vbox)
	var title := Label.new()
	title.text = "RUN PERDIDA"
	vbox.add_child(title)
	var restart := Button.new()
	restart.text = "RETORNAR AO LABORATÓRIO"
	vbox.add_child(restart)
	var back := Button.new()
	back.text = "VOLTAR AO MENU"
	vbox.add_child(back)
	var pressed := [0]
	restart.pressed.connect(func() -> void: pressed[0] += 1)

	var view := PRESENTATION.build(overlay, vbox, title, [restart, back])
	assert(not title.visible, "legacy title must stay as hidden fallback")
	assert(restart.get_parent().name == "Actions" and back.get_parent().name == "Actions")
	restart.pressed.emit()
	assert(pressed[0] == 1, "button signal connections must survive reparenting")

	PRESENTATION.populate(view, {
		"completed": false, "time": "00:31", "difficulty": "Normal", "stage": 1, "route": "DIRETA",
		"money_earned": 0, "remaining": 0,
		"players": [{"id": "P1", "intellect": 0, "health": 0, "strength": 0, "weapons": PackedStringArray(["LÂMINA DE SUCATA", "VAZIO"])}],
	})
	assert((view.headline as Label).text == "RUN PERDIDA")
	assert((view.values.time as Label).text == "00:31")
	assert((view.values.money as Label).text == "$0")
	assert((view.players as VBoxContainer).get_child_count() == 1)
	PRESENTATION.play_intro(view, overlay)
	await process_frame
	PRESENTATION.populate(view, {"completed": true, "players": []})
	assert((view.headline as Label).text == "RUN CONCLUÍDA")
	PRESENTATION.stop(view)
	overlay.queue_free()
	await process_frame
	print("RUN_END_PRESENTATION_SMOKE_TEST_OK")
	quit(0)
