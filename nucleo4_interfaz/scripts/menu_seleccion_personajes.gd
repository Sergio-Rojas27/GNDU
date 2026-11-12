extends Control

signal on_match_start

const SCAN_INTERVAL: float = 1.0 # Segundos entre cada escaneo en tiempo real
const COLUMNAS_GRILLA: int = 3

# Catálogos dinámicos de luchadores
var profesores_catalog: Array[Dictionary] = []
var estudiantes_catalog: Array[Dictionary] = []
var total_fighters: Array[Dictionary] = []

# Registro de carpetas conocidas para detectar cambios en tiempo real
var carpetas_conocidas: PackedStringArray = []
var scan_timer: Timer

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

var all_buttons: Array[TextureButton] = []

func _ready() -> void:
	randomize()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	# Carga inicial forzada
	refrescar_luchadores_si_hubo_cambios(true)
	
	# Configurar el temporizador para vigilar carpetas nuevas en ejecución
	iniciar_vigilancia_carpetas()
	
	# Validar el escenario persistido en DatosGlobales
	var stage_id: String = DatosGlobales.escenario_seleccionado_id
	var stage_name: String = DatosGlobales.escenario_seleccionado_nombre
	if stage_id != "":
		print("Escenario cargado desde DatosGlobales: ", stage_name, " (", stage_id, ")")
	else:
		DatosGlobales.escenario_seleccionado_id = "escenario_uni"

func iniciar_vigilancia_carpetas() -> void:
	scan_timer = Timer.new()
	scan_timer.wait_time = SCAN_INTERVAL
	scan_timer.autostart = true
	scan_timer.timeout.connect(_on_scan_timer_timeout)
	add_child(scan_timer)

func _on_scan_timer_timeout() -> void:
	refrescar_luchadores_si_hubo_cambios(false)

func obtener_ruta_real_fighters() -> String:
	if OS.has_feature("editor"):
		if DirAccess.dir_exists_absolute("res://assets/fighters"):
			return "res://assets/fighters"
		elif DirAccess.dir_exists_absolute("res://assets/Fighters"):
			return "res://assets/Fighters"
		else:
			push_error("ERROR CRÍTICO: No existe ni 'res://assets/fighters' ni 'res://assets/Fighters'")
			return ""
	
	var base_exe: String = OS.get_executable_path().get_base_dir()
	if DirAccess.dir_exists_absolute(base_exe.path_join("fighters")):
		return base_exe.path_join("fighters")
	elif DirAccess.dir_exists_absolute(base_exe.path_join("Fighters")):
		return base_exe.path_join("Fighters")
	
	if DirAccess.dir_exists_absolute("res://assets/fighters"):
		return "res://assets/fighters"
	return "res://assets/Fighters"

func obtener_lista_carpetas_actuales(ruta_base: String) -> PackedStringArray:
	var resultado := PackedStringArray()
	if ruta_base == "":
		return resultado
		
	var dir := DirAccess.open(ruta_base)
	if dir == null:
		push_error("No se pudo abrir el directorio: " + ruta_base + " (Código error: " + str(DirAccess.get_open_error()) + ")")
		return resultado
		
	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		# Ignorar carpetas ocultas y la carpeta especial 'default'
		if dir.current_is_dir() and not folder_name.begins_with(".") and folder_name.to_lower() != "default":
			resultado.append(folder_name)
		folder_name = dir.get_next()
	dir.list_dir_end()
	
	resultado.sort()
	return resultado

