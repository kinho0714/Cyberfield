class_name DevMode
extends Node
## Modo Dev (02/11/2026, P0-B): ferramentas de teste dentro do jogo real.
##
## Ativação: Configurações → JOGO → "MODO DEV" (LocalSettings.dev_mode_enabled, desligado por
## padrão). Com ele ligado aparece o botão DEV no HUD (toque) e F9 abre o painel (PC).
##
## Isolamento: a PRIMEIRA ferramenta usada liga o perfil de teste do MetaProgression (arquivo
## `<save>_dev_sandbox.json`) e marca a run como sessão de teste. O perfil legítimo não é
## gravado enquanto isso; ao desligar o Modo Dev ele é recarregado intacto do disco.
##
## Extensão: cada aba é uma lista de entradas devolvida por um Callable registrado com
## `register_section(id, título, construtor)`. Uma entrada é um Dictionary:
##   {"kind": "header", "text": ...}
##   {"kind": "info", "text": ...}
##   {"kind": "button", "label": ..., "action": Callable, "closes": bool, "id": ...}
##   {"kind": "row", "label": ..., "buttons": [{"label", "action", "closes", "id"}, ...]}
## Ferramentas novas: registrar uma seção ou acrescentar entradas num construtor existente.
## Tudo usa registros reais (WeaponCatalog, CyberwareCatalog, AccessoryCatalog, cenas de
## inimigos, BiomeLootPlaceholder/TrapChest, WeaponLootTable, RoomManager/RunManager).

signal log_changed

const PANEL_SCRIPT := preload("res://scene/dev/dev_mode_panel.gd")
const BOSS_STAGE_SCRIPT := preload("res://scene/biomes/boss_stage.gd")
const ENEMY_SCENES := {
	&"common": preload("res://entities/Enemy.tscn"),
	&"ranged": preload("res://entities/RangedEnemy.tscn"),
	&"heavy": preload("res://entities/HeavyEnemy.tscn"),
}
const ENEMY_LABELS := {&"common": "CORPO A CORPO", &"ranged": "À DISTÂNCIA", &"heavy": "PESADO"}
const ROLE_LABELS := {&"normal": "NORMAL", &"elite": "ELITE", &"boss": "CHEFE"}
const BIOME_LABELS := {&"lower_city": "CIDADE BAIXA", &"industrial": "INDUSTRIAL", &"lab": "LABORATÓRIO"}
const LOOT_SCENE := preload("res://scene/biomes/biome_loot_placeholder.tscn")
const TRAP_SCENE := preload("res://scene/interactables/trap_chest.tscn")
const STAGES := [[0, "CIDADE BAIXA"], [1, "INDUSTRIAL"], [2, "LABORATÓRIO"], [5, "ARENA DO CHEFE"]]
const DEV_GROUP := &"dev_spawned"

var panel: CanvasLayer
var weapon_rarity: StringName = &"common"
var enemy_biome: StringName = &"lower_city"
var enemy_role: StringName = &"normal"
var dev_ai_paused := false
var log_lines: PackedStringArray = []
var _sections: Array[Dictionary] = []
var _counter := 0
var _last_safe_position := Vector2.INF


func _ready() -> void:
	add_to_group("dev_mode")
	process_mode = Node.PROCESS_MODE_ALWAYS
	register_section(&"player", "JOGADOR", _player_entries)
	register_section(&"arsenal", "ARSENAL", _arsenal_entries)
	register_section(&"enemies", "INIMIGOS", _enemy_entries)
	register_section(&"world", "MUNDO", _world_entries)
	register_section(&"session", "SESSÃO", _session_entries)
	panel = PANEL_SCRIPT.new()
	panel.name = "DevModePanel"
	panel.dev_mode = self
	add_child(panel)
	var settings := _settings()
	if settings != null:
		settings.settings_changed.connect(_on_settings_changed)


# --- registro extensível -------------------------------------------------------------

func register_section(id: StringName, title: String, builder: Callable) -> void:
	for section in _sections:
		if section.id == id:
			section.title = title
			section.builder = builder
			return
	_sections.append({"id": id, "title": title, "builder": builder})


func get_sections() -> Array[Dictionary]:
	return _sections


func get_entries(section_id: StringName) -> Array:
	for section in _sections:
		if section.id == section_id:
			return (section.builder as Callable).call() as Array
	return []


## Executa uma ação pelo id (usado pelo painel e pelos testes).
func run_action(section_id: StringName, action_id: String) -> bool:
	for entry: Dictionary in get_entries(section_id):
		var candidates: Array = [entry]
		if entry.get("kind") == "row":
			candidates = entry.get("buttons", []) as Array
		for button: Dictionary in candidates:
			if String(button.get("id", "")) == action_id and button.has("action"):
				(button.action as Callable).call()
				return true
	return false


# --- estado / disponibilidade --------------------------------------------------------

func is_enabled() -> bool:
	var settings := _settings()
	return settings != null and settings.dev_mode_enabled


