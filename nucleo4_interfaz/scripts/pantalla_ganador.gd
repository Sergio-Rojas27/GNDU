extends Control

@onready var personaje_rect = $Personaje
@onready var label_nombre = $TimerLabel
@onready var btn_revancha = $Revancha
@onready var btn_cambiar_pj = $CambiarPersonaje
@onready var btn_menu = $Salir # <--- 1. Declara la referencia a tu tercer botón (ajusta la ruta '$MenuPrincipal' si tiene otro nombre en tu escena)

# Lista de botones navegables con WASD
var botones: Array = []
var indice_actual: int = 0

func _ready():
	# Deshabilitar trackpad/ratón en esta pantalla
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Configurar botones navegables (Asegúrate de incluir btn_menu aquí)
	for btn in [btn_revancha, btn_cambiar_pj, btn_menu]:
		if btn:
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.focus_mode = Control.FOCUS_ALL
			botones.append(btn)

	# Conectar las señales de los tres botones
	if btn_revancha:
		btn_revancha.pressed.connect(_on_btn_revancha_pressed)
	if btn_cambiar_pj:
		btn_cambiar_pj.pressed.connect(_on_btn_cambiar_pj_pressed)
	if btn_menu:
		btn_menu.pressed.connect(_on_btn_menu_pressed) # <--- 2. Conecta la señal del tercer botón

	# Dar foco al primer botón
	if not botones.is_empty():
		botones[0].grab_focus.call_deferred()

	# Obtenemos el ganador guardado
	var ganador = DatosGlobales.ganador_id

	# Lógica para mostrar empate o al ganador
	if ganador == "empate":
		personaje_rect.hide()
	else:
		var limpio := str(ganador).to_lower().replace("profesor_", "").replace("profesora_", "").replace("estudiante_", "")
		label_nombre.text = limpio.replace("_", " ").capitalize()
		var ruta_imagen = "res://assets/Fighters/" + ganador + "/preview.png"
		if ResourceLoader.exists(ruta_imagen):
			personaje_rect.texture = load(ruta_imagen)
		elif FileAccess.file_exists(ProjectSettings.globalize_path(ruta_imagen)):
			var img := Image.load_from_file(ProjectSettings.globalize_path(ruta_imagen))
			if img != null and not img.is_empty():
				personaje_rect.texture = ImageTexture.create_from_image(img)

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
	# Gracias a wrapi(..., 0, botones.size()), al agregar el tercer botón 
	# el tamaño pasará automáticamente a ser 3 (índices 0, 1 y 2).
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