func refrescar_luchadores_si_hubo_cambios(forzar: bool = false) -> void:
	var ruta_base: String = obtener_ruta_real_fighters()
	var carpetas_actuales: PackedStringArray = obtener_lista_carpetas_actuales(ruta_base)
	
	if not forzar and carpetas_actuales == carpetas_conocidas:
		return
	
	# Guardar los IDs seleccionados actualmente
	var id_actual_p1: String = total_fighters[p1_index]["id"] if not total_fighters.is_empty() and p1_index < total_fighters.size() else ""
	var id_actual_p2: String = total_fighters[p2_index]["id"] if not total_fighters.is_empty() and p2_index < total_fighters.size() else ""
	
	var hubo_cambios_reales: bool = forzar
	
	# 1. Eliminar solo los luchadores cuya carpeta fue borrada del disco
	for i in range(profesores_catalog.size() - 1, -1, -1):
		if not carpetas_actuales.has(profesores_catalog[i]["id"]):
			profesores_catalog.remove_at(i)
			hubo_cambios_reales = true
			
	for i in range(estudiantes_catalog.size() - 1, -1, -1):
		if not carpetas_actuales.has(estudiantes_catalog[i]["id"]):
			estudiantes_catalog.remove_at(i)
			hubo_cambios_reales = true
	
	# 2. Agregar las carpetas nuevas (incluso si no tienen portrait.png, usarán la silueta de /default/)
	var carpetas_validadas := PackedStringArray()
	
	for id_luchador in carpetas_actuales:
		if existe_en_catalogo(id_luchador):
			carpetas_validadas.append(id_luchador)
			continue
			
		var folder_path: String = ruta_base.path_join(id_luchador)
		var icon_path: String = folder_path.path_join("portrait.png")
		var preview_path: String = folder_path.path_join("preview.png")
		
		var fighter_entry: Dictionary = {
			"id": id_luchador,
			"name": formatear_nombre(id_luchador),
			"icon_path": icon_path,
			"preview_path": preview_path
		}
		
		if id_luchador.to_lower().begins_with("profesor"):
			profesores_catalog.append(fighter_entry)
		else:
			estudiantes_catalog.append(fighter_entry)
			
		carpetas_validadas.append(id_luchador)
		hubo_cambios_reales = true
	
	carpetas_conocidas = carpetas_validadas
	
	if not hubo_cambios_reales:
		return
		
	profesores_catalog.sort_custom(func(a, b): return a["id"] < b["id"])
	estudiantes_catalog.sort_custom(func(a, b): return a["id"] < b["id"])
	
	total_fighters.clear()
	total_fighters.append_array(profesores_catalog)
	total_fighters.append_array(estudiantes_catalog)
	
	setup_grids()
	
	p1_index = buscar_indice_por_id(id_actual_p1)
	p2_index = buscar_indice_por_id(id_actual_p2)
	
	if not total_fighters.is_empty():
		actualizar_vista_p1()
		actualizar_vista_p2()
		actualizar_instrucciones()

func existe_en_catalogo(id_luchador: String) -> bool:
	for p in profesores_catalog:
		if p["id"] == id_luchador:
			return true
	for e in estudiantes_catalog:
		if e["id"] == id_luchador:
			return true
	return false

func buscar_indice_por_id(fighter_id: String) -> int:
	if fighter_id == "" or total_fighters.is_empty():
		return 0
	for i in range(total_fighters.size()):
		if total_fighters[i]["id"] == fighter_id:
			return i
	return 0

func formatear_nombre(id_raw: String) -> String:
	return id_raw.replace("_", " ").capitalize()

func mover_indice_2d(indice_actual: int, direccion: String) -> int:
	var total: int = all_buttons.size()
	if total == 0:
		return 0
		
	var nuevo_indice: int = indice_actual
	
	match direccion:
		"IZQUIERDA":
			nuevo_indice = wrapi(indice_actual - 1, 0, total)
		"DERECHA":
			nuevo_indice = wrapi(indice_actual + 1, 0, total)
		"ARRIBA":
			nuevo_indice = indice_actual - COLUMNAS_GRILLA
			if nuevo_indice < 0:
				nuevo_indice = wrapi(nuevo_indice, 0, total)
		"ABAJO":
			nuevo_indice = indice_actual + COLUMNAS_GRILLA
			if nuevo_indice >= total:
				nuevo_indice = wrapi(nuevo_indice, 0, total)
				
	return nuevo_indice
	
func setup_grids() -> void:
	for child in profesores_grid.get_children():
		profesores_grid.remove_child(child)
		child.queue_free()
	for child in estudiantes_grid.get_children():
		estudiantes_grid.remove_child(child)
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
	if p1_confirmed or all_buttons.is_empty():
		cursor_p1.visible = false
		return

	if p1_index >= 0 and p1_index < all_buttons.size():
		var target_btn: TextureButton = all_buttons[p1_index]
		
		cursor_p1.visible = true
		cursor_p1.size = target_btn.size
		
		await get_tree().process_frame
		if not is_instance_valid(target_btn):
			return
			
		var tween := create_tween()
		tween.tween_property(cursor_p1, "global_position", target_btn.global_position, 0.08)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
	else:
		cursor_p1.visible = false

