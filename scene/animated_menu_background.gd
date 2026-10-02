extends Control
## Independent environment. Official textures only; no gameplay or UI dependencies.

@export_group("Modules")
@export var rain_enabled: bool = true:
	set(value):
		rain_enabled = value
		if is_node_ready():
			_sync_modules()
@export var lights_enabled: bool = true:
	set(value):
		lights_enabled = value
		if is_node_ready():
			_sync_modules()
@export var atmosphere_enabled: bool = true:
	set(value):
		atmosphere_enabled = value
		if is_node_ready():
			_sync_modules()
@export var lightning_enabled: bool = true:
	set(value):
		lightning_enabled = value
		if is_node_ready():
			_sync_modules()
@export var clouds_enabled: bool = true:
	set(value):
		clouds_enabled = value
		if is_node_ready():
			_sync_modules()
@export_group("Clouds")
@export_range(0.2, 20.0, 0.1) var cloud_back_speed: float = 7.0
@export_range(0.2, 20.0, 0.1) var cloud_front_speed: float = 11.5
@export_group("Rain")
@export_range(24, 420, 1) var rain_base_amount: int = 400
@export_range(0.0, 0.25, 0.01) var rain_variation: float = 0.18
@export_range(-25.0, -5.0, 1.0) var rain_angle: float = -16.0
@export_range(200.0, 450.0, 10.0) var rain_speed: float = 300.0
@export_group("Lights")
@export_range(6.0, 60.0, 1.0) var light_event_min_interval: float = 6.0
@export_range(6.0, 90.0, 1.0) var light_event_max_interval: float = 12.0
@export_group("Lightning")
@export_range(3.0, 60.0, 1.0) var lightning_min_interval: float = 7.0
@export_range(3.0, 90.0, 1.0) var lightning_max_interval: float = 16.0
@export_range(0.0, 1.0, 0.05) var lightning_intensity: float = 0.85
@export_group("Debug — runtime Remote Inspector; defaults OFF")
@export var debug_force_rain: bool = false
@export var debug_force_lights: bool = false
@export var debug_force_lightning: bool = false

# Alpha-weighted source x centers, measured from the six official bolt textures.
const BOLT_CENTERS: Array[float] = [0.200271, 0.475109, 0.718880, 0.314004, 0.574766, 0.826206]
const MASTER_SIZE: Vector2 = Vector2(1664.0, 936.0)
const RAIN_SHADER: Shader = preload("res://scene/menu_rain.gdshader")
const BACK_DROP: Texture2D = preload("res://assets/ui/menu/animated/v3/rain/rain_back_drop_v3.png")
const FRONT_DROP: Texture2D = preload("res://assets/ui/menu/animated/v3/rain/rain_front_drop_v3.png")
@onready var composition: Node2D = $Composition
@onready var weather: Node2D = $Composition/Weather
@onready var cyan: Sprite2D = $Composition/Cyan
@onready var magenta: Array[Sprite2D] = [$Composition/Magenta0, $Composition/Magenta1]
@onready var windows: Array[Sprite2D] = [$Composition/Windows0, $Composition/Windows1, $Composition/Windows2]
@onready var glow: Sprite2D = $Composition/CityGlow
@onready var haze: Sprite2D = $Composition/Atmosphere
@onready var bolts: Array[Sprite2D] = [$Composition/Large1, $Composition/Large2, $Composition/Large3, $Composition/Short1, $Composition/Short2, $Composition/Short3]
@onready var flash: Sprite2D = $Composition/LightningFlash
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var rain_back: CPUParticles2D
var rain_front: CPUParticles2D
var rain_clock: float = 0.0
var rain_level: float = 1.0
var rain_target: float = 1.0
var light_clock: float = 0.0
var light_phase: float = 0.0
var window_levels: Vector3 = Vector3(0.18, 0.26, 0.14)
var window_targets: Vector3 = Vector3(0.18, 0.26, 0.14)
var neon_event_age: float = -1.0
var neon_group: int = 0
var atmosphere_phase: float = 0.0
var lightning_clock: float = 0.0
var flash_age: float = -1.0
var flash_strength: float = 0.0
var double_flash: bool = false
var selected_bolt: int = -1
var pre_glow_duration: float = 0.04
var cloud_phase: Vector2 = Vector2.ZERO
@onready var cloud_back: Array[Sprite2D] = [$Composition/BackA, $Composition/BackB, $Composition/BackMask]
@onready var cloud_front: Array[Sprite2D] = [$Composition/FrontA, $Composition/FrontB, $Composition/FrontMask]


func _ready() -> void:
	rng.randomize()
	light_phase = rng.randf_range(0.0, 100.0)
	atmosphere_phase = rng.randf_range(0.0, 100.0)
	rain_clock = rng.randf_range(9.0, 18.0)
	light_clock = _interval(light_event_min_interval, light_event_max_interval)
	lightning_clock = _interval(lightning_min_interval, lightning_max_interval)
	resized.connect(_fit_master)
	visibility_changed.connect(_sync_modules)
	_fit_master()
	_sync_modules()


