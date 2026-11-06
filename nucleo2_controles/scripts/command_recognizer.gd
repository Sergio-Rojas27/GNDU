class_name N2CommandRecognizer
extends RefCounted

var patterns: Array = []
var global_cooldown: int = 2
var _last_emit: Dictionary = {}
var _last_any_emit: int = -100000

# Frame de la ultima pulsacion usada por un comando. Las pulsaciones ya
# consumidas no se pueden reutilizar para otro comando (evita que un sufijo
# como "abajo, derecha, B" dispare despues de "derecha, abajo, derecha, B").
var _last_consumed_frame: int = -1
var _match_first_frame: int = -1
var _match_last_frame: int = -1

func _init(initial_patterns: Array = []) -> void:
	set_patterns(initial_patterns)

func set_patterns(new_patterns: Array) -> void:
	patterns = new_patterns.duplicate(true)
	patterns.sort_custom(_sort_by_priority)
	_last_emit.clear()
	_last_any_emit = -100000
	_last_consumed_frame = -1

func evaluate(buffer: N2InputBuffer, frame: int) -> Variant:
	if frame - _last_any_emit < global_cooldown:
		return null
	for pattern in patterns:
		if not (pattern is Dictionary):
			continue
		var command_name := str(pattern.get("name", ""))
		if command_name.is_empty():
			continue
		var cooldown := int(pattern.get("cooldown", 10))
		if frame - int(_last_emit.get(command_name, -100000)) < cooldown:
			continue
		if _matches(pattern, buffer):
			if _match_first_frame <= _last_consumed_frame:
				continue
			_last_emit[command_name] = frame
			_last_any_emit = frame
			_last_consumed_frame = _match_last_frame
			return command_name
	return null

func _sort_by_priority(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("priority", 0)) > int(b.get("priority", 0))

func _matches(pattern: Dictionary, buffer: N2InputBuffer) -> bool:
	_match_first_frame = -1
	_match_last_frame = -1
	var steps: Array = pattern.get("steps", [])
	if steps.is_empty():
		return false
	var window := int(pattern.get("window_frames", 24))
	var frames := buffer.get_last(window)
	if frames.size() < steps.size():
		return false
	var cursor := frames.size() - 1
	var final_window := int(pattern.get("final_window", 2))
	var positions: Array = []
	for i in range(steps.size() - 1, -1, -1):
		var step = steps[i]
		if not (step is Dictionary):
			return false
		var gap := int(step.get("max_gap", 10))
		if i == steps.size() - 1:
			gap = mini(gap, final_window)
		var min_idx := maxi(0, cursor - gap)
		var found := -1
		for j in range(cursor, min_idx - 1, -1):
			if _step_matches(step, frames[j]):
				found = j
				break
		if found == -1:
			return false
		positions.push_front({"index": found, "step": step})
		if i == steps.size() - 1:
			_match_last_frame = int(frames[found].get("frame", -1))
		_match_first_frame = int(frames[found].get("frame", -1))
		cursor = found - 1

	# Un paso "exclusive" no admite otras pulsaciones entre el paso anterior
	# y el suyo: asi un doble toque no se confunde con el inicio de un combo.
	for k in range(1, positions.size()):
		var step: Dictionary = positions[k]["step"]
		if not bool(step.get("exclusive", false)):
			continue
		var action := str(step.get("action", ""))
		var from_idx := int(positions[k - 1]["index"]) + 1
		var to_idx := int(positions[k]["index"]) - 1
		for j in range(from_idx, to_idx + 1):
			var pressed: Dictionary = frames[j].get("pressed", {})
			for other in pressed.keys():
				if bool(pressed[other]) and str(other) != action:
					return false
	return true

func _step_matches(step: Dictionary, snap: Dictionary) -> bool:
	var action := str(step.get("action", ""))
	var mode := str(step.get("mode", "press"))
	match mode:
		"press":
			var pressed: Dictionary = snap.get("pressed", {})
			return bool(pressed.get(action, false))
		"hold":
			var held: Dictionary = snap.get("held", {})
			return bool(held.get(action, false))
		"release":
			var released: Dictionary = snap.get("released", {})
			return bool(released.get(action, false))
	return false
