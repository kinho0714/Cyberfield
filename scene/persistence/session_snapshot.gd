class_name SessionSnapshot
extends RefCounted
## Data-only session adapter. Objects, callables and signals are never decoded.
## RNG state is explicit; active coroutine effects defer the snapshot.
const MAP_STATE := preload("res://scene/biomes/biome_map_state.gd")
const VERSION := 1


static func capture(game: Node) -> Dictionary:
	if not game.mode_selected or game.is_transitioning or game.get_players().is_empty():
		return {}
	# Await continuations cannot be serialized. Defer until an idle boundary.
	for actor in game.get_tree().get_nodes_in_group("player") + game.get_tree().get_nodes_in_group("enemy"):
		if actor.get("is_attacking") == true or actor.get("is_hurt") == true or actor.get("is_dead") == true or float(actor.get("dash_timer") if actor.get("dash_timer") != null else 0.0) > 0.0:
			return {}
	if not game.get_tree().get_nodes_in_group("player_gadget").is_empty():
		return {}
	var maps := {}
	for id: Variant in game.run_manager.map_states:
		maps[id] = game.run_manager.map_states[id].to_dictionary()
	var world: Array[Dictionary] = []
	_capture_tree(game.current_room, game.current_room, world)
	var players: Array[Dictionary] = []
	for player in game.get_players():
		var children: Array[Dictionary] = []
		_capture_tree(player, player, children)
		players.append({"properties": properties(player), "position": player.global_position, "children": children})
	var report: Dictionary = game.current_room.get_generation_report() if game.current_room.has_method("get_generation_report") else {}
	return {"version": VERSION, "hub": game.current_is_hub,
		"run": properties(game.run_manager), "maps": maps,
		"players": players, "world": world,
		"signature": report.get("signature", ""),
		"permanent": game.get_node("MetaProgression").to_dictionary()}


static func restore(game: Node, snapshot: Dictionary) -> bool:
	if not valid(snapshot) or game.get_players().size() != snapshot.players.size():
		return false
	var area_seed := _prepare_restore(game, snapshot)
	game.restoring_snapshot = true
	var loaded: bool = game._load_laboratory_hub() if snapshot.hub else game._load_current_stage(area_seed)
	game.restoring_snapshot = false
	return loaded and _finish_restore(game, snapshot)


static func restore_async(game: Node, snapshot: Dictionary) -> bool:
	if not valid(snapshot) or game.get_players().size() != snapshot.players.size() or not game.loading.active:
		return false
	var token: int = game.loading.generation
	var area_seed := _prepare_restore(game, snapshot)
	game.restoring_snapshot = true
	var loaded: bool = await game._load_laboratory_hub_async() if snapshot.hub else await game._load_current_stage_async(area_seed)
	game.restoring_snapshot = false
	if not loaded or token != game.loading.generation:
		return false
	game.loading.stage("Restaurando campanha…")
	await game.get_tree().process_frame
	return _finish_restore(game, snapshot)


static func _prepare_restore(game: Node, snapshot: Dictionary) -> int:
	var manager: Node = game.run_manager
	apply_properties(manager, snapshot.run)
	game.get_node("MetaProgression")._reset_defaults()
	game.get_node("MetaProgression")._apply_save(snapshot.permanent)
	# Remove immediately from tree before regeneration, avoiding stale group members.
	if is_instance_valid(game.current_room):
		game.current_room.get_parent().remove_child(game.current_room)
		game.current_room.free()
		game.current_room = null
	var area_seed: int = int(snapshot.run.get("area_seed_value", 0))
	if area_seed <= 0:
		area_seed = manager.get_stage_seed()
	return area_seed


