extends Node

signal contract_error(message: String)

var _last_frames: Dictionary = {1: -1, 2: -1}
var _last_error: String = ""

func _ready() -> void:
	N2InputCore.report_emitted.connect(_on_report)

func _on_report(report: Dictionary) -> void:
	var error := _validate(report)
	if not error.is_empty():
		if error != _last_error:
			_last_error = error
			push_error("CONTRATO N2: " + error)
			contract_error.emit(error)
		return

	var command = report.get("command_detected", null)
	if command is String:
		print("[MOCK N3] frame %d | J%d | %s" % [
			int(report.get("frame", 0)),
			int(report.get("player_id", 0)),
			command
		])

func _validate(report: Dictionary) -> String:
	if report.is_empty():
		return "reporte vacio"
	for key in ["player_id", "frame", "state", "command_detected"]:
		if not report.has(key):
			return "falta la clave '%s'" % key

	if not (typeof(report["player_id"]) == TYPE_INT):
		return "player_id debe ser entero"
	var pid := int(report["player_id"])
	if pid != 1 and pid != 2:
		return "player_id debe ser 1 o 2"

	if not (typeof(report["frame"]) == TYPE_INT):
		return "frame debe ser entero"
	var frame := int(report["frame"])
	if _last_frames.has(pid) and frame <= int(_last_frames[pid]):
		return "frame no es creciente para J%d" % pid
	_last_frames[pid] = frame

	if not (report["state"] is Dictionary):
		return "state debe ser un objeto"
	var state: Dictionary = report["state"]
	for key in ["move_x", "move_y", "punch", "kick", "block", "pause", "jump"]:
		if not state.has(key):
			return "state.%s falta" % key

	for key in ["move_x", "move_y"]:
		if not (typeof(state[key]) == TYPE_INT):
			return "state.%s debe ser entero" % key
		var value := int(state[key])
		if value != -1 and value != 0 and value != 1:
			return "state.%s fuera de [-1, 0, 1]" % key

	for key in ["punch", "kick", "block", "pause", "jump"]:
		if not (typeof(state[key]) == TYPE_BOOL):
			return "state.%s debe ser booleano" % key

	var command = report["command_detected"]
	if not (command == null or command is String):
		return "command_detected debe ser string o null"
	if command is String and command.is_empty():
		return "command_detected no puede ser vacio"

	return ""
