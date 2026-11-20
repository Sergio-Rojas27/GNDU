extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	print("== Pruebas Nucleo 2 ==")
	_test_config_json()
	_test_buffer()
	_test_double_tap()
	_test_specials()
	_test_tolerances()
	_test_combos()
	_test_no_reuse()
	_test_snapshot_actions()
	_test_project_root()
	_test_special_moves_match_n3()
	_test_contract()
	_test_contract_artifacts()
	_test_viewer_artifacts()
	_test_report_sign()

	if _failures == 0:
		print("OK: todas las pruebas pasaron")
		quit(0)
	else:
		print("FALLARON %d pruebas" % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		_failures += 1
		print("  FAIL " + message)

func _snap(frame: int, held: Dictionary = {}, pressed: Dictionary = {}) -> Dictionary:
	return {
		"frame": frame,
		"held": held.duplicate(true),
		"pressed": pressed.duplicate(true),
		"released": {}
	}

func _patterns() -> Array:
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
				{"action": "right", "mode": "press", "max_gap": 9}
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
				{"action": "left", "mode": "press", "max_gap": 9}
			]
		}
	]

func _test_config_json() -> void:
	var file := FileAccess.open("res://controls_config.json", FileAccess.READ)
	_check(file != null, "controls_config.json existe")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	_check(parser.parse(text) == OK, "controls_config.json es JSON valido")
	_check(parser.data is Dictionary, "la raiz de la config es un objeto")
	if parser.data is Dictionary:
		_check(parser.data.has("players"), "la config tiene players")
		_check(parser.data.has("commands"), "la config tiene commands")
		_check(int(parser.data.get("version", 0)) == 3, "la config usa version 3")
		var buffer_size := int(parser.data.get("buffer_size_frames", 0))
		_check(buffer_size >= 15 and buffer_size <= 30, "el buffer configurado esta entre 15 y 30")

	var Config = load("res://scripts/controls_config.gd")
	var config = Config.new()
	var low_buffer: Dictionary = config._validate({"buffer_size_frames": 5})
	var high_buffer: Dictionary = config._validate({"buffer_size_frames": 100})
	_check(int(low_buffer["buffer_size_frames"]) == 15, "el buffer se limita a 15 frames")
	_check(int(high_buffer["buffer_size_frames"]) == 30, "el buffer se limita a 30 frames")
	config.free()

func _test_buffer() -> void:
	var buffer = N2InputBuffer.new(5)
	for i in range(7):
		buffer.push(_snap(i))
	var last: Array = buffer.get_last(3)
	_check(buffer.size() == 5, "el buffer respeta la capacidad")
	_check(last.size() == 3, "get_last devuelve la cantidad pedida")
	_check(int(last[0]["frame"]) == 4 and int(last[2]["frame"]) == 6, "get_last mantiene el orden viejo -> nuevo")

	var short_buffer = N2InputBuffer.new(30)
	short_buffer.push(_snap(42))
	var one: Array = short_buffer.get_last(10)
	_check(one.size() == 1 and int(one[0]["frame"]) == 42, "get_last funciona con pocos frames")

func _test_double_tap() -> void:
	var buffer = N2InputBuffer.new(30)
	for f in range(0, 6):
		var pressed := {}
		if f == 2 or f == 5:
			pressed["right"] = true
		buffer.push(_snap(f, {}, pressed))
	var recognizer = N2CommandRecognizer.new(_patterns())
	var result = recognizer.evaluate(buffer, 5)
	_check(result is String and result == "DASH_RIGHT", "detecta doble toque derecho")

	buffer.push(_snap(6))
	_check(recognizer.evaluate(buffer, 6) == null, "el cooldown evita repetir el comando")

	var slow = N2InputBuffer.new(30)
	for f in range(0, 21):
		var pressed := {}
		if f == 2 or f == 20:
			pressed["right"] = true
		slow.push(_snap(f, {}, pressed))
	var slow_recognizer = N2CommandRecognizer.new(_patterns())
	_check(slow_recognizer.evaluate(slow, 20) == null, "el doble toque lento no se detecta")

	var left = N2InputBuffer.new(30)
	for f in range(0, 6):
		var pressed := {}
		if f == 2 or f == 5:
			pressed["left"] = true
		left.push(_snap(f, {}, pressed))
	var left_recognizer = N2CommandRecognizer.new(_patterns())
	var left_result = left_recognizer.evaluate(left, 5)
	_check(left_result is String and left_result == "DASH_LEFT", "detecta doble toque izquierdo")

