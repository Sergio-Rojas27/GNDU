extends Control

func _process(_delta: float) -> void:
	pass

# Lista oficial de escenarios pertenecientes a la interfaz
var stage_catalog: Array[Dictionary] = [
	{
		"id": "Escenario_Espacio",
		"name": "Espacio",
		"bg_path": "res://assets/Menus/PortadasEscenarios/portada_espacio.png"
	},
	{
		"id": "Escenario_Playa",
		"name": "Playa",
		"bg_path": "res://assets/Menus/PortadasEscenarios/portada_playa.png"
	},
	{
		"id": "Escenario_Uni",
		"name": "Unimar",
		"bg_path": "res://assets/Menus/PortadasEscenarios/portada_uni.png"
	},
	{
		"id": "Escenario_CampoEntrenamiento",
		"name": "Centro de entrenamiento",
		"bg_path": "res://assets/Menus/PortadasEscenarios/portada_CampoEntrenamiento.jpg"
	},
	{
		"id": "Escenario_Desierto",
		"name": "Desierto",
		"bg_path": "res://assets/Menus/PortadasEscenarios/portada_desierto.png"
	},
	{
		"id": "Escenario_Navidad",
		"name": "Navidad",
		"bg_path": "res://assets/Menus/PortadasEscenarios/portada_navidad.png"
	},
	{
		"id": "Escenario_Sakura",
		"name": "Sakura",
		"bg_path": "res://assets/Menus/PortadasEscenarios/portada_sakura.png"
	},
	{
		"id": "Escenario_Ciudad",
		"name": "Ciudad",
		"bg_path": "res://assets/Menus/PortadasEscenarios/portada_ciudad.png"
	},
	{
		"id": "Escenario_Ring",
		"name": "Ring",
		"bg_path": "res://assets/Menus/PortadasEscenarios/portada_ring.png"
	},
	{
		"id": "escenario_random",
		"name": "Escenario Random",
		"bg_path": "res://assets/Menus/PortadasEscenarios/portada_random.jpg"
	}
]

var selected_stage_id: String = ""

# Control de doble confirmación por Enter
var pending_stage_id: String = ""

# Rutas a los nodos
@onready var background_preview: TextureRect = $TextureRect
@onready var stage_name_label: Label = $MarginContainer/VBoxContainer/PanelContainer/Label
@onready var grid_container: GridContainer = $MarginContainer/VBoxContainer/MarginContainer/GridContainer
@onready var instructions_label: Label = $MarginContainer/VBoxContainer/label_instruccion

func _ready() -> void:
	randomize()
	# Ocultar el cursor del mouse al ingresar a la selección
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	setup_stage_grid()

func setup_stage_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	
	for stage_data in stage_catalog:
		var btn := TextureButton.new()
		
		btn.custom_minimum_size = Vector2(250, 150)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		
		# Bloquear mouse y habilitar solo teclado/foco
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.focus_mode = Control.FOCUS_ALL
		
		var texture_to_use: Texture2D
		if stage_data["id"] == "escenario_random":
			texture_to_use = create_random_icon_texture()
		else:
			texture_to_use = load_stage_texture(stage_data["bg_path"])
			
		btn.texture_normal = texture_to_use
		
		btn.focus_entered.connect(_on_stage_focused.bind(stage_data))
		btn.pressed.connect(_on_stage_selected.bind(stage_data))
		
		grid_container.add_child(btn)

func _unhandled_input(event: InputEvent) -> void:
	# Al presionar cualquier flecha sin tener foco activo, enfocar el primer elemento de la grilla
	if get_viewport().gui_get_focus_owner() == null:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			if grid_container.get_child_count() > 0:
				grid_container.get_child(0).grab_focus()
				get_viewport().set_input_as_handled()

func _on_stage_focused(stage_data: Dictionary) -> void:
	pending_stage_id = ""
	# Reinicia el texto de instrucciones si el usuario navega a otra casilla
	instructions_label.text = "Presione enter para seleccionar un escenario"
	
	stage_name_label.text = stage_data["name"]
	
	if stage_data["id"] == "escenario_random":
		background_preview.texture = create_random_icon_texture()
	else:
		background_preview.texture = load_stage_texture(stage_data["bg_path"])

func _on_stage_selected(stage_data: Dictionary) -> void:
	var target_id: String = stage_data["id"]
	
	# Verificación de doble Enter sin límite de tiempo
	if pending_stage_id == target_id:
		# --- SEGUNDO ENTER (Confirmación final) ---
		if target_id == "escenario_random":
			var escenario_azar = obtener_escenario_aleatorio()
			DatosGlobales.escenario_seleccionado_id = escenario_azar["id"]
			DatosGlobales.escenario_seleccionado_nombre = escenario_azar["name"]
			print("Escenario ALEATORIO confirmado por doble Enter: ", escenario_azar["name"])
		else:
			DatosGlobales.escenario_seleccionado_id = stage_data["id"]
			DatosGlobales.escenario_seleccionado_nombre = stage_data["name"]
			print("Escenario confirmado por doble Enter: ", stage_data["name"])
		
		cambiar_escena()
	else:
		# --- PRIMER ENTER (Pre-selección) ---
		pending_stage_id = target_id
		
		# Cambiar el mensaje en pantalla
		instructions_label.text = "Presione nuevamente para confirmar"
		print("Primer Enter registrado en: ", target_id)

func obtener_escenario_aleatorio() -> Dictionary:
	var escenarios_validos: Array[Dictionary] = []
	for stage in stage_catalog:
		if stage["id"] != "escenario_random":
			escenarios_validos.append(stage)
	
	if escenarios_validos.size() > 0:
		var indice_azar := randi() % escenarios_validos.size()
		return escenarios_validos[indice_azar]
	return {"id": "", "name": ""}

func load_stage_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	
	var fallback := GradientTexture2D.new()
	fallback.width = 300
	fallback.height = 180
	var grad := Gradient.new()
	grad.set_color(0, Color(0.2, 0.2, 0.3))
	fallback.gradient = grad
	return fallback

func create_random_icon_texture() -> Texture2D:
	return load_stage_texture(stage_catalog[9]["bg_path"])

func cambiar_escena() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Emisión del evento oficial on_state_change
	var state_change_event: Dictionary = {
		"event_name": "on_state_change",
		"source_core": "nucleo4_interfaz",
		"data": {
			"previous_screen": "SELECCION_ESCENARIO",
			"current_screen": "SELECCION_PERSONAJES"
		}
	}
	
	print("--- EMITIENDO EVENTO GLOBAL: on_state_change ---")
	print(JSON.stringify(state_change_event, "\t"))
	
	var nueva_escena = "res://nucleo4_interfaz/scenes/menu_seleccion_personajes.tscn"
	var error = get_tree().change_scene_to_file(nueva_escena)
	if error != OK:
		print("Error al cambiar de escena: ", error)
