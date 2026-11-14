extends CanvasLayer

@onready var btn_reanudar = $Reanudar
@onready var btn_opciones = $Opciones
@onready var btn_salir = $Salir

# Lista de botones navegables con WASD
var botones: Array = []
var indice_actual: int = 0

func _ready() -> void:
	hide()

	# Registrar botones en orden de navegación
	botones = [btn_reanudar, btn_opciones, btn_salir]
	for btn in botones:
		if btn:
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.focus_mode = Control.FOCUS_ALL

	btn_reanudar.pressed.connect(_on_reanudar_pressed)
	btn_opciones.pressed.connect(_on_opciones_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)

	# NUEVO: Godot avisará a esta función cada vez que el menú se muestre u oculte
	visibility_changed.connect(_al_cambiar_visibilidad)

# Esta función garantiza que el teclado funcione sin importar si pausas
# desde el EventBus (Núcleo 2) o desde aquí.
func _al_cambiar_visibilidad() -> void:
	if visible:
		indice_actual = 0
		botones[indice_actual].call_deferred("grab_focus")

func _input(event: InputEvent) -> void:
	# Bloquear ratón/trackpad mientras el menú de pausa está visible
	if visible and (event is InputEventMouseButton or event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		toggle_pausa()
		get_viewport().set_input_as_handled()
		return

	# Solo procesar teclas cuando el menú está visible
	if not visible:
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

func toggle_pausa() -> void:
	var nuevo_estado = not get_tree().paused
	get_tree().paused = nuevo_estado
	visible = nuevo_estado

	# Emitir on_state_change al pausar/reanudar
	if nuevo_estado:
		# Entrando a pausa: notificamos que salimos del estado COMBATE temporalmente
		var evento: Dictionary = {
			"event_name": "on_state_change",
			"source_core": "nucleo4_interfaz",
			"data": {
				"previous_screen": "COMBATE",
				"current_screen": "PAUSA"
			}
		}
		print("--- EMITIENDO EVENTO GLOBAL: on_state_change (PAUSA) ---")
		print(JSON.stringify(evento, "\t"))
		DatosGlobales.on_state_change.emit(evento)
	else:
		# Reanudando: notificamos que volvemos a COMBATE
		var evento: Dictionary = {
			"event_name": "on_state_change",
			"source_core": "nucleo4_interfaz",
			"data": {
				"previous_screen": "PAUSA",
				"current_screen": "COMBATE"
			}
		}
		print("--- EMITIENDO EVENTO GLOBAL: on_state_change (REANUDAR) ---")
		print(JSON.stringify(evento, "\t"))
		DatosGlobales.on_state_change.emit(evento)

func _on_reanudar_pressed() -> void:
	toggle_pausa()

func _on_opciones_pressed() -> void:
	get_tree().paused = false
	#get_tree().change_scene_to_file("res://nucleo4_interfaz/scenes/Pantalla_InfoControles.tscn")

func _on_salir_pressed() -> void:
	get_tree().paused = false
	# Emitir on_state_change al salir al menú principal
	DatosGlobales.cambiar_estado(
		DatosGlobales.AppState.MENU_PRINCIPAL,
		"res://nucleo4_interfaz/scenes/Menu_Principal.tscn"
	)
