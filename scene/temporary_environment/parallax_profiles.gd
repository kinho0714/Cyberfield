extends RefCounted
## TEMPORARY assets live in painter/layout data, not in this camera-response contract.
const PROFILES = {
	"city": {"far_speed": 0.25, "mid_speed": 0.65, "far_limit": 24.0, "mid_limit": 8.0},
	"house": {"far_speed": 0.18, "mid_speed": 0.75, "far_limit": 12.0, "mid_limit": 4.0},
	"industrial": {"far_speed": 0.35, "mid_speed": 0.75, "far_limit": 16.0, "mid_limit": 6.0},
	"lab": {"far_speed": 0.35, "mid_speed": 0.75, "far_limit": 16.0, "mid_limit": 6.0},
}
