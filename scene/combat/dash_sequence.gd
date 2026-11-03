class_name DashSequence
extends RefCounted
## Simulation seconds after the end (including interruption) of the last dash.
var capacity := 3
var minimum_interval := 0.15
var recovery_delay := 0.75
var used := 0
var active := false
var idle_seconds := 0.0


func available() -> int:
	return maxi(capacity - used, 0)


func try_start() -> bool:
	if active or available() <= 0 or (used > 0 and idle_seconds + 0.000001 < minimum_interval):
		return false
	used += 1
	active = true
	idle_seconds = 0.0
	return true


func finish() -> void:
	if active:
		active = false
		idle_seconds = 0.0


func advance(delta: float) -> void:
	if active or used == 0:
		return
	idle_seconds += maxf(delta, 0.0)
	if idle_seconds + 0.000001 >= maxf(recovery_delay, minimum_interval):
		used = 0
		idle_seconds = 0.0


func reset() -> void:
	used = 0
	active = false
	idle_seconds = 0.0