## Ferramentas só em jogo local (LAN fica de fora para não dessincronizar host/clientes).
func is_available() -> bool:
	var room_manager := _room_manager()
	if not is_enabled() or room_manager == null or not bool(room_manager.mode_selected):
		return false
	var lan := room_manager.get_node_or_null("LanSession")
	if lan != null and lan.is_network_game():
		return false
	return room_manager.run_manager.is_gameplay_context_active()


func is_sandbox_active() -> bool:
	var meta := _meta()
	return meta != null and meta.dev_sandbox_active


## Toda ferramenta passa por aqui antes de mexer no jogo.
func taint() -> void:
	var meta := _meta()
	if meta != null and not meta.dev_sandbox_active:
		meta.begin_dev_sandbox()
		_log("Perfil de teste ativo: %s (o perfil real não será gravado)" % meta.save_path.get_file())
		var room_manager := _room_manager()
		if room_manager != null and bool(room_manager.current_is_hub):
			room_manager.apply_meta_loadout()
	var run_manager := _run_manager()
	if run_manager != null and bool(run_manager.run_active):
		run_manager.mark_dev_session()


func end_session() -> void:
	var meta := _meta()
	if meta != null and meta.dev_sandbox_active:
		meta.end_dev_sandbox()
		_log("Perfil real recarregado do disco.")
		var room_manager := _room_manager()
		if room_manager != null and bool(room_manager.current_is_hub):
			room_manager.apply_meta_loadout()
	for player in _players():
		player.set("dev_invincible", false)


func _on_settings_changed() -> void:
	if not is_enabled():
		if panel != null and panel.is_open():
			panel.close_panel()
		end_session()
	if panel != null:
		panel.refresh_button()


func _physics_process(_delta: float) -> void:
	# Invencível não pode cair para sempre: volta ao último chão seguro.
	var player := local_player()
	if player == null or not bool(player.get("dev_invincible")):
		return
	if player.is_on_floor():
		_last_safe_position = player.global_position
	var room_manager := _room_manager()
	var bounds: Rect2 = room_manager.generated_biome_bounds if room_manager != null else Rect2()
	if bounds.size != Vector2.ZERO and player.global_position.y > bounds.end.y + 160.0 and _last_safe_position != Vector2.INF:
		player.global_position = _last_safe_position + Vector2(0, -24)
		player.velocity = Vector2.ZERO


# --- JOGADOR -------------------------------------------------------------------------

func _player_entries() -> Array:
	var player := local_player()
	var entries: Array = []
	if player == null:
		return [{"kind": "info", "text": "Nenhum jogador local."}]
	var run_manager := _run_manager()
	var meta := _meta()
	entries.append({"kind": "info", "text": "VIDA %d/%d   ·   DINHEIRO DA RUN $%d   ·   CRÉDITOS ◈%d   ·   SUCATA ⚙%d%s" % [int(player.health), int(player.max_health), int(run_manager.dirty_money), meta.credits if meta else 0, meta.scrap if meta else 0, "   ·   INVENCÍVEL" if bool(player.get("dev_invincible")) else ""]})
	entries.append({"kind": "row", "label": "VIDA", "buttons": [
		{"label": "-50", "id": "health_minus", "action": change_health.bind(-50)},
		{"label": "-10", "id": "health_minus_10", "action": change_health.bind(-10)},
		{"label": "+10", "id": "health_plus_10", "action": change_health.bind(10)},
		{"label": "+50", "id": "health_plus", "action": change_health.bind(50)},
		{"label": "CURAR TUDO", "id": "heal_full", "action": heal_full},
	]})
	entries.append({"kind": "row", "label": "TESTE", "buttons": [
		{"label": "INVENCÍVEL: %s" % ("SIM" if bool(player.get("dev_invincible")) else "NÃO"), "id": "toggle_invincible", "action": toggle_invincible},
		{"label": "REINICIAR RECARGAS", "id": "reset_cooldowns", "action": reset_cooldowns},
	]})
	entries.append({"kind": "row", "label": "DINHEIRO", "buttons": [
		{"label": "RUN -100", "id": "money_minus", "action": change_run_money.bind(-100)},
		{"label": "RUN +100", "id": "money_plus", "action": change_run_money.bind(100)},
		{"label": "CRÉD. -100", "id": "credits_minus", "action": change_credits.bind(-100)},
		{"label": "CRÉD. +100", "id": "credits_plus", "action": change_credits.bind(100)},
		{"label": "SUCATA +50", "id": "scrap_plus", "action": change_scrap.bind(50)},
	]})
	return entries


func change_health(amount: int) -> void:
	var player := local_player()
	if player == null:
		return
	taint()
	if bool(player.is_downed) and amount > 0:
		player.revive()
	player.health = clampi(int(player.health) + amount, 1, int(player.max_health))
	player.call("_update_health_label")
	_log("Vida %+d → %d/%d" % [amount, int(player.health), int(player.max_health)])


