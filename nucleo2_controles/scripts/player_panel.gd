class_name N2PlayerPanel
extends PanelContainer

const DIR_ACTIONS := ["left", "right", "up", "down"]
const BTN_ACTIONS := ["punch", "kick", "block", "pause"]
const TAPE_SIZE := 30

const ACTION_TEXT := {
	"left": "IZQ",
	"right": "DER",
	"up": "ARRIBA",
	"down": "ABAJO",
	"punch": "PUNO",
	"kick": "PATADA",
	"block": "BLOQUEO",
	"pause": "PAUSA"
}

const ACTION_SHORT := {
	"punch": "P",
	"kick": "K",
	"block": "B",
	"pause": "II"
}

var player_id: int = 1
var accent: Color = Color(0.2, 0.8, 1.0)

var _dir_indicators: Dictionary = {}
var _btn_indicators: Dictionary = {}
var _tape_cells: Array = []
var _label_device: Label
var _label_state: Label
var _label_events: Label
var _events: Array[String] = []
var _frozen: bool = false
var _flash_until: Dictionary = {}

func setup(id: int, accent_color: Color) -> void:
	player_id = id
	accent = accent_color

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	set_process(true)

func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13)
	style.border_color = accent.darkened(0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var title := Label.new()
	title.text = "JUGADOR %d" % player_id
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", accent)
	box.add_child(title)

	_label_device = Label.new()
	_label_device.text = N2InputCore.get_device_label(player_id)
	_label_device.add_theme_font_size_override("font_size", 11)
	_label_device.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	_label_device.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_label_device)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	grid.add_child(_blank())
	grid.add_child(_make_indicator("^", "up", _dir_indicators, 17, Vector2(54, 34)))
	grid.add_child(_blank())
	grid.add_child(_make_indicator("<", "left", _dir_indicators, 17, Vector2(54, 34)))
	var neutral := Label.new()
	neutral.text = "."
	neutral.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	neutral.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	neutral.custom_minimum_size = Vector2(54, 34)
	neutral.add_theme_font_size_override("font_size", 17)
	neutral.add_theme_color_override("font_color", Color(0.35, 0.42, 0.55))
	grid.add_child(neutral)
	grid.add_child(_make_indicator(">", "right", _dir_indicators, 17, Vector2(54, 34)))
	grid.add_child(_blank())
	grid.add_child(_make_indicator("v", "down", _dir_indicators, 17, Vector2(54, 34)))
	grid.add_child(_blank())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	box.add_child(buttons)
	for action in BTN_ACTIONS:
		var hint := _action_hint(action)
		var text: String = ACTION_TEXT[action]
		if not hint.is_empty():
			text += "\n" + hint
		var indicator := _make_indicator(text, action, _btn_indicators, 9, Vector2(0, 40))
		indicator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(indicator)

	_label_state = Label.new()
	_label_state.text = "move_x: 0    move_y: 0"
	_label_state.add_theme_font_size_override("font_size", 12)
	_label_state.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	box.add_child(_label_state)

	var tape_title := Label.new()
	tape_title.text = "BUFER (30 fotogramas)"
	tape_title.add_theme_font_size_override("font_size", 10)
	tape_title.add_theme_color_override("font_color", Color(0.55, 0.62, 0.75))
	box.add_child(tape_title)

	var tape := HBoxContainer.new()
	tape.add_theme_constant_override("separation", 1)
	box.add_child(tape)
	for i in range(TAPE_SIZE):
		var rect := ColorRect.new()
		rect.custom_minimum_size = Vector2(17, 24)
		rect.color = Color(0.16, 0.20, 0.29)
		var label := Label.new()
		label.text = ""
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
		rect.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tape.add_child(rect)
		_tape_cells.append({"rect": rect, "label": label})

	var legend := Label.new()
	legend.text = "<- -> ^ v (^ = salto)    P=puñetazo  K=patada  B=bloqueo  II=pausa"
	legend.add_theme_font_size_override("font_size", 9)
	legend.add_theme_color_override("font_color", Color(0.45, 0.52, 0.65))
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(legend)

	_label_events = Label.new()
	_label_events.text = "Eventos:"
	_label_events.add_theme_font_size_override("font_size", 10)
	_label_events.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	_label_events.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_events.custom_minimum_size = Vector2(0, 42)
	box.add_child(_label_events)

func _blank() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(54, 34)
	return c

