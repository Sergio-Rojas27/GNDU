extends Node

signal report_emitted(report: Dictionary)
signal devices_changed

const InputBufferScript = preload("res://scripts/input_buffer.gd")
const RecognizerScript = preload("res://scripts/command_recognizer.gd")

const PLAYERS := [1, 2]
const ACTIONS := ["left", "right", "up", "down", "punch", "kick", "block", "pause"]

const JOY_BUTTONS := {
	"a": JOY_BUTTON_A,
	"b": JOY_BUTTON_B,
	"x": JOY_BUTTON_X,
	"y": JOY_BUTTON_Y,
	"dpad_up": JOY_BUTTON_DPAD_UP,
	"dpad_down": JOY_BUTTON_DPAD_DOWN,
	"dpad_left": JOY_BUTTON_DPAD_LEFT,
	"dpad_right": JOY_BUTTON_DPAD_RIGHT,
	"left_shoulder": JOY_BUTTON_LEFT_SHOULDER,
	"right_shoulder": JOY_BUTTON_RIGHT_SHOULDER,
	"left_stick": JOY_BUTTON_LEFT_STICK,
	"right_stick": JOY_BUTTON_RIGHT_STICK,
	"start": JOY_BUTTON_START,
	"back": JOY_BUTTON_BACK,
	"guide": JOY_BUTTON_GUIDE
}

const JOY_AXES := {
	"left_x": JOY_AXIS_LEFT_X,
	"left_y": JOY_AXIS_LEFT_Y,
	"right_x": JOY_AXIS_RIGHT_X,
	"right_y": JOY_AXIS_RIGHT_Y,
	"trigger_left": JOY_AXIS_TRIGGER_LEFT,
	"trigger_right": JOY_AXIS_TRIGGER_RIGHT
}

var buffers: Dictionary = {}
var recognizers: Dictionary = {}
var previous: Dictionary = {}
var last_reports: Dictionary = {}
var last_snapshots: Dictionary = {}

var _pad_by_player: Dictionary = {1: -1, 2: -1}
var _guid_by_player: Dictionary = {1: "", 2: ""}
var _warned: Dictionary = {}

var last_raw_event: Dictionary = {}
var _raw_serial: int = 0
var _last_axis_value: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	N2ControlsConfig.config_reloaded.connect(_on_config_reloaded)
	_refresh_assignments()
	_on_config_reloaded()

func _on_config_reloaded() -> void:
	var size := N2ControlsConfig.get_buffer_size()
	for pid in PLAYERS:
		buffers[pid] = InputBufferScript.new(size)
		recognizers[pid] = RecognizerScript.new(N2ControlsConfig.get_commands())
		recognizers[pid].global_cooldown = N2ControlsConfig.get_global_cooldown()
		previous[pid] = {}
		last_reports[pid] = {}
		last_snapshots[pid] = {}
	_refresh_assignments()
	devices_changed.emit()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_assignments()
	devices_changed.emit()

func _refresh_assignments() -> void:
	var pads := Input.get_connected_joypads()

	for pid in PLAYERS:
		if int(_pad_by_player.get(pid, -1)) != -1 and not pads.has(int(_pad_by_player[pid])):
			_pad_by_player[pid] = -1

	for pid in PLAYERS:
		var dev := N2ControlsConfig.get_device(pid)
		var dtype := str(dev.get("type", "keyboard"))
		var needs_pad := dtype == "joypad" or dtype == "hybrid"
		if not needs_pad:
			_pad_by_player[pid] = -1
			_guid_by_player[pid] = ""
			continue
		if int(_pad_by_player.get(pid, -1)) != -1:
			continue

		var chosen := -1
		var wanted_guid := str(_guid_by_player.get(pid, ""))
		if not wanted_guid.is_empty():
			for pad in pads:
				if Input.get_joy_guid(pad) == wanted_guid and not _pad_used_by_other(pid, pad):
					chosen = pad
					break

		if chosen == -1:
			var idx := int(dev.get("joypad_index", 0))
			if idx >= 0 and idx < pads.size() and not _pad_used_by_other(pid, pads[idx]):
				chosen = pads[idx]

		if chosen == -1:
			for pad in pads:
				if not _pad_used_by_other(pid, pad):
					chosen = pad
					break

		if chosen != -1:
			_pad_by_player[pid] = chosen
			_guid_by_player[pid] = Input.get_joy_guid(chosen)

func _pad_used_by_other(player_id: int, pad: int) -> bool:
	for other in PLAYERS:
		if other != player_id and int(_pad_by_player.get(other, -1)) == pad:
			return true
	return false

func _physics_process(_delta: float) -> void:
	var frame := Engine.get_physics_frames()
	for pid in PLAYERS:
		if not buffers.has(pid):
			continue
		var held := _read_player(pid)
		var prev: Dictionary = previous.get(pid, {})
		var pressed := {}
		var released := {}
		for action in ACTIONS:
			var now_on := bool(held.get(action, false))
			var was_on := bool(prev.get(action, false))
			pressed[action] = now_on and not was_on
			released[action] = (not now_on) and was_on

		var snapshot := {
			"frame": frame,
			"held": held,
			"pressed": pressed,
			"released": released
		}
		buffers[pid].push(snapshot)

		var command: Variant = recognizers[pid].evaluate(buffers[pid], frame)
		var report := _build_report(pid, frame, held, command)

		previous[pid] = held.duplicate(true)
		last_snapshots[pid] = snapshot
		last_reports[pid] = report
		report_emitted.emit(report)