func heal_full() -> void:
	var player := local_player()
	if player == null:
		return
	taint()
	if bool(player.is_downed):
		player.revive()
	player.health = int(player.max_health)
	player.heal_doses = int(player.max_heal_doses)
	player.call("_update_health_label")
	_log("Vida e doses de cura cheias.")


func toggle_invincible() -> void:
	var player := local_player()
	if player == null:
		return
	taint()
	player.dev_invincible = not bool(player.dev_invincible)
	_last_safe_position = player.global_position
	_log("Invencibilidade: %s" % ("LIGADA" if player.dev_invincible else "DESLIGADA"))


func reset_cooldowns() -> void:
	var player := local_player()
	if player == null:
		return
	taint()
	player.weapon_cooldowns = [0.0, 0.0]
	for weapon_id: StringName in (player.weapon_reload_timers as Dictionary).keys():
		player.call("_finish_weapon_reload", weapon_id)
	for weapon_id: StringName in player.owned_weapons:
		(player.weapon_ammo as Dictionary).erase(weapon_id)
		player.call("_ensure_weapon_ammo", weapon_id)
	player.heal_doses = int(player.max_heal_doses)
	player.combo_end_recovery_timer = 0.0
	player.wall_climb_time = float(player.max_wall_climb_duration)
	var gadgets: PlayerGadgets = player.gadgets
	if gadgets != null:
		for slot in AccessoryCatalog.SLOT_COUNT:
			gadgets.charges[slot] = gadgets.max_charges(slot)
			gadgets.recharge[slot] = 0.0
	_log("Recargas, munição, doses, escalada e acessórios reiniciados.")


func change_run_money(amount: int) -> void:
	var run_manager := _run_manager()
	taint()
	run_manager.dirty_money = maxi(int(run_manager.dirty_money) + amount, 0)
	run_manager.state_changed.emit()
	_log("Dinheiro da run %+d → $%d" % [amount, int(run_manager.dirty_money)])


func change_credits(amount: int) -> void:
	taint()
	var meta := _meta()
	meta.credits = maxi(meta.credits + amount, 0)
	meta.save_profile()
	meta.profile_changed.emit()
	_log("Créditos (perfil de teste) %+d → ◈%d" % [amount, meta.credits])


func change_scrap(amount: int) -> void:
	taint()
	var meta := _meta()
	meta.scrap = maxi(meta.scrap + amount, 0)
	meta.save_profile()
	meta.profile_changed.emit()
	_log("Sucata (perfil de teste) %+d → ⚙%d" % [amount, meta.scrap])


# --- ARSENAL -------------------------------------------------------------------------

func _arsenal_entries() -> Array:
	var player := local_player()
	var entries: Array = []
	var equipped := "—"
	if player != null:
		equipped = "S1 %s   ·   S2 %s" % [_weapon_label(player, 0), _weapon_label(player, 1)]
	entries.append({"kind": "info", "text": "EQUIPADO: %s" % equipped})
	entries.append({"kind": "row", "label": "RARIDADE", "buttons": [
		{"label": "%s  ▸" % RarityTable.label(weapon_rarity), "id": "cycle_rarity", "action": cycle_weapon_rarity},
		{"label": "TODOS OS BLUEPRINTS", "id": "grant_all_blueprints", "action": grant_all_blueprints},
	]})
	entries.append({"kind": "header", "text": "ARMAS (%d registradas)  —  S1/S2 equipa · CHÃO gera pickup real · BP concede blueprint" % WeaponCatalog.WEAPONS.size()})
	for weapon_id: StringName in WeaponCatalog.WEAPONS:
		entries.append({"kind": "row", "label": "%s  [%s]" % [WeaponCatalog.get_display_name(weapon_id), WeaponCatalog.category_label(weapon_id)], "icon": WeaponCatalog.get_visual_texture(weapon_id, "inventory_icon"), "buttons": [
			{"label": "S1", "id": "equip0_%s" % weapon_id, "action": equip_weapon.bind(weapon_id, 0)},
			{"label": "S2", "id": "equip1_%s" % weapon_id, "action": equip_weapon.bind(weapon_id, 1)},
			{"label": "CHÃO", "id": "drop_%s" % weapon_id, "action": spawn_weapon_pickup.bind(weapon_id)},
			{"label": "BP", "id": "bp_%s" % weapon_id, "action": grant_blueprint.bind(weapon_id)},
		]})
	entries.append({"kind": "header", "text": "CYBERWARES (instalação na run atual, raridade %s)" % RarityTable.label(weapon_rarity)})
	for line: StringName in CyberwareCatalog.LINE_ORDER:
		var buttons: Array = []
		for level in [1, 2, 3]:
			buttons.append({"label": "MK%d" % level, "id": "cyber_%s_%d" % [line, level], "action": install_cyberware.bind(line, level)})
		entries.append({"kind": "row", "label": "%s  (%s)" % [String(CyberwareCatalog.line_data(line).name), CyberwareCatalog.SLOT_LABELS.get(CyberwareCatalog.slot_for(line), "")], "icon": CyberwareCatalog.icon(line), "buttons": buttons})
	entries.append({"kind": "button", "label": "REMOVER IMPLANTES DA RUN", "id": "clear_cyberware", "action": clear_cyberware})
	entries.append({"kind": "header", "text": "ACESSÓRIOS ATIVOS"})
	for accessory_id: StringName in AccessoryCatalog.ORDER:
		entries.append({"kind": "row", "label": AccessoryCatalog.display_name(accessory_id), "icon": AccessoryCatalog.icon(accessory_id), "buttons": [
			{"label": "A1", "id": "gadget0_%s" % accessory_id, "action": equip_accessory.bind(accessory_id, 0)},
			{"label": "A2", "id": "gadget1_%s" % accessory_id, "action": equip_accessory.bind(accessory_id, 1)},
		]})
	return entries


