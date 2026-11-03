extends Control
## HUD do equipamento (01/11/2026): arma ativa (raridade, munição/recarga), segunda arma,
## os dois slots ativos (ícone, cargas, recarga) e os implantes ativos na run.
## Só apresentação: lê o jogador local a cada quadro, não altera estado.

const PANEL := Color(0.012, 0.03, 0.055, 0.78)
const EDGE := Color("39dff2")
const DIM := Color(0.15, 0.25, 0.3)
const KEY_HINTS := ["F", "G"]

var player: Node
var _state: Array = []
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2(24, 138)
	size = Vector2(440, 96)
	_font = ThemeDB.fallback_font
	ContentRegistry.apply_ui_theme(self)
	var themed := get_theme_default_font()
	if themed != null:
		_font = themed


func update_state(local_player: Node, hud_visible: bool) -> void:
	var changed_player := player != local_player
	player = local_player
	visible = hud_visible and is_instance_valid(player)
	if not visible:
		return
	var gadgets: PlayerGadgets = player.get("gadgets")
	var state: Array = [player.get_instance_id(), player.active_weapon_slot,
		player.equipped_weapons.duplicate(), player.weapon_ammo.duplicate(true),
		player.weapon_reload_timers.duplicate(true), player.cyberware_instances.duplicate(true),
		player.weapon_rarity.duplicate()]
	if gadgets != null:
		for slot in AccessoryCatalog.SLOT_COUNT:
			state.append([gadgets.slots[slot], gadgets.charges[slot], gadgets.recharge[slot]])
	if changed_player or state != _state:
		_state = state
		queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	# 01/11 (Missão Visual 02): fontes maiores, munição em número grande, recarga dos
	# acessórios como preenchimento sobre o ícone e dicas de tecla só fora do celular.
	var touch := OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	# --- arma ativa ---
	var weapon_id: StringName = player.get_active_weapon_id()
	var rarity: StringName = player.get_weapon_rarity(weapon_id)
	var rarity_color := RarityTable.color(rarity)
	var panel := Rect2(0, 0, 268, 58)
	draw_rect(panel, PANEL)
	draw_rect(panel, Color(rarity_color, 0.85), false, 1.0)
	draw_rect(Rect2(0, 0, 4, 58), rarity_color)
	var icon := WeaponCatalog.get_visual_texture(weapon_id, "inventory_icon")
	if icon != null:
		var factor := minf(60.0 / icon.get_width(), 30.0 / icon.get_height())
		var extent := icon.get_size() * factor
		draw_texture_rect(icon, Rect2(Vector2(40, 22) - extent * 0.5, extent), false)
	_text(Vector2(8, 52), RarityTable.label(rarity), 11, rarity_color)
	_text(Vector2(78, 20), WeaponCatalog.get_display_name(weapon_id), 15, Color.WHITE)
	_text(Vector2(78, 36), WeaponCatalog.category_label(weapon_id), 11, Color("94dce8"))
	if WeaponCatalog.is_ranged(weapon_id):
		var ammo: Dictionary = player.weapon_ammo.get(weapon_id, {})
		var magazine := int(player.get_weapon_stats(weapon_id).get("magazine", 0))
		var clip := int(ammo.get("clip", magazine))
		if player.weapon_reload_timers.has(weapon_id):
			var total := float(player.get_weapon_stats(weapon_id).get("reload_time", 1.5))
			var ratio := 1.0 - clampf(float(player.weapon_reload_timers[weapon_id]) / maxf(total, 0.01), 0.0, 1.0)
			draw_rect(Rect2(78, 43, 120, 7), DIM)
			draw_rect(Rect2(78, 43, 120 * ratio, 7), Color("ffb347"))
			_text(Vector2(204, 51), "RECARGA", 11, Color("ffb347"))
		else:
			var pips := mini(magazine, 12)
			var pip_w := floorf(120.0 / maxf(pips, 1)) - 2.0
			var filled_pips := roundi(float(clip) / maxf(magazine, 1) * pips)
			for index in pips:
				draw_rect(Rect2(78 + index * (pip_w + 2.0), 44, pip_w, 6), rarity_color if index < filled_pips else DIM)
			var low := clip <= maxi(1, magazine / 4)
			_text(Vector2(204, 52), str(clip), 18, Color("ff6a5a") if low else Color.WHITE)
			_text(Vector2(204 + 11.0 * str(clip).length(), 52), "/%d" % magazine, 11, Color("94dce8"))
			_text(Vector2(222, 36), "RES %d" % int(ammo.get("reserve", 0)), 10, Color("8195a3"))
	# segunda arma
	var other_slot: int = 1 - int(player.active_weapon_slot)
	var other_id: StringName = player.equipped_weapons[other_slot]
	var second := Rect2(272, 0, 58, 58)
	draw_rect(second, PANEL)
	draw_rect(second, DIM, false, 1.0)
	if not other_id.is_empty():
		var other_icon := WeaponCatalog.get_visual_texture(other_id, "inventory_icon")
		if other_icon != null:
			var factor := minf(46.0 / other_icon.get_width(), 24.0 / other_icon.get_height())
			var extent := other_icon.get_size() * factor
			draw_texture_rect(other_icon, Rect2(Vector2(301, 30) - extent * 0.5, extent), false, Color(1, 1, 1, 0.7))
		draw_rect(Rect2(276, 51, 50, 3), RarityTable.color(player.get_weapon_rarity(other_id)))
	_text(Vector2(277, 13), "ATQ 2" if touch else "X · TROCA", 10, Color("8195a3"))
	# --- dois slots ativos ---
	var gadgets: PlayerGadgets = player.get("gadgets")
	for slot in AccessoryCatalog.SLOT_COUNT:
		var origin := Vector2(334 + slot * 54, 0)
		var box := Rect2(origin, Vector2(50, 58))
		draw_rect(box, PANEL)
		var accessory_id: StringName = gadgets.slots[slot] if gadgets != null else &""
		if accessory_id.is_empty():
			draw_rect(box, DIM, false, 1.0)
			_text(origin + Vector2(19, 34), "—", 14, DIM)
		else:
			var data := AccessoryCatalog.get_definition(accessory_id)
			var accent: Color = data.color
			var charges: int = gadgets.charges[slot]
			draw_rect(box, accent if charges > 0 else DIM, false, 1.0)
			var gadget_icon := AccessoryCatalog.icon(accessory_id)
			var icon_rect := Rect2(origin + Vector2(9, 6), Vector2(32, 32))
			if gadget_icon != null:
				draw_texture_rect(gadget_icon, icon_rect, false, Color.WHITE if charges > 0 else Color(0.5, 0.5, 0.55))
			var ratio := gadgets.recharge[slot]
			if ratio < 1.0:                                       # recarga sobe sobre o ícone
				var covered := icon_rect.size.y * (1.0 - ratio)
				draw_rect(Rect2(icon_rect.position, Vector2(icon_rect.size.x, covered)), Color(0.0, 0.02, 0.05, 0.55))
				draw_rect(Rect2(icon_rect.position + Vector2(0, covered), Vector2(icon_rect.size.x, 1)), accent)
			for pip in gadgets.max_charges(slot):
				draw_rect(Rect2(origin + Vector2(6 + pip * 10, 46), Vector2(8, 6)), accent if pip < charges else DIM)
			if charges == 0:
				var seconds := ceili(gadgets.recharge_time(slot) * (1.0 - ratio))
				_text(origin + Vector2(30, 54), "%ds" % seconds, 11, Color.WHITE)
		if not touch:
			_text(origin + Vector2(40, 12), KEY_HINTS[slot], 11, Color("94dce8"))
	# --- implantes ativos ---
	var instances: Array = player.get("cyberware_instances")
	for index in instances.size():
		var instance: Dictionary = instances[index]
		var at := Vector2(index * 32, 62)
		var cyber_icon := CyberwareCatalog.icon(StringName(instance.line))
		draw_rect(Rect2(at, Vector2(28, 28)), PANEL)
		draw_rect(Rect2(at, Vector2(28, 28)), RarityTable.color(StringName(instance.rarity)), false, 1.0)
		if cyber_icon != null:
			draw_texture_rect(cyber_icon, Rect2(at + Vector2(2, 2), Vector2(24, 24)), false)
		_text(at + Vector2(17, 27), str(int(instance.level)), 10, Color.WHITE)


func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
