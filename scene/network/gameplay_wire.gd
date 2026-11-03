class_name GameplayWire
extends RefCounted
## JSON primitives only. Never deserialize objects, scripts, resources or callables.
static func encode(value: Variant) -> Variant:
	if value is PackedVector2Array:
		var points: Array = []
		for point: Vector2 in value:
			points.append([point.x, point.y])
		return {"_pv2": points}
	if value is Vector2:
		return {"_v2": [value.x, value.y]}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[String(key)] = encode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(encode(item))
		return result
	if value is StringName:
		return String(value)
	return value if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING] else null

static func decode(value: Variant, depth := 0) -> Variant:
	if depth > 24:
		return null
	if value is Dictionary:
		if value.size() == 1 and value.get("_pv2") is Array:
			var points := PackedVector2Array()
			if value._pv2.size() > 1024:
				return points
			for point: Variant in value._pv2:
				if point is not Array or point.size() != 2 or typeof(point[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(point[1]) not in [TYPE_INT, TYPE_FLOAT]:
					return PackedVector2Array()
				points.append(Vector2(float(point[0]), float(point[1])))
			return points
		if value.size() == 1 and value.get("_v2") is Array and value._v2.size() == 2:
			if typeof(value._v2[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(value._v2[1]) in [TYPE_INT, TYPE_FLOAT]:
				return Vector2(float(value._v2[0]), float(value._v2[1]))
			return null
		var result: Dictionary = {}
		for key: Variant in value:
			result[String(key)] = decode(value[key], depth + 1)
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(decode(item, depth + 1))
		return result
	return value