func _weapon_label(player: Node, slot: int) -> String:
	var weapon_id: StringName = player.equipped_weapons[slot]
	return "%s [%s]" % [WeaponCatalog.get_display_name(weapon_id), RarityTable.label(player.get_weapon_rarity(weapon_id))] if not weapon_id.is_empty() else "VAZIO"


func cycle_weapon_rarity() -> void:
	var tiers := RarityTable.enabled_tiers()
	weapon_rarity = tiers[(tiers.find(weapon_rarity) + 1) % tiers.size()]


func equip_weapon(weapon_id: StringName, slot: int) -> bool:
	var player := local_player()
	if player == null or not WeaponCatalog.has_weapon(weapon_id):
		return false
	taint()
	var equipped := false
	if (player.equipped_weapons as Array).has(weapon_id):
		equipped = player.equip_owned_weapon(weapon_id, slot)
	else:
		equipped = player.equip_weapon(weapon_id, slot, weapon_rarity)
	if equipped:
		# Raridade exata escolhida no painel (inclusive para baixo) e munição cheia.
		player.weapon_rarity[weapon_id] = weapon_rarity
		(player.weapon_ammo as Dictionary).erase(weapon_id)
		player.call("_ensure_weapon_ammo", weapon_id)
		player.active_weapon_slot = slot
	_log("%s %s no slot %d [%s]" % ["Equipada" if equipped else "Falhou", WeaponCatalog.get_display_name(weapon_id), slot + 1, RarityTable.label(weapon_rarity)])
	return equipped


func spawn_weapon_pickup(weapon_id: StringName) -> WeaponPickup:
	var player := local_player()
	var point := find_safe_spawn_point(1)
	if player == null or point.is_empty():
		_log("Sem ponto seguro para a arma.")
		return null
	taint()
	_counter += 1
	var pickup := WeaponPickup.new()
	pickup.pickup_id = StringName("dev_weapon_%d_%d" % [_counter, Time.get_ticks_msec()])
	pickup.weapon_id = weapon_id
	pickup.rarity = weapon_rarity
	pickup.add_to_group(DEV_GROUP)
	var parent := _content_parent()
	pickup.position = parent.to_local(point[0] + Vector2(0, -14))
	parent.add_child(pickup)
	_log("Pickup real de %s [%s] gerado." % [WeaponCatalog.get_display_name(weapon_id), RarityTable.label(weapon_rarity)])
	return pickup


func grant_blueprint(weapon_id: StringName) -> void:
	taint()
	var meta := _meta()
	if not meta.recovered_models.has(weapon_id):
		meta.recovered_models.append(weapon_id)
	if not meta.blueprints.has(weapon_id):
		meta.blueprints.append(weapon_id)
	meta.save_profile()
	meta.profile_changed.emit()
	_log("Blueprint concedido (perfil de teste): %s" % WeaponCatalog.get_display_name(weapon_id))


func grant_all_blueprints() -> void:
	taint()
	var meta := _meta()
	for weapon_id: StringName in WeaponCatalog.WEAPONS:
		if not meta.recovered_models.has(weapon_id):
			meta.recovered_models.append(weapon_id)
		if not meta.blueprints.has(weapon_id):
			meta.blueprints.append(weapon_id)
	meta.save_profile()
	meta.profile_changed.emit()
	_log("Todos os %d blueprints concedidos (perfil de teste)." % WeaponCatalog.WEAPONS.size())


func install_cyberware(line: StringName, level: int) -> bool:
	var player := local_player()
	if player == null:
		return false
	taint()
	_counter += 1
	var instance := CyberwareCatalog.make_instance(line, weapon_rarity, level, "cw_dev_%d_%d" % [_counter, Time.get_ticks_msec()])
	var slot := CyberwareCatalog.slot_for(line)
	var kept: Array[Dictionary] = []
	for current: Dictionary in player.cyberware_instances:
		if CyberwareCatalog.slot_for(StringName(current.line)) != slot:
			kept.append(current)
	kept.append(instance)
	player.cyberware_instances = kept
	player.call("_recompute_cyberware", false)
	_log("Implante %s MK%d [%s] no slot %s." % [CyberwareCatalog.display_name(instance), level, RarityTable.label(weapon_rarity), CyberwareCatalog.SLOT_LABELS.get(slot, slot)])
	return true


