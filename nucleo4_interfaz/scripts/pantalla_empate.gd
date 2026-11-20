extends Control

@onready var personaje1_rect = $Personaje1
@onready var personaje2_rect = $Personaje2
@onready var btn_revancha = $Revancha
@onready var btn_cambiar_pj = $CambiarPersonaje
@onready var btn_menu = $Salir # O $MenuPrincipal según cómo lo hayas nombrado en esta escena

# Lista de botones navegables con WASD
var botones: Array = []
var indice_actual: int = 0

func _ready():
	# Deshabilitar trackpad/ratón en esta pantalla
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Configurar y registrar los tres botones navegables
	for btn in [btn_revancha, btn_cambiar_pj, btn_menu]:
		if btn:
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.focus_mode = Control.FOCUS_ALL
			botones.append(btn)

	# Conectar las señales de cada botón
	if btn_revancha:
		btn_revancha.pressed.connect(_on_btn_revancha_pressed)
	if btn_cambiar_pj:
		btn_cambiar_pj.pressed.connect(_on_btn_cambiar_pj_pressed)
	if btn_menu:
		btn_menu.pressed.connect(_on_btn_menu_pressed)

	# Dar foco al primer botón
	if not botones.is_empty():
		botones[0].grab_focus.call_deferred()

	# Obtener IDs desde el Singleton
	var p1 = DatosGlobales.p1_fighter_id
	var p2 = DatosGlobales.p2_fighter_id

	# Cargar preview del Jugador 1
	var ruta_imagen_p1 = "res://assets/Fighters/" + p1 + "/preview.png"
	if ResourceLoader.exists(ruta_imagen_p1):
		personaje1_rect.texture = load(ruta_imagen_p1)
	elif FileAccess.file_exists(ProjectSettings.globalize_path(ruta_imagen_p1)):
		var img1 := Image.load_from_file(ProjectSettings.globalize_path(ruta_imagen_p1))
		if img1 != null and not img1.is_empty():
			personaje1_rect.texture = ImageTexture.create_from_image(img1)

	# Cargar preview del Jugador 2
	var ruta_imagen_p2 = "res://assets/Fighters/" + p2 + "/preview.png"
	if ResourceLoader.exists(ruta_imagen_p2):
		personaje2_rect.texture = load(ruta_imagen_p2)
	elif FileAccess.file_exists(ProjectSettings.globalize_path(ruta_imagen_p2)):
		var img2 := Image.load_from_file(ProjectSettings.globalize_path(ruta_imagen_p2))
		if img2 != null and not img2.is_empty():
			personaje2_rect.texture = ImageTexture.create_from_image(img2)

func _input(event: InputEvent) -> void:
	# Bloquear cualquier entrada de ratón/trackpad
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_W, KEY_A:
			get_viewport().set_input_as_handled()
			_cambiar_foco(-1)
		KEY_S, KEY_D:
			get_viewport().set_input_as_handled()
			_cambiar_foco(1)
		KEY_SPACE:
			get_viewport().set_input_as_handled()
			if not botones.is_empty():
				botones[indice_actual].pressed.emit()

func _cambiar_foco(direccion: int) -> void:
	indice_actual = wrapi(indice_actual + direccion, 0, botones.size())
	botones[indice_actual].grab_focus()

func _on_btn_revancha_pressed() -> void:
	DatosGlobales.cambiar_estado(
		DatosGlobales.AppState.COMBATE,
		"res://nucleo4_interfaz/scenes/pantalla_combate.tscn"
	)

func _on_btn_cambiar_pj_pressed() -> void:
	DatosGlobales.cambiar_estado(
		DatosGlobales.AppState.MENU_SELECCION_PERSONAJES,
		"res://nucleo4_interfaz/scenes/menu_seleccion_personajes.tscn"
	)

func _on_btn_menu_pressed() -> void:
	DatosGlobales.cambiar_estado(
		DatosGlobales.AppState.MENU_PRINCIPAL,
		"res://nucleo4_interfaz/scenes/Menu_Principal.tscn"
	)
