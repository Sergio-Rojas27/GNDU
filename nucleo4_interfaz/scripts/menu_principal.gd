extends Control

@onready var btn_jugar: TextureButton = $VBoxContainer/btn_jugar
@onready var btn_config: TextureButton = $VBoxContainer/btn_config
@onready var btn_salir: TextureButton = $VBoxContainer2/btn_salir
@onready var btn_personajes: TextureButton = $VBoxContainer2/btn_personajes

var botones: Array[TextureButton] = []
var indice_actual: int = 0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	botones = [
		btn_jugar,
		btn_config,
		btn_salir,
		btn_personajes
	]
	
	for btn in botones:
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.focus_mode = Control.FOCUS_ALL
	
	botones[0].grab_focus.call_deferred()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Bloquear flechas y Enter para usar exclusivamente WASD y Espacio
	if event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		return

	match event.keycode:
		KEY_W, KEY_A:
			get_viewport().set_input_as_handled()
			cambiar_foco(-1)
		KEY_S, KEY_D:
			get_viewport().set_input_as_handled()
			cambiar_foco(1)
		KEY_SPACE:
			get_viewport().set_input_as_handled()
			botones[indice_actual].pressed.emit()
			
func cambiar_foco(direccion: int) -> void:
	indice_actual = wrapi(indice_actual + direccion, 0, botones.size())
	botones[indice_actual].grab_focus()

func _on_btn_jugar_pressed() -> void:
	DatosGlobales.cambiar_estado(
		DatosGlobales.AppState.MENU_SELECCION_ESCENARIO,
		"res://nucleo4_interfaz/scenes/menu_seleccion_escenario.tscn"
	)

func _on_btn_salir_pressed() -> void:
	get_tree().quit()
