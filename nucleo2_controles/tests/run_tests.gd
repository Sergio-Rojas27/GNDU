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
	_test_contract()
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
	var right = N2InputBuffer.new(30)
	for f in range(0, 11):
		var pressed := {}
		if f == 2:
			pressed["down"] = true
		if f == 6:
			pressed["right"] = true
		if f == 10:
			pressed["punch"] = true
		right.push(_snap(f, {}, pressed))
	var recognizer = N2CommandRecognizer.new(_patterns())
	var result = recognizer.evaluate(right, 10)
	_check(result is String and result == "SPECIAL_ATTACK_1", "detecta especial derecha")

	var left = N2InputBuffer.new(30)
	for f in range(0, 11):
		var pressed := {}
		if f == 2:
			pressed["down"] = true
		if f == 6:
			pressed["left"] = true
		if f == 10:
			pressed["punch"] = true
		left.push(_snap(f, {}, pressed))
	var left_recognizer = N2CommandRecognizer.new(_patterns())
	var left_result = left_recognizer.evaluate(left, 10)
	_check(left_result is String and left_result == "SPECIAL_ATTACK_2", "detecta especial izquierda")

func _test_tolerances() -> void:
	var wrong = N2InputBuffer.new(30)
	for f in range(0, 11):
		var pressed := {}
		if f == 2:
			pressed["down"] = true
		if f == 6:
			pressed["punch"] = true
		if f == 10:
			pressed["right"] = true
		wrong.push(_snap(f, {}, pressed))
	var recognizer = N2CommandRecognizer.new(_patterns())
	_check(recognizer.evaluate(wrong, 10) == null, "el orden incorrecto no dispara el especial")

	var slow = N2InputBuffer.new(30)
	for f in range(0, 41):
		var pressed := {}
		if f == 0:
			pressed["down"] = true
		if f == 20:
			pressed["right"] = true
		if f == 40:
			pressed["punch"] = true
		slow.push(_snap(f, {}, pressed))
	var slow_recognizer = N2CommandRecognizer.new(_patterns())
	_check(slow_recognizer.evaluate(slow, 40) == null, "el especial fuera de ventana no se detecta")

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
	_check(_detect(["right", "down", "right", "kick"], patterns) == "COMBO_RIGHT_DOWN_RIGHT_B", "detecta derecha-abajo-derecha-B")
	_check(_detect(["down", "up", "punch"], patterns) == "COMBO_DOWN_UP_A", "detecta abajo-arriba-A")
	_check(_detect(["down", "right", "kick"], patterns) == "COMBO_DOWN_RIGHT_B", "detecta abajo-derecha-B")
	_check(_detect(["left", "right", "punch"], patterns) == "COMBO_LEFT_RIGHT_A", "detecta izquierda-derecha-A")
	_check(_detect(["down", "right", "punch"], patterns) == "SPECIAL_ATTACK_1", "abajo-derecha-A es SPECIAL_ATTACK_1")

	_check(OS.find_keycode_from_string("Space") == KEY_SPACE, "la tecla Space existe")

	var file := FileAccess.open("res://controls_config.json", FileAccess.READ)
	if file == null:
		_check(false, "controls_config.json legible para salto")
		return
	var parser := JSON.new()
	parser.parse(file.get_as_text())
	file.close()
	var players: Dictionary = parser.data.get("players", {})
	var expected_up := {
		"1": ["Space", "x", "y"],
		"2": ["x", "y"]
	}
	for pid in ["1", "2"]:
		var bindings: Dictionary = players.get(pid, {}).get("bindings", {})
		var up: Array = bindings.get("up", [])
		_check(not up.is_empty(), "J%s tiene la accion up configurada" % pid)
		_check(not bindings.has("jump"), "J%s ya no expone la accion jump" % pid)
		for wanted in expected_up[pid]:
			var found := false
			for src in up:
				if not (src is Dictionary):
					continue
				var stype := str(src.get("type", ""))
				if wanted == "Space" and stype == "key" and str(src.get("code", "")) == "Space":
					found = true
				elif stype == "joy_button" and str(src.get("button", "")) == wanted:
					found = true
			_check(found, "J%s salta con %s mediante up/move_y" % [pid, wanted])

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
	_check(suffix == ["COMBO_RIGHT_DOWN_RIGHT_B"], "el combo 6 no dispara tambien el combo 8")

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
		"command_detected": "SPECIAL_ATTACK_1"
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

func _test_report_sign() -> void:
	var Core = load("res://scripts/input_core.gd")
	if Core == null:
		_check(false, "se puede cargar input_core.gd")
		return
	var core = Core.new()
	var up_report: Dictionary = core._build_report(1, 1, {"up": true, "down": false}, null)
	_check(int(up_report["state"]["move_y"]) == 1, "move_y = +1 al pulsar arriba (salto)")
	var down_report: Dictionary = core._build_report(1, 1, {"up": false, "down": true}, null)
	_check(int(down_report["state"]["move_y"]) == -1, "move_y = -1 al pulsar abajo (agachado)")
	_check(not up_report["state"].has("jump"), "el reporte no incluye state.jump")
	_check(up_report["state"].size() == 6, "state tiene exactamente las 6 claves del PDF")
	core.free()
