extends Control

const ESCENA_MENU_PRINCIPAL := "res://nucleo4_interfaz/scenes/Menu_Principal.tscn"
const RUTA_GUARDADO := "user://configuracion.cfg"

# Recursos pixel art del proyecto (si alguno no existe se usan cajas planas cuadradas)
const RUTA_FUENTE := "res://assets/General/VCR_OSD_MONO_1.001.ttf"
const RUTA_BOTON := "res://assets/General/boton.png"
const RUTA_BOTON_HOVER := "res://assets/General/botonHover.png"
const RUTA_BOTON_PRESSED := "res://assets/General/botonPressed.png"
const RUTA_PANEL := "res://assets/General/Cuadrado.png"

# accion: [nombre visible, tecla principal (reasignable), tecla extra fija (KEY_NONE = ninguna)]
const CONTROLES_DEFECTO := {
	"p1_left": ["Izquierda", KEY_A, KEY_NONE],
	"p1_right": ["Derecha", KEY_D, KEY_NONE],
	"p1_up": ["Arriba", KEY_W, KEY_NONE],
	"p1_down": ["Abajo", KEY_S, KEY_NONE],
	"p1_jump": ["Salto", KEY_SPACE, KEY_NONE],
	"p1_punch": ["Puño", KEY_H, KEY_NONE],
	"p1_kick": ["Patada", KEY_J, KEY_NONE],
	"p1_block": ["Bloqueo", KEY_K, KEY_NONE],
	"p1_grab": ["Agarre", KEY_L, KEY_NONE],
	"p2_left": ["Izquierda", KEY_LEFT, KEY_NONE],
	"p2_right": ["Derecha", KEY_RIGHT, KEY_NONE],
	"p2_up": ["Arriba", KEY_UP, KEY_NONE],
	"p2_down": ["Abajo", KEY_DOWN, KEY_NONE],
	"p2_jump": ["Salto", KEY_SLASH, KEY_NONE],
	"p2_punch": ["Puño", KEY_SHIFT, KEY_NONE],
	"p2_kick": ["Patada", KEY_ENTER, KEY_NONE],
	"p2_block": ["Bloqueo", KEY_CTRL, KEY_NONE],
	"p2_grab": ["Agarre", KEY_ALT, KEY_NONE],
}

const ACCION_A_N2 := {
	"p1_left": [1, "left", "p1_izquierda"],
	"p1_right": [1, "right", "p1_derecha"],
	"p1_up": [1, "up", "p1_arriba"],
	"p1_down": [1, "down", "p1_agachar"],
	"p1_jump": [1, "jump", "p1_salto"],
	"p1_punch": [1, "punch", "p1_puno"],
	"p1_kick": [1, "kick", "p1_patada"],
	"p1_block": [1, "block", "p1_bloquear"],
	"p1_grab": [1, "grab", "p1_agarre"],
	"p2_left": [2, "left", "p2_izquierda"],
	"p2_right": [2, "right", "p2_derecha"],
	"p2_up": [2, "up", "p2_arriba"],
	"p2_down": [2, "down", "p2_agachar"],
	"p2_jump": [2, "jump", "p2_salto"],
	"p2_punch": [2, "punch", "p2_puno"],
	"p2_kick": [2, "kick", "p2_patada"],
	"p2_block": [2, "block", "p2_bloquear"],
	"p2_grab": [2, "grab", "p2_agarre"],
}

const RESOLUCION := Vector2(1920, 1080)
const COL_FONDO := Color("#0b0f1a")
const COL_TEXTO := Color("#ffffff")
const COL_ACENTO := Color("#f1c40f")
const COL_BORDE := Color("#55607a")
const COL_CAJA := Color("#1d2638")
const COL_PANEL := Color("#2b3652")
const COL_SUAVE := Color("#9aa7c4")
const PASO_VOLUMEN := 0.05

var lienzo: Control
var accion_esperando := ""
var cargando := false
var teclas := {} # accion -> tecla principal actual
var botones_teclas := {}
var sliders_audio := {}
var etiquetas_porcentaje := {}

var botones_tab: Array = []
var paginas: Array = []
var tab_actual := 0
var btn_reset: Button
var btn_volver: Button

# Navegación con teclado: filas[fila][columna] = control enfocable
var filas: Array = []
var fila_i := 0
var col_i := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # 1920x1080
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST        # pixel art nítido
	_inicializar_acciones()
	_aplicar_estilo_visual()
	_construir_interfaz()
	_cargar_datos()
	_mostrar_tab(0)
	_enfocar.call_deferred()

