class_name AudioService
extends Node

const MENU_SOUNDTRACK = preload("res://assets/audio/menu/menu soundtrack.ogg")
const MENU_RAIN = preload("res://assets/audio/menu/ambiente_chuva.ogg")
const MENU_CITY = preload("res://assets/audio/menu/ambiente_urbano.ogg")
const MENU_THUNDER = preload("res://assets/audio/menu/Efeito_sonoro_Trovoadas.wav")
const MENU_MUSIC_VOLUME_DB := -10.0

const MUSIC_CONTEXTS: Array[StringName] = [&"main_menu", &"house", &"operation", &"boss"]
const EVENT_BUSES := {
	&"ui_focus": &"SFX",
	&"ui_confirm": &"SFX",
	&"ui_cancel": &"SFX",
	&"ui_open": &"SFX",
	&"ui_close": &"SFX",
	&"player_jump": &"SFX",
	&"player_dash": &"SFX",
	&"player_attack": &"SFX",
	&"player_hurt": &"SFX",
	&"player_downed": &"SFX",
	&"player_revive": &"SFX",
	&"enemy_attack": &"SFX",
	&"enemy_hurt": &"SFX",
	&"enemy_death": &"SFX",
	&"enemy_telegraph": &"SFX",
	&"world_door": &"SFX",
	&"world_interact": &"SFX",
	&"loot_open": &"SFX",
	&"menu_thunder": &"SFX",
}

var event_streams: Dictionary = {}
var music_streams: Dictionary = {}
var current_music_context: StringName = &""
var _music_player: AudioStreamPlayer
var _music_fade: Tween
var _menu_rain_player: AudioStreamPlayer
var _menu_city_player: AudioStreamPlayer
var _ambience_fades: Dictionary = {}
var _menu_ambience_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("audio_service")
	var menu_music := MENU_SOUNDTRACK.duplicate() as AudioStreamOggVorbis
	var menu_rain := MENU_RAIN.duplicate() as AudioStreamOggVorbis
	var menu_city := MENU_CITY.duplicate() as AudioStreamOggVorbis
	menu_music.loop = true
	menu_rain.loop = true
	menu_city.loop = true
	register_music_stream(&"main_menu", menu_music)
	register_event_stream(&"menu_thunder", MENU_THUNDER, &"SFX")
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Music"
	add_child(_music_player)
	_menu_rain_player = _make_menu_ambience("MenuRain", menu_rain, -15.0)
	_menu_city_player = _make_menu_ambience("MenuCity", menu_city, -25.0)
	var visual := get_parent().get_node_or_null("MenuEnvironment/AnimatedMenuBackground")
	if visual != null:
		visual.lightning_struck.connect(_on_menu_lightning)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_wire_existing_buttons")


func _process(_delta: float) -> void:
	var menu_environment := get_parent().get_node_or_null("MenuEnvironment")
	var should_play: bool = current_music_context == &"main_menu" and menu_environment != null and menu_environment.visible
	if should_play == _menu_ambience_active:
		return
	_menu_ambience_active = should_play
	for player: AudioStreamPlayer in [_menu_rain_player, _menu_city_player]:
		var old_tween := _ambience_fades.get(player) as Tween
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
		if should_play and not player.playing:
			player.volume_db = -55.0
			player.play()
		var tween := create_tween()
		tween.tween_property(player, "volume_db", float(player.get_meta("menu_volume_db")) if should_play else -55.0, 0.35)
		if not should_play:
			tween.tween_callback(player.stop)
		_ambience_fades[player] = tween


func _make_menu_ambience(node_name: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream
	player.bus = &"Ambience"
	player.volume_db = -55.0
	player.set_meta("menu_volume_db", volume_db)
	add_child(player)
	return player


func _on_menu_lightning() -> void:
	if _menu_ambience_active:
		play_event(&"menu_thunder")


func register_event_stream(event_id: StringName, stream: AudioStream, bus: StringName = &"") -> void:
	if event_id.is_empty():
		return
	if stream == null:
		event_streams.erase(event_id)
		return
	event_streams[event_id] = {"stream": stream, "bus": bus}


func register_music_stream(context: StringName, stream: AudioStream) -> void:
	if not MUSIC_CONTEXTS.has(context):
		return
	if stream == null:
		music_streams.erase(context)
		return
	music_streams[context] = stream


func play_event(event_id: StringName, pitch_scale: float = 1.0) -> bool:
	var entry: Variant = event_streams.get(event_id)
	if entry == null:
		return false
	var stream: AudioStream = entry.get("stream") as AudioStream
	if stream == null:
		return false
	var player := AudioStreamPlayer.new()
	player.name = "OneShot_%s" % String(event_id)
	player.stream = stream
	var explicit_bus := StringName(entry.get("bus", &""))
	player.bus = explicit_bus if not explicit_bus.is_empty() else StringName(EVENT_BUSES.get(event_id, &"SFX"))
	if event_id == &"menu_thunder":
		player.volume_db = -8.0
	player.pitch_scale = clampf(pitch_scale, 0.25, 4.0)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return true


func set_music_context(context: StringName, fade_seconds: float = 0.0) -> bool:
	if not MUSIC_CONTEXTS.has(context):
		return false
	if context == current_music_context and _music_player.stream != null:
		return true
	current_music_context = context
	if _music_fade != null and _music_fade.is_valid():
		_music_fade.kill()
	var stream := music_streams.get(context) as AudioStream
	if stream == null:
		if fade_seconds > 0.0 and _music_player.playing:
			_music_fade = create_tween()
			_music_fade.tween_property(_music_player, "volume_db", -55.0, fade_seconds)
			_music_fade.tween_callback(func() -> void:
				_music_player.stop()
				_music_player.stream = null)
		else:
			_music_player.stop()
			_music_player.stream = null
		return false
	var target_volume: float = MENU_MUSIC_VOLUME_DB if context == &"main_menu" else 0.0
	if fade_seconds <= 0.0 or not _music_player.playing:
		_music_player.stop()
		_music_player.stream = stream
		_music_player.volume_db = -55.0 if fade_seconds > 0.0 else target_volume
		_music_player.play()
		if fade_seconds > 0.0:
			_music_fade = create_tween()
			_music_fade.tween_property(_music_player, "volume_db", target_volume, fade_seconds)
		return true
	var duration := maxf(fade_seconds, 0.02)
	_music_fade = create_tween()
	_music_fade.tween_property(_music_player, "volume_db", -55.0, duration * 0.5)
	_music_fade.tween_callback(func() -> void:
		_music_player.stop()
		_music_player.stream = stream
		_music_player.volume_db = -55.0
		_music_player.play()
	)
	_music_fade.tween_property(_music_player, "volume_db", target_volume, duration * 0.5)
	return true


func clear_registered_streams() -> void:
	event_streams.clear()
	music_streams.clear()
	_music_player.stop()
	_music_player.stream = null
	current_music_context = &""


func _wire_existing_buttons() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		_wire_button(node as BaseButton)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)


func _wire_button(button: BaseButton) -> void:
	if button == null or button.has_meta("audio_service_wired"):
		return
	button.set_meta("audio_service_wired", true)
	button.focus_entered.connect(_on_button_focus_entered)
	button.pressed.connect(_on_button_pressed)


func _on_button_focus_entered() -> void:
	play_event(&"ui_focus")


func _on_button_pressed() -> void:
	play_event(&"ui_confirm")