func _make_indicator(text: String, action: String, target: Dictionary, font_size: int, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.13, 0.19)
	style.border_color = Color(0, 0, 0, 0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(3)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = min_size
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.98))
	panel.add_child(label)
	target[action] = panel
	return panel

func _action_hint(action: String) -> String:
	var labels: Array = []
	for source in N2ControlsConfig.get_bindings(player_id, action):
		if source is Dictionary:
			labels.append(N2ControlsConfig.describe_source(source))
		if labels.size() >= 3:
			break
	return " / ".join(labels)

func update_from_report(report: Dictionary) -> void:
	var state: Dictionary = report.get("state", {})
	var snap := N2InputCore.get_last_snapshot(player_id)
	var held: Dictionary = snap.get("held", {})
	var pressed: Dictionary = snap.get("pressed", {})
	var now := Time.get_ticks_msec()

	for action in DIR_ACTIONS:
		_set_indicator(_dir_indicators, action, bool(held.get(action, false)), bool(pressed.get(action, false)), now)
	for action in BTN_ACTIONS:
		_set_indicator(_btn_indicators, action, bool(state.get(action, false)), bool(pressed.get(action, false)), now)

	_label_state.text = "move_x: %d    move_y: %d" % [
		int(state.get("move_x", 0)),
		int(state.get("move_y", 0))
	]
	_label_device.text = N2InputCore.get_device_label(player_id)

	if not _frozen:
		var buffer = N2InputCore.get_buffer(player_id)
		if buffer != null:
			_update_tape(buffer.get_last(TAPE_SIZE))

	for action in pressed.keys():
		if bool(pressed[action]):
			_add_event(int(snap.get("frame", 0)), str(action))

func _set_indicator(store: Dictionary, action: String, active: bool, pressed: bool, now: int) -> void:
	if not store.has(action):
		return
	var panel: PanelContainer = store[action]
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	if active:
		style.bg_color = accent.darkened(0.35)
	else:
		style.bg_color = Color(0.10, 0.13, 0.19)
	if pressed:
		_flash_until[action] = now + 120

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for action in _flash_until.keys():
		var panel = _btn_indicators.get(action, _dir_indicators.get(action))
		if panel == null:
			continue
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		if now < int(_flash_until[action]):
			style.border_color = Color(1, 1, 1)
		else:
			style.border_color = Color(0, 0, 0, 0)
			_flash_until.erase(action)

func _update_tape(frames: Array) -> void:
	var offset := TAPE_SIZE - frames.size()
	for i in range(TAPE_SIZE):
		var cell: Dictionary = _tape_cells[i]
		var rect: ColorRect = cell["rect"]
		var label: Label = cell["label"]
		if i < offset:
			label.text = ""
			rect.color = Color(0.10, 0.12, 0.18)
			continue

		var snap: Dictionary = frames[i - offset]
		var held: Dictionary = snap.get("held", {})
		var pressed: Dictionary = snap.get("pressed", {})
		var text := ""

		if bool(held.get("left", false)):
			text += "<"
		elif bool(held.get("right", false)):
			text += ">"
		elif bool(held.get("up", false)):
			text += "^"
		elif bool(held.get("down", false)):
			text += "v"

		var has_press := false
		for action in BTN_ACTIONS:
			if bool(pressed.get(action, false)):
				text += ACTION_SHORT[action]
				has_press = true
				break
		if not has_press:
			for action in BTN_ACTIONS:
				if bool(held.get(action, false)):
					text += str(ACTION_SHORT[action]).to_lower()
					break

		label.text = text
		var has_held := bool(held.get("left", false)) or bool(held.get("right", false)) or bool(held.get("up", false)) or bool(held.get("down", false))
		if has_press:
			rect.color = accent.darkened(0.05)
		elif has_held:
			rect.color = accent.darkened(0.55)
		else:
			rect.color = Color(0.10, 0.12, 0.18)

func _add_event(frame: int, action: String) -> void:
	var label := str(ACTION_TEXT.get(action, action))
	_events.append("f%d %s" % [frame, label])
	while _events.size() > 5:
		_events.pop_front()
	_label_events.text = "Eventos: " + "   ".join(_events)

func set_frozen(value: bool) -> void:
	_frozen = value
	if not value:
		var buffer = N2InputCore.get_buffer(player_id)
		if buffer != null:
			_update_tape(buffer.get_last(TAPE_SIZE))
