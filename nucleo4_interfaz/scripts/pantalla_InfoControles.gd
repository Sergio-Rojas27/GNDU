extends Control

# Se emite cuando la pantalla se cierra estando como overlay (p. ej. sobre el menú de pausa)
signal cerrada

# Ruta a la que regresa si se abrió como escena independiente
const RUTA_RETORNO := "res://nucleo4_interfaz/scenes/Menu_Principal.tscn"
const RUTA_GUARDADO := "user://configuracion.cfg"

# Recursos pixel art del proyecto (si alguno no existe se usan cajas planas cuadradas)
const RUTA_FUENTE := "res://assets/General/VCR_OSD_MONO_1.001.ttf"
const RUTA_BOTON := "res://assets/General/boton.png"
const RUTA_BOTON_HOVER := "res://assets/General/botonHover.png"
const RUTA_BOTON_PRESSED := "res://assets/General/botonPressed.png"
const RUTA_PANEL := "res://assets/General/Cuadrado.png"

# Misma tabla que en MenuConfiguracion.gd: [nombre, tecla principal, tecla extra fija]
const CONTROLES_DEFECTO := {
	"p1_left": ["Izquierda", KEY_A, KEY_NONE],
	"p1_right": ["Derecha", KEY_D, KEY_NONE],
	"p1_up": ["Arriba / Salto", KEY_W, KEY_SPACE],
	"p1_down": ["Abajo", KEY_S, KEY_NONE],
	"p1_punch": ["Puño", KEY_F, KEY_NONE],
	"p1_kick": ["Patada", KEY_G, KEY_NONE],
	"p1_block": ["Bloqueo", KEY_H, KEY_NONE],
	"p2_left": ["Izquierda", KEY_LEFT, KEY_NONE],
	"p2_right": ["Derecha", KEY_RIGHT, KEY_NONE],
	"p2_up": ["Arriba / Salto", KEY_UP, KEY_NONE],
	"p2_down": ["Abajo", KEY_DOWN, KEY_NONE],
	"p2_punch": ["Puño", KEY_J, KEY_NONE],
	"p2_kick": ["Patada", KEY_K, KEY_NONE],
	"p2_block": ["Bloqueo", KEY_L, KEY_NONE],
}

# Botones del mando (J1 = mando 0, J2 = mando 1; misma distribución). Clave = acción sin "p1_"/"p2_"
const MANDO := {
	"left": "D-pad izq. / stick",
	"right": "D-pad der. / stick",
	"up": "D-pad arr. / stick / X / Y",
	"down": "D-pad aba. / stick",
	"punch": "A (sur)",
	"kick": "B (este)",
	"block": "RB",
}

const RESOLUCION := Vector2(1920, 1080)
const COL_FONDO := Color("#0b0f1a")
const COL_TEXTO := Color("#ffffff")
const COL_ACENTO := Color("#f1c40f")
const COL_BORDE := Color("#55607a")
const COL_CAJA := Color("#1d2638")
const COL_PANEL := Color("#2b3652")
const COL_SUAVE := Color("#9aa7c4")

# Si quien abre esta pantalla quiere volver a una escena concreta, puede asignarla antes
var ruta_retorno: String = ""

var lienzo: Control
var btn_volver: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # funciona también con el juego en pausa
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # 1920x1080
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST        # pixel art nítido
	_aplicar_estilo_visual()
	_construir_interfaz()
	btn_volver.call_deferred("grab_focus")

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

func _aplicar_estilo_visual() -> void:
	var tema := Theme.new()
	if ResourceLoader.exists(RUTA_FUENTE):
		tema.default_font = load(RUTA_FUENTE)
	tema.default_font_size = 26

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

	# El marco Cuadrado.png es blanco: se tiñe de azul oscuro para que el texto blanco se lea
	var panel := _caja_textura(RUTA_PANEL, COL_CAJA, COL_ACENTO)
	if panel is StyleBoxTexture:
		panel.modulate_color = COL_PANEL
	panel.content_margin_left = 56
	panel.content_margin_right = 56
	panel.content_margin_top = 52
	panel.content_margin_bottom = 52
	tema.set_stylebox("panel", "PanelContainer", panel)

	self.theme = tema

# ---------------------------------------------------------------- Interfaz