func mover_cursor_p2() -> void:
	if not has_node("CursorP2"):
		return
	var cursor_p2: TextureRect = $CursorP2

	if p2_confirmed or all_buttons.is_empty():
		cursor_p2.visible = false
		return

	if p2_index >= 0 and p2_index < all_buttons.size():
		var target_btn: TextureButton = all_buttons[p2_index]
		
		cursor_p2.visible = true
		cursor_p2.size = target_btn.size
		
		await get_tree().process_frame
		if not is_instance_valid(target_btn):
			return

		var tween := create_tween()
		tween.tween_property(cursor_p2, "global_position", target_btn.global_position, 0.08)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
	else:
		cursor_p2.visible = false
		
func crear_boton_luchador(fighter_data: Dictionary) -> TextureButton:
	var btn := TextureButton.new()
	btn.custom_minimum_size = Vector2(100, 100)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.focus_mode = Control.FOCUS_NONE
	btn.texture_normal = load_texture_runtime(fighter_data["icon_path"], "portrait.png")
	return btn

func _unhandled_input(event: InputEvent) -> void:
	if total_fighters.is_empty():
		return
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	var key_event := event as InputEventKey

	# --- CONTROLES SIMULTÁNEOS JUGADOR 1 (W/A/S/D + Espacio) ---
	if not p1_confirmed:
		var movio_p1 := false
		if key_event.keycode == KEY_D:
			p1_index = mover_indice_2d(p1_index, "DERECHA")
			movio_p1 = true
		elif key_event.keycode == KEY_A:
			p1_index = mover_indice_2d(p1_index, "IZQUIERDA")
			movio_p1 = true
		elif key_event.keycode == KEY_W:
			p1_index = mover_indice_2d(p1_index, "ARRIBA")
			movio_p1 = true
		elif key_event.keycode == KEY_S:
			p1_index = mover_indice_2d(p1_index, "ABAJO")
			movio_p1 = true
		elif key_event.keycode == KEY_SPACE:
			confirmar_p1()
			marcar_entrada_manejada()

		if movio_p1:
			p1_pending_id = ""
			actualizar_vista_p1()
			actualizar_instrucciones()
			marcar_entrada_manejada()

	# --- CONTROLES SIMULTÁNEOS JUGADOR 2 (Flechas + Enter) ---
	if not p2_confirmed:
		var movio_p2 := false
		if key_event.keycode == KEY_RIGHT:
			p2_index = mover_indice_2d(p2_index, "DERECHA")
			movio_p2 = true
		elif key_event.keycode == KEY_LEFT:
			p2_index = mover_indice_2d(p2_index, "IZQUIERDA")
			movio_p2 = true
		elif key_event.keycode == KEY_UP:
			p2_index = mover_indice_2d(p2_index, "ARRIBA")
			movio_p2 = true
		elif key_event.keycode == KEY_DOWN:
			p2_index = mover_indice_2d(p2_index, "ABAJO")
			movio_p2 = true
		elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			confirmar_p2()
			marcar_entrada_manejada()

		if movio_p2:
			p2_pending_id = ""
			actualizar_vista_p2()
			actualizar_instrucciones()
			marcar_entrada_manejada()

func marcar_entrada_manejada() -> void:
	if is_inside_tree() and get_viewport():
		get_viewport().set_input_as_handled()

func actualizar_vista_p1() -> void:
	var fighter: Dictionary = total_fighters[p1_index]
	p1_preview.texture = load_texture_runtime(fighter["preview_path"], "preview.png")
	if p1_confirmed:
		p1_name_label.text = "P1: " + fighter["name"] + " [LISTO]"
	else:
		p1_name_label.text = "P1: " + fighter["name"]
	mover_cursor_p1()

func actualizar_vista_p2() -> void:
	var fighter: Dictionary = total_fighters[p2_index]
	p2_preview.texture = load_texture_runtime(fighter["preview_path"], "preview.png")
	if p2_confirmed:
		p2_name_label.text = "P2: " + fighter["name"] + " [LISTO]"
	else:
		p2_name_label.text = "P2: " + fighter["name"]
	mover_cursor_p2()

func actualizar_instrucciones() -> void:
	if not p1_confirmed and not p2_confirmed:
		instructions_label.text = "P1: W/A/S/D + Espacio  |  P2: Flechas + Enter"
	elif p1_confirmed and not p2_confirmed:
		instructions_label.text = "P1 LISTO — Esperando a P2 (Flechas + Enter)"
	elif not p1_confirmed and p2_confirmed:
		instructions_label.text = "P2 LISTO — Esperando a P1 (W/A/S/D + Espacio)"