func _test_specials() -> void:
	var patterns := _config_patterns()
	_check(_detect(["left", "right", "punch"], patterns) == "HADOKEN", "detecta HADOKEN (izquierda-derecha-A)")
	_check(_detect(["right", "down", "right", "punch"], patterns) == "SHORYUKEN", "detecta SHORYUKEN (derecha-abajo-derecha-A)")
	_check(_detect(["down", "up", "punch"], patterns) == "ABAJO_ARRIBA", "detecta ABAJO_ARRIBA (abajo-arriba-A)")
	_check(_detect(["down", "right", "kick"], patterns) == "DOBLE_PATADA", "detecta DOBLE_PATADA (abajo-derecha-B)")
	_check(_detect(["right", "down", "right", "kick"], patterns) == "EMBESTIDA", "detecta EMBESTIDA (derecha-abajo-derecha-B)")
	_check(_detect(["left", "right", "kick"], patterns) == "TATSUMAKI", "detecta TATSUMAKI (izquierda-derecha-B)")

	var names: Array = []
	for pattern in patterns:
		if pattern is Dictionary:
			names.append(str(pattern.get("name", "")))
	for canonical in ["HADOKEN", "SHORYUKEN", "ABAJO_ARRIBA", "DOBLE_PATADA", "EMBESTIDA", "TATSUMAKI"]:
		_check(canonical in names, "la config incluye el comando canonico %s" % canonical)

func _test_tolerances() -> void:
	var wrong = N2InputBuffer.new(30)
	for f in range(0, 11):
		var pressed := {}
		if f == 2:
			pressed["punch"] = true
		if f == 6:
			pressed["right"] = true
		if f == 10:
			pressed["left"] = true
		wrong.push(_snap(f, {}, pressed))
	var recognizer = N2CommandRecognizer.new(_config_patterns())
	_check(recognizer.evaluate(wrong, 10) == null, "el orden incorrecto no dispara el especial")

	var slow = N2InputBuffer.new(60)
	for f in range(0, 61):
		var pressed := {}
		if f == 0:
			pressed["left"] = true
		if f == 30:
			pressed["right"] = true
		if f == 60:
			pressed["punch"] = true
		slow.push(_snap(f, {}, pressed))
	var slow_recognizer = N2CommandRecognizer.new(_config_patterns())
	_check(slow_recognizer.evaluate(slow, 60) == null, "el especial fuera de ventana no se detecta")