func clear_cyberware() -> void:
	var player := local_player()
	if player == null:
		return
	taint()
	player.cyberware_instances.clear()
	player.call("_recompute_cyberware", false)
	_log("Implantes da run removidos.")


func equip_accessory(accessory_id: StringName, slot: int) -> void:
	var player := local_player()
	if player == null or player.gadgets == null:
		return
	taint()
	var slots: Array = (player.gadgets.slots as Array).duplicate()
	var other := 1 - slot
	if slots[other] == accessory_id:
		slots[other] = &""
	slots[slot] = accessory_id
	player.gadgets.configure(slots)
	_log("Acessório %s no slot A%d (cargas cheias)." % [AccessoryCatalog.display_name(accessory_id), slot + 1])


# --- INIMIGOS ------------------------------------------------------------------------

func _enemy_entries() -> Array:
	var entries: Array = []
	var spawned := get_tree().get_nodes_in_group(DEV_GROUP).filter(func(node: Node) -> bool: return node.is_in_group("enemy"))
	entries.append({"kind": "info", "text": "GERADOS PELO MODO DEV: %d   ·   VARIANTE VISUAL %s   ·   PAPEL %s   ·   IA %s" % [spawned.size(), BIOME_LABELS[enemy_biome], ROLE_LABELS[enemy_role], "PARADA" if dev_ai_paused else "ATIVA"]})
	entries.append({"kind": "row", "label": "VARIAÇÃO", "buttons": [
		{"label": "BIOMA: %s  ▸" % BIOME_LABELS[enemy_biome], "id": "cycle_enemy_biome", "action": cycle_enemy_biome},
		{"label": "PAPEL: %s  ▸" % ROLE_LABELS[enemy_role], "id": "cycle_enemy_role", "action": cycle_enemy_role},
		{"label": "IA: %s" % ("PARADA" if dev_ai_paused else "ATIVA"), "id": "toggle_ai", "action": toggle_dev_ai},
	]})
	entries.append({"kind": "header", "text": "INIMIGOS REGISTRADOS (cenas reais, vida e dano pela dificuldade da run; elite/chefe valem para corpo a corpo e à distância)"})
	for archetype: StringName in ENEMY_SCENES:
		entries.append({"kind": "row", "label": ENEMY_LABELS[archetype], "buttons": [
			{"label": "GERAR 1", "id": "spawn_%s_1" % archetype, "action": spawn_enemies.bind(archetype, 1)},
			{"label": "GERAR 3", "id": "spawn_%s_3" % archetype, "action": spawn_enemies.bind(archetype, 3)},
		]})
	entries.append({"kind": "row", "label": "LIMPEZA", "buttons": [
		{"label": "REMOVER GERADOS", "id": "remove_spawned", "action": remove_spawned_enemies},
		{"label": "DERROTAR TODOS (COM DROPS)", "id": "defeat_all", "action": defeat_room_enemies},
	]})
	return entries


func cycle_enemy_biome() -> void:
	var keys: Array = BIOME_LABELS.keys()
	enemy_biome = keys[(keys.find(enemy_biome) + 1) % keys.size()]


func cycle_enemy_role() -> void:
	var keys: Array = ROLE_LABELS.keys()
	enemy_role = keys[(keys.find(enemy_role) + 1) % keys.size()]


func toggle_dev_ai() -> void:
	dev_ai_paused = not dev_ai_paused
	for enemy in get_tree().get_nodes_in_group(DEV_GROUP):
		if enemy.is_in_group("enemy"):
			enemy.set_physics_process(not dev_ai_paused)


## Gera inimigos reais em pontos de chão seguros perto do jogador.
func spawn_enemies(archetype: StringName, count: int) -> Array[Node]:
	var result: Array[Node] = []
	var run_manager := _run_manager()
	if run_manager == null or not bool(run_manager.run_active):
		_log("Inimigos só durante a run (use MUNDO para entrar num bioma).")
		return result
	var points := find_safe_spawn_point(count)
	if points.is_empty():
		_log("Nenhum ponto seguro perto do jogador.")
		return result
	taint()
	var parent := _content_parent()
	for index in points.size():
		var enemy := _build_enemy(archetype)
		# Posição antes de entrar na árvore (lição do P1-A).
		enemy.position = parent.to_local(points[index])
		parent.add_child(enemy)
		run_manager.configure_spawned_enemy(enemy)
		if dev_ai_paused:
			enemy.set_physics_process(false)
		result.append(enemy)
	_log("%d × %s %s (%s) gerado(s)." % [result.size(), ENEMY_LABELS[archetype], ROLE_LABELS[enemy_role], BIOME_LABELS[enemy_biome]])
	return result


