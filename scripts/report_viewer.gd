extends Control

const REPORTS_DIR := "user://n2_reports"
const EXAMPLE_PATH := "res://contracts/input_report.example.jsonl"
const MAX_REPORTS := 2000
const MAX_VISIBLE_LINES := 400

var _reports: Array = []
var _filter_player: int = 0
var _only_commands: bool = false
var _view_paused: bool = false
var _dirty: bool = true
var _last_refresh: int = 0
var _last_status_update: int = 0

var _record_file: FileAccess = null
var _record_path: String = ""
var _record_lines: int = 0

var _display: RichTextLabel
var _counter: Label
var _footer: Label
var _pause_button: CheckButton
var _record_button: CheckButton
var _only_commands_button: CheckBox
var _filter_button: OptionButton

func _ready() -> void:
	_build_ui()
	N2InputCore.report_emitted.connect(_on_report)
	_set_footer("Los reportes se guardan en %s" % ProjectSettings.globalize_path(REPORTS_DIR))
	set_process(true)

func _exit_tree() -> void:
	if _record_file != null:
		_record_file.flush()
		_record_file.close()
		_record_file = null

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.045, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var title := Label.new()
	title.text = "GNDU - Visor de reportes JSON"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_counter = Label.new()
	_counter.text = "reportes: 0"
	_counter.add_theme_font_size_override("font_size", 12)
	_counter.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	header.add_child(_counter)

	header.add_child(_make_button("Volver (Esc)", _go_back))

	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 4)
	root.add_child(controls)

	_filter_button = OptionButton.new()
	_filter_button.add_item("Todos", 0)
	_filter_button.add_item("Solo J1", 1)
	_filter_button.add_item("Solo J2", 2)
	_filter_button.add_theme_font_size_override("font_size", 12)
	_filter_button.item_selected.connect(_on_filter_selected)
	controls.add_child(_filter_button)

	_only_commands_button = CheckBox.new()
	_only_commands_button.text = "Solo comandos"
	_only_commands_button.add_theme_font_size_override("font_size", 12)
	_only_commands_button.toggled.connect(_on_only_commands_toggled)
	controls.add_child(_only_commands_button)

	_pause_button = CheckButton.new()
	_pause_button.text = "Pausar vista"
	_pause_button.add_theme_font_size_override("font_size", 12)
	_pause_button.toggled.connect(_on_pause_toggled)
	controls.add_child(_pause_button)

	_record_button = CheckButton.new()
	_record_button.text = "Grabar en vivo"
	_record_button.add_theme_font_size_override("font_size", 12)
	_record_button.toggled.connect(_on_record_toggled)
	controls.add_child(_record_button)

	controls.add_child(_make_button("Limpiar", _clear_reports))
	controls.add_child(_make_button("Copiar visibles", _copy_visible))
	controls.add_child(_make_button("Guardar JSONL", _save_visible))
	controls.add_child(_make_button("Abrir carpeta", _open_reports_folder))
	controls.add_child(_make_button("Cargar ejemplo", _load_example))

	_display = RichTextLabel.new()
	_display.scroll_following = true
	_display.bbcode_enabled = false
	_display.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_display.add_theme_font_size_override("normal_font_size", 11)
	_display.add_theme_font_size_override("bold_font_size", 11)
	_display.add_theme_color_override("default_color", Color(0.7, 0.78, 0.86))
	_display.custom_minimum_size = Vector2(0, 320)
	root.add_child(_display)

	_footer = Label.new()
	_footer.text = ""
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_theme_font_size_override("font_size", 11)
	_footer.add_theme_color_override("font_color", Color(0.55, 0.72, 0.6))
	root.add_child(_footer)

func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	return button

func _on_report(report: Dictionary) -> void:
	var copy: Dictionary = report.duplicate(true)
	_reports.append(copy)
	while _reports.size() > MAX_REPORTS:
		_reports.pop_front()

	if _record_file != null:
		_record_file.store_line(JSON.stringify(copy))
		_record_lines += 1
		if _record_lines % 10 == 0:
			_record_file.flush()

	_dirty = true

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()

	if now - _last_status_update >= 250:
		_last_status_update = now
		_update_counter()

	if _dirty and not _view_paused and now - _last_refresh >= 100:
		_last_refresh = now
		_rebuild_display()
		_dirty = false

func _update_counter() -> void:
	var visible := _matching_reports().size()
	_counter.text = "reportes: %d / %d  |  frame: %d  |  fps: %d" % [
		visible,
		_reports.size(),
		Engine.get_physics_frames(),
		Engine.get_frames_per_second()
	]

func _rebuild_display() -> void:
	_display.clear()
	var lines := _matching_reports()
	if lines.is_empty():
		_display.add_text("(sin reportes; pulsa Cargar ejemplo o mueve un mando)\n")
		return

	var start := maxi(0, lines.size() - MAX_VISIBLE_LINES)
	if start > 0:
		_display.push_color(Color(0.45, 0.5, 0.6))
		_display.add_text("... %d reportes anteriores ocultos ...\n" % start)
		_display.pop()

	for i in range(start, lines.size()):
		var report: Dictionary = lines[i]
		var pid := int(report.get("player_id", 0))
		var frame := int(report.get("frame", 0))

		_display.push_color(_player_color(pid))
		_display.add_text("J%d" % pid)
		_display.pop()

		_display.push_color(Color(0.5, 0.58, 0.68))
		_display.add_text("  f%d  " % frame)
		_display.pop()

		var command = report.get("command_detected", null)
		if command is String:
			_display.push_color(Color(0.45, 1.0, 0.55))
			_display.add_text("[%s]  " % command)
			_display.pop()

		_display.add_text(JSON.stringify(report) + "\n")

