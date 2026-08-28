extends Node2D


func _ready() -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var summary := $LastRunSummary as Label
	if run_manager == null or run_manager.last_run_results.is_empty():
		summary.text = "ÚLTIMA RUN // NENHUM RESULTADO NESTA SESSÃO"
		return
	var result: Dictionary = run_manager.last_run_results
	var weapons := _normalize_weapons(result.get("weapons_found"))
	var participants := _normalize_dictionary(result.get("participants"))
	var attributes: PackedStringArray = []
	for participant_id in participants:
		var values := _normalize_dictionary(participants[participant_id])
		attributes.append("%s: INT %d | SAÚDE %d | FORÇA %d" % [String(participant_id).replace("player_", "P"), _safe_int(values.get("intellect")), _safe_int(values.get("health")), _safe_int(values.get("strength"))])
	var weapon_lines: PackedStringArray = []
	for weapon_id in weapons:
		weapon_lines.append("• %s" % WeaponCatalog.get_display_name(StringName(weapon_id)))
	if weapon_lines.is_empty():
		weapon_lines.append("• NENHUMA ARMA REGISTRADA")
	if attributes.is_empty():
		attributes.append("INT 0 | SAÚDE 0 | FORÇA 0")
	var stages := _normalize_sequence(result.get("stage_history"))
	summary.text = "ÚLTIMA RUN // %s\nTEMPO %s | DIFICULDADE %s | STAGE %d/6 | DINHEIRO $%d\nARMAS:\n%s\nATRIBUTOS: %s" % ["VITÓRIA" if bool(result.get("completed", false)) else "DERROTA", _format_time(_safe_float(result.get("elapsed_time"))), String(result.get("difficulty", "normal")).to_upper(), clampi(maxi(stages.size(), _safe_int(result.get("stage_index")) + 1), 1, 6), _safe_int(result.get("money_earned")), "\n".join(weapon_lines), " // ".join(attributes)]


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), floori(seconds) % 60]


func _normalize_sequence(value: Variant) -> Array:
	if value is Array:
		return value.duplicate(true)
	if value is PackedStringArray:
		return Array(value)
	if value is Dictionary:
		return value.values()
	if value == null or String(value).is_empty():
		return []
	return [value]


func _normalize_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _normalize_weapons(value: Variant) -> Array:
	var flattened: Array = []
	for entry in _normalize_sequence(value):
		for weapon in _normalize_sequence(entry):
			var weapon_id := StringName(weapon)
			if not weapon_id.is_empty() and not flattened.has(weapon_id):
				flattened.append(weapon_id)
	return flattened


func _safe_int(value: Variant, fallback := 0) -> int:
	return int(value) if value != null and (value is int or value is float or String(value).is_valid_int()) else fallback


func _safe_float(value: Variant, fallback := 0.0) -> float:
	return float(value) if value != null and (value is int or value is float or String(value).is_valid_float()) else fallback
