extends Control

const ESCENA_MENU_PRINCIPAL := "res://nucleo4_interfaz/scenes/Menu_Principal.tscn"
const RUTA_GUARDADO := "user://configuracion.cfg"

const CONTROLES_DEFECTO := {
	"p1_up": ["J1 Arriba", KEY_W],
	"p1_down": ["J1 Abajo", KEY_S],
	"p1_left": ["J1 Izquierda", KEY_A],
	"p1_right": ["J1 Derecha", KEY_D],
	"p1_action": ["J1 Acción", KEY_SPACE],
	"p2_up": ["J2 Arriba", KEY_UP],
	"p2_down": ["J2 Abajo", KEY_DOWN],
	"p2_left": ["J2 Izquierda", KEY_LEFT],
	"p2_right": ["J2 Derecha", KEY_RIGHT],
	"p2_action": ["J2 Acción", KEY_ENTER],
}

var accion_esperando := ""
var botones_teclas := {}
var sliders_audio := {}
var etiquetas_porcentaje := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # 1920x1080
	_inicializar_acciones()
	_aplicar_estilo_visual() # <- Aplica la capa de diseño moderno
	_construir_interfaz()
	_cargar_datos()

func _inicializar_acciones() -> void:
	for accion in CONTROLES_DEFECTO:
		if not InputMap.has_action(accion):
			InputMap.add_action(accion)
			var ev := InputEventKey.new()
			ev.physical_keycode = CONTROLES_DEFECTO[accion][1]
			InputMap.action_add_event(accion, ev)

func _aplicar_estilo_visual() -> void:
	# Creamos un Tema global personalizado por código para estilizar los componentes
	var tema := Theme.new()
	tema.default_font_size = 28
	
	# Colores de la paleta Cyberpunk / Sci-Fi acorde a tu juego
	var col_fondo := Color("#121824")
	var col_panel := Color("#1a2332")
	var col_borde := Color("#2c3e50")
	var col_acento := Color("#3498db")
	var col_acento_hover := Color("#2980b9")
	var col_texto := Color("#ecf0f1")
	
	# Estilo general para paneles y fondos de pestañas
	var estilo_panel = StyleBoxFlat.new()
	estilo_panel.bg_color = col_panel
	estilo_panel.border_color = col_acento
	estilo_panel.set_border_width_all(2)
	estilo_panel.set_corner_radius_all(6)
	estilo_panel.content_margin_left = 32
	estilo_panel.content_margin_right = 32
	estilo_panel.content_margin_top = 32
	estilo_panel.content_margin_bottom = 32
	tema.set_stylebox("panel", "TabContainer", estilo_panel)
	
	# Estilo para las pestañas (Tabs)
	var estilo_tab_normal = StyleBoxFlat.new()
	estilo_tab_normal.bg_color = col_borde
	estilo_tab_normal.corner_radius_top_left = 4
	estilo_tab_normal.corner_radius_top_right = 4
	estilo_tab_normal.corner_radius_bottom_right = 0
	estilo_tab_normal.corner_radius_bottom_left = 0
	estilo_tab_normal.content_margin_left = 28
	estilo_tab_normal.content_margin_right = 28
	estilo_tab_normal.content_margin_top = 14
	estilo_tab_normal.content_margin_bottom = 14
	tema.set_stylebox("tab_selected", "TabContainer", estilo_panel)
	tema.set_stylebox("tab_unselected", "TabContainer", estilo_tab_normal)
	
	# Estilo para los Botones normales
	var estilo_btn = StyleBoxFlat.new()
	estilo_btn.bg_color = col_borde
	estilo_btn.border_color = col_acento
	estilo_btn.set_border_width_all(1)
	estilo_btn.set_corner_radius_all(4)
	estilo_btn.content_margin_top = 12
	estilo_btn.content_margin_bottom = 12
	
	var estilo_btn_hover = estilo_btn.duplicate()
	estilo_btn_hover.bg_color = col_acento_hover
	
	tema.set_stylebox("normal", "Button", estilo_btn)
	tema.set_stylebox("hover", "Button", estilo_btn_hover)
	tema.set_stylebox("pressed", "Button", estilo_btn_hover)
	
	# Colores de texto predeterminados
	tema.set_stylebox("focus", "Button", estilo_btn_hover)
	tema.set_color("font_color", "Button", col_texto)
	tema.set_color("font_hover_color", "Button", col_texto)
	tema.set_color("font_focus_color", "Button", col_texto)
	tema.set_color("font_selected_color", "TabContainer", col_texto)
	tema.set_color("font_unselected_color", "TabContainer", Color(col_texto, 0.7))
	tema.set_font_size("font_size", "TabContainer", 30)
	tema.set_color("font_color", "Label", col_texto)
	
	self.theme = tema

