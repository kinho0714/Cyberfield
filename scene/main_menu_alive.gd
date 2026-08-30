extends VBoxContainer

const RED := Color("ff3b4f")
const CYAN := Color("39dff2")
const WHITE := Color("f2f7ff")
const DIM := Color("7894a3")
const DARK := Color(0.012, 0.025, 0.045, 0.94)


func _ready() -> void:
	for child in get_children():
		if child is Button:
			var button := child as Button
			button.focus_mode = Control.FOCUS_ALL
			button.mouse_entered.connect(_focus_button.bind(button))
			button.focus_entered.connect(_refresh)
			button.focus_exited.connect(_refresh)
			button.button_down.connect(_refresh)
			button.button_up.connect(_refresh)
	call_deferred("_refresh")


func _focus_button(button: Button) -> void:
	if not button.disabled:
		button.grab_focus()


func _refresh() -> void:
	for child in get_children():
		if child is Button:
			_apply_button(child as Button)


func _apply_button(button: Button) -> void:
	var selected := button.has_focus() and not button.disabled
	var normal := _make_style(false, button.disabled)
	var active := _make_style(true, false)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", active)
	button.add_theme_stylebox_override("focus", active)
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_stylebox_override("disabled", _make_style(false, true))
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_focus_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)
	button.add_theme_color_override("font_disabled_color", DIM)
	button.add_theme_font_size_override("font_size", 25 if selected else 22)


func _make_style(selected: bool, disabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.025, 0.045, 0.96) if selected else DARK
	style.border_color = RED if selected else (Color(0.2, 0.32, 0.38, 0.55) if disabled else CYAN.darkened(0.5))
	style.set_border_width_all(3 if selected else 1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style
