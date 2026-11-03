extends Node2D

@export_group("Jugadores")
@export var jugador1: CharacterBody2D
@export var jugador2: CharacterBody2D

@export_group("Elementos de UI")
@export var texto_tiempo: Label
@export var reloj_combate: Timer
@export var barra_vida_j1: ProgressBar
@export var barra_vida_j2: ProgressBar

var tiempo_restante: int = 99

func _ready() -> void:
	# Inicializar reloj
	tiempo_restante = 99
	texto_tiempo.text = str(tiempo_restante)
	reloj_combate.timeout.connect(_on_reloj_combate_timeout)
	
	# Configurar vida inicial
	if jugador1:
		barra_vida_j1.max_value = jugador1.max_hp
		barra_vida_j1.value = jugador1.current_hp
	if jugador2:
		barra_vida_j2.max_value = jugador2.max_hp
		barra_vida_j2.value = jugador2.current_hp

func _process(_delta: float) -> void:
	# Sincronización continua de las barras de vida
	if jugador1 and barra_vida_j1:
		barra_vida_j1.value = jugador1.current_hp
	if jugador2 and barra_vida_j2:
		barra_vida_j2.value = jugador2.current_hp

func _on_reloj_combate_timeout() -> void:
	if tiempo_restante > 0:
		tiempo_restante -= 1
		texto_tiempo.text = str(tiempo_restante)
	else:
		reloj_combate.stop()
		print("¡TIME OVER!") # Evento de fin de tiempo (TIME_OVER)