func _construir_interfaz() -> void:
	# Fondo general semitransparente oscuro para resaltar el menú sobre el juego
	var fondo_oscuro := ColorRect.new()
	fondo_oscuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo_oscuro.color = Color("#121824")
	fondo_oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo_oscuro)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 40)
	centro.add_child(caja)

	var titulo := Label.new()
	titulo.text = "⚙️ CONFIGURACIÓN"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 64)
	caja.add_child(titulo)

	var pestanas := TabContainer.new()
	pestanas.custom_minimum_size = Vector2(1300, 560)
	caja.add_child(pestanas)

	# --- PESTAÑA AUDIO ---
	var tab_audio := VBoxContainer.new()
	tab_audio.name = "🔊 Audio"
	tab_audio.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_audio.add_theme_constant_override("separation", 48)
	pestanas.add_child(tab_audio)

	for item in [["Master", "Volumen General"], ["Music", "Música"], ["SFX", "Efectos (SFX)"]]:
		var bus: String = item[0]
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 32)

		var lbl := Label.new()
		lbl.text = item[1]
		lbl.custom_minimum_size = Vector2(320, 0)

		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = 1.0
		slider.custom_minimum_size = Vector2(560, 40)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var pct := Label.new()
		pct.text = "100%"
		pct.custom_minimum_size = Vector2(110, 0)

		slider.value_changed.connect(func(val: float):
			_cambiar_volumen(bus, val)
			pct.text = "%d%%" % int(val * 100.0)
			_guardar_datos()
		)

		sliders_audio[bus] = slider
		etiquetas_porcentaje[bus] = pct

		fila.add_child(lbl)
		fila.add_child(slider)
		fila.add_child(pct)
		tab_audio.add_child(fila)

	# --- PESTAÑA CONTROLES ---
	var tab_controles := HBoxContainer.new()
	tab_controles.name = "🎮 Controles"
	tab_controles.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_controles.add_theme_constant_override("separation", 100)
	pestanas.add_child(tab_controles)

	for prefijo in ["p1", "p2"]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 20)

		var subtitulo := Label.new()
		subtitulo.text = "— JUGADOR " + prefijo.substr(1) + " —"
		subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(subtitulo)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 32)
		grid.add_theme_constant_override("v_separation", 16)

		for accion in CONTROLES_DEFECTO:
			if not accion.begins_with(prefijo):
				continue
			var lbl := Label.new()
			lbl.text = CONTROLES_DEFECTO[accion][0]
			grid.add_child(lbl)

			var btn := Button.new()
			btn.custom_minimum_size = Vector2(240, 56)
			btn.text = _obtener_nombre_tecla(accion)
			btn.pressed.connect(func():
				_actualizar_botones_teclas()
				accion_esperando = accion
				btn.text = "⏳ Pulsa tecla..."
			)
			botones_teclas[accion] = btn
			grid.add_child(btn)

		col.add_child(grid)
		tab_controles.add_child(col)

	# --- BOTONES INFERIORES ---
	var fila_botones := HBoxContainer.new()
	fila_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_botones.add_theme_constant_override("separation", 40)
	caja.add_child(fila_botones)

	var btn_reset := Button.new()
	btn_reset.text = "🔄 RESTABLECER CONTROLES"
	btn_reset.custom_minimum_size = Vector2(440, 72)
	btn_reset.pressed.connect(_restablecer_controles)
	fila_botones.add_child(btn_reset)

	var btn_volver := Button.new()
	btn_volver.text = "⬅️ VOLVER"
	btn_volver.custom_minimum_size = Vector2(300, 72)
	btn_volver.pressed.connect(_volver_al_menu)
	fila_botones.add_child(btn_volver)

func _volver_al_menu() -> void:
	_guardar_datos()
	var datos := get_node_or_null("/root/DatosGlobales")
	if datos != null and datos.has_method("cambiar_estado"):
		datos.cambiar_estado(datos.AppState.MENU_PRINCIPAL, ESCENA_MENU_PRINCIPAL)
	elif ResourceLoader.exists(ESCENA_MENU_PRINCIPAL):
		get_tree().change_scene_to_file(ESCENA_MENU_PRINCIPAL)
	else:
		push_error("No se encuentra la escena en la ruta: " + ESCENA_MENU_PRINCIPAL)

func _input(event: InputEvent) -> void:
	if accion_esperando == "":
		# ESC sin reasignar ninguna tecla = volver
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_volver_al_menu()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode != KEY_ESCAPE:
			_asignar_tecla(accion_esperando, event.physical_keycode)
			_guardar_datos()
		accion_esperando = ""
		_actualizar_botones_teclas()

func _cambiar_volumen(bus_nombre: String, valor: float) -> void:
	var idx := AudioServer.get_bus_index(bus_nombre)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(valor))
		AudioServer.set_bus_mute(idx, valor <= 0.001)

func _asignar_tecla(accion: String, codigo_fisico: Key) -> void:
	InputMap.action_erase_events(accion)
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo_fisico
	InputMap.action_add_event(accion, ev)

func _obtener_nombre_tecla(accion: String) -> String:
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventKey:
			var codigo: Key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
			return OS.get_keycode_string(codigo)
	return "Sin tecla"

func _actualizar_botones_teclas() -> void:
	for accion in botones_teclas:
		botones_teclas[accion].text = _obtener_nombre_tecla(accion)

func _restablecer_controles() -> void:
	accion_esperando = ""
	for accion in CONTROLES_DEFECTO:
		_asignar_tecla(accion, CONTROLES_DEFECTO[accion][1])
	_actualizar_botones_teclas()
	_guardar_datos()

func _guardar_datos() -> void:
	var cfg := ConfigFile.new()
	for bus in sliders_audio:
		cfg.set_value("audio", bus, sliders_audio[bus].value)
	for accion in CONTROLES_DEFECTO:
		for ev in InputMap.action_get_events(accion):
			if ev is InputEventKey:
				cfg.set_value("controles", accion, ev.physical_keycode)
	cfg.save(RUTA_GUARDADO)

func _cargar_datos() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_GUARDADO) != OK:
		return
	for bus in sliders_audio:
		var val: float = cfg.get_value("audio", bus, 1.0)
		sliders_audio[bus].value = val
		etiquetas_porcentaje[bus].text = "%d%%" % int(val * 100.0)
		_cambiar_volumen(bus, val)
	for accion in CONTROLES_DEFECTO:
		var codigo = cfg.get_value("controles", accion, CONTROLES_DEFECTO[accion][1])
		_asignar_tecla(accion, codigo)
	_actualizar_botones_teclas()
