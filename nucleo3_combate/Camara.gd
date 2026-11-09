extends Camera2D

@export var jugador_1: CharacterBody2D
@export var jugador_2: CharacterBody2D

# Las medidas exactas de tu fondo
const LIMITE_IZQUIERDO: float = 0.0
const LIMITE_DERECHO: float = 1920.0
const LIMITE_SUPERIOR: float = 0.0
const LIMITE_INFERIOR: float = 1080.0

func _ready() -> void:
	make_current()

func _process(delta: float) -> void:
	if not jugador_1 or not jugador_2:
		return

	# 1. Punto medio de los jugadores
	var centro_x = (jugador_1.global_position.x + jugador_2.global_position.x) / 2.0
	var centro_y = (jugador_1.global_position.y + jugador_2.global_position.y) / 2.0

	var ancho_pantalla_mitad = (get_viewport_rect().size.x / 2.0) / zoom.x
	var alto_pantalla_mitad = (get_viewport_rect().size.y / 2.0) / zoom.y

	# 2. X exacto e instantáneo (Freno lateral automático)
	var posicion_final_x = clamp(
		centro_x, 
		LIMITE_IZQUIERDO + ancho_pantalla_mitad, 
		LIMITE_DERECHO - ancho_pantalla_mitad
	)

	# 3. Y dinámico para los saltos
	var limite_piso_y = LIMITE_INFERIOR - alto_pantalla_mitad
	# Restamos un offset (ej. 100) al centro_y para encuadrar el pecho/cabeza y no los pies
	var objetivo_y = clamp(centro_y - 100, LIMITE_SUPERIOR + alto_pantalla_mitad, limite_piso_y)

	# 4. Aplicar movimiento: X es rígido, Y es suave (lerp)
	global_position.x = posicion_final_x
	global_position.y = lerp(global_position.y, objetivo_y, 5.0 * delta)