# ---------------------------------------------------------------- Acciones

func _inicializar_acciones() -> void:
	for accion in CONTROLES_DEFECTO:
		teclas[accion] = int(CONTROLES_DEFECTO[accion][1])
		if not InputMap.has_action(accion):
			InputMap.add_action(accion)

# Cambia solo las teclas de teclado de la acción (no toca los botones de mando)
func _asignar_tecla(accion: String, codigo: int) -> void:
	for viejo in InputMap.action_get_events(accion):
		if viejo is InputEventKey:
			InputMap.action_erase_event(accion, viejo)
	var principal := InputEventKey.new()
	principal.physical_keycode = codigo as Key
	InputMap.action_add_event(accion, principal)
	var extra: int = int(CONTROLES_DEFECTO[accion][2])
	if extra != KEY_NONE:
		var ev_extra := InputEventKey.new()
		ev_extra.physical_keycode = extra as Key
		InputMap.action_add_event(accion, ev_extra)

	if ACCION_A_N2.has(accion):
		var meta: Array = ACCION_A_N2[accion]
		var pid: int = int(meta[0])
		var n2_act: String = str(meta[1])
		var imap_act: String = str(meta[2])
		if InputMap.has_action(imap_act):
			for viejo in InputMap.action_get_events(imap_act):
				if viejo is InputEventKey:
					InputMap.action_erase_event(imap_act, viejo)
			var ev_n3 := InputEventKey.new()
			ev_n3.physical_keycode = codigo as Key
			InputMap.action_add_event(imap_act, ev_n3)
		var n2_cfg := get_node_or_null("/root/N2ControlsConfig")
		if n2_cfg and "data" in n2_cfg:
			var p_str := str(pid)
			if n2_cfg.data.has("players") and n2_cfg.data["players"].has(p_str):
				var bindings: Dictionary = n2_cfg.data["players"][p_str].get("bindings", {})
				if bindings.has(n2_act) and bindings[n2_act] is Array:
					var key_str := OS.get_keycode_string(codigo as Key)
					var nuevos_sources: Array = [{"type": "key", "code": key_str}]
					for src in bindings[n2_act]:
						if src is Dictionary and str(src.get("type", "")) != "key":
							nuevos_sources.append(src)
					bindings[n2_act] = nuevos_sources

func _reasignar(accion: String, codigo: int) -> void:
	if codigo == KEY_NONE:
		return
	# Si otra acción del mismo jugador ya usa esa tecla, se intercambian
	var prefijo := accion.substr(0, 3)
	for otra in CONTROLES_DEFECTO:
		if otra != accion and otra.begins_with(prefijo) and teclas[otra] == codigo:
			teclas[otra] = teclas[accion]
			_asignar_tecla(otra, teclas[otra])
	teclas[accion] = codigo
	_asignar_tecla(accion, codigo)
	_guardar_datos()

func _nombre_tecla(codigo: int) -> String:
	match codigo:
		KEY_SPACE: return "Espacio"
		KEY_UP: return "Flecha arr."
		KEY_DOWN: return "Flecha aba."
		KEY_LEFT: return "Flecha izq."
		KEY_RIGHT: return "Flecha der."
		KEY_SLASH: return "/"
		KEY_ENTER, KEY_KP_ENTER: return "Enter"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_NONE: return "Sin tecla"
	return OS.get_keycode_string(codigo as Key)

func _texto_tecla(accion: String) -> String:
	var texto := _nombre_tecla(teclas[accion])
	var extra: int = int(CONTROLES_DEFECTO[accion][2])
	if extra != KEY_NONE:
		texto += " / " + _nombre_tecla(extra)
	return texto

# ---------------------------------------------------------------- Estilo pixel art

func _caja_plana(bg: Color, borde: Color) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = bg
	e.border_color = borde
	e.set_border_width_all(4)
	e.set_corner_radius_all(0)
	e.anti_aliasing = false
	return e

func _caja_textura(ruta: String, bg: Color, borde: Color) -> StyleBox:
	if ResourceLoader.exists(ruta):
		var e := StyleBoxTexture.new()
		e.texture = load(ruta)
		return e
	return _caja_plana(bg, borde)