func _read_player(player_id: int) -> Dictionary:
	var cfg := N2ControlsConfig.get_player(player_id)
	var info := get_device_info(player_id)
	var bindings: Dictionary = cfg.get("bindings", {})
	var result := {}
	for action in ACTIONS:
		var active := false
		var sources = bindings.get(action, [])
		if sources is Array:
			for source in sources:
				if source is Dictionary and _source_active(source, info):
					active = true
					break
		result[action] = active
	return result

func _source_active(source: Dictionary, info: Dictionary) -> bool:
	var stype := str(source.get("type", ""))
	var dtype := str(info.get("type", "keyboard"))
	match stype:
		"key":
			if dtype == "joypad":
				return false
			var key := OS.find_keycode_from_string(str(source.get("code", "")))
			if key == KEY_NONE:
				_warn_once("key:%s" % str(source.get("code", "")), "Tecla desconocida: %s" % str(source.get("code", "")))
				return false
			return Input.is_physical_key_pressed(key)
		"joy_button":
			if not bool(info.get("pad_connected", false)):
				return false
			var btn := int(JOY_BUTTONS.get(str(source.get("button", "")), JOY_BUTTON_INVALID))
			if btn == JOY_BUTTON_INVALID:
				_warn_once("button:%s" % str(source.get("button", "")), "Boton desconocido: %s" % str(source.get("button", "")))
				return false
			return Input.is_joy_button_pressed(int(info.get("pad_id", -1)), btn)
		"joy_axis":
			if not bool(info.get("pad_connected", false)):
				return false
			var axis := int(JOY_AXES.get(str(source.get("axis", "")), JOY_AXIS_INVALID))
			if axis == JOY_AXIS_INVALID:
				_warn_once("axis:%s" % str(source.get("axis", "")), "Eje desconocido: %s" % str(source.get("axis", "")))
				return false
			var value := Input.get_joy_axis(int(info.get("pad_id", -1)), axis)
			var direction := float(source.get("direction", 1))
			var deadzone := float(source.get("deadzone", 0.35))
			return value * direction >= deadzone
	_warn_once("type:%s" % stype, "Tipo de fuente desconocido: %s" % stype)
	return false

func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning("N2InputCore: " + message)

func _build_report(player_id: int, frame: int, held: Dictionary, command: Variant) -> Dictionary:
	var move_x := int(held.get("right", false)) - int(held.get("left", false))
	var move_y := int(held.get("up", false)) - int(held.get("down", false))
	return {
		"player_id": player_id,
		"frame": frame,
		"state": {
			"move_x": clampi(move_x, -1, 1),
			"move_y": clampi(move_y, -1, 1),
			"punch": bool(held.get("punch", false)),
			"kick": bool(held.get("kick", false)),
			"block": bool(held.get("block", false)),
			"pause": bool(held.get("pause", false))
		},
		"command_detected": command if command is String else null
	}

func get_device_info(player_id: int) -> Dictionary:
	var dev := N2ControlsConfig.get_device(player_id)
	var dtype := str(dev.get("type", "keyboard"))
	var pad_id := int(_pad_by_player.get(player_id, -1))
	var pad_connected := pad_id != -1
	var name := "Teclado"
	var guid := ""
	if pad_connected:
		name = Input.get_joy_name(pad_id)
		guid = Input.get_joy_guid(pad_id)
	var connected := true
	if dtype == "joypad":
		connected = pad_connected
	return {
		"player_id": player_id,
		"type": dtype,
		"connected": connected,
		"pad_id": pad_id,
		"pad_connected": pad_connected,
		"name": name,
		"guid": guid
	}

func get_device_label(player_id: int) -> String:
	var info := get_device_info(player_id)
	var dtype := str(info.get("type", "keyboard"))
	var pad_id := int(info.get("pad_id", -1))
	var pad_connected := bool(info.get("pad_connected", false))
	match dtype:
		"keyboard":
			return "Teclado"
		"joypad":
			if pad_connected:
				return "Mando #%d: %s" % [pad_id, str(info.get("name", "?"))]
			return "Mando desconectado"
		"hybrid":
			if pad_connected:
				return "Teclado + mando #%d: %s" % [pad_id, str(info.get("name", "?"))]
			return "Teclado (mando desconectado)"
	return str(dtype)

func get_last_report(player_id: int) -> Dictionary:
	return last_reports.get(player_id, {})

func get_last_snapshot(player_id: int) -> Dictionary:
	return last_snapshots.get(player_id, {})

func get_buffer(player_id: int) -> RefCounted:
	return buffers.get(player_id, null)

func get_last_raw_event() -> Dictionary:
	return last_raw_event

func get_raw_serial() -> int:
	return _raw_serial

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		last_raw_event = {
			"kind": "key",
			"device": 0,
			"text": OS.get_keycode_string(event.keycode),
			"pressed": true,
			"frame": Engine.get_physics_frames()
		}
		_raw_serial += 1
	elif event is InputEventJoypadButton and event.pressed:
		last_raw_event = {
			"kind": "joy_button",
			"device": event.device,
			"index": event.button_index,
			"pressed": true,
			"frame": Engine.get_physics_frames()
		}
		_raw_serial += 1
	elif event is InputEventJoypadMotion:
		var key := "%d:%d" % [event.device, event.axis]
		var old := float(_last_axis_value.get(key, 0.0))
		if abs(event.axis_value - old) >= 0.25:
			_last_axis_value[key] = event.axis_value
			last_raw_event = {
				"kind": "joy_axis",
				"device": event.device,
				"axis": event.axis,
				"value": event.axis_value,
				"frame": Engine.get_physics_frames()
			}
			_raw_serial += 1
