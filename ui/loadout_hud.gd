extends Control
## HUD do equipamento (01/11/2026): arma ativa (raridade, munição/recarga), segunda arma,
## os dois slots ativos (ícone, cargas, recarga) e os implantes ativos na run.
## Só apresentação: lê o jogador local a cada quadro, não altera estado.

const PANEL := Color(0.012, 0.03, 0.055, 0.78)
const EDGE := Color("39dff2")
const DIM := Color(0.15, 0.25, 0.3)
const KEY_HINTS := ["F", "G"]

var player: Node
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2(24, 138)
	size = Vector2(420, 120)
	_font = ThemeDB.fallback_font
	ContentRegistry.apply_ui_theme(self)
	var themed := get_theme_default_font()
	if themed != null:
		_font = themed


func update_state(local_player: Node, hud_visible: bool) -> void:
	player = local_player
	visible = hud_visible and player != null
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	# --- arma ativa ---
	var weapon_id: StringName = player.get_active_weapon_id()
	var rarity: StringName = player.get_weapon_rarity(weapon_id)
	var rarity_color := RarityTable.color(rarity)
	draw_rect(Rect2(0, 0, 250, 54), PANEL)
	draw_rect(Rect2(0, 0, 250, 54), rarity_color, false, 1.0)
	draw_rect(Rect2(0, 0, 4, 54), rarity_color)
	var icon := WeaponCatalog.get_visual_texture(weapon_id, "inventory_icon")
	if icon != null:
		var factor := minf(64.0 / icon.get_width(), 30.0 / icon.get_height())
		var extent := icon.get_size() * factor
		draw_texture_rect(icon, Rect2(Vector2(42, 22) - extent * 0.5, extent), false)
	_text(Vector2(80, 18), WeaponCatalog.get_display_name(weapon_id), 14, rarity_color)
	_text(Vector2(80, 34), "%s  //  %s" % [RarityTable.label(rarity), WeaponCatalog.category_label(weapon_id)], 11, Color("c8d6e0"))
	if WeaponCatalog.is_ranged(weapon_id):
		var ammo: Dictionary = player.weapon_ammo.get(weapon_id, {})
		var magazine := int(player.get_weapon_stats(weapon_id).get("magazine", 0))
		if player.weapon_reload_timers.has(weapon_id):
			var total := float(player.get_weapon_stats(weapon_id).get("reload_time", 1.5))
			var ratio := 1.0 - clampf(float(player.weapon_reload_timers[weapon_id]) / maxf(total, 0.01), 0.0, 1.0)
			draw_rect(Rect2(80, 40, 160, 6), DIM)
			draw_rect(Rect2(80, 40, 160 * ratio, 6), Color("ffb347"))
			_text(Vector2(80, 52), "RECARREGANDO", 10, Color("ffb347"))
		else:
			var clip := int(ammo.get("clip", magazine))
			var pips := mini(magazine, 18)
			for index in pips:
				var filled := index < roundi(float(clip) / maxf(magazine, 1) * pips)
				draw_rect(Rect2(80 + index * 8, 41, 6, 5), rarity_color if filled else DIM)
			_text(Vector2(80 + pips * 8 + 4, 49), "%d/%d +%d" % [clip, magazine, int(ammo.get("reserve", 0))], 10, Color.WHITE)
	# segunda arma
	var other_slot: int = 1 - int(player.active_weapon_slot)
	var other_id: StringName = player.equipped_weapons[other_slot]
	draw_rect(Rect2(254, 0, 60, 54), PANEL)
	draw_rect(Rect2(254, 0, 60, 54), DIM, false, 1.0)
	if not other_id.is_empty():
		var other_icon := WeaponCatalog.get_visual_texture(other_id, "inventory_icon")
		if other_icon != null:
			var factor := minf(50.0 / other_icon.get_width(), 24.0 / other_icon.get_height())
			var extent := other_icon.get_size() * factor
			draw_texture_rect(other_icon, Rect2(Vector2(284, 24) - extent * 0.5, extent), false, Color(1, 1, 1, 0.65))
		draw_rect(Rect2(258, 46, 52, 3), RarityTable.color(player.get_weapon_rarity(other_id)))
	_text(Vector2(258, 12), "X / ATQ2", 9, Color("8195a3"))
	# --- dois slots ativos ---
	var gadgets: PlayerGadgets = player.get("gadgets")
	for slot in AccessoryCatalog.SLOT_COUNT:
		var origin := Vector2(318 + slot * 50, 0)
		draw_rect(Rect2(origin, Vector2(46, 54)), PANEL)
		var accessory_id: StringName = gadgets.slots[slot] if gadgets != null else &""
		if accessory_id.is_empty():
			draw_rect(Rect2(origin, Vector2(46, 54)), DIM, false, 1.0)
			_text(origin + Vector2(4, 30), "—", 12, DIM)
		else:
			var data := AccessoryCatalog.get_definition(accessory_id)
			var charged: bool = gadgets.charges[slot] > 0
			draw_rect(Rect2(origin, Vector2(46, 54)), data.color if charged else DIM, false, 1.0)
			var gadget_icon := AccessoryCatalog.icon(accessory_id)
			if gadget_icon != null:
				draw_texture_rect(gadget_icon, Rect2(origin + Vector2(7, 4), Vector2(32, 32)), false, Color.WHITE if charged else Color(0.45, 0.45, 0.5))
			var ratio := gadgets.recharge_ratio(slot)
			if ratio < 1.0:
				draw_rect(Rect2(origin + Vector2(4, 38), Vector2(38, 3)), DIM)
				draw_rect(Rect2(origin + Vector2(4, 38), Vector2(38 * ratio, 3)), data.color)
			for pip in gadgets.max_charges(slot):
				draw_rect(Rect2(origin + Vector2(5 + pip * 9, 44), Vector2(7, 5)), data.color if pip < gadgets.charges[slot] else DIM)
		_text(origin + Vector2(36, 12), KEY_HINTS[slot], 10, Color("8195a3"))
	# --- implantes ativos ---
	var instances: Array = player.get("cyberware_instances")
	for index in instances.size():
		var instance: Dictionary = instances[index]
		var at := Vector2(index * 30, 58)
		var cyber_icon := CyberwareCatalog.icon(StringName(instance.line))
		draw_rect(Rect2(at, Vector2(26, 26)), PANEL)
		draw_rect(Rect2(at, Vector2(26, 26)), RarityTable.color(StringName(instance.rarity)), false, 1.0)
		if cyber_icon != null:
			draw_texture_rect(cyber_icon, Rect2(at + Vector2(1, 1), Vector2(24, 24)), false)
		_text(at + Vector2(16, 25), str(int(instance.level)), 9, Color.WHITE)


func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