func _textura_color(ancho: int, alto: int, color: Color) -> ImageTexture:
	var img := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _aplicar_estilo_visual() -> void:
	var tema := Theme.new()
	if ResourceLoader.exists(RUTA_FUENTE):
		tema.default_font = load(RUTA_FUENTE)
	tema.default_font_size = 28

	# Botones (mismas texturas que el menú de pausa)
	var normal := _caja_textura(RUTA_BOTON, COL_CAJA, COL_BORDE)
	var hover := _caja_textura(RUTA_BOTON_HOVER, COL_BORDE, COL_ACENTO)
	var presionado := _caja_textura(RUTA_BOTON_PRESSED, COL_BORDE, COL_ACENTO)
	tema.set_stylebox("normal", "Button", normal)
	tema.set_stylebox("hover", "Button", hover)
	tema.set_stylebox("pressed", "Button", presionado)
	tema.set_stylebox("focus", "Button", hover)
	tema.set_color("font_color", "Button", COL_TEXTO)
	tema.set_color("font_hover_color", "Button", COL_ACENTO)
	tema.set_color("font_focus_color", "Button", COL_ACENTO)
	tema.set_color("font_pressed_color", "Button", COL_ACENTO)
	tema.set_color("font_color", "Label", COL_TEXTO)

	# Panel
	# El marco Cuadrado.png es blanco: se tiñe de azul oscuro para que el texto blanco se lea
	var panel := _caja_textura(RUTA_PANEL, COL_CAJA, COL_ACENTO)
	if panel is StyleBoxTexture:
		panel.modulate_color = COL_PANEL
	panel.content_margin_left = 64
	panel.content_margin_right = 64
	panel.content_margin_top = 36
	panel.content_margin_bottom = 36
	tema.set_stylebox("panel", "PanelContainer", panel)

	# Sliders cuadrados
	var pista := _caja_plana(COL_CAJA, COL_BORDE)
	pista.set_content_margin_all(6)
	var relleno := _caja_plana(COL_ACENTO, COL_ACENTO)
	relleno.set_content_margin_all(6)
	var foco := _caja_plana(Color(0, 0, 0, 0), COL_ACENTO)
	foco.draw_center = false
	tema.set_stylebox("slider", "HSlider", pista)
	tema.set_stylebox("grabber_area", "HSlider", relleno)
	tema.set_stylebox("grabber_area_highlight", "HSlider", relleno)
	tema.set_stylebox("focus", "HSlider", foco)
	tema.set_icon("grabber", "HSlider", _textura_color(20, 44, COL_TEXTO))
	tema.set_icon("grabber_highlight", "HSlider", _textura_color(20, 44, COL_ACENTO))
	tema.set_icon("grabber_disabled", "HSlider", _textura_color(20, 44, COL_BORDE))

	self.theme = tema

# ---------------------------------------------------------------- Interfaz

func _crear_boton(texto: String, tam: Vector2) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = tam
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE # solo teclado
	return b

func _crear_etiqueta(texto: String, tam: Vector2 = Vector2.ZERO) -> Label:
	var l := Label.new()
	l.text = texto
	l.custom_minimum_size = tam
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _ajustar_escala() -> void:
	var vp := get_viewport_rect().size
	var esc := minf(vp.x / RESOLUCION.x, vp.y / RESOLUCION.y)
	lienzo.scale = Vector2(esc, esc)
	lienzo.position = (vp - RESOLUCION * esc) / 2.0