func _fit_master() -> void:
	# Uniform cover: exact 10/13 at 1280x720; only excess is clipped on other aspects.
	var factor: float = maxf(size.x / MASTER_SIZE.x, size.y / MASTER_SIZE.y)
	composition.scale = Vector2.ONE * maxf(factor, 0.001)
	composition.position = (size - MASTER_SIZE * factor) * 0.5
	# Recover 24 logical pixels of top framing only where cover already crops vertically.
	# Clamp to the available crop: 16:9 remains exactly (0, 0), with no empty edge.
	var vertical_excess: float = maxf(0.0, MASTER_SIZE.y * factor - size.y)
	composition.position.y = clampf(composition.position.y + 24.0 * size.y / 720.0, -vertical_excess, 0.0)


func _interval(low: float, high: float) -> float:
	return rng.randf_range(maxf(1.0, low), maxf(maxf(1.0, low), high))


func _sync_modules() -> void:
	var active: bool = is_visible_in_tree()
	if active and rain_enabled:
		if not is_instance_valid(rain_back):
			rain_back = _create_rain(false)
			rain_front = _create_rain(true)
	else:
		for emitter: CPUParticles2D in [rain_back, rain_front]:
			if is_instance_valid(emitter):
				emitter.emitting = false
				emitter.hide()
				emitter.queue_free()
		rain_back = null
		rain_front = null
	cyan.visible = active and lights_enabled
	glow.visible = active and lights_enabled
	for overlay: Sprite2D in magenta + windows:
		overlay.visible = active and lights_enabled
	for cloud: Sprite2D in cloud_back + cloud_front:
		cloud.visible = active and clouds_enabled
	if not active or not clouds_enabled or not lightning_enabled:
		cloud_back[2].modulate.a = 0.0
		cloud_front[2].modulate.a = 0.0
	haze.visible = active and atmosphere_enabled
	flash.visible = active and lightning_enabled
	for bolt: Sprite2D in bolts:
		bolt.visible = active and lightning_enabled
	if not active or not lightning_enabled:
		flash_age = -1.0
		flash_strength = 0.0
		flash.modulate.a = 0.0
		for bolt: Sprite2D in bolts:
			bolt.modulate.a = 0.0
		if lights_enabled:
			glow.modulate.a = 0.09 + 0.015 * sin(light_phase * 0.11 + 1.4)
		lightning_clock = _interval(lightning_min_interval, lightning_max_interval)
	if not active or not lights_enabled:
		neon_event_age = -1.0
	set_process(active and (rain_enabled or lights_enabled or atmosphere_enabled or lightning_enabled or clouds_enabled))


func _create_rain(front: bool) -> CPUParticles2D:
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.name = "RainFront" if front else "RainBack"
	emitter.amount = maxi(8, int(rain_base_amount * 0.25)) if front else rain_base_amount
	emitter.lifetime = 3.2 if front else 5.6
	emitter.preprocess = emitter.lifetime
	emitter.local_coords = true
	emitter.fixed_fps = 30
	emitter.position = Vector2(MASTER_SIZE.x * 0.5 + 150.0, -25.0)
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.emission_rect_extents = Vector2(MASTER_SIZE.x * 0.5 + 240.0, 20.0)
	var angle: float = deg_to_rad(rain_angle)
	emitter.direction = Vector2(sin(angle), cos(angle))
	emitter.spread = 2.0
	emitter.lifetime_randomness = 0.08
	emitter.gravity = Vector2.ZERO
	var speed: float = rain_speed * (1.7 if front else 0.85)
	emitter.initial_velocity_min = speed * 0.82
	emitter.initial_velocity_max = speed * 1.18
	emitter.angle_min = -rain_angle
	emitter.angle_max = -rain_angle
	emitter.scale_amount_min = 0.65 if front else 0.40
	emitter.scale_amount_max = 0.85 if front else 0.60
	emitter.color = Color(1.0, 1.0, 1.0, 0.90 if front else 0.72)
	emitter.texture = FRONT_DROP if front else BACK_DROP
	var drawing: ShaderMaterial = ShaderMaterial.new()
	drawing.shader = RAIN_SHADER
	emitter.material = drawing
	emitter.emitting = true
	weather.add_child(emitter)
	return emitter


func _process(delta: float) -> void:
	if clouds_enabled:
		_update_clouds(delta)
	if rain_enabled:
		_update_rain(delta)
	if lights_enabled:
		_update_lights(delta)
	if atmosphere_enabled:
		atmosphere_phase += delta * 0.12
		haze.modulate.a = 0.42 + 0.10 * sin(atmosphere_phase)
	if lightning_enabled:
		if debug_force_lightning:
			debug_force_lightning = false
			trigger_lightning()
		_update_lightning(delta)


