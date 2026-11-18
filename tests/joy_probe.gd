extends SceneTree
## Sonda de mandos: lista los mandos conectados y muestra en vivo
## que boton/eje reporta cada uno. No usa la configuracion del juego.
##
## Uso:
##   flatpak run org.godotengine.Godot --path . --script res://tests/joy_probe.gd
##
## Opcional: N2_PROBE_SECONDS=30 para cambiar la duracion (por defecto 60).

const BUTTON_NAMES := {
	0: "A/sur", 1: "B/este", 2: "X/oeste", 3: "Y/norte",
	4: "back", 5: "guide", 6: "start", 7: "left_stick", 8: "right_stick",
	9: "left_shoulder", 10: "right_shoulder", 11: "dpad_up", 12: "dpad_down",
	13: "dpad_left", 14: "dpad_right", 15: "misc1", 16: "paddle1",
	17: "paddle2", 18: "paddle3", 19: "paddle4", 20: "touchpad"
}

const AXIS_NAMES := {
	0: "left_x", 1: "left_y", 2: "right_x", 3: "right_y",
	4: "trigger_left", 5: "trigger_right"
}

var _duration_ms: int = 60000
var _start_ms: int = 0
var _pads_reported: Dictionary = {}
var _buttons: Dictionary = {}
var _axes: Dictionary = {}
var _next_list_ms: int = 0

func _initialize() -> void:
	var env := OS.get_environment("N2_PROBE_SECONDS")
	if not env.is_empty():
		_duration_ms = int(env) * 1000
	_start_ms = Time.get_ticks_msec()
	print("== Sonda de mandos ==")
	print("Duracion: %d s. Pulsa botones y mueve sticks/d-pad." % int(_duration_ms / 1000))
	print("")

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - _start_ms >= _duration_ms:
		print("")
		print("Fin de la sonda.")
		return true

	if now >= _next_list_ms:
		_next_list_ms = now + 2000
		_list_pads()

	for pad in Input.get_connected_joypads():
		for btn in BUTTON_NAMES.keys():
			var pressed := Input.is_joy_button_pressed(pad, btn)
			var key := "b:%d:%d" % [pad, btn]
			var old := bool(_buttons.get(key, false))
			if pressed != old:
				_buttons[key] = pressed
				if pressed:
					print("  J%d boton %d (%s) PULSADO" % [pad, btn, BUTTON_NAMES[btn]])
				else:
					print("  J%d boton %d (%s) soltado" % [pad, btn, BUTTON_NAMES[btn]])
		for axis in AXIS_NAMES.keys():
			var value := Input.get_joy_axis(pad, axis)
			var key := "a:%d:%d" % [pad, axis]
			var old := float(_axes.get(key, 0.0))
			if absf(value - old) >= 0.5 or (absf(value) < 0.15 and absf(old) >= 0.5):
				_axes[key] = value
				print("  J%d eje %d (%s) = %.2f" % [pad, axis, AXIS_NAMES[axis], value])
	return false

func _list_pads() -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		if _pads_reported.is_empty() or not bool(_pads_reported.get("empty", false)):
			print("[%5.1fs] No hay mandos conectados." % _elapsed())
			_pads_reported = {"empty": true}
		return

	for pad in pads:
		var guid := Input.get_joy_guid(pad)
		var name := Input.get_joy_name(pad)
		var key := "%d:%s" % [pad, guid]
		if _pads_reported.has(key):
			continue
		_pads_reported[key] = true
		print("[%5.1fs] Mando #%d  %s" % [_elapsed(), pad, name])
		print("         GUID: %s" % guid)
	print("")

func _elapsed() -> float:
	return float(Time.get_ticks_msec() - _start_ms) / 1000.0
