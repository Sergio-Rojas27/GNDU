extends Control

# Ruta a la que regresará al presionar VOLVER
# (solo se usa si esta pantalla se abrió como escena independiente)
const RUTA_RETORNO := "res://nucleo4_interfaz/scenes/Menu_Principal.tscn"
const RUTA_GUARDADO := "user://configuracion.cfg"

# Misma tabla que en MenuConfiguracion.gd (nombre visible, tecla por defecto)
const CONTROLES_DEFECTO := {
	"p1_up": ["Arriba", KEY_W],
	"p1_down": ["Abajo", KEY_S],
	"p1_left": ["Izquierda", KEY_A],
	"p1_right": ["Derecha", KEY_D],
	"p1_action": ["Acción", KEY_SPACE],
	"p2_up": ["Arriba", KEY_UP],
	"p2_down": ["Abajo", KEY_DOWN],
	"p2_left": ["Izquierda", KEY_LEFT],
	"p2_right": ["Derecha", KEY_RIGHT],
	"p2_action": ["Acción", KEY_ENTER],
}

const COL_FONDO := Color("#121824")
const COL_PANEL := Color("#1a2332")
const COL_BORDE := Color("#2c3e50")
const COL_ACENTO := Color("#3498db")
const COL_ACENTO_HOVER := Color("#2980b9")
const COL_TEXTO := Color("#ecf0f1")

# Se emite cuando la pantalla se cierra estando como overlay (p. ej. sobre el menú de pausa)
signal cerrada

# Si quien abre esta pantalla quiere volver a una escena concreta (otra que no sea
# el menú principal), puede asignarla antes de añadirla: pantalla.ruta_retorno = "res://..."
var ruta_retorno: String = ""

var btn_volver: Button

func _ready() -> void:
	# Que funcione también con el juego en pausa
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Cubrir toda la pantalla (1920x1080 en el proyecto)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_construir_interfaz()
	btn_volver.call_deferred("grab_focus")

func _construir_interfaz() -> void:
	# Fondo opaco para que se vea siempre al seleccionarla
	var fondo := ColorRect.new()
	fondo.color = COL_FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 40)
	centro.add_child(caja)

	var titulo := Label.new()
	titulo.text = "🎮 CONTROLES"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 72)
	titulo.add_theme_color_override("font_color", COL_TEXTO)
	caja.add_child(titulo)

	var columnas := HBoxContainer.new()
	columnas.alignment = BoxContainer.ALIGNMENT_CENTER
	columnas.add_theme_constant_override("separation", 80)
	caja.add_child(columnas)

	for prefijo in ["p1", "p2"]:
		columnas.add_child(_crear_panel_jugador(prefijo))

	var pista := Label.new()
	pista.text = "Puedes cambiar las teclas en Configuración  •  ESC para volver"
	pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pista.add_theme_font_size_override("font_size", 26)
	pista.add_theme_color_override("font_color", Color(COL_TEXTO, 0.6))
	caja.add_child(pista)

	btn_volver = Button.new()
	btn_volver.name = "BotonVolver"
	btn_volver.text = "⬅️ VOLVER"
	btn_volver.custom_minimum_size = Vector2(320, 80)
	btn_volver.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_volver.add_theme_font_size_override("font_size", 32)
	btn_volver.add_theme_color_override("font_color", COL_TEXTO)
	btn_volver.add_theme_color_override("font_hover_color", COL_TEXTO)
	btn_volver.add_theme_color_override("font_focus_color", COL_TEXTO)
	btn_volver.add_theme_stylebox_override("normal", _estilo_boton(COL_BORDE))
	btn_volver.add_theme_stylebox_override("hover", _estilo_boton(COL_ACENTO_HOVER))
	btn_volver.add_theme_stylebox_override("pressed", _estilo_boton(COL_ACENTO_HOVER))
	btn_volver.add_theme_stylebox_override("focus", _estilo_boton(COL_ACENTO))
	btn_volver.pressed.connect(_on_volver_pressed)
	caja.add_child(btn_volver)

func _crear_panel_jugador(prefijo: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 520)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COL_PANEL
	estilo.border_color = COL_ACENTO
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", estilo)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	panel.add_child(col)

	var sub := Label.new()
	sub.text = "— JUGADOR " + prefijo.substr(1) + " —"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 40)
	sub.add_theme_color_override("font_color", COL_ACENTO)
	col.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 18)
	col.add_child(grid)

	var teclas := _cargar_teclas()
	for accion in CONTROLES_DEFECTO:
		if not accion.begins_with(prefijo):
			continue
		var lbl := Label.new()
		lbl.text = CONTROLES_DEFECTO[accion][0]
		lbl.custom_minimum_size = Vector2(240, 0)
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.add_theme_color_override("font_color", COL_TEXTO)
		grid.add_child(lbl)

		var tecla := Label.new()
		tecla.text = OS.get_keycode_string(teclas[accion])
		tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tecla.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tecla.custom_minimum_size = Vector2(200, 56)
		tecla.add_theme_font_size_override("font_size", 30)
		tecla.add_theme_color_override("font_color", COL_TEXTO)
		var caja_tecla := StyleBoxFlat.new()
		caja_tecla.bg_color = COL_BORDE
		caja_tecla.border_color = COL_ACENTO
		caja_tecla.set_border_width_all(2)
		caja_tecla.set_corner_radius_all(8)
		tecla.add_theme_stylebox_override("normal", caja_tecla)
		grid.add_child(tecla)
	return panel

func _estilo_boton(color: Color) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = color
	e.border_color = COL_ACENTO
	e.set_border_width_all(2)
	e.set_corner_radius_all(8)
	return e

# Lee las teclas guardadas en Configuración (o las de por defecto)
func _cargar_teclas() -> Dictionary:
	var resultado := {}
	var cfg := ConfigFile.new()
	var ok := cfg.load(RUTA_GUARDADO) == OK
	for accion in CONTROLES_DEFECTO:
		var codigo: int = CONTROLES_DEFECTO[accion][1]
		if ok:
			codigo = int(cfg.get_value("controles", accion, codigo))
		resultado[accion] = codigo
	return resultado

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_volver_pressed()

func _on_volver_pressed() -> void:
	# 1) Abierta como overlay (instanciada encima de otra pantalla, p. ej. el menú de pausa):
	#    solo se cierra y queda visible lo que había debajo.
	if get_tree().current_scene != self:
		cerrada.emit()
		queue_free()
		return

	# 2) Abierta como escena independiente: volver a la ruta indicada o al menú principal.
	var destino := ruta_retorno if ruta_retorno != "" else RUTA_RETORNO
	var datos := get_node_or_null("/root/DatosGlobales")
	if ruta_retorno == "" and datos != null and datos.has_method("cambiar_estado"):
		datos.cambiar_estado(datos.AppState.MENU_PRINCIPAL, destino)
	elif ResourceLoader.exists(destino):
		get_tree().change_scene_to_file(destino)
	else:
		push_error("No se encontró la ruta de retorno: " + destino)