func _config_patterns() -> Array:
	var file := FileAccess.open("res://controls_config.json", FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or not (parser.data is Dictionary):
		return []
	return parser.data.get("commands", [])

func _detect(actions: Array, patterns: Array) -> Variant:
	var buffer = N2InputBuffer.new(40)
	var f := 0
	for action in actions:
		buffer.push(_snap(f, {}, {action: true}))
		buffer.push(_snap(f + 1))
		f += 4
	var recognizer = N2CommandRecognizer.new(patterns)
	return recognizer.evaluate(buffer, f - 3)

func _test_combos() -> void:
	var patterns := _config_patterns()
	_check(patterns.size() == 12, "la config tiene 12 comandos")

	_check(_detect(["punch", "punch", "punch"], patterns) == "COMBO_AAA", "detecta AAA")
	_check(_detect(["kick", "kick", "kick"], patterns) == "COMBO_BBB", "detecta BBB")
	_check(_detect(["punch", "kick", "punch"], patterns) == "COMBO_ABA", "detecta ABA")
	_check(_detect(["punch", "punch", "kick"], patterns) == "COMBO_AAB", "detecta AAB")
	_check(_detect(["right", "down", "right", "kick"], patterns) == "EMBESTIDA", "detecta EMBESTIDA sin ambiguedad")
	_check(_detect(["down", "up", "punch"], patterns) == "ABAJO_ARRIBA", "detecta ABAJO_ARRIBA")
	_check(_detect(["down", "right", "kick"], patterns) == "DOBLE_PATADA", "detecta DOBLE_PATADA")
	_check(_detect(["left", "right", "punch"], patterns) == "HADOKEN", "detecta HADOKEN")
	_check(_detect(["left", "right", "kick"], patterns) == "TATSUMAKI", "detecta TATSUMAKI")
	_check(_detect(["right", "down", "right", "punch"], patterns) == "SHORYUKEN", "detecta SHORYUKEN")

	_check(OS.find_keycode_from_string("Space") == KEY_SPACE, "la tecla Space existe")
	_check(OS.find_keycode_from_string("Slash") == KEY_SLASH, "la tecla Slash existe")
	_check(OS.find_keycode_from_string("Left") == KEY_LEFT, "la tecla Left existe")
	_check(OS.find_keycode_from_string("Shift") == KEY_SHIFT, "la tecla Shift existe")
	_check(OS.find_keycode_from_string("Enter") == KEY_ENTER, "la tecla Enter existe")
	_check(OS.find_keycode_from_string("Ctrl") == KEY_CTRL, "la tecla Ctrl existe")
	_check(OS.find_keycode_from_string("Alt") == KEY_ALT, "la tecla Alt existe")
	_check(OS.find_keycode_from_string("Backspace") == KEY_BACKSPACE, "la tecla Backspace existe")

	var file := FileAccess.open("res://controls_config.json", FileAccess.READ)
	if file == null:
		_check(false, "controls_config.json legible para salto y agarre")
		return
	var parser := JSON.new()
	parser.parse(file.get_as_text())
	file.close()
	var players: Dictionary = parser.data.get("players", {})

	var expected_keys := {
		"1": {
			"left": "A", "right": "D", "up": "W", "down": "S",
			"jump": "Space", "punch": "H", "kick": "J", "block": "K",
			"grab": "L", "pause": "Escape"
		},
		"2": {
			"left": "Left", "right": "Right", "up": "Up", "down": "Down",
			"jump": "Slash", "punch": "Shift", "kick": "Enter", "block": "Ctrl",
			"grab": "Alt", "pause": "Backspace"
		}
	}
	for pid in ["1", "2"]:
		var bindings: Dictionary = players.get(pid, {}).get("bindings", {})
		for action in ["left", "right", "up", "down", "jump", "punch", "kick", "block", "grab", "pause"]:
			_check(bindings.has(action), "J%s tiene la accion %s" % [pid, action])
		var up: Array = bindings.get("up", [])
		_check(not _binding_has_key(up, "Space"), "J%s: up ya no incluye Space" % pid)
		_check(not _binding_has_button(up, "x") and not _binding_has_button(up, "y"), "J%s: up ya no incluye X/Y" % pid)
		var jump: Array = bindings.get("jump", [])
		_check(_binding_has_button(jump, "x") and _binding_has_button(jump, "y"), "J%s salta con X y Y" % pid)
		var grab: Array = bindings.get("grab", [])
		_check(_binding_has_button(grab, "left_shoulder"), "J%s agarra con LB/L1" % pid)
		for action in expected_keys[pid].keys():
			var code: String = expected_keys[pid][action]
			_check(_binding_has_key(bindings.get(action, []), code), "J%s usa %s para %s" % [pid, code, action])

func _binding_has_key(sources: Array, code: String) -> bool:
	for src in sources:
		if src is Dictionary and str(src.get("type", "")) == "key" and str(src.get("code", "")) == code:
			return true
	return false

func _binding_has_button(sources: Array, button: String) -> bool:
	for src in sources:
		if src is Dictionary and str(src.get("type", "")) == "joy_button" and str(src.get("button", "")) == button:
			return true
	return false

func _combo_events(script: Dictionary, frames: int) -> Array:
	var buffer = N2InputBuffer.new(40)
	var recognizer = N2CommandRecognizer.new(_config_patterns())
	var out: Array = []
	for f in range(frames):
		var pressed := {}
		if script.has(f):
			pressed[str(script[f])] = true
		buffer.push(_snap(f, {}, pressed))
		var result = recognizer.evaluate(buffer, f)
		if result != null:
			out.append(str(result))
	return out

func _test_no_reuse() -> void:
	var stale = _combo_events({0: "punch", 4: "punch", 8: "punch", 20: "kick"}, 26)
	_check(stale == ["COMBO_AAA"], "un kick posterior no reutiliza los punos del AAA")

	var suffix = _combo_events({0: "right", 4: "down", 8: "right", 12: "kick"}, 18)
	_check(suffix == ["EMBESTIDA"], "EMBESTIDA no dispara tambien DOBLE_PATADA")

	var chained = _combo_events({
		0: "punch", 4: "punch", 8: "punch",
		14: "punch", 18: "punch", 22: "kick"
	}, 28)
	_check(chained == ["COMBO_AAA", "COMBO_AAB"], "AAA y AAB se encadenan con pulsaciones nuevas")

func _test_contract() -> void:
	var MockConsumer = load("res://scripts/mock_consumer.gd")
	if MockConsumer == null:
		_check(false, "se puede cargar el validador del contrato")
		return
	var report := {
		"player_id": 1,
		"frame": 10,
		"state": {
			"move_x": 1,
			"move_y": -1,
			"punch": false,
			"kick": true,
			"block": false,
			"pause": false
		},
		"command_detected": "HADOKEN"
	}
	var ok_validator = MockConsumer.new()
	_check(ok_validator._validate(report) == "", "un reporte v3 valido pasa el contrato")
	ok_validator.free()

	var extra_state := report.duplicate(true)
	extra_state["state"]["jump"] = false
	var state_validator = MockConsumer.new()
	_check(state_validator._validate(extra_state) != "", "el validador rechaza state.jump extra")
	state_validator.free()

	var extra_top := report.duplicate(true)
	extra_top["extra"] = 1
	var top_validator = MockConsumer.new()
	_check(top_validator._validate(extra_top) != "", "el validador rechaza claves de primer nivel extra")
	top_validator.free()

	var empty_command := report.duplicate(true)
	empty_command["command_detected"] = ""
	var command_validator = MockConsumer.new()
	_check(command_validator._validate(empty_command) != "", "el validador rechaza command_detected vacio")
	command_validator.free()

	var bad_y := report.duplicate(true)
	bad_y["state"]["move_y"] = 2
	var y_validator = MockConsumer.new()
	_check(y_validator._validate(bad_y) != "", "el validador rechaza move_y fuera de [-1, 0, 1]")
	y_validator.free()

func _load_json_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

func _normalize_report(value: Variant) -> Dictionary:
	var out: Dictionary = value.duplicate(true)
	out["player_id"] = int(out.get("player_id", 0))
	out["frame"] = int(out.get("frame", 0))
	var state: Dictionary = out.get("state", {})
	state["move_x"] = int(state.get("move_x", 0))
	state["move_y"] = int(state.get("move_y", 0))
	out["state"] = state
	return out

func _test_contract_artifacts() -> void:
	var schema = _load_json_file("res://contracts/input_report.schema.json")
	_check(schema is Dictionary, "el esquema JSON existe y es un objeto")
	if schema is Dictionary:
		_check(schema.has("$schema"), "el esquema declara $schema")
		_check(schema.get("additionalProperties", true) == false, "el esquema no admite claves extra")
		var required: Array = schema.get("required", [])
		for key in ["player_id", "frame", "state", "command_detected"]:
			_check(key in required, "el esquema exige %s" % key)
		var state_schema: Dictionary = schema.get("properties", {}).get("state", {})
		var state_required: Array = state_schema.get("required", [])
		_check(state_required.size() == 6, "el esquema exige las 6 claves de state")
		_check(not state_schema.get("properties", {}).has("jump"), "el esquema no admite state.jump")
		var move_y_enum: Array = state_schema.get("properties", {}).get("move_y", {}).get("enum", [])
		_check(move_y_enum.has(1.0) and move_y_enum.has(-1.0), "el esquema admite move_y -1 y +1")

	var example = _load_json_file("res://contracts/input_report.example.json")
	_check(example is Dictionary, "el ejemplo JSON es un objeto")
	var MockConsumer = load("res://scripts/mock_consumer.gd")
	if MockConsumer == null:
		_check(false, "se puede cargar el validador para los ejemplos")
		return
	var validator = MockConsumer.new()
	if example is Dictionary:
		_check(validator._validate(_normalize_report(example)) == "", "el ejemplo JSON pasa el contrato")
	validator.free()

	var lines: Array = []
	var file := FileAccess.open("res://contracts/input_report.example.jsonl", FileAccess.READ)
	_check(file != null, "el ejemplo JSONL existe")
	if file != null:
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if not line.is_empty():
				lines.append(line)
		file.close()
	_check(lines.size() >= 4, "el ejemplo JSONL tiene varios reportes")
	var jsonl_validator = MockConsumer.new()
	var sees_p1 := false
	var sees_p2 := false
	var sees_command := false
	var last_frames := {1: -1, 2: -1}
	for line in lines:
		var report = JSON.parse_string(line)
		var valid := false
		if report is Dictionary:
			report = _normalize_report(report)
			valid = jsonl_validator._validate(report) == ""
		_check(valid, "cada linea JSONL pasa el contrato")
		if not (report is Dictionary):
			continue
		var pid := int(report.get("player_id", 0))
		var frame := int(report.get("frame", -1))
		if pid == 1:
			sees_p1 = true
		if pid == 2:
			sees_p2 = true
		if report.get("command_detected", null) is String:
			sees_command = true
		if last_frames.has(pid):
			_check(frame > int(last_frames[pid]), "los frames de J%d crecen en el JSONL" % pid)
			last_frames[pid] = frame
	jsonl_validator.free()
	_check(sees_p1 and sees_p2, "el ejemplo JSONL incluye a J1 y J2")
	_check(sees_command, "el ejemplo JSONL incluye al menos un comando")

func _test_viewer_artifacts() -> void:
	var Viewer = load("res://scripts/report_viewer.gd")
	_check(Viewer != null, "se puede cargar el script del visor")
	_check(ResourceLoader.exists("res://scenes/report_viewer.tscn"), "la escena del visor existe")
	_check(ResourceLoader.exists("res://scenes/diagnostic.tscn"), "la escena de diagnostico sigue existiendo")
	if Viewer == null:
		return
	var viewer = Viewer.new()
	viewer._load_example()
	_check(viewer._reports.size() == 6, "el visor carga el ejemplo JSONL")
	_check(typeof(viewer._reports[0]["frame"]) == TYPE_INT, "el visor normaliza los enteros del ejemplo")
	viewer._filter_player = 1
	_check(viewer._matching_reports().size() == 3, "el visor filtra Solo J1")
	viewer._filter_player = 0
	viewer._only_commands = true
	_check(viewer._matching_reports().size() == 2, "el visor filtra Solo comandos")
	viewer.free()

func _test_report_sign() -> void:
	var Core = load("res://scripts/input_core.gd")
	if Core == null:
		_check(false, "se puede cargar input_core.gd")
		return
	var core = Core.new()
	var up_report: Dictionary = core._build_report(1, 1, {"up": true, "down": false}, null)
	_check(int(up_report["state"]["move_y"]) == 1, "move_y = +1 al pulsar arriba (direccion)")
	var down_report: Dictionary = core._build_report(1, 1, {"up": false, "down": true}, null)
	_check(int(down_report["state"]["move_y"]) == -1, "move_y = -1 al pulsar abajo (agachado)")
	_check(not up_report["state"].has("jump"), "el reporte no incluye state.jump")
	_check(up_report["state"].size() == 6, "state tiene exactamente las 6 claves del PDF")

	var up_no_jump: Dictionary = core._build_report(1, 1, {"up": true, "jump": true}, null)
	_check(int(up_no_jump["state"]["move_y"]) == 1, "mantener arriba no altera el salto")
	_check(not up_no_jump["state"].has("grab"), "el reporte no incluye state.grab")
	core.free()

func _test_snapshot_actions() -> void:
	var Core = load("res://scripts/input_core.gd")
	var Config = load("res://scripts/controls_config.gd")
	if Core == null or Config == null:
		_check(false, "se pueden cargar los scripts de N2")
		return
	var core = Core.new()
	var config = Config.new()
	for action in ["jump", "grab"]:
		_check(action in core.ACTIONS, "input_core conoce la accion %s" % action)
		_check(action in config.ACTIONS, "controls_config conoce la accion %s" % action)
	for action in ["left", "right", "up", "down", "punch", "kick", "block", "pause"]:
		_check(action in core.ACTIONS, "input_core conserva la accion %s" % action)

	# Captura de pulsaciones entre ticks: las teclas se asocian a la accion y
	# al jugador correctos.
	var cfg = root.get_node_or_null("N2ControlsConfig")
	if cfg and cfg.data.is_empty():
		cfg.data = cfg._default_config()
	var ev_h := InputEventKey.new()
	ev_h.physical_keycode = KEY_H
	ev_h.pressed = true
	core._latch_press_from_event(ev_h)
	_check(bool(core._pending_presses[1].get("punch", false)), "H captura punch para J1")
	core._pending_presses[1] = {}

	var ev_space := InputEventKey.new()
	ev_space.physical_keycode = KEY_SPACE
	ev_space.pressed = true
	core._latch_press_from_event(ev_space)
	_check(bool(core._pending_presses[1].get("jump", false)), "Espacio captura jump para J1")
	_check(not bool(core._pending_presses[1].get("up", false)), "Espacio ya no captura up")
	core._pending_presses[1] = {}

	var ev_l := InputEventKey.new()
	ev_l.physical_keycode = KEY_L
	ev_l.pressed = true
	core._latch_press_from_event(ev_l)
	_check(bool(core._pending_presses[1].get("grab", false)), "L captura grab para J1")
	core._pending_presses[1] = {}

	var ev_slash := InputEventKey.new()
	ev_slash.physical_keycode = KEY_SLASH
	ev_slash.pressed = true
	core._latch_press_from_event(ev_slash)
	_check(bool(core._pending_presses[2].get("jump", false)), "/ captura jump para J2")
	_check(not bool(core._pending_presses[1].get("jump", false)), "/ no captura jump para J1")
	core._pending_presses = {1: {}, 2: {}}
	core.free()
	config.free()

func _test_project_root() -> void:
	var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(main in ["res://scenes/escenario.tscn", "res://nucleo4_interfaz/scenes/Menu_Principal.tscn"], "la escena principal es valida (%s)" % main)
	for path in [
		"res://scenes/escenario.tscn", "res://scenes/jugador.tscn",
		"res://scenes/proyectil_hadoken.tscn", "res://scenes/diagnostic.tscn",
		"res://scenes/report_viewer.tscn", "res://scripts/jugador.gd",
		"res://controls_config.json", "res://icon.svg",
		"res://nucleo4_interfaz/scenes/Menu_Principal.tscn",
		"res://nucleo4_interfaz/scenes/pantalla_combate.tscn"
	]:
		_check(ResourceLoader.exists(path) or FileAccess.file_exists(path), "existe %s" % path)
	_check(ProjectSettings.has_setting("autoload/N2InputCore"), "N2InputCore esta como autoload")
	_check(ProjectSettings.has_setting("autoload/N2ControlsConfig"), "N2ControlsConfig esta como autoload")
	_check(ProjectSettings.has_setting("autoload/EventBus"), "EventBus esta como autoload")
	_check(ProjectSettings.has_setting("autoload/DatosGlobales"), "DatosGlobales esta como autoload")
	for action in ["p1_salto", "p1_agarre", "p2_salto", "p2_agarre", "p1_puno", "p2_patada"]:
		_check(InputMap.has_action(action), "el InputMap raiz define %s" % action)

func _test_special_moves_match_n3() -> void:
	var file := FileAccess.open("res://scripts/jugador.gd", FileAccess.READ)
	_check(file != null, "se puede leer jugador.gd")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	for cmd in ["HADOKEN", "SHORYUKEN", "ABAJO_ARRIBA", "DOBLE_PATADA", "EMBESTIDA", "TATSUMAKI"]:
		_check(text.contains('"%s"' % cmd), "N3 reconoce el comando canonico %s" % cmd)
	_check(text.contains('flancos.get("jump"'), "N3 lee el salto del snapshot de N2")
	_check(text.contains('flancos.get("grab"'), "N3 lee el agarre del snapshot de N2")
	_check(not text.contains("_usar_reporte_externo_n2"), "N3 ya no mezcla la entrada de N2 con el InputMap local")
	_check(text.contains("func _buffer_activo"), "N3 conserva un buffer de intencion explicito")
	_check(not text.contains("input_nucleo2[accion] = true"), "el buffer no reescribe los flancos de entrada")
