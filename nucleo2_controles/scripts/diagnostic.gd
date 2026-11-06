extends Control

const PlayerPanelScript = preload("res://scripts/player_panel.gd")
const MockConsumerScript = preload("res://scripts/mock_consumer.gd")

var _panels: Dictionary = {}
var _banner: Label
var _status: Label
var _raw_label: Label
var _frame_label: Label
var _fps_label: Label
var _log: RichTextLabel
var _console_button: Button
var _freeze_button: Button

var _log_lines: Array[String] = []
var _log_dirty: bool = false
var _last_log_update: int = 0
var _console_enabled: bool = false
var _frozen: bool = false
var _banner_until: int = 0
var _last_raw_serial: int = -1
var _last_status_update: int = 0

func _ready() -> void:
	_build_ui()

	N2InputCore.report_emitted.connect(_on_report)
	N2ControlsConfig.config_error.connect(_on_config_error)

	var mock := MockConsumerScript.new()
	add_child(mock)
	mock.contract_error.connect(_on_config_error)

	_status.text = "Config: %s" % N2ControlsConfig.CONFIG_PATH
	if not N2ControlsConfig.last_error.is_empty():
		_on_config_error(N2ControlsConfig.last_error)
	set_process(true)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08)
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
	root.add_theme_constant_override("separation", 5)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var title := Label.new()
	title.text = "GNDU - Nucleo 2 - Controles"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_frame_label = Label.new()
	_frame_label.text = "frame: 0"
	_frame_label.add_theme_font_size_override("font_size", 11)
	header.add_child(_frame_label)

	_fps_label = Label.new()
	_fps_label.text = "fps: 0"
	_fps_label.add_theme_font_size_override("font_size", 11)
	header.add_child(_fps_label)

	header.add_child(_make_button("Recargar (R)", _reload_config))
	_console_button = _make_button("Consola: OFF (J)", _toggle_console)
	header.add_child(_console_button)
	_freeze_button = _make_button("Congelar: OFF (C)", _toggle_freeze)
	header.add_child(_freeze_button)
	header.add_child(_make_button("Salir (F10)", func() -> void: get_tree().quit()))

	_status = Label.new()
	_status.text = "Config:"
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	_raw_label = Label.new()
	_raw_label.text = "Ultimo evento fisico: (sin eventos)"
	_raw_label.add_theme_font_size_override("font_size", 11)
	_raw_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.35))
	root.add_child(_raw_label)

	var players := HBoxContainer.new()
	players.add_theme_constant_override("separation", 10)
	players.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(players)

	var p1 := PlayerPanelScript.new()
	p1.setup(1, Color(0.2, 0.8, 1.0))
	players.add_child(p1)
	_panels[1] = p1

	var p2 := PlayerPanelScript.new()
	p2.setup(2, Color(1.0, 0.6, 0.2))
	players.add_child(p2)
	_panels[2] = p2

	_banner = Label.new()
	_banner.text = ""
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	_banner.custom_minimum_size = Vector2(0, 44)
	root.add_child(_banner)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = false
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0, 140)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 10)
	_log.add_theme_color_override("default_color", Color(0.65, 0.75, 0.85))
	root.add_child(_log)

func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(callback)
	return button

func _on_report(report: Dictionary) -> void:
	var pid := int(report.get("player_id", 0))
	if _panels.has(pid):
		_panels[pid].update_from_report(report)

	var command = report.get("command_detected", null)
	if command is String:
		_show_banner(pid, command)

	if _console_enabled:
		print(JSON.stringify(report))

	_log_lines.append(JSON.stringify(report))
	while _log_lines.size() > 20:
		_log_lines.pop_front()
	_log_dirty = true

func _show_banner(player_id: int, command: String) -> void:
	_banner.text = "J%d  %s" % [player_id, command]
	_banner.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6) if player_id == 1 else Color(1.0, 0.75, 0.3))
	_banner_until = Time.get_ticks_msec() + 900

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()

	if now - _last_status_update >= 200:
		_last_status_update = now
		_frame_label.text = "frame: %d" % Engine.get_physics_frames()
		_fps_label.text = "fps: %d" % Engine.get_frames_per_second()
		_update_raw_label()

	if now >= _banner_until and not _banner.text.is_empty():
		_banner.text = ""

	if _log_dirty and now - _last_log_update >= 100:
		_last_log_update = now
		_log.text = "\n".join(_log_lines)
		_log_dirty = false

func _update_raw_label() -> void:
	var serial := N2InputCore.get_raw_serial()
	if serial == _last_raw_serial:
		return
	_last_raw_serial = serial
	var event := N2InputCore.get_last_raw_event()
	if event.is_empty():
		return
	match str(event.get("kind", "")):
		"key":
			_raw_label.text = "Ultimo evento fisico: tecla %s (frame %d)" % [
				str(event.get("text", "?")),
				int(event.get("frame", 0))
			]
		"joy_button":
			_raw_label.text = "Ultimo evento fisico: mando %d, boton %d (frame %d)" % [
				int(event.get("device", -1)),
				int(event.get("index", -1)),
				int(event.get("frame", 0))
			]
		"joy_axis":
			_raw_label.text = "Ultimo evento fisico: mando %d, eje %d = %.2f (frame %d)" % [
				int(event.get("device", -1)),
				int(event.get("axis", -1)),
				float(event.get("value", 0.0)),
				int(event.get("frame", 0))
			]

func _reload_config() -> void:
	if N2ControlsConfig.reload():
		_status.text = "Config recargada: %s" % N2ControlsConfig.CONFIG_PATH
		_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	else:
		_on_config_error(N2ControlsConfig.last_error)

func _on_config_error(message: String) -> void:
	_status.text = "ERROR DE CONFIG: " + message
	_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

func _toggle_console() -> void:
	_console_enabled = not _console_enabled
	_console_button.text = "Consola: %s (J)" % ("ON" if _console_enabled else "OFF")

func _toggle_freeze() -> void:
	_frozen = not _frozen
	_freeze_button.text = "Congelar: %s (C)" % ("ON" if _frozen else "OFF")
	for pid in _panels.keys():
		_panels[pid].set_frozen(_frozen)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R:
			_reload_config()
			get_viewport().set_input_as_handled()
		KEY_J:
			_toggle_console()
			get_viewport().set_input_as_handled()
		KEY_C:
			_toggle_freeze()
			get_viewport().set_input_as_handled()
		KEY_F10:
			get_tree().quit()
