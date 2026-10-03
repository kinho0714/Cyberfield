extends Control
## Presentation only; updates from the existing RunDebugHUD data loop.
const LOW_HP_RATIO := 0.25
const HUD_PLAYER_FRAME = preload("res://assets/ui/gameplay_hud/assets/shared/hud/player_frame.png")
const HUD_HP_TRACK = preload("res://assets/ui/gameplay_hud/assets/shared/hud/hp_track.png")
const HUD_HP_FILL = preload("res://assets/ui/gameplay_hud/assets/shared/hud/hp_fill.png")
const HUD_PORTRAIT_FRAME = preload("res://assets/ui/gameplay_hud/assets/shared/hud/portrait_frame.png")
const ICON_HEAL = preload("res://assets/ui/gameplay_hud/assets/shared/icons/heal_icon.png")
const ICON_ATTR_HEALTH = preload("res://assets/ui/gameplay_hud/assets/shared/icons/icon_attr_health.png")
const ICON_ATTR_INTELLIGENCE = preload("res://assets/ui/gameplay_hud/assets/shared/icons/icon_attr_intelligence.png")
const ICON_ATTR_STRENGTH = preload("res://assets/ui/gameplay_hud/assets/shared/icons/icon_attr_strength.png")
const ICON_MONEY = preload("res://assets/ui/gameplay_hud/assets/shared/icons/money_icon.png")
const LOW_HP_VIGNETTE = preload("res://assets/ui/gameplay_hud/assets/shared/low_hp/low_hp_vignette.png")
const HUD_PLAYER_FRAME_CRITICAL = preload("res://assets/ui/gameplay_hud/assets/shared/low_hp/player_frame_critical_accent.png")

var _values: Array = []
var _hp_text: Label
var _participant: Label
var _counts: Array[Label] = []
var _portrait: Texture2D
var _portrait_frames: SpriteFrames
var _critical := false
var _ratio := 1.0
var _doses := 0
var _capacity := 0
var _vignette: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2(24, 20)
	size = Vector2(400, 112)
	_participant = _label(Vector2(86, 0), Vector2(280, 22), Color.WHITE)
	_hp_text = _label(Vector2(86, 22), Vector2(286, 24), Color.WHITE)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var colors := [Color.CYAN, Color.LIGHT_GREEN, Color.MEDIUM_PURPLE,
		Color.SALMON, Color.GOLD]
	for index in 5:
		_counts.append(_label(Vector2(42 + index * 72, 78), Vector2(48, 26), colors[index]))
	var layer := CanvasLayer.new()
	layer.layer = 39 # World < critical overlay < mobile40 < minimap48 < HUD50 < modals.
	add_child(layer)
	_vignette = TextureRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.texture = LOW_HP_VIGNETTE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.modulate.a = 0.22
	_vignette.visible = false


func _label(at: Vector2, extent: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	return label


func update_state(player: Node, money: int, hud_visible: bool) -> void:
	if player == null:
		_vignette.visible = false
		return
	var state: Array = [player.participant_id, player.health, player.max_health,
		player.heal_doses, player.max_heal_doses, player.health_attribute,
		player.intellect, player.strength, money, player.is_downed]
	var visual := player.get_node_or_null("PlayerCharacterVisual") as AnimatedSprite2D
	if visual != null and visual.sprite_frames != _portrait_frames:
		_portrait_frames = visual.sprite_frames
		if _portrait_frames != null and _portrait_frames.has_animation(&"idle"):
			_portrait = _portrait_frames.get_frame_texture(&"idle", 0)
		queue_redraw()
	if state != _values:
		_values = state
		_ratio = clampf(float(player.health) / maxf(float(player.max_health), 1.0), 0, 1)
		_critical = _ratio <= LOW_HP_RATIO
		_doses = player.heal_doses
		_capacity = player.max_heal_doses
		_participant.text = "%s%s" % [String(player.participant_id).replace("player_", "P"),
			" — CAÍDO" if player.is_downed else ""]
		_hp_text.text = "%d / %d" % [player.health, player.max_health]
		var counts := [player.heal_doses, player.health_attribute,
			player.intellect, player.strength, money]
		for index in 5:
			_counts[index].text = str(counts[index])
		queue_redraw()
	_vignette.visible = hud_visible and _critical


func _draw() -> void:
	draw_texture(HUD_PLAYER_FRAME, Vector2.ZERO)
	if _critical:
		draw_texture(HUD_PLAYER_FRAME_CRITICAL, Vector2.ZERO)
	if _portrait != null:
		var native := _portrait.get_size()
		var factor := minf(56.0 / native.x, 56.0 / native.y)
		var extent := native * factor
		draw_texture_rect(_portrait, Rect2(Vector2(48, 42) - extent * 0.5, extent), false)
	draw_texture(HUD_PORTRAIT_FRAME, Vector2(16, 12))
	draw_texture(HUD_HP_TRACK, Vector2(86, 22))
	var extent := Vector2(286 * _ratio, 24)
	if extent.x > 0.0:
		draw_texture_rect_region(HUD_HP_FILL, Rect2(Vector2(86, 22), extent),
			Rect2(Vector2.ZERO, extent), Color(1, 0.3, 0.3) if _critical else Color.WHITE)
	for index in mini(_capacity, 8):
		draw_rect(Rect2(86 + index * 22, 53, 18, 5),
			Color.CYAN if index < _doses else Color(0.15, 0.25, 0.3))
	var icons := [ICON_HEAL, ICON_ATTR_HEALTH, ICON_ATTR_INTELLIGENCE,
		ICON_ATTR_STRENGTH, ICON_MONEY]
	for index in 5:
		draw_texture_rect(icons[index], Rect2(10 + index * 72, 74, 32, 32), false)
