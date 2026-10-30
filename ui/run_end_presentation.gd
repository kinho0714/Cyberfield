extends RefCounted
## Visual adapter for the run end overlay (29/10/2026).
## RunDebugHUD still owns data, signals, focus, visibility and the legacy Title
## label (kept as a hidden fallback). This file only builds and fills nodes.

const CYAN := Color("39dff2")
const WHITE := Color("f2f7ff")
const SOFT := Color("bbccd9")
const DIM := Color("7f97a8")
const LOST := Color("ff3d5f")
const WON := Color("43f2b0")
const PANEL_BG := Color(0.010, 0.024, 0.042, 0.97)
const TILE_BG := Color(0.030, 0.066, 0.096, 0.88)
const PANEL_WIDTH := 860.0
const TILE_WIDTH := 252.0
const HEADLINE_FONT := preload("res://assets/fonts/pixelify_sans/PixelifySans-Bold.woff2")


static func build(overlay: ColorRect, vbox: VBoxContainer, title: Label, buttons: Array) -> Dictionary:
	overlay.color = Color(0.004, 0.008, 0.018, 0.90)
	var glow := _make_glow()
	overlay.add_child(glow)
	overlay.move_child(glow, 0)

	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	title.visible = false

	var card := PanelContainer.new()
	card.name = "EndCard"
	ContentRegistry.apply_ui_theme(card)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = PANEL_BG
	card_style.border_color = Color(CYAN, 0.40)
	card_style.set_border_width_all(1)
	card_style.border_width_top = 3
	card_style.content_margin_left = 34.0
	card_style.content_margin_right = 34.0
	card_style.content_margin_top = 24.0
	card_style.content_margin_bottom = 26.0
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	card_style.shadow_size = 18
	card.add_theme_stylebox_override("panel", card_style)
	vbox.add_child(card)
	vbox.move_child(card, 0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)

	var kicker := _label("", 15, DIM)
	kicker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(kicker)
	var headline := _label("RUN PERDIDA", 44, LOST)
	headline.add_theme_font_override("font", HEADLINE_FONT)
	column.add_child(headline)
	var rule := ColorRect.new()
	rule.name = "AccentRule"
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	var values := {}
	for entry: Array in [["time", "TEMPO"], ["difficulty", "DIFICULDADE"], ["stage", "STAGES"], ["route", "ROTA"], ["money", "DINHEIRO OBTIDO"], ["remaining", "RESTANTE"]]:
		values[entry[0]] = _add_tile(grid, String(entry[1]))

	var players := VBoxContainer.new()
	players.name = "Players"
	players.add_theme_constant_override("separation", 8)
	column.add_child(players)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	for value: Variant in buttons:
		var button := value as Button
		if button == null:
			continue
		if button.get_parent() != null:
			button.get_parent().remove_child(button)
		actions.add_child(button)
		_style_button(button)

	return {
		"overlay": overlay, "glow": glow, "card": card, "card_style": card_style,
		"kicker": kicker, "headline": headline, "rule": rule, "values": values,
		"players": players, "pulse": null,
	}


static func populate(view: Dictionary, data: Dictionary) -> void:
	var completed := bool(data.get("completed", false))
	var accent := WON if completed else LOST
	var kicker := view.kicker as Label
	kicker.text = "// " + String(TranslationServer.translate("EXTRAÇÃO CONCLUÍDA" if completed else "SINAL PERDIDO"))
	kicker.add_theme_color_override("font_color", Color(accent, 0.85))
	var headline := view.headline as Label
	headline.text = "RUN CONCLUÍDA" if completed else "RUN PERDIDA"
	headline.add_theme_color_override("font_color", accent)
	(view.rule as ColorRect).color = accent
	(view.card_style as StyleBoxFlat).border_color = Color(accent, 0.55)
	(view.card_style as StyleBoxFlat).border_width_top = 3
	(view.glow as Control).modulate = accent

	var values := view.values as Dictionary
	(values.time as Label).text = String(data.get("time", "00:00"))
	(values.difficulty as Label).text = String(data.get("difficulty", "—"))
	(values.stage as Label).text = "%d / 6" % int(data.get("stage", 1))
	(values.route as Label).text = String(data.get("route", "—"))
	(values.money as Label).text = "$%d" % int(data.get("money_earned", 0))
	(values.remaining as Label).text = "$%d" % int(data.get("remaining", 0))

	var players := view.players as VBoxContainer
	for child in players.get_children():
		players.remove_child(child)
		child.queue_free()
	for entry: Dictionary in data.get("players", []):
		players.add_child(_player_row(entry))