func _build_enemy(archetype: StringName) -> Node:
	var enemy: Node = (ENEMY_SCENES[archetype] as PackedScene).instantiate()
	_counter += 1
	enemy.name = "DevEnemy%d" % _counter
	enemy.persistent_id = StringName("dev_%s_%d_%d" % [archetype, _counter, Time.get_ticks_msec() % 100000])
	enemy.required_for_completion = false
	enemy.add_to_group(DEV_GROUP)
	var content_visual := enemy.get_node_or_null("EnemyCharacterVisual")
	if content_visual != null:
		content_visual.set("content_biome_id", ContentRegistry.biome_id(enemy_biome))
	# O pesado já tem papel próprio (HEAVY) definido no _ready da cena: sem elite/chefe.
	match enemy_role if archetype != &"heavy" else &"normal":
		&"elite":
			if enemy.has_method("configure_elite"):
				enemy.configure_elite()
			else:
				enemy.set("enemy_role", 2)
		&"boss":
			if archetype == &"common":
				BOSS_STAGE_SCRIPT.configure_prototype_boss(enemy)
			else:
				enemy.set("enemy_role", 1)
	return enemy


func remove_spawned_enemies() -> int:
	var removed := 0
	for node in get_tree().get_nodes_in_group(DEV_GROUP):
		if node.is_in_group("enemy"):
			node.queue_free()
			removed += 1
	_log("%d inimigo(s) do Modo Dev removido(s)." % removed)
	return removed


func defeat_room_enemies() -> int:
	var room_manager := _room_manager()
	if room_manager == null or room_manager.current_room == null:
		return 0
	taint()
	var defeated := 0
	for node in room_manager.current_room.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group("enemy") and EnemyStatus.is_alive(node) and node.has_method("take_damage"):
			node.take_damage(int(node.health) + 9999, 0.0, 0.0)
			defeated += 1
	_log("%d inimigo(s) derrotado(s) pelo caminho de dano real." % defeated)
	return defeated


# --- MUNDO ---------------------------------------------------------------------------

func _world_entries() -> Array:
	var entries: Array = []
	var room_manager := _room_manager()
	var run_manager := _run_manager()
	entries.append({"kind": "info", "text": "LOCAL: %s   ·   ESTÁGIO %d   ·   SEMENTE %d" % ["CASA DO JHON" if bool(room_manager.current_is_hub) else String(run_manager.current_biome_name), int(run_manager.stage_index), int(run_manager.seed_value)]})
	var stage_buttons: Array = []
	for stage: Array in STAGES:
		stage_buttons.append({"label": String(stage[1]), "id": "stage_%d" % int(stage[0]), "action": load_stage.bind(int(stage[0])), "closes": true})
	entries.append({"kind": "row", "label": "BIOMA", "buttons": stage_buttons})
	entries.append({"kind": "row", "label": "SALA", "buttons": [
		{"label": "REINICIAR SALA ATUAL", "id": "restart_stage", "action": restart_stage, "closes": true},
	]})
	entries.append({"kind": "row", "label": "BAÚS", "buttons": [
		{"label": "BAÚ COMUM", "id": "chest_common", "action": spawn_chest.bind(false, false)},
		{"label": "BAÚ COM ARMA", "id": "chest_weapon", "action": spawn_chest.bind(false, true)},
		{"label": "BAÚ TRAP", "id": "chest_trap", "action": spawn_chest.bind(true, true)},
	]})
	entries.append({"kind": "row", "label": "DROPS", "buttons": [
		{"label": "SIMULAR TABELA DO BIOMA", "id": "simulate_drops", "action": simulate_drops},
		{"label": "DERROTAR MAIS PRÓXIMO", "id": "defeat_nearest", "action": defeat_nearest_enemy},
	]})
	entries.append({"kind": "header", "text": "TELEPORTE (pontos válidos do bioma atual)"})
	for point: Dictionary in teleport_points():
		entries.append({"kind": "button", "label": "%s  (%d, %d)" % [point.label, int(point.position.x), int(point.position.y)], "id": "tp_%s" % point.id, "action": teleport_to.bind(point.position), "closes": true})
	return entries


func load_stage(stage: int) -> void:
	var room_manager := _room_manager()
	if room_manager == null:
		return
	taint()
	_log("Carregando estágio %d…" % stage)
	await room_manager.dev_load_stage(stage)
	taint()


func restart_stage() -> void:
	var room_manager := _room_manager()
	if room_manager == null or not bool(room_manager.run_manager.run_active):
		_log("Reiniciar sala: só dentro de uma run.")
		return
	taint()
	await room_manager.dev_restart_stage()
	_log("Sala reiniciada (mesmo layout, estado zerado).")