func _etiqueta(texto: String, tam: Vector2 = Vector2.ZERO, color: Color = COL_TEXTO, fuente: int = 26) -> Label:
	var l := Label.new()
	l.text = texto
	l.custom_minimum_size = tam
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", fuente)
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
	caja.add_theme_constant_override("separation", 26)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(caja)

	var titulo := _etiqueta("CONTROLES", Vector2.ZERO, COL_ACENTO, 64)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)

	var columnas := HBoxContainer.new()
	columnas.alignment = BoxContainer.ALIGNMENT_CENTER
	columnas.add_theme_constant_override("separation", 24)
	columnas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(columnas)

	var teclas := _cargar_teclas()
	columnas.add_child(_crear_panel_jugador("p1", teclas))
	columnas.add_child(_crear_panel_jugador("p2", teclas))

	btn_volver = Button.new()
	btn_volver.name = "BotonVolver"
	btn_volver.text = "VOLVER"
	btn_volver.custom_minimum_size = Vector2(340, 76)
	btn_volver.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_volver.focus_mode = Control.FOCUS_ALL
	btn_volver.mouse_filter = Control.MOUSE_FILTER_IGNORE # solo teclado
	btn_volver.pressed.connect(_on_volver_pressed)
	caja.add_child(btn_volver)

	var ayuda := _etiqueta("ESC o ENTER: volver   (las teclas se cambian en Configuración)", Vector2.ZERO, COL_SUAVE, 22)
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(ayuda)
	_ajustar_escala()

func _crear_panel_jugador(prefijo: String, teclas: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	var lbl_sub := _etiqueta("JUGADOR " + prefijo.substr(1) + " (teclado + mando)", Vector2.ZERO, COL_ACENTO, 32)
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lbl_sub)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)

	# Encabezados
	grid.add_child(_etiqueta("ACCIÓN", Vector2(210, 0), COL_SUAVE, 22))
	grid.add_child(_etiqueta("TECLADO", Vector2(190, 0), COL_SUAVE, 22))
	grid.add_child(_etiqueta("MANDO", Vector2(340, 0), COL_SUAVE, 22))

	for accion in CONTROLES_DEFECTO:
		if not accion.begins_with(prefijo):
			continue
		grid.add_child(_etiqueta(CONTROLES_DEFECTO[accion][0], Vector2(210, 44)))
		grid.add_child(_etiqueta(_texto_tecla(accion, teclas), Vector2(190, 44), COL_ACENTO))
		grid.add_child(_etiqueta(MANDO.get(accion.substr(3), ""), Vector2(340, 44), COL_TEXTO, 22))

	# Pausa (fija, no se puede cambiar)
	grid.add_child(_etiqueta("Pausa", Vector2(210, 44)))
	grid.add_child(_etiqueta("Esc", Vector2(190, 44), COL_ACENTO))
	grid.add_child(_etiqueta("Start", Vector2(340, 44), COL_TEXTO, 22))
	return panel

func _nombre_tecla(codigo: int) -> String:
	match codigo:
		KEY_SPACE: return "Espacio"
		KEY_UP: return "Flecha arr."
		KEY_DOWN: return "Flecha aba."
		KEY_LEFT: return "Flecha izq."
		KEY_RIGHT: return "Flecha der."
		KEY_NONE: return "Sin tecla"
	return OS.get_keycode_string(codigo as Key)

func _texto_tecla(accion: String, teclas: Dictionary) -> String:
	var texto := _nombre_tecla(teclas[accion])
	var extra: int = int(CONTROLES_DEFECTO[accion][2])
	if extra != KEY_NONE:
		texto += " / " + _nombre_tecla(extra)
	return texto

# Lee las teclas guardadas en Configuración (o las de por defecto)
func _cargar_teclas() -> Dictionary:
	var resultado := {}
	var cfg := ConfigFile.new()
	var ok := cfg.load(RUTA_GUARDADO) == OK
	for accion in CONTROLES_DEFECTO:
		var codigo: int = int(CONTROLES_DEFECTO[accion][1])
		if ok:
			codigo = int(cfg.get_value("controles", accion, codigo))
		resultado[accion] = codigo
	return resultado

# ---------------------------------------------------------------- Entrada (solo teclado)

func _input(event: InputEvent) -> void:
	# Se bloquean ratón y trackpad
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			_on_volver_pressed()

func _on_volver_pressed() -> void:
	# 1) Abierta como overlay (p. ej. sobre el menú de pausa): solo se cierra
	if get_tree().current_scene != self:
		cerrada.emit()
		queue_free()
		return

	# 2) Abierta como escena independiente: volver a la ruta indicada o al menú principal
	var destino := ruta_retorno if ruta_retorno != "" else RUTA_RETORNO
	var datos := get_node_or_null("/root/DatosGlobales")
	if ruta_retorno == "" and datos != null and datos.has_method("cambiar_estado"):
		datos.cambiar_estado(datos.AppState.MENU_PRINCIPAL, destino)
	elif ResourceLoader.exists(destino):
		get_tree().change_scene_to_file(destino)
	else:
		push_error("No se encontró la ruta de retorno: " + destino)