func _update_rain(delta: float) -> void:
	rain_clock -= delta
	if rain_clock <= 0.0:
		rain_clock = rng.randf_range(9.0, 18.0)
		rain_target = clampf(1.0 + rng.randf_range(-rain_variation, rain_variation), 0.75, 1.25)
	rain_level = move_toward(rain_level, rain_target, delta * 0.035)
	var strength: float = 1.75 if debug_force_rain else rain_level
	# Native particle count stays fixed: smoothly vary opacity, no emitter restarts.
	rain_back.modulate.a = strength
	rain_front.modulate.a = strength


func _update_lights(delta: float) -> void:
	light_phase += delta
	light_clock -= delta
	if light_clock <= 0.0:
		light_clock = _interval(light_event_min_interval, light_event_max_interval)
		var group: int = rng.randi_range(0, 4)
		if group < 2:
			neon_group = group
			neon_event_age = 0.0
		else:
			var index: int = group - 2
			window_targets[index] = 0.08 if window_targets[index] > 0.20 else rng.randf_range(0.30, 0.48)
	window_levels = window_levels.move_toward(window_targets, delta * 0.22)
	cyan.modulate.a = 0.28 + 0.065 * sin(light_phase * 0.23)
	for index in range(2):
		magenta[index].modulate.a = 0.25 + 0.045 * sin(light_phase * (0.17 + index * 0.035) + index * 2.7)
	if neon_event_age >= 0.0:
		neon_event_age += delta
		if neon_event_age < 0.08 or (neon_event_age > 0.19 and neon_event_age < 0.26):
			magenta[neon_group].modulate.a = 0.07
		elif neon_event_age > 0.36:
			neon_event_age = -1.0
	for index in range(3):
		windows[index].modulate.a = window_levels[index]
	glow.modulate.a = 0.09 + 0.015 * sin(light_phase * 0.11 + 1.4)
	if debug_force_lights:
		var debug_alpha: float = 0.45 + 0.35 * sin(light_phase * 2.0)
		cyan.modulate.a = debug_alpha
		for overlay: Sprite2D in magenta + windows:
			overlay.modulate.a = debug_alpha


func _update_clouds(delta: float) -> void:
	cloud_phase.x = fposmod(cloud_phase.x + delta * cloud_back_speed / MASTER_SIZE.x, 1.0)
	cloud_phase.y = fposmod(cloud_phase.y + delta * cloud_front_speed / MASTER_SIZE.x, 1.0)
	for cloud: Sprite2D in cloud_back:
		(cloud.material as ShaderMaterial).set_shader_parameter("scroll", cloud_phase.x)
	for cloud: Sprite2D in cloud_front:
		(cloud.material as ShaderMaterial).set_shader_parameter("scroll", cloud_phase.y)


func trigger_lightning() -> void:
	## Remote Inspector debug_force_lightning requests one complete event.
	if not lightning_enabled or not is_visible_in_tree():
		return
	var first: int = 3 if rng.randf() < 0.65 else 0
	var candidates: Array[int] = []
	for index in range(first, first + 3):
		if index != selected_bolt:
			candidates.append(index)
	selected_bolt = candidates[rng.randi_range(0, candidates.size() - 1)]
	flash_age = 0.0
	pre_glow_duration = rng.randf_range(0.02, 0.06)
	flash.modulate.a = 0.0
	for bolt: Sprite2D in bolts:
		bolt.modulate.a = 0.0
	for mask: Sprite2D in [cloud_back[2], cloud_front[2]]:
		mask.modulate.a = 0.0
		(mask.material as ShaderMaterial).set_shader_parameter("event_x", BOLT_CENTERS[selected_bolt])
	double_flash = rng.randf() < 0.30
	lightning_clock = _interval(lightning_min_interval, lightning_max_interval)


func _update_lightning(delta: float) -> void:
	lightning_clock -= delta
	if flash_age < 0.0 and lightning_clock <= 0.0:
		trigger_lightning()
	flash_strength = 0.0
	var cloud_strength: float = 0.0
	if flash_age >= 0.0:
		flash_age += delta
		var pulse_age: float = flash_age - pre_glow_duration
		if pulse_age < 0.0:
			cloud_strength = 0.15 * flash_age / pre_glow_duration
		else:
			flash_strength = maxf(0.0, 1.0 - pulse_age / 0.22)
			cloud_strength = maxf(0.0, 1.0 - pulse_age / 0.42) * 0.65
			if double_flash and pulse_age >= 0.34:
				flash_strength = maxf(0.0, 1.0 - (pulse_age - 0.34) / 0.14) * 0.45
				cloud_strength = maxf(0.0, 1.0 - (pulse_age - 0.34) / 0.32) * 0.40
			if pulse_age >= 0.70:
				flash_age = -1.0
				flash_strength = 0.0
				cloud_strength = 0.0
	flash.modulate.a = flash_strength * lightning_intensity
	for index in range(bolts.size()):
		bolts[index].modulate.a = flash_strength if index == selected_bolt else 0.0
	cloud_back[2].modulate.a = cloud_strength if clouds_enabled else 0.0
	cloud_front[2].modulate.a = cloud_strength if clouds_enabled else 0.0
	if lights_enabled:
		glow.modulate.a += flash_strength * 0.10