func teleport_points() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var room_manager := _room_manager()
	if room_manager == null or room_manager.current_room == null:
		return result
	var room: Node = room_manager.current_room
	if room.has_method("get_start_position"):
		result.append({"id": "start", "label": "INÍCIO", "position": room.get_start_position()})
	var seen := {}
	for node in room.find_children("*", "Area2D", true, false):
		var label := ""
		if node is BiomeTeleporter:
			label = "TELEPORTE %s" % String(node.display_name)
		elif node.get_script() == preload("res://scene/biomes/biome_exit.gd"):
			label = "SAÍDA %s" % String(node.destination_id).to_upper()
		elif node is TrapChest:
			label = "BAÚ TRAP"
		elif node.is_in_group("biome_loot"):
			label = "BAÚ"
		elif node is WeaponPickup:
			label = "ARMA %s" % WeaponCatalog.get_display_name(node.weapon_id)
		elif node.is_in_group("dash_passage"):
			label = "PASSAGEM DE DASH"
		if label.is_empty():
			continue
		var key := "%s_%d" % [label, int(node.global_position.x)]
		if seen.has(key):
			continue
		seen[key] = true
		result.append({"id": String(node.name).to_snake_case(), "label": label, "position": node.global_position})
	return result


func teleport_to(position: Vector2) -> void:
	var player := local_player()
	if player == null:
		return
	taint()
	player.global_position = position + Vector2(0, -24)
	player.velocity = Vector2.ZERO
	_last_safe_position = player.global_position
	_log("Teleporte para (%d, %d)." % [int(position.x), int(position.y)])


## Baús reais: comum (com ou sem arma da tabela) ou trap com emboscada em pontos seguros.
func spawn_chest(trap: bool, with_weapon: bool) -> Node:
	var run_manager := _run_manager()
	if run_manager == null or not bool(run_manager.run_active):
		_log("Baús só durante a run.")
		return null
	var points := find_safe_spawn_point(4 if trap else 1)
	if points.size() < (3 if trap else 1):
		_log("Sem espaço seguro para o baú.")
		return null
	taint()
	_counter += 1
	var content_id := StringName("dev_%d_loot_%02d" % [Time.get_ticks_msec() % 100000, _counter])
	var chest: Node2D
	if trap:
		var trap_chest := TRAP_SCENE.instantiate() as TrapChest
		trap_chest.trap_id = content_id
		for index in range(1, mini(points.size(), 4)):
			trap_chest.event_spawn_positions.append(points[index])
		chest = trap_chest
	else:
		var loot := LOOT_SCENE.instantiate()
		loot.loot_id = content_id
		loot.amount = 25
		chest = loot
	if with_weapon:
		var offers := WeaponLootTable.stage_sequence(Time.get_ticks_usec(), int(run_manager.stage_index), run_manager.current_biome_kind, run_manager.run_weapon_pool if not (run_manager.run_weapon_pool as Array).is_empty() else WeaponCatalog.discoverable_ids(), [], 1)
		if offers.is_empty():
			offers = [WeaponCatalog.discoverable_ids()[0]]
		chest.set("reward_weapon_id", offers[0])
		chest.set("reward_rarity", WeaponLootTable.rarity_for(&"trap_reward" if trap else &"chest", Time.get_ticks_usec(), content_id, int(run_manager.stage_index)))
	chest.add_to_group(DEV_GROUP)
	var parent := _content_parent()
	chest.position = parent.to_local(points[0] + Vector2(0, -10))
	parent.add_child(chest)
	_log("%s gerado%s." % ["Baú trap" if trap else "Baú comum", " com %s" % WeaponCatalog.get_display_name(chest.get("reward_weapon_id")) if with_weapon else ""])
	return chest


## Distribuição real da WeaponLootTable para o bioma/estágio/pool/histórico atuais.
func simulate_drops() -> Dictionary:
	var run_manager := _run_manager()
	var pool: Array = run_manager.run_weapon_pool if not (run_manager.run_weapon_pool as Array).is_empty() else WeaponCatalog.discoverable_ids()
	var kind: StringName = run_manager.current_biome_kind if not StringName(run_manager.current_biome_kind).is_empty() else &"lower_city"
	var distribution := WeaponLootTable.distribution(pool, kind, int(run_manager.stage_index), run_manager.weapon_offer_history)
	var ordered: Array = distribution.keys()
	ordered.sort_custom(func(a: Variant, b: Variant) -> bool: return float(distribution[a]) > float(distribution[b]))
	var parts: PackedStringArray = []
	for id: Variant in ordered.slice(0, 6):
		parts.append("%s %d%%" % [WeaponCatalog.get_display_name(id), roundi(float(distribution[id]) * 100.0)])
	_log("Tabela %s/estágio %d: %s  (baú %d%% · trap %d%% · pickup 38%%)" % [BIOME_LABELS.get(kind, kind), int(run_manager.stage_index), "  ".join(parts), roundi(float(WeaponLootTable.SOURCES.chest.chance) * 100), roundi(float(WeaponLootTable.SOURCES.trap_reward.chance) * 100)])
	return distribution