static func _finish_restore(game: Node, snapshot: Dictionary) -> bool:
	var manager: Node = game.run_manager
	var report: Dictionary = game.current_room.get_generation_report() if game.current_room.has_method("get_generation_report") else {}
	if String(report.get("signature", "")) != String(snapshot.signature):
		return false
	apply_properties(manager, snapshot.run)
	manager.map_states.clear()
	for id: Variant in snapshot.maps:
		var map := MAP_STATE.new(StringName(id))
		map.apply_dictionary(snapshot.maps[id])
		manager.map_states[id] = map
	if not _restore_world(game.current_room, snapshot.world):
		return false
	for i in snapshot.players.size():
		var player: Node = game.get_players()[i]
		player.call("_end_dash")
		if not _restore_world(player, snapshot.players[i].get("children", [])):
			return false
		apply_properties(player, snapshot.players[i].properties)
		player.global_position = snapshot.players[i].position
		if game.loading.active:
			player.set_input_enabled(false)
		player.dev_invincible = false
		player.call("_update_health_label")
	manager.state_changed.emit()
	game.refresh_teleporter_states()
	return true


static func valid(snapshot: Dictionary) -> bool:
	if int(snapshot.get("version", 0)) != VERSION or snapshot.get("hub") is not bool or snapshot.get("signature") is not String:
		return false
	for key in ["run", "maps", "permanent"]:
		if snapshot.get(key) is not Dictionary:
			return false
	if snapshot.get("world") is not Array or snapshot.get("players") is not Array:
		return false
	if snapshot.players.is_empty() or snapshot.players.size() > 4 or snapshot.world.size() > 20000:
		return false
	if snapshot.run.get("seed_value") is not int or snapshot.run.get("stage_index") is not int:
		return false
	for player: Variant in snapshot.players:
		if player is not Dictionary or player.get("properties") is not Dictionary or player.get("position") is not Vector2:
			return false
		if not _valid_world(player.get("children", [])):
			return false
	for map: Variant in snapshot.maps.values():
		if map is not Dictionary:
			return false
	return _valid_world(snapshot.world)


static func _valid_world(world: Variant) -> bool:
	if world is not Array or world.size() > 20000:
		return false
	for data: Variant in world:
		if data is not Dictionary or data.get("properties") is not Dictionary or data.get("native_children") is not Dictionary:
			return false
		for key in ["path", "parent", "name", "scene", "script", "identity"]:
			if data.get(key) is not String:
				return false
		for child_path: Variant in data.native_children:
			if child_path is not String or data.native_children[child_path] is not Dictionary or ".." in child_path.split("/"):
				return false
			for key: Variant in data.native_children[child_path]:
				if key not in ["disabled", "monitoring", "monitorable"] or data.native_children[child_path][key] is not bool:
					return false
		if ".." in data.path.split("/") or ".." in data.parent.split("/"):
			return false
		if not data.script.begins_with("res://") or not data.script.ends_with(".gd"):
			return false
		if not data.scene.is_empty() and (not data.scene.begins_with("res://") or not data.scene.ends_with(".tscn")):
			return false
	return true


static func properties(node: Node) -> Dictionary:
	var values := {}
	for property: Dictionary in node.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var value: Variant = node.get(property.name)
		if _data_only(value):
			values[String(property.name)] = value.duplicate(true) if value is Array or value is Dictionary else value
	# Preserve explicitly the state of script-owned RNGs without serializing objects.
	for property: Dictionary in node.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = node.get(property.name)
			if value is RandomNumberGenerator:
				values["rng::" + String(property.name)] = {"seed": value.seed, "state": value.state}
	return values


static func apply_properties(node: Node, values: Dictionary) -> void:
	var allowed := {}
	for property: Dictionary in node.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			allowed[String(property.name)] = true
	for key: String in values:
		if key.begins_with("rng::"):
			var rng: Variant = node.get(key.trim_prefix("rng::"))
			if rng is RandomNumberGenerator:
				rng.seed = values[key].seed
				rng.state = values[key].state
		elif allowed.has(key) and _data_only(values[key]):
			node.set(key, values[key])


static func _data_only(value: Variant, depth := 0) -> bool:
	if depth > 24 or typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]:
		return false
	if value is Array:
		if value.is_typed() and value.get_typed_builtin() == TYPE_OBJECT:
			return false
		for item: Variant in value:
			if not _data_only(item, depth + 1):
				return false
	if value is Dictionary:
		for key: Variant in value:
			if not _data_only(key, depth + 1) or not _data_only(value[key], depth + 1):
				return false
	return true


