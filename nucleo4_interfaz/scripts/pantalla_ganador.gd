extends Control

@onready var personaje_rect = $Personaje
@onready var label_nombre = $TimerLabel
@onready var btn_revancha = $Revancha
@onready var btn_cambiar_pj = $CambiarPersonaje

# Lista de botones navegables con WASD
var botones: Array = []
var indice_actual: int = 0

func _ready():
	# Deshabilitar trackpad/ratón en esta pantalla
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Configurar botones navegables
	for btn in [btn_revancha, btn_cambiar_pj]:
		if btn:
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.focus_mode = Control.FOCUS_ALL
			botones.append(btn)

	if btn_revancha:
		btn_revancha.pressed.connect(_on_btn_revancha_pressed)
	if btn_cambiar_pj:
		btn_cambiar_pj.pressed.connect(_on_btn_cambiar_pj_pressed)

	# Dar foco al primer botón
	if not botones.is_empty():
		botones[0].grab_focus.call_deferred()

	# Obtenemos el ganador guardado
	var ganador = DatosGlobales.ganador_id

	# Lógica para mostrar empate o al ganador
	if ganador == "empate":
		personaje_rect.hide()
	else:
		label_nombre.text = ganador.capitalize()
		var ruta_imagen = "res://assets/Fighters/" + ganador + "/preview.png"
		if ResourceLoader.exists(ruta_imagen):
			personaje_rect.texture = load(ruta_imagen)

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
	# Volver a COMBATE y recargar la escena de combate
	DatosGlobales.cambiar_estado(
		DatosGlobales.AppState.COMBATE,
		"res://nucleo4_interfaz/scenes/pantalla_combate.tscn"
	)

func _on_btn_cambiar_pj_pressed() -> void:
	# Volver a selección de personajes
	DatosGlobales.cambiar_estado(
		DatosGlobales.AppState.MENU_SELECCION_PERSONAJES,
		"res://nucleo4_interfaz/scenes/menu_seleccion_personajes.tscn"
	)

func _on_btn_menu_pressed() -> void:
	# Volver al menú principal
	DatosGlobales.cambiar_estado(
		DatosGlobales.AppState.MENU_PRINCIPAL,
		"res://nucleo4_interfaz/scenes/Menu_Principal.tscn"
	)