func _construir_interfaz() -> void:
	var fondo := ColorRect.new()
	fondo.color = COL_FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	# Lienzo de diseño fijo 1920x1080: se escala para caber en cualquier tamaño de ventana
	lienzo = Control.new()
	lienzo.size = RESOLUCION
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lienzo)
	get_viewport().size_changed.connect(_ajustar_escala)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.add_child(centro)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 22)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(caja)

	var titulo := _crear_etiqueta("CONFIGURACIÓN")
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.add_theme_color_override("font_color", COL_ACENTO)
	caja.add_child(titulo)

	# --- Pestañas (botones) ---
	var fila_tabs := HBoxContainer.new()
	fila_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_tabs.add_theme_constant_override("separation", 30)
	caja.add_child(fila_tabs)
	for nombre in ["AUDIO", "CONTROLES"]:
		var bt := _crear_boton(nombre, Vector2(360, 72))
		botones_tab.append(bt)
		fila_tabs.add_child(bt)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1440, 680)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(panel)

	# --- Página AUDIO ---
	var tab_audio := VBoxContainer.new()
	tab_audio.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_audio.add_theme_constant_override("separation", 56)
	panel.add_child(tab_audio)
	paginas.append(tab_audio)

	for item in [["Master", "Volumen general"], ["Music", "Música"], ["SFX", "Efectos (SFX)"]]:
		var bus: String = item[0]
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 32)

		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = _volumen_actual(bus)
		slider.custom_minimum_size = Vector2(560, 44)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_ALL
		slider.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var pct := _crear_etiqueta("%d%%" % int(slider.value * 100.0), Vector2(120, 0))
		slider.value_changed.connect(func(val: float):
			_cambiar_volumen(bus, val)
			pct.text = "%d%%" % int(val * 100.0)
			_guardar_datos()
		)
		sliders_audio[bus] = slider
		etiquetas_porcentaje[bus] = pct

		fila.add_child(_crear_etiqueta(item[1], Vector2(360, 0)))
		fila.add_child(slider)
		fila.add_child(pct)
		tab_audio.add_child(fila)

	# --- Página CONTROLES ---
	var tab_controles := HBoxContainer.new()
	tab_controles.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_controles.add_theme_constant_override("separation", 80)
	panel.add_child(tab_controles)
	paginas.append(tab_controles)

	for prefijo in ["p1", "p2"]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 14)

		var sub := _crear_etiqueta("JUGADOR " + prefijo.substr(1))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_color_override("font_color", COL_ACENTO)
		sub.add_theme_font_size_override("font_size", 34)
		col.add_child(sub)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 6)

		for accion in CONTROLES_DEFECTO:
			if not accion.begins_with(prefijo):
				continue
			grid.add_child(_crear_etiqueta(CONTROLES_DEFECTO[accion][0], Vector2(250, 44)))

			var btn := _crear_boton(_texto_tecla(accion), Vector2(290, 44))
			btn.pressed.connect(func():
				_actualizar_botones_teclas()
				accion_esperando = accion
				btn.text = "Pulsa tecla..."
			)
			botones_teclas[accion] = btn
			grid.add_child(btn)
		col.add_child(grid)
		tab_controles.add_child(col)

	# --- Botones inferiores ---
	var fila_botones := HBoxContainer.new()
	fila_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_botones.add_theme_constant_override("separation", 40)
	caja.add_child(fila_botones)

	btn_reset = _crear_boton("RESTABLECER CONTROLES", Vector2(540, 76))
	btn_reset.pressed.connect(_restablecer_controles)
	fila_botones.add_child(btn_reset)

	btn_volver = _crear_boton("VOLVER", Vector2(320, 76))
	btn_volver.pressed.connect(_volver_al_menu)
	fila_botones.add_child(btn_volver)

	var ayuda := _crear_etiqueta("W/A/S/D o flechas: mover   ENTER/ESPACIO: elegir   ESC: volver")
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ayuda.add_theme_font_size_override("font_size", 22)
	ayuda.add_theme_color_override("font_color", COL_SUAVE)
	caja.add_child(ayuda)
	_ajustar_escala()

# ---------------------------------------------------------------- Navegación con teclado

func _mostrar_tab(i: int) -> void:
	tab_actual = i
	for p in paginas.size():
		paginas[p].visible = (p == i)
	for t in botones_tab.size():
		var color: Color = COL_ACENTO if t == i else COL_TEXTO
		botones_tab[t].add_theme_color_override("font_color", color)
		botones_tab[t].text = ("> %s <" if t == i else "%s") % ["AUDIO", "CONTROLES"][t]
	_reconstruir_filas()

func _reconstruir_filas() -> void:
	filas = [botones_tab]
	if tab_actual == 0:
		for bus in ["Master", "Music", "SFX"]:
			filas.append([sliders_audio[bus]])
	else:
		var a1: Array = []
		var a2: Array = []
		for accion in CONTROLES_DEFECTO:
			if accion.begins_with("p1"):
				a1.append(accion)
			else:
				a2.append(accion)
		for i in maxi(a1.size(), a2.size()):
			var fila: Array = []
			if i < a1.size():
				fila.append(botones_teclas[a1[i]])
			if i < a2.size():
				fila.append(botones_teclas[a2[i]])
			filas.append(fila)
	filas.append([btn_reset, btn_volver])
	fila_i = clampi(fila_i, 0, filas.size() - 1)
	col_i = clampi(col_i, 0, filas[fila_i].size() - 1)

func _enfocar() -> void:
	var ctl: Control = filas[fila_i][col_i]
	ctl.grab_focus()

