class_name TemporaryEnvironmentCycle
extends RefCounted

## Visual-only deterministic environment clock. The authoritative LAN snapshot
## already synchronizes RunManager.run_elapsed_time, so no extra network clock
## is required. Weather is intentionally a hook only in this pass.
const CYCLE_SECONDS := 300.0
const WEATHER_CLEAR: StringName = &"clear"
const SUPPORTED_WEATHER_STATES: Array[StringName] = [
	&"clear", &"cloudy", &"rain", &"fog", &"wind", &"storm",
]

const KEYFRAMES := [
	{
		"at": 0.00,
		"phase": &"dawn",
		"sky_top": Color("182a42"),
		"sky_horizon": Color("b56f67"),
		"far_tint": Color("71839a"),
		"mid_tint": Color("6c7682"),
		"world_tint": Color("6d7785"),
		"world_strength": 0.10,
	},
	{
		"at": 0.16,
		"phase": &"day",
		"sky_top": Color("31566d"),
		"sky_horizon": Color("8ba2a7"),
		"far_tint": Color("81929e"),
		"mid_tint": Color("77848b"),
		"world_tint": Color("7d878b"),
		"world_strength": 0.06,
	},
	{
		"at": 0.50,
		"phase": &"sunset",
		"sky_top": Color("2a354d"),
		"sky_horizon": Color("bd6f55"),
		"far_tint": Color("766f79"),
		"mid_tint": Color("75656a"),
		"world_tint": Color("805f62"),
		"world_strength": 0.10,
	},
	{
		"at": 0.66,
		"phase": &"night",
		"sky_top": Color("07111f"),
		"sky_horizon": Color("17283b"),
		"far_tint": Color("3f5266"),
		"mid_tint": Color("42515d"),
		"world_tint": Color("30445a"),
		"world_strength": 0.16,
	},
	{
		"at": 0.88,
		"phase": &"late_night",
		"sky_top": Color("050b16"),
		"sky_horizon": Color("102034"),
		"far_tint": Color("34495d"),
		"mid_tint": Color("394a58"),
		"world_tint": Color("263a52"),
		"world_strength": 0.18,
	},
	{
		"at": 1.00,
		"phase": &"dawn",
		"sky_top": Color("182a42"),
		"sky_horizon": Color("b56f67"),
		"far_tint": Color("71839a"),
		"mid_tint": Color("6c7682"),
		"world_tint": Color("6d7785"),
		"world_strength": 0.10,
	},
]


static func snapshot(elapsed_seconds: float, stage_index: int = 0, weather: StringName = WEATHER_CLEAR) -> Dictionary:
	var offset := float(maxi(stage_index, 0)) * 18.0
	var normalized := fposmod(maxf(elapsed_seconds, 0.0) + offset, CYCLE_SECONDS) / CYCLE_SECONDS
	var first: Dictionary = KEYFRAMES[0]
	var second: Dictionary = KEYFRAMES[1]
	for index in KEYFRAMES.size() - 1:
		var left: Dictionary = KEYFRAMES[index]
		var right: Dictionary = KEYFRAMES[index + 1]
		if normalized >= float(left.at) and normalized <= float(right.at):
			first = left
			second = right
			break
	var span := maxf(float(second.at) - float(first.at), 0.0001)
	var blend := clampf((normalized - float(first.at)) / span, 0.0, 1.0)
	return {
		"normalized_time": normalized,
		"phase": StringName(first.phase),
		"next_phase": StringName(second.phase),
		"phase_blend": blend,
		"sky_top": (first.sky_top as Color).lerp(second.sky_top as Color, blend),
		"sky_horizon": (first.sky_horizon as Color).lerp(second.sky_horizon as Color, blend),
		"far_tint": (first.far_tint as Color).lerp(second.far_tint as Color, blend),
		"mid_tint": (first.mid_tint as Color).lerp(second.mid_tint as Color, blend),
		"world_tint": (first.world_tint as Color).lerp(second.world_tint as Color, blend),
		"world_strength": lerpf(float(first.world_strength), float(second.world_strength), blend),
		"weather": weather if SUPPORTED_WEATHER_STATES.has(weather) else WEATHER_CLEAR,
	}

