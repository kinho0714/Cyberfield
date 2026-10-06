extends RefCounted
## Family-specific depth response. Module-local limits remain small; the continuous
## background can travel freely because its textures/architecture are tiled.
const PROFILES = {
	"city": {"far_speed": 0.22, "mid_speed": 0.56, "far_limit": 26.0, "mid_limit": 10.0},
	"house": {"far_speed": 0.18, "mid_speed": 0.75, "far_limit": 12.0, "mid_limit": 4.0},
	"industrial": {"far_speed": 0.30, "mid_speed": 0.68, "far_limit": 18.0, "mid_limit": 7.0},
	"lab": {"far_speed": 0.38, "mid_speed": 0.78, "far_limit": 14.0, "mid_limit": 5.0},
}
