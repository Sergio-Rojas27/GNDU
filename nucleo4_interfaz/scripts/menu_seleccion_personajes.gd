extends Control

signal on_match_start
# Catálogos de luchadores (Profesores y Estudiantes)
var profesores_catalog: Array[Dictionary] = [
	{
		"id": "profesor_mara",
		"name": "profesor_mara",
		"icon_path": "res://assets/fighters/profesor_mara/portrait.png",
		"preview_path": "res://assets/fighters/profesor_mara/preview.png"
	}
	]
	

var estudiantes_catalog: Array[Dictionary] = [
	{
		"id": "estudiante_maria",
		"name": "estudiante_maria",
		"icon_path": "res://assets/Fighters/estudiante_maria/portrait.png",
		"preview_path": "res://assets/Fighters/estudiante_maria/preview.png"
	}
]

# Lista unificada para la navegación por índices
var total_fighters: Array[Dictionary] = []

# Índices de selección para cada jugador
var p1_index: int = 0
var p2_index: int = 0

# Estado de la selección
var p1_fighter_id: String = ""
var p2_fighter_id: String = ""

var p1_confirmed: bool = false
var p2_confirmed: bool = false

var p1_pending_id: String = ""
var p2_pending_id: String = ""

# Referencias directas a los nodos UI de la escena
@onready var main_title_label: Label = $MarginContainer/VBoxContainer/Label
@onready var instructions_label: Label = $MarginContainer/VBoxContainer/MarginContainer/Label

# Jugador 1 (Izquierda)
@onready var p1_preview: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer/Control/TextureRect
@onready var p1_name_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/Control/Label

# Jugador 2 (Derecha)
@onready var p2_preview: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer/Control2/TextureRect
@onready var p2_name_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/Control2/Label

# Grillas de selección
@onready var profesores_grid: GridContainer = $MarginContainer/VBoxContainer/HBoxContainer/HBoxContainer/VBoxContainer/fondogrilla/GridContainer
@onready var estudiantes_grid: GridContainer = $MarginContainer/VBoxContainer/HBoxContainer/HBoxContainer/VBoxContainer2/fondogrilla2/GridContainer
@onready var cursor_p1: TextureRect = $CursorP1
var p1_eligiendo_en_grilla: bool = false
var all_buttons: Array[TextureButton] = []

func _ready() -> void:
	randomize()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	total_fighters.append_array(profesores_catalog)
	total_fighters.append_array(estudiantes_catalog)
	
	setup_grids()
	
	p1_index = 0
	p2_index = 0
	
	cursor_p1.visible = false
	if has_node("CursorP2"):
		$CursorP2.visible = false
	actualizar_vista_p1()
	
	# Validar el escenario persistido en DatosGlobales
	var stage_id = DatosGlobales.escenario_seleccionado_id
	var stage_name = DatosGlobales.escenario_seleccionado_nombre
	if stage_id != "":
		print("Escenario cargado desde DatosGlobales: ", stage_name, " (", stage_id, ")")
	else:
		DatosGlobales.escenario_seleccionado_id = "escenario_uni"

# Cantidad de columnas configurada en tu GridContainer (por ejemplo, 3)
const COLUMNAS_GRILLA: int = 3

func mover_indice_2d(indice_actual: int, direccion: String) -> int:
	var total := all_buttons.size()
	if total == 0:
		return 0
		
	var nuevo_indice := indice_actual
	
	match direccion:
		"IZQUIERDA":
			nuevo_indice = wrapi(indice_actual - 1, 0, total)
		"DERECHA":
			nuevo_indice = wrapi(indice_actual + 1, 0, total)
		"ARRIBA":
			nuevo_indice = indice_actual - COLUMNAS_GRILLA
			if nuevo_indice < 0:
				nuevo_indice = wrapi(nuevo_indice, 0, total) # Da la vuelta hacia abajo
		"ABAJO":
			nuevo_indice = indice_actual + COLUMNAS_GRILLA
			if nuevo_indice >= total:
				nuevo_indice = wrapi(nuevo_indice, 0, total) # Da la vuelta hacia arriba
				
	return nuevo_indice
	