func _mover(dx: int, dy: int) -> void:
	if dy != 0:
		if fila_i == 0 and dy > 0:
			col_i = 0
		fila_i = wrapi(fila_i + dy, 0, filas.size())
		col_i = mini(col_i, filas[fila_i].size() - 1)
	elif dx != 0:
		var ctl = filas[fila_i][col_i]
		if ctl is HSlider:
			ctl.value = clampf(ctl.value + dx * PASO_VOLUMEN, 0.0, 1.0)
			return
		col_i = wrapi(col_i + dx, 0, filas[fila_i].size())
		if fila_i == 0:
			_mostrar_tab(col_i)
	_enfocar()

func _activar() -> void:
	var ctl = filas[fila_i][col_i]
	if fila_i == 0:
		_mover(0, 1) # desde las pestañas, Enter baja al contenido
	elif ctl is Button:
		ctl.pressed.emit()

func _input(event: InputEvent) -> void:
	# Todo se maneja con el teclado: se bloquean ratón y trackpad
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed):
		return

	# Esperando una tecla nueva para reasignar
	if accion_esperando != "":
		if event.echo:
			return
		get_viewport().set_input_as_handled()
		if event.keycode != KEY_ESCAPE:
			_reasignar(accion_esperando, event.physical_keycode)
		accion_esperando = ""
		_actualizar_botones_teclas()
		return

	var horizontal: bool = event.keycode in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]
	if event.echo and not horizontal:
		return

	match event.keycode:
		KEY_W, KEY_UP:
			get_viewport().set_input_as_handled()
			_mover(0, -1)
		KEY_S, KEY_DOWN:
			get_viewport().set_input_as_handled()
			_mover(0, 1)
		KEY_A, KEY_LEFT:
			get_viewport().set_input_as_handled()
			_mover(-1, 0)
		KEY_D, KEY_RIGHT:
			get_viewport().set_input_as_handled()
			_mover(1, 0)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			get_viewport().set_input_as_handled()
			_activar()
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_volver_al_menu()

func _volver_al_menu() -> void:
	_guardar_datos()
	var datos := get_node_or_null("/root/DatosGlobales")
	if datos != null and datos.has_method("cambiar_estado"):
		datos.cambiar_estado(datos.AppState.MENU_PRINCIPAL, ESCENA_MENU_PRINCIPAL)
	elif ResourceLoader.exists(ESCENA_MENU_PRINCIPAL):
		get_tree().change_scene_to_file(ESCENA_MENU_PRINCIPAL)
	else:
		push_error("No se encuentra la escena en la ruta: " + ESCENA_MENU_PRINCIPAL)

# ---------------------------------------------------------------- Audio / datos

func _volumen_actual(bus_nombre: String) -> float:
	var idx := AudioServer.get_bus_index(bus_nombre)
	if idx == -1:
		return 1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)

func _cambiar_volumen(bus_nombre: String, valor: float) -> void:
	var idx := AudioServer.get_bus_index(bus_nombre)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(valor))
		AudioServer.set_bus_mute(idx, valor <= 0.001)

func _actualizar_botones_teclas() -> void:
	for accion in botones_teclas:
		botones_teclas[accion].text = _texto_tecla(accion)

func _restablecer_controles() -> void:
	accion_esperando = ""
	for accion in CONTROLES_DEFECTO:
		teclas[accion] = int(CONTROLES_DEFECTO[accion][1])
		_asignar_tecla(accion, teclas[accion])
	_actualizar_botones_teclas()
	_guardar_datos()

func _guardar_datos() -> void:
	if cargando:
		return
	var cfg := ConfigFile.new()
	for bus in sliders_audio:
		cfg.set_value("audio", bus, sliders_audio[bus].value)
	for accion in CONTROLES_DEFECTO:
		cfg.set_value("controles", accion, teclas[accion])
	cfg.save(RUTA_GUARDADO)

func _cargar_datos() -> void:
	cargando = true
	var cfg := ConfigFile.new()
	var hay_archivo := cfg.load(RUTA_GUARDADO) == OK
	if hay_archivo:
		for bus in sliders_audio:
			var val: float = float(cfg.get_value("audio", bus, sliders_audio[bus].value))
			sliders_audio[bus].value = val
			etiquetas_porcentaje[bus].text = "%d%%" % int(val * 100.0)
			_cambiar_volumen(bus, val)
		for accion in CONTROLES_DEFECTO:
			teclas[accion] = int(cfg.get_value("controles", accion, teclas[accion]))
	# Se aplican siempre (guardadas o por defecto) para que el InputMap quede coherente
	for accion in CONTROLES_DEFECTO:
		_asignar_tecla(accion, teclas[accion])
	_actualizar_botones_teclas()
	cargando = false
