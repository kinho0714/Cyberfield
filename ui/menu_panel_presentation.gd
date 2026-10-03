extends RefCounted
## Visual adapter only. Existing pages own input, callbacks and modal lifetime.
const ROOT := "res://assets/ui/menu_panels/assets/shared/"
const CYAN := Color("39dff2")


static func style(path: String, margin: int, padding: int = 0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(ROOT + path + ".png") as Texture2D
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, margin)
		box.set_content_margin(side, padding)
	return box


static func background(page: Control, path: String) -> void:
	# Behind children, ignored by layout/input and stretched with native 9-slice.
	var panel := NinePatchRect.new()
	panel.name = "OfficialPanel"
	panel.texture = load(ROOT + path + ".png") as Texture2D
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backing := Node2D.new()
	backing.name = "OfficialPanelBacking"
	backing.show_behind_parent = true
	panel.patch_margin_left = 18
	panel.patch_margin_right = 18
	panel.patch_margin_top = 18
	panel.patch_margin_bottom = 18
	page.add_child(backing)
	backing.add_child(panel)
	panel.position = Vector2(-16, -16)
	panel.size = page.size + Vector2(32, 32)
	page.resized.connect(func() -> void: panel.size = page.size + Vector2(32, 32))
	page.set("draw_frame", false)


static func style_button(button: Button) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var normal := style("pause/pause_row_normal", 10, 12)
	var selected := style("pause/pause_row_selected", 10, 12)
	button.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "pressed", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(state, selected)
	button.add_theme_color_override("font_color", Color("f2f7ff"))
	button.add_theme_color_override("font_focus_color", CYAN)


static func style_inventory_slot(button: Button) -> void:
	style_button(button)
	button.add_theme_stylebox_override("normal", style("inventory/slot_normal", 10, 12))
	button.add_theme_stylebox_override("disabled", style("inventory/slot_empty", 10, 12))
	for state in ["hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style("inventory/slot_selected", 10, 12))
	button.add_theme_font_size_override("font_size", 18)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func mark_equipped(button: Button, equipped: bool) -> void:
	# Called only when inventory refreshes, never while navigating focus.
	button.add_theme_stylebox_override("normal", style("inventory/slot_selected" if equipped else "inventory/slot_normal", 10, 12))


static func style_slider(slider: HSlider, focus_color: Color = CYAN) -> void:
	var track := style("settings/slider_track", 4)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := style("settings/slider_fill", 4)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	var active := fill.duplicate() as StyleBoxTexture
	active.modulate_color = focus_color
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", active)
	var handle := load(ROOT + "settings/slider_handle.png") as Texture2D
	slider.add_theme_icon_override("grabber", handle)
	slider.add_theme_icon_override("grabber_highlight", handle)
	slider.focus_entered.connect(func() -> void: slider.add_theme_stylebox_override("grabber_area", active))
	slider.focus_exited.connect(func() -> void: slider.add_theme_stylebox_override("grabber_area", fill))


static func apply_pause(main: Control, settings: Control, content: Control) -> void:
	background(main, "pause/pause_side_panel")
	background(settings, "settings/settings_panel")
	for child in main.get_children():
		if child is Button:
			style_button(child)
	for danger in ["Abandon", "MainMenu"]:
		var button := main.get_node(danger) as Button
		button.add_theme_color_override("font_color", Color("ff9999"))
	style_button(settings.get_node("Back") as Button)
	style_slider(content.get_node("TouchScale") as HSlider)
	for child in content.get_children():
		if child is OptionButton or child is CheckButton:
			child.add_theme_stylebox_override("normal", style("settings/option_row_normal", 8, 12))
			for state in ["hover", "focus", "pressed"]:
				child.add_theme_stylebox_override(state, style("settings/option_row_focused", 8, 12))