func setup_grids() -> void:
	for child in profesores_grid.get_children():
		child.queue_free()
	for child in estudiantes_grid.get_children():
		child.queue_free()
	all_buttons.clear()
		
	for fighter in profesores_catalog:
		var btn := crear_boton_luchador(fighter)
		profesores_grid.add_child(btn)
		all_buttons.append(btn)
		
	for fighter in estudiantes_catalog:
		var btn := crear_boton_luchador(fighter)
		estudiantes_grid.add_child(btn)
		all_buttons.append(btn)

func mover_cursor_p1() -> void:
	# 1. Si P1 ya confirmó o no hay botones, ocultar el cursor inmediatamente
	if p1_confirmed or all_buttons.is_empty():
		cursor_p1.visible = false
		return

	# 2. Verificar que el índice esté dentro del rango de la grilla
	if p1_index >= 0 and p1_index < all_buttons.size():
		var target_btn: TextureButton = all_buttons[p1_index]
		
		# Solo mostrar si la bandera de selección en grilla está activa
		cursor_p1.visible = p1_eligiendo_en_grilla
		cursor_p1.size = target_btn.size
		
		var tween := create_tween()
		tween.tween_property(cursor_p1, "global_position", target_btn.global_position, 0.08)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
	else:
		cursor_p1.visible = false

# Si usas cursor para P2
func mover_cursor_p2() -> void:
	if not has_node("CursorP2"): return
	var cursor_p2 = $CursorP2

	# P2 solo ve su cursor cuando P1 ya confirmó y P2 aún no
	if not p1_confirmed or p2_confirmed or all_buttons.is_empty():
		cursor_p2.visible = false
		return

	cursor_p2.visible = true
	var target_btn: TextureButton = all_buttons[p2_index]
	cursor_p2.size = target_btn.size

	var tween := create_tween()
	tween.tween_property(cursor_p2, "global_position", target_btn.global_position, 0.08)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
		
func crear_boton_luchador(fighter_data: Dictionary) -> TextureButton:
	var btn := TextureButton.new()
	btn.custom_minimum_size = Vector2(100, 100)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.focus_mode = Control.FOCUS_NONE
	btn.texture_normal = load_texture(fighter_data["icon_path"])
	return btn

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	var key_event := event as InputEventKey

	# --- TURNO JUGADOR 1 (W/A/S/D + Espacio) ---
	if not p1_confirmed:
		var movio := false
		
		if key_event.keycode == KEY_D:
			p1_index = mover_indice_2d(p1_index, "DERECHA")
			movio = true
		elif key_event.keycode == KEY_A:
			p1_index = mover_indice_2d(p1_index, "IZQUIERDA")
			movio = true
		elif key_event.keycode == KEY_W:
			p1_index = mover_indice_2d(p1_index, "ARRIBA")
			movio = true
		elif key_event.keycode == KEY_S:
			p1_index = mover_indice_2d(p1_index, "ABAJO")
			movio = true
		elif key_event.keycode == KEY_SPACE:
			confirmar_p1()
			marcar_entrada_manejada()

		if movio:
			p1_eligiendo_en_grilla = true
			p1_pending_id = ""
			actualizar_vista_p1()
			marcar_entrada_manejada()

	# --- TURNO JUGADOR 2 (Flechas + Enter) ---
	elif p1_confirmed and not p2_confirmed:
		var movio := false
		
		if key_event.keycode == KEY_RIGHT:
			p2_index = mover_indice_2d(p2_index, "DERECHA")
			movio = true
		elif key_event.keycode == KEY_LEFT:
			p2_index = mover_indice_2d(p2_index, "IZQUIERDA")
			movio = true
		elif key_event.keycode == KEY_UP:
			p2_index = mover_indice_2d(p2_index, "ARRIBA")
			movio = true
		elif key_event.keycode == KEY_DOWN:
			p2_index = mover_indice_2d(p2_index, "ABAJO")
			movio = true
		elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			confirmar_p2()
			marcar_entrada_manejada()

		if movio:
			p2_pending_id = ""
			actualizar_vista_p2()
			marcar_entrada_manejada()