func _matching_reports() -> Array:
	var out: Array = []
	for report in _reports:
		if not (report is Dictionary):
			continue
		if _filter_player != 0 and int(report.get("player_id", 0)) != _filter_player:
			continue
		if _only_commands and not (report.get("command_detected", null) is String):
			continue
		out.append(report)
	return out

func _player_color(pid: int) -> Color:
	return Color(0.2, 0.8, 1.0) if pid == 1 else Color(1.0, 0.65, 0.25)

func _on_filter_selected(index: int) -> void:
	_filter_player = index
	_dirty = true

func _on_only_commands_toggled(enabled: bool) -> void:
	_only_commands = enabled
	_dirty = true

func _on_pause_toggled(paused: bool) -> void:
	_view_paused = paused
	if not paused:
		_dirty = true

func _on_record_toggled(enabled: bool) -> void:
	if enabled:
		_start_recording()
	else:
		_stop_recording()

func _start_recording() -> void:
	if _record_file != null:
		return
	_ensure_reports_dir()
	_record_path = "%s/live_%s.jsonl" % [REPORTS_DIR, _timestamp()]
	_record_file = FileAccess.open(_record_path, FileAccess.WRITE)
	if _record_file == null:
		_record_button.set_pressed_no_signal(false)
		_set_footer("No se pudo grabar: %s" % error_string(FileAccess.get_open_error()))
		return
	_record_lines = 0
	_set_footer("Grabando en vivo en %s" % ProjectSettings.globalize_path(_record_path))

func _stop_recording() -> void:
	if _record_file == null:
		return
	_record_file.flush()
	_record_file.close()
	_record_file = null
	if is_inside_tree():
		_set_footer("Grabacion guardada en %s (%d reportes)" % [
			ProjectSettings.globalize_path(_record_path),
			_record_lines
		])

func _clear_reports() -> void:
	_reports.clear()
	_dirty = true
	_set_footer("Lista limpiada.")

func _copy_visible() -> void:
	var lines := _matching_reports()
	if lines.is_empty():
		_set_footer("No hay reportes para copiar.")
		return
	var parts := PackedStringArray()
	for report in lines:
		parts.append(JSON.stringify(report))
	DisplayServer.clipboard_set("\n".join(parts))
	_set_footer("Copiados %d reportes al portapapeles." % lines.size())

func _save_visible() -> void:
	var lines := _matching_reports()
	if lines.is_empty():
		_set_footer("No hay reportes para guardar.")
		return
	_ensure_reports_dir()
	var path := "%s/reports_%s.jsonl" % [REPORTS_DIR, _timestamp()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_footer("No se pudo guardar: %s" % error_string(FileAccess.get_open_error()))
		return
	for report in lines:
		file.store_line(JSON.stringify(report))
	file.close()
	_set_footer("Guardado: %s (%d reportes)" % [
		ProjectSettings.globalize_path(path),
		lines.size()
	])

func _load_example() -> void:
	var file := FileAccess.open(EXAMPLE_PATH, FileAccess.READ)
	if file == null:
		_set_footer("No se encontro %s" % EXAMPLE_PATH)
		return
	_reports.clear()
	var loaded := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			_reports.append(_normalize_loaded_report(parsed))
			loaded += 1
	file.close()
	while _reports.size() > MAX_REPORTS:
		_reports.pop_front()
	_dirty = true
	_set_footer("Ejemplo cargado: %d reportes." % loaded)

func _normalize_loaded_report(value: Dictionary) -> Dictionary:
	var out: Dictionary = value.duplicate(true)
	out["player_id"] = int(out.get("player_id", 0))
	out["frame"] = int(out.get("frame", 0))
	var state: Dictionary = out.get("state", {})
	state["move_x"] = int(state.get("move_x", 0))
	state["move_y"] = int(state.get("move_y", 0))
	out["state"] = state
	return out

func _open_reports_folder() -> void:
	_ensure_reports_dir()
	var path := ProjectSettings.globalize_path(REPORTS_DIR)
	var err := OS.shell_open(path)
	if err != OK:
		_set_footer("Carpeta: %s" % path)

func _ensure_reports_dir() -> void:
	if not DirAccess.dir_exists_absolute(REPORTS_DIR):
		DirAccess.make_dir_recursive_absolute(REPORTS_DIR)

func _timestamp() -> String:
	return "%s_%d" % [
		Time.get_datetime_string_from_system().replace(":", "-"),
		Time.get_ticks_msec()
	]

func _set_footer(text: String) -> void:
	if _footer != null:
		_footer.text = text

func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/diagnostic.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_V:
		_go_back()
		get_viewport().set_input_as_handled()