static func _capture_tree(root: Node, node: Node, result: Array[Dictionary]) -> void:
	if node.is_queued_for_deletion():
		return
	if node.get_script() != null:
		var data := {"path": String(root.get_path_to(node)), "parent": String(root.get_path_to(node.get_parent())) if node != root else "",
			"name": String(node.name), "scene": node.scene_file_path,
			"script": node.get_script().resource_path, "properties": properties(node),
			"identity": _identity(node), "native_children": _native_children(node)}
		if node is CharacterBody2D:
			data.velocity = node.velocity
		if node is Node2D:
			data.position = node.position
			data.visible = node.visible
		result.append(data)
	for child in node.get_children():
		_capture_tree(root, child, result)


static func _identity(node: Node) -> String:
	for key in ["persistent_id", "pickup_id", "drop_id", "loot_id", "trap_id", "passage_id"]:
		for property: Dictionary in node.get_property_list():
			if String(property.name) == key and not String(node.get(key)).is_empty():
				return String(node.get_script().resource_path) + "::" + String(node.get(key))
	return ""


static func _restore_world(root: Node, world: Array) -> bool:
	var existing: Array[Dictionary] = []
	_capture_tree(root, root, existing)
	var by_identity := {}
	for data: Dictionary in existing:
		if not String(data.identity).is_empty():
			by_identity[data.identity] = root.get_node(NodePath(data.path))
	var retained: Array[Node] = []
	var resolved := {}
	for data: Dictionary in world:
		var node: Node = by_identity.get(data.identity) if not String(data.identity).is_empty() else _resolve_path(root, data.path, resolved)
		if node == null:
			var parent := _resolve_path(root, data.parent, resolved)
			if parent == null or not String(data.script).begins_with("res://"):
				return false
			if not String(data.scene).is_empty():
				var packed := load(String(data.scene)) as PackedScene
				if packed == null:
					return false
				node = packed.instantiate()
			else:
				var script := load(String(data.script)) as Script
				if script == null or not script.can_instantiate():
					return false
				node = script.new()
			node.name = data.name
			apply_properties(node, data.properties)
			if node is Node2D:
				node.position = data.get("position", Vector2.ZERO)
			parent.add_child(node)
		if node.get_script() == null or String(node.get_script().resource_path) != String(data.script):
			return false
		resolved[data.path] = node
		apply_properties(node, data.properties)
		if node is CharacterBody2D:
			node.velocity = data.get("velocity", Vector2.ZERO)
		if node is Node2D:
			node.position = data.get("position", node.position)
			node.visible = data.get("visible", true)
		for child_path: String in data.get("native_children", {}):
			var child := node.get_node_or_null(NodePath(child_path))
			if child != null:
				for key: String in data.native_children[child_path]:
					child.set_deferred(key, data.native_children[child_path][key])
		retained.append(node)
	for data: Dictionary in existing:
		var node := root.get_node_or_null(NodePath(data.path))
		if node != null and node != root and not retained.has(node):
			node.get_parent().remove_child(node)
			node.free()
	return true


static func _native_children(node: Node) -> Dictionary:
	var result := {}
	for child in node.get_children():
		var values := {}
		if child is CollisionShape2D or child is CollisionPolygon2D:
			values.disabled = child.disabled
		if child is Area2D:
			values.monitoring = child.monitoring
			values.monitorable = child.monitorable
		if not values.is_empty():
			result[String(node.get_path_to(child))] = values
	return result


static func _resolve_path(root: Node, path: String, resolved: Dictionary) -> Node:
	if resolved.has(path):
		return resolved[path]
	var parts := path.split("/")
	for count in range(parts.size() - 1, 0, -1):
		var prefix := "/".join(parts.slice(0, count))
		if resolved.has(prefix):
			return resolved[prefix].get_node_or_null(NodePath("/".join(parts.slice(count))))
	return root.get_node_or_null(NodePath(path))