# Función auxiliar para consumir la entrada de forma segura sin romper la transición
func marcar_entrada_manejada() -> void:
	if is_inside_tree() and get_viewport():
		get_viewport().set_input_as_handled()

func actualizar_vista_p1() -> void:
	var fighter = total_fighters[p1_index]
	p1_name_label.text = "P1: " + fighter["name"]
	p1_preview.texture = load_texture(fighter["preview_path"])
	
	if not p1_confirmed:
		p2_name_label.text = "P2: Esperando a P1..."
		instructions_label.text = "Turno de Jugador 1 (A/D + Espacio)"
		
	mover_cursor_p1()

func actualizar_vista_p2() -> void:
	var fighter = total_fighters[p2_index]
	p2_name_label.text = "P2: " + fighter["name"]
	p2_preview.texture = load_texture(fighter["preview_path"])
	instructions_label.text = "Turno de Jugador 2 (Flechas + Enter)"

func confirmar_p1() -> void:
	var current_fighter = total_fighters[p1_index]
	var target_id = current_fighter["id"]
	
	if p1_pending_id == target_id:
		# Segundo Espacio -> Confirmar P1 y activar P2
		if "random" in target_id:
			p1_fighter_id = obtener_random()
		else:
			p1_fighter_id = target_id
			
		p1_confirmed = true
		p1_name_label.text = "P1: " + current_fighter["name"] + " [LISTO]"
		print("P1 Confirmado: ", p1_fighter_id)
		
		# Activar la interfaz de P2
		actualizar_vista_p2()
	else:
		p1_pending_id = target_id
		instructions_label.text = "P1: Presione Espacio nuevamente para confirmar a " + current_fighter["name"]

func confirmar_p2() -> void:
	var current_fighter = total_fighters[p2_index]
	var target_id = current_fighter["id"]
	
	if p2_pending_id == target_id:
		if "random" in target_id:
			p2_fighter_id = obtener_random()
		else:
			p2_fighter_id = target_id
			
		p2_confirmed = true
		
		# 1. Guardar en Autoload
		DatosGlobales.p1_fighter_id = p1_fighter_id
		DatosGlobales.p2_fighter_id = p2_fighter_id
		
		# 2. Emitir JSON en consola
		emitir_evento_match_start()
		
		# 3. Cambiar inmediatamente a la escena de combate
		get_tree().change_scene_to_file("res://nucleo4_interfaz/scenes/pantalla_combate.tscn")
	else:
		p2_pending_id = target_id
		instructions_label.text = "P2: Presione Enter nuevamente para confirmar a " + current_fighter["name"]

func emitir_evento_match_start() -> void:
	var match_data: Dictionary = {
		"event_name": "on_match_start",
		"source_core": "nucleo4_interfaz",
		"frame": 0,
		"data": {
			"player_1_fighter_id": DatosGlobales.p1_fighter_id,
			"player_2_fighter_id": DatosGlobales.p2_fighter_id,
			"stage_id": DatosGlobales.escenario_seleccionado_id,
			"round_time": 99,
			"rounds_to_win": 2
		}
	}
	
	# 1. Impresión en consola (para verificación visual)
	print("\n==============================================")
	print("--- EMITIENDO EVENTO GLOBAL: on_match_start ---")
	print(JSON.stringify(match_data, "\t"))
	print("==============================================\n")
	
	# 2. Emisión real al bus (para que Núcleo 3 y Núcleo 5 reciban el Diccionario)
	if Engine.has_singleton("EventBus") or get_node_or_null("/nucleo4_interfaz/EventBus"):
		get_node("/nucleo4_interfaz/EventBus").emit_signal("on_match_start", match_data)

func obtener_random() -> String:
	var validos: Array[Dictionary] = []
	for item in total_fighters:
		if not "random" in item["id"]:
			validos.append(item)
	if validos.size() > 0:
		return validos[randi() % validos.size()]["id"]
	return "estudiante_juan"

func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	
	var fallback := GradientTexture2D.new()
	fallback.width = 120
	fallback.height = 120
	var grad := Gradient.new()
	grad.set_color(0, Color(0.15, 0.2, 0.3))
	fallback.gradient = grad
	return fallback