static func play_intro(view: Dictionary, host: Node) -> void:
	stop(view)
	var card := view.card as Control
	var glow := view.glow as Control
	card.modulate.a = 0.0
	glow.self_modulate.a = 0.0
	var intro := host.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro.tween_property(card, "modulate:a", 1.0, 0.35)
	intro.tween_property(glow, "self_modulate:a", 1.0, 0.9)
	# Slow breathing on the accent rule only: one property, no shader, Android-safe.
	var rule := view.rule as Control
	rule.modulate.a = 1.0
	var pulse := host.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pulse.tween_property(rule, "modulate:a", 0.35, 1.2)
	pulse.tween_property(rule, "modulate:a", 1.0, 1.2)
	view["pulse"] = pulse


static func stop(view: Dictionary) -> void:
	var pulse := view.get("pulse") as Tween
	if pulse != null and pulse.is_valid():
		pulse.kill()
	view["pulse"] = null


static func _make_glow() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.20))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 144
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.42)
	texture.fill_to = Vector2(1.0, 0.42)
	var glow := TextureRect.new()
	glow.name = "EndGlow"
	glow.texture = texture
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return glow


static func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _add_tile(grid: GridContainer, caption: String) -> Label:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(TILE_WIDTH, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = TILE_BG
	style.border_color = Color(CYAN, 0.55)
	style.border_width_left = 2
	style.content_margin_left = 14.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 10.0
	tile.add_theme_stylebox_override("panel", style)
	grid.add_child(tile)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	tile.add_child(stack)
	stack.add_child(_label(caption, 13, DIM))
	var value := _label("—", 24, WHITE)
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(value)
	return value


static func _player_row(entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.045, 0.068, 0.75)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	row.add_child(line)
	var id_label := _label(String(entry.get("id", "P1")), 22, CYAN)
	id_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	id_label.custom_minimum_size.x = 44.0
	line.add_child(id_label)
	var stats := _label("INT %d   ·   %s %d   ·   %s %d" % [
		int(entry.get("intellect", 0)),
		String(TranslationServer.translate("SAÚDE")), int(entry.get("health", 0)),
		String(TranslationServer.translate("FORÇA")), int(entry.get("strength", 0)),
	], 17, SOFT)
	stats.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	line.add_child(stats)
	var weapons: PackedStringArray = entry.get("weapons", PackedStringArray())
	var weapon_label := _label("%s   %s" % [String(TranslationServer.translate("ARMAS")), " / ".join(weapons)], 17, WHITE)
	weapon_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_label.clip_text = true
	weapon_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(weapon_label)
	return row


static func _style_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(320.0, 54.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.018, 0.050, 0.075, 0.92)
	normal.border_color = Color(CYAN, 0.30)
	normal.set_border_width_all(1)
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0
	var selected := StyleBoxFlat.new()
	# Same selection language as the main menu (main_menu_alive.gd selection_style).
	selected.bg_color = Color(0.025, 0.16, 0.21, 0.85)
	selected.border_color = CYAN
	selected.set_border_width_all(2)
	selected.content_margin_left = 18.0
	selected.content_margin_right = 18.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", selected)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected)
	button.add_theme_stylebox_override("focus", selected)
	button.add_theme_color_override("font_color", SOFT)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, WHITE)
