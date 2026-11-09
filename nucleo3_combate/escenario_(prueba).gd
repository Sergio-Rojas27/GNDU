extends Node2D

@export_group("Jugadores")
@export var jugador1: CharacterBody2D
@export var jugador2: CharacterBody2D

@export_group("Cámara")
@export var camara: Camera2D # <-- Asigna el nodo Camera2D desde el inspector

@export_group("Elementos de UI")
@export var texto_tiempo: Label
@export var reloj_combate: Timer
@export var barra_vida_j1: ProgressBar
@export var barra_vida_j2: ProgressBar
@export var texto_victoria: Label

var tiempo_restante: int = 99
var combate_finalizado: bool = false
var altura_fija_camara: float = 0.0

func _ready() -> void:
	tiempo_restante = 99
	combate_finalizado = false
	
	if texto_tiempo:
		texto_tiempo.text = str(tiempo_restante)
	if reloj_combate:
		reloj_combate.timeout.connect(_on_reloj_combate_timeout)
	if texto_victoria:
		texto_victoria.text = "" # Inicia oculto/vacío
	
	if jugador1:
		barra_vida_j1.max_value = jugador1.max_hp
		barra_vida_j1.value = jugador1.current_hp
	if jugador2:
		barra_vida_j2.max_value = jugador2.max_hp
		barra_vida_j2.value = jugador2.current_hp

	# Guardamos la altura inicial de la cámara para que solo se mueva en el eje X
	if camara:
		altura_fija_camara = camara.global_position.y

func _process(_delta: float) -> void:
	# --- LÓGICA DE CÁMARA DINÁMICA ---
	if camara and jugador1 and jugador2:
		# Calcula el centro exacto entre los dos peleadores
		var punto_medio_x = (jugador1.global_position.x + jugador2.global_position.x) / 2.0
		# Mueve la cámara a ese punto en X, manteniendo la altura original en Y
		camara.global_position = Vector2(punto_medio_x, altura_fija_camara)

	if combate_finalizado:
		return

	# Actualizar barras de vida (Funciona perfecto como demo local del Núcleo 3)
	if jugador1 and barra_vida_j1:
		barra_vida_j1.value = jugador1.current_hp
	if jugador2 and barra_vida_j2:
		barra_vida_j2.value = jugador2.current_hp

	# Verificar si un jugador perdió toda su vida
	if jugador1 and jugador1.current_hp <= 0:
		finalizar_combate("¡SE ACABÓ EL COMBATE!\n¡GANÓ EL JUGADOR 2!")
	elif jugador2 and jugador2.current_hp <= 0:
		finalizar_combate("¡SE ACABÓ EL COMBATE!\n¡GANÓ EL JUGADOR 1!")

func finalizar_combate(mensaje: String) -> void:
	combate_finalizado = true
	if reloj_combate:
		reloj_combate.stop()
	if texto_victoria:
		texto_victoria.text = mensaje

func _on_reloj_combate_timeout() -> void:
	if tiempo_restante > 0:
		tiempo_restante -= 1
		if texto_tiempo:
			texto_tiempo.text = str(tiempo_restante)
	else:
		reloj_combate.stop()
		# Evaluar ganador por tiempo si expiran los 99s
		if jugador1.current_hp > jugador2.current_hp:
			finalizar_combate("¡TIME OVER!\n¡GANÓ EL JUGADOR 1!")
		elif jugador2.current_hp > jugador1.current_hp:
			finalizar_combate("¡TIME OVER!\n¡GANÓ EL JUGADOR 2!")
		else:
			finalizar_combate("¡TIME OVER!\n¡EMPATE (DRAW)!")
