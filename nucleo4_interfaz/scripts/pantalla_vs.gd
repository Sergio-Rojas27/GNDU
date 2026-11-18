extends Control

@onready var personaje1_rect = $Personaje1
@onready var personaje2_rect = $Personaje2
@onready var nombre1_label = $Nombre1
@onready var nombre2_label = $Nombre2

var haciendo_transicion: bool = false

func _ready():
	# Deshabilitar trackpad/ratón en esta pantalla
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Obtener IDs desde el Singleton
	var p1 = DatosGlobales.p1_fighter_id
	var p2 = DatosGlobales.p2_fighter_id

	# Actualizar los textos de los Labels capitalizando el texto
	if nombre1_label:
		nombre1_label.text = str(p1).capitalize()
	if nombre2_label:
		nombre2_label.text = str(p2).capitalize()

	# Cargar preview del Jugador 1 comprobando si existe la ruta
	var ruta_imagen_p1 = "res://assets/Fighters/" + str(p1) + "/preview.png"
	if ResourceLoader.exists(ruta_imagen_p1):
		personaje1_rect.texture = load(ruta_imagen_p1)

	# Cargar preview del Jugador 2 comprobando si existe la ruta
	var ruta_imagen_p2 = "res://assets/Fighters/" + str(p2) + "/preview.png"
	if ResourceLoader.exists(ruta_imagen_p2):
		personaje2_rect.texture = load(ruta_imagen_p2)
		
	# Llamamos a la función que hará la animación rápida de entrada
	aparecer_elementos()

func aparecer_elementos():
	# Transparencia inicial a 0
	personaje1_rect.modulate.a = 0.0
	personaje2_rect.modulate.a = 0.0
	if nombre1_label: nombre1_label.modulate.a = 0.0
	if nombre2_label: nombre2_label.modulate.a = 0.0
	
	# Creamos la animación
	var tween = create_tween()
	tween.set_parallel(true)
	
	# ⚡ Fade-in rápido en 0.4 segundos
	tween.tween_property(personaje1_rect, "modulate:a", 1.0, 0.4)
	tween.tween_property(personaje2_rect, "modulate:a", 1.0, 0.4)
	if nombre1_label: tween.tween_property(nombre1_label, "modulate:a", 1.0, 0.4)
	if nombre2_label: tween.tween_property(nombre2_label, "modulate:a", 1.0, 0.4)
	
	# ⚡ Espera corta de 0.8 segundos antes de saltar al combate automáticamente
	tween.chain().tween_callback(_ir_al_combate).set_delay(0.8)

func _input(event: InputEvent) -> void:
	# Bloquear cualquier entrada de ratón/trackpad
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Si el jugador presiona ESPACIO, adelantamos el cambio a la pelea
	if event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_ir_al_combate()

func _ir_al_combate() -> void:
	# Evitamos que se ejecute varias veces si el jugador presiona ESPACIO repetidamente
	if haciendo_transicion:
		return
	haciendo_transicion = true

	# Crear un recuadro de color negro que cubrirá toda la pantalla
	var fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 0) # Comienza transparente
	fade_rect.z_index = 100 # Se dibuja por encima del humo y los personajes
	add_child(fade_rect)

	# Creamos la animación de transición rápida
	var tween = create_tween()
	tween.set_parallel(true)
	
	# ⚡ Salida veloz de los personajes hacia los bordes (0.25 segundos)
	tween.tween_property(personaje1_rect, "position:x", personaje1_rect.position.x - 300, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
	tween.tween_property(personaje2_rect, "position:x", personaje2_rect.position.x + 300, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	# ⚡ Oscurecimiento rápido de la pantalla (0.25 segundos)
	tween.tween_property(fade_rect, "color:a", 1.0, 0.25)

	# Una vez que termina, cambiamos de escena de inmediato
	tween.chain().tween_callback(func():
		await get_tree().process_frame
		DatosGlobales.cambiar_estado(
			DatosGlobales.AppState.COMBATE,
			"res://nucleo4_interfaz/scenes/pantalla_combate.tscn"
		)
	)
