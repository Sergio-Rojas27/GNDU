extends Node

signal config_reloaded
signal config_error(message: String)

const CONFIG_PATH := "res://controls_config.json"
const AUTO_RELOAD_INTERVAL := 0.5
const ACTIONS := ["left", "right", "up", "down", "punch", "kick", "block", "pause"]

var data: Dictionary = {}
var last_error: String = ""
var _auto_reload_timer := 0.0
var _last_config_hash := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not reload():
		if data.is_empty():
			data = _default_config()
		push_warning("N2ControlsConfig: %s" % last_error)

func _process(delta: float) -> void:
	_auto_reload_timer += delta
	if _auto_reload_timer < AUTO_RELOAD_INTERVAL:
		return
	_auto_reload_timer = 0.0
	var current := _config_hash()
	if current.is_empty() or current == _last_config_hash:
		return
	reload()

func _config_hash() -> String:
	if not FileAccess.file_exists(CONFIG_PATH):
		return ""
	return FileAccess.get_md5(CONFIG_PATH)

func reload() -> bool:
	_last_config_hash = _config_hash()
	last_error = ""
	if not FileAccess.file_exists(CONFIG_PATH):
		_fail("No existe %s" % CONFIG_PATH)
		if data.is_empty():
			data = _default_config()
		return false

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		_fail("No se pudo abrir %s" % CONFIG_PATH)
		if data.is_empty():
			data = _default_config()
		return false

	var text := file.get_as_text()
	file.close()

	if text.strip_edges().is_empty():
		_fail("%s esta vacio" % CONFIG_PATH)
		if data.is_empty():
			data = _default_config()
		return false

	var parser := JSON.new()
	var err := parser.parse(text)
	if err != OK:
		_fail("JSON invalido en linea %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		if data.is_empty():
			data = _default_config()
		return false

	if not (parser.data is Dictionary):
		_fail("La raiz del JSON debe ser un objeto")
		if data.is_empty():
			data = _default_config()
		return false

	data = _validate(parser.data)
	config_reloaded.emit()
	return true

func _fail(message: String) -> void:
	last_error = message
	push_warning("N2ControlsConfig: " + message)
	config_error.emit(message)

func _validate(raw: Dictionary) -> Dictionary:
	var out := _default_config()
	out["version"] = int(raw.get("version", 1))
	out["buffer_size_frames"] = clampi(int(raw.get("buffer_size_frames", 30)), 15, 30)
	out["global_cooldown_frames"] = clampi(int(raw.get("global_cooldown_frames", 2)), 0, 30)

	var players = raw.get("players", {})
	if players is Dictionary:
		for pid in ["1", "2"]:
			if not players.has(pid):
				continue
			var p = players[pid]
			if not (p is Dictionary):
				continue
			var dev = p.get("device", {})
			if dev is Dictionary and dev.has("type"):
				var dtype := str(dev.get("type", "keyboard"))
				if dtype in ["keyboard", "joypad", "hybrid"]:
					out["players"][pid]["device"] = dev.duplicate(true)
			var bindings = p.get("bindings", {})
			if bindings is Dictionary:
				for action in ACTIONS:
					var sources = bindings.get(action, [])
					if sources is Array and not sources.is_empty():
						out["players"][pid]["bindings"][action] = sources.duplicate(true)

	var commands = raw.get("commands", [])
	if commands is Array:
		var valid_commands: Array = []
		for cmd in commands:
			if _valid_command(cmd):
				valid_commands.append(cmd.duplicate(true))
		if not valid_commands.is_empty():
			out["commands"] = valid_commands

	return out

func _valid_command(cmd: Variant) -> bool:
	if not (cmd is Dictionary):
		return false
	if not cmd.has("name") or not cmd.has("steps"):
		return false
	if not (cmd["steps"] is Array) or cmd["steps"].is_empty():
		return false
	for step in cmd["steps"]:
		if not (step is Dictionary):
			return false
		if not ACTIONS.has(str(step.get("action", ""))):
			return false
		if not ["press", "hold", "release"].has(str(step.get("mode", "press"))):
			return false
	return true

func get_player(player_id: int) -> Dictionary:
	var key := str(player_id)
	if data.has("players") and data["players"].has(key):
		return data["players"][key]
	return {"device": {"type": "keyboard"}, "bindings": {}}

func get_device(player_id: int) -> Dictionary:
	return get_player(player_id).get("device", {"type": "keyboard"})

func get_bindings(player_id: int, action: String) -> Array:
	var bindings: Dictionary = get_player(player_id).get("bindings", {})
	return bindings.get(action, [])

func get_commands() -> Array:
	return data.get("commands", [])

func get_buffer_size() -> int:
	return int(data.get("buffer_size_frames", 30))

func get_global_cooldown() -> int:
	return int(data.get("global_cooldown_frames", 2))

func get_action_names() -> Array:
	return ACTIONS.duplicate()

func describe_source(source: Dictionary) -> String:
	var stype := str(source.get("type", ""))
	match stype:
		"key":
			return str(source.get("code", "?"))
		"joy_button":
			return str(source.get("button", "?"))
		"joy_axis":
			var axis := str(source.get("axis", "?"))
			var direction := int(source.get("direction", 1))
			return "%s %s" % [axis, "<" if direction < 0 else ">"]
	return "?"

func get_binding_summary(player_id: int) -> String:
	var parts: Array = []
	for action in ACTIONS:
		var labels: Array = []
		for source in get_bindings(player_id, action):
			if source is Dictionary:
				labels.append(describe_source(source))
		parts.append("%s=%s" % [action, "/".join(labels)])
	return "  ".join(parts)

func _default_config() -> Dictionary:
	return {
		"version": 3,
		"buffer_size_frames": 30,
		"global_cooldown_frames": 2,
		"players": {
			"1": {
				"device": {"type": "hybrid", "joypad_index": 0},
				"bindings": {
					"left": [
						{"type": "key", "code": "A"},
						{"type": "joy_button", "button": "dpad_left"},
						{"type": "joy_axis", "axis": "left_x", "direction": -1, "deadzone": 0.35}
					],
					"right": [
						{"type": "key", "code": "D"},
						{"type": "joy_button", "button": "dpad_right"},
						{"type": "joy_axis", "axis": "left_x", "direction": 1, "deadzone": 0.35}
					],
					"up": [
						{"type": "key", "code": "W"},
						{"type": "key", "code": "Space"},
						{"type": "joy_button", "button": "dpad_up"},
						{"type": "joy_button", "button": "x"},
						{"type": "joy_button", "button": "y"},
						{"type": "joy_axis", "axis": "left_y", "direction": -1, "deadzone": 0.35}
					],
					"down": [
						{"type": "key", "code": "S"},
						{"type": "joy_button", "button": "dpad_down"},
						{"type": "joy_axis", "axis": "left_y", "direction": 1, "deadzone": 0.35}
					],
					"punch": [
						{"type": "key", "code": "F"},
						{"type": "joy_button", "button": "a"}
					],
					"kick": [
						{"type": "key", "code": "G"},
						{"type": "joy_button", "button": "b"}
					],
					"block": [
						{"type": "key", "code": "H"},
						{"type": "joy_button", "button": "right_shoulder"}
					],
					"pause": [
						{"type": "key", "code": "Escape"},
						{"type": "joy_button", "button": "start"}
					]
				}
			},
			"2": {
				"device": {"type": "joypad", "joypad_index": 1},
				"bindings": {
					"left": [
						{"type": "joy_button", "button": "dpad_left"},
						{"type": "joy_axis", "axis": "left_x", "direction": -1, "deadzone": 0.35}
					],
					"right": [
						{"type": "joy_button", "button": "dpad_right"},
						{"type": "joy_axis", "axis": "left_x", "direction": 1, "deadzone": 0.35}
					],
					"up": [
						{"type": "joy_button", "button": "dpad_up"},
						{"type": "joy_button", "button": "x"},
						{"type": "joy_button", "button": "y"},
						{"type": "joy_axis", "axis": "left_y", "direction": -1, "deadzone": 0.35}
					],
					"down": [
						{"type": "joy_button", "button": "dpad_down"},
						{"type": "joy_axis", "axis": "left_y", "direction": 1, "deadzone": 0.35}
					],
					"punch": [{"type": "joy_button", "button": "a"}],
					"kick": [{"type": "joy_button", "button": "b"}],
					"block": [{"type": "joy_button", "button": "right_shoulder"}],
					"pause": [{"type": "joy_button", "button": "start"}]
				}
			}
		},
		"commands": _default_commands()
	}

func _default_commands() -> Array:
	return [
		{
			"name": "SPECIAL_ATTACK_1",
			"priority": 100,
			"window_frames": 24,
			"final_window": 2,
			"cooldown": 10,
			"steps": [
				{"action": "down", "mode": "press", "max_gap": 10},
				{"action": "right", "mode": "press", "max_gap": 10},
				{"action": "punch", "mode": "press", "max_gap": 10}
			]
		},
		{
			"name": "SPECIAL_ATTACK_2",
			"priority": 100,
			"window_frames": 24,
			"final_window": 2,
			"cooldown": 10,
			"steps": [
				{"action": "down", "mode": "press", "max_gap": 10},
				{"action": "left", "mode": "press", "max_gap": 10},
				{"action": "punch", "mode": "press", "max_gap": 10}
			]
		},
		{
			"name": "DASH_RIGHT",
			"priority": 50,
			"window_frames": 18,
			"final_window": 2,
			"cooldown": 10,
			"steps": [
				{"action": "right", "mode": "press", "max_gap": 9},
				{"action": "right", "mode": "press", "max_gap": 9, "exclusive": true}
			]
		},
		{
			"name": "DASH_LEFT",
			"priority": 50,
			"window_frames": 18,
			"final_window": 2,
			"cooldown": 10,
			"steps": [
				{"action": "left", "mode": "press", "max_gap": 9},
				{"action": "left", "mode": "press", "max_gap": 9, "exclusive": true}
			]
		},
		{
			"name": "COMBO_AAA",
			"priority": 80,
			"window_frames": 30,
			"final_window": 2,
			"cooldown": 18,
			"steps": [
				{"action": "punch", "mode": "press", "max_gap": 12},
				{"action": "punch", "mode": "press", "max_gap": 12},
				{"action": "punch", "mode": "press", "max_gap": 12}
			]
		},
		{
			"name": "COMBO_BBB",
			"priority": 80,
			"window_frames": 30,
			"final_window": 2,
			"cooldown": 18,
			"steps": [
				{"action": "kick", "mode": "press", "max_gap": 12},
				{"action": "kick", "mode": "press", "max_gap": 12},
				{"action": "kick", "mode": "press", "max_gap": 12}
			]
		},
		{
			"name": "COMBO_ABA",
			"priority": 85,
			"window_frames": 30,
			"final_window": 2,
			"cooldown": 18,
			"steps": [
				{"action": "punch", "mode": "press", "max_gap": 12},
				{"action": "kick", "mode": "press", "max_gap": 12},
				{"action": "punch", "mode": "press", "max_gap": 12}
			]
		},
		{
			"name": "COMBO_AAB",
			"priority": 85,
			"window_frames": 30,
			"final_window": 2,
			"cooldown": 18,
			"steps": [
				{"action": "punch", "mode": "press", "max_gap": 12},
				{"action": "punch", "mode": "press", "max_gap": 12},
				{"action": "kick", "mode": "press", "max_gap": 12}
			]
		},
		{
			"name": "COMBO_RIGHT_DOWN_RIGHT_B",
			"priority": 95,
			"window_frames": 32,
			"final_window": 2,
			"cooldown": 12,
			"steps": [
				{"action": "right", "mode": "press", "max_gap": 10},
				{"action": "down", "mode": "press", "max_gap": 10},
				{"action": "right", "mode": "press", "max_gap": 10},
				{"action": "kick", "mode": "press", "max_gap": 10}
			]
		},
		{
			"name": "COMBO_DOWN_UP_A",
			"priority": 90,
			"window_frames": 24,
			"final_window": 2,
			"cooldown": 12,
			"steps": [
				{"action": "down", "mode": "press", "max_gap": 10},
				{"action": "up", "mode": "press", "max_gap": 10},
				{"action": "punch", "mode": "press", "max_gap": 10}
			]
		},
		{
			"name": "COMBO_DOWN_RIGHT_B",
			"priority": 90,
			"window_frames": 24,
			"final_window": 2,
			"cooldown": 12,
			"steps": [
				{"action": "down", "mode": "press", "max_gap": 10},
				{"action": "right", "mode": "press", "max_gap": 10},
				{"action": "kick", "mode": "press", "max_gap": 10}
			]
		},
		{
			"name": "COMBO_LEFT_RIGHT_A",
			"priority": 90,
			"window_frames": 24,
			"final_window": 2,
			"cooldown": 12,
			"steps": [
				{"action": "left", "mode": "press", "max_gap": 10},
				{"action": "right", "mode": "press", "max_gap": 10},
				{"action": "punch", "mode": "press", "max_gap": 10}
			]
		}
	]
