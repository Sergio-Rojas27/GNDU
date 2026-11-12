extends Control

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

var pending_stage_id: String = ""

@onready var background_preview: TextureRect = $TextureRect
@onready var stage_name_label: Label = $MarginContainer/VBoxContainer/PanelContainer/Label
@onready var grid_container: GridContainer = $MarginContainer/VBoxContainer/MarginContainer/GridContainer
@onready var instructions_label: Label = $MarginContainer/VBoxContainer/label_instruccion

func _ready() -> void:
	randomize()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	setup_stage_grid()

func setup_stage_grid() -> void:
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()
	
	for i in range(stage_catalog.size()):
		var stage_data: Dictionary = stage_catalog[i]
		var btn := TextureButton.new()
		
		btn.custom_minimum_size = Vector2(250, 150)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.focus_mode = Control.FOCUS_ALL
		
		if stage_data["id"] == "escenario_random":
			btn.texture_normal = create_random_icon_texture()
		else:
			btn.texture_normal = load_stage_texture(stage_data["bg_path"])
			
		btn.focus_entered.connect(_on_stage_focused.bind(stage_data))
		btn.pressed.connect(_on_stage_selected.bind(stage_data))
		
		grid_container.add_child(btn)
		
		if i == 0:
			btn.grab_focus.call_deferred()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Bloquear flechas y Enter
	if event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		return

	# Confirmar con Espacio
	if event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		var foco_actual := get_viewport().gui_get_focus_owner()
		if foco_actual is BaseButton:
			foco_actual.pressed.emit()
		return

	# Navegación con WASD
	var direccion := 0
	var columnas := grid_container.columns
	
	match event.keycode:
		KEY_A:
			direccion = -1
		KEY_D:
			direccion = 1
		KEY_W:
			direccion = -columnas
		KEY_S:
			direccion = columnas
		_:
			return

	get_viewport().set_input_as_handled()

	var total_botones := grid_container.get_child_count()
	if total_botones == 0:
		return

	var foco := get_viewport().gui_get_focus_owner()
	if foco == null or foco.get_parent() != grid_container:
		grid_container.get_child(0).grab_focus()
		return

	var nuevo_indice := foco.get_index() + direccion
	if nuevo_indice >= 0 and nuevo_indice < total_botones:
		grid_container.get_child(nuevo_indice).grab_focus()

func _on_stage_focused(stage_data: Dictionary) -> void:
	pending_stage_id = ""
	instructions_label.text = "Presione espacio para seleccionar un escenario"
	stage_name_label.text = stage_data["name"]
	
	if stage_data["id"] == "escenario_random":
		background_preview.texture = create_random_icon_texture()
	else:
		background_preview.texture = load_stage_texture(stage_data["bg_path"])

func _on_stage_selected(stage_data: Dictionary) -> void:
	var target_id: String = stage_data["id"]
	
	if pending_stage_id == target_id:
		if target_id == "escenario_random":
			var escenario_azar = obtener_escenario_aleatorio()
			DatosGlobales.escenario_seleccionado_id = escenario_azar["id"]
			DatosGlobales.escenario_seleccionado_nombre = escenario_azar["name"]
		else:
			DatosGlobales.escenario_seleccionado_id = stage_data["id"]
			DatosGlobales.escenario_seleccionado_nombre = stage_data["name"]
		
		cambiar_escena()
	else:
		pending_stage_id = target_id
		instructions_label.text = "Presione nuevamente para confirmar"

func obtener_escenario_aleatorio() -> Dictionary:
	var escenarios_validos: Array[Dictionary] = []
	for stage in stage_catalog:
		if stage["id"] != "escenario_random":
			escenarios_validos.append(stage)
	
	if escenarios_validos.size() > 0:
		return escenarios_validos[randi() % escenarios_validos.size()]
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
	DatosGlobales.cambiar_estado(
		DatosGlobales.AppState.MENU_SELECCION_PERSONAJES,
		"res://nucleo4_interfaz/scenes/menu_seleccion_personajes.tscn"
	)