func confirmar_p1() -> void:
	var current_fighter: Dictionary = total_fighters[p1_index]
	var target_id: String = current_fighter["id"]
	
	if p1_pending_id == target_id:
		if "random" in target_id:
			p1_fighter_id = obtener_random()
		else:
			p1_fighter_id = target_id
			
		p1_confirmed = true
		p1_name_label.text = "P1: " + current_fighter["name"] + " [LISTO]"
		print("P1 Confirmado: ", p1_fighter_id)
		
		mover_cursor_p1()
		actualizar_instrucciones()
		verificar_inicio_combate()
	else:
		p1_pending_id = target_id
		instructions_label.text = "P1: Presione Espacio nuevamente para confirmar a " + current_fighter["name"]

func confirmar_p2() -> void:
	var current_fighter: Dictionary = total_fighters[p2_index]
	var target_id: String = current_fighter["id"]
	
	if p2_pending_id == target_id:
		if "random" in target_id:
			p2_fighter_id = obtener_random()
		else:
			p2_fighter_id = target_id
			
		p2_confirmed = true
		p2_name_label.text = "P2: " + current_fighter["name"] + " [LISTO]"
		print("P2 Confirmado: ", p2_fighter_id)
		
		mover_cursor_p2()
		actualizar_instrucciones()
		verificar_inicio_combate()
	else:
		p2_pending_id = target_id
		instructions_label.text = "P2: Presione Enter nuevamente para confirmar a " + current_fighter["name"]

func verificar_inicio_combate() -> void:
	if p1_confirmed and p2_confirmed:
		DatosGlobales.p1_fighter_id = p1_fighter_id
		DatosGlobales.p2_fighter_id = p2_fighter_id
		
		emitir_evento_match_start()
		
		# Cambia el estado a COMBATE (reactiva PhysicsServer2D/3D) y abre la escena de pelea
		DatosGlobales.cambiar_estado(
			DatosGlobales.AppState.COMBATE,
			"res://nucleo4_interfaz/scenes/pantalla_combate.tscn"
		)
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
	
	print("\n==============================================")
	print("--- EMITIENDO EVENTO GLOBAL: on_match_start ---")
	print(JSON.stringify(match_data, "\t"))
	print("==============================================\n")
	
	if Engine.has_singleton("EventBus") or get_node_or_null("/nucleo4_interfaz/EventBus"):
		get_node("/nucleo4_interfaz/EventBus").emit_signal("on_match_start", match_data)

func obtener_random() -> String:
	var validos: Array[Dictionary] = []
	for item in total_fighters:
		if not "random" in item["id"]:
			validos.append(item)
	if validos.size() > 0:
		return validos[randi() % validos.size()]["id"]
	return total_fighters[0]["id"] if not total_fighters.is_empty() else ""

# Intenta cargar una imagen específica desde disco o recurso; devuelve null si no existe
func _cargar_imagen_directa(path: String) -> Texture2D:
	var ruta_fisica: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	
	if FileAccess.file_exists(ruta_fisica):
		var img := Image.load_from_file(ruta_fisica)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
		
	return null

# Carga la imagen del luchador o recurre sin errores a la carpeta fighters/default/
func load_texture_runtime(path: String, default_filename: String = "portrait.png") -> Texture2D:
	# 1. Intentar cargar la imagen propia del luchador
	var tex: Texture2D = _cargar_imagen_directa(path)
	if tex != null:
		return tex
		
	# 2. Si falta, buscar en la carpeta fighters/default/
	var ruta_base: String = obtener_ruta_real_fighters()
	if ruta_base != "":
		var default_folder: String = ruta_base.path_join("default")
		
		# Intentar cargar el archivo solicitado (portrait.png o preview.png) en default/
		var default_tex: Texture2D = _cargar_imagen_directa(default_folder.path_join(default_filename))
		if default_tex != null:
			return default_tex
			
		# Si en default/ solo pusiste portrait.png (y faltaba preview.png), usar portrait.png como silueta
		if default_filename != "default.png":
			var default_portrait: Texture2D = _cargar_imagen_directa(default_folder.path_join("default.png"))
			if default_portrait != null:
				return default_portrait
	
	# 3. Respaldo final de seguridad por si la carpeta default también estuviera vacía
	var fallback := GradientTexture2D.new()
	fallback.width = 120
	fallback.height = 120
	var grad := Gradient.new()
	grad.set_color(0, Color(0.15, 0.2, 0.3))
	fallback.gradient = grad
	return fallback