func defeat_nearest_enemy() -> bool:
	var player := local_player()
	var room_manager := _room_manager()
	if player == null or room_manager == null or room_manager.current_room == null:
		return false
	var nearest: Node2D = null
	for node in room_manager.current_room.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group("enemy") and EnemyStatus.is_alive(node) and (nearest == null or node.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position)):
			nearest = node
	if nearest == null:
		_log("Nenhum inimigo vivo na sala.")
		return false
	taint()
	nearest.take_damage(int(nearest.health) + 9999, 0.0, 0.0)
	_log("%s derrotado: drops pelo caminho real." % nearest.name)
	return true


# --- SESSÃO --------------------------------------------------------------------------

func _session_entries() -> Array:
	var meta := _meta()
	var run_manager := _run_manager()
	var entries: Array = []
	entries.append({"kind": "info", "text": "PERFIL: %s\nRUN DE TESTE: %s   ·   O resultado de runs de teste nunca entra no perfil real." % ["TESTE (%s) — o perfil real não está sendo gravado" % meta.save_path.get_file() if meta.dev_sandbox_active else "REAL (%s)" % meta.save_path.get_file(), "SIM" if bool(run_manager.dev_session) else "NÃO"]})
	entries.append({"kind": "row", "label": "PERFIL", "buttons": [
		{"label": "VOLTAR AO PERFIL REAL", "id": "end_session", "action": end_session},
		{"label": "RECOMEÇAR TESTE DO REAL", "id": "reset_sandbox", "action": reset_sandbox},
	]})
	entries.append({"kind": "header", "text": "REGISTRO"})
	for line in log_lines.slice(maxi(log_lines.size() - 10, 0)):
		entries.append({"kind": "info", "text": line})
	return entries


func reset_sandbox() -> void:
	taint()
	_meta().reset_dev_sandbox_from_legit()
	_log("Perfil de teste recomeçado como cópia do perfil real.")


# --- utilidades ----------------------------------------------------------------------

## Pontos de chão firme perto do jogador: raio para baixo no cenário (camada 1), espaço
## livre para o corpo, sem queda maior que 200 px, dentro dos limites do bioma.
func find_safe_spawn_point(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var player := local_player()
	if player == null:
		return result
	var space := player.get_world_2d().direct_space_state
	var exclude: Array[RID] = []
	for node in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemy"):
		if node is CollisionObject2D:
			exclude.append((node as CollisionObject2D).get_rid())
	var room_manager := _room_manager()
	var bounds: Rect2 = room_manager.generated_biome_bounds if room_manager != null and bool(room_manager.current_is_generated_biome) else Rect2()
	var origin := player.global_position
	for distance in [110.0, 170.0, 230.0, 290.0, 350.0, 420.0, 500.0, 80.0]:
		for side in [1.0, -1.0]:
			if result.size() >= count:
				return result
			var x: float = origin.x + float(side) * float(distance)
			if bounds.size != Vector2.ZERO and (x < bounds.position.x + 40.0 or x > bounds.end.x - 40.0):
				continue
			var from := Vector2(x, origin.y - 90.0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 300), 1, exclude))
			if hit.is_empty() or (hit.collider as Node) is CharacterBody2D:
				continue
			var floor_point: Vector2 = hit.position
			if floor_point.y - origin.y > 200.0 or floor_point.y < origin.y - 90.0 + 2.0:
				continue
			var body_clear := true
			for height in [8.0, 24.0, 44.0]:
				var query := PhysicsPointQueryParameters2D.new()
				query.position = floor_point + Vector2(0, -height)
				query.collision_mask = 1
				query.exclude = exclude
				if not space.intersect_point(query, 1).is_empty():
					body_clear = false
					break
			if not body_clear:
				continue
			var candidate := floor_point + Vector2(0, -20)
			if result.any(func(other: Vector2) -> bool: return other.distance_to(candidate) < 48.0):
				continue
			result.append(candidate)
	return result


func local_player() -> CharacterBody2D:
	for candidate in _players():
		if candidate.get("input_profile") == "p1" and not bool(candidate.get("network_remote_replica")):
			return candidate as CharacterBody2D
	return null


func _players() -> Array[Node]:
	var room_manager := _room_manager()
	return room_manager.get_players() if room_manager != null else []


func _content_parent() -> Node2D:
	var room_manager := _room_manager()
	return room_manager.current_room as Node2D


func _log(text: String) -> void:
	var line := "[%s] %s" % [Time.get_time_string_from_system(), text]
	log_lines.append(line)
	if log_lines.size() > 60:
		log_lines.remove_at(0)
	print("DEV_MODE ", text)
	log_changed.emit()


func _settings() -> LocalSettings:
	return get_parent().get_node_or_null("LocalSettings") as LocalSettings if get_parent() != null else null


func _meta() -> MetaProgression:
	return get_tree().get_first_node_in_group("meta_progression") as MetaProgression


func _room_manager() -> Node:
	return get_tree().get_first_node_in_group("room_manager")


func _run_manager() -> Node:
	return get_tree().get_first_node_in_group("run_manager")
