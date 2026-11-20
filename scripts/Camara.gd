extends Camera2D

@export var jugador_1: CharacterBody2D
@export var jugador_2: CharacterBody2D

# Límites dinámicos del escenario actual (por defecto 1920x1080)
@export var limite_izquierdo: float = 0.0
@export var limite_derecho: float = 1920.0
@export var limite_superior: float = 0.0
@export var limite_inferior: float = 1080.0

func _ready() -> void:
	make_current()

func configurar_limites(izq: float, der: float, sup: float = 0.0, inf: float = 1080.0) -> void:
	limite_izquierdo = izq
	limite_derecho = der
	limite_superior = sup
	limite_inferior = inf

func _physics_process(delta: float) -> void:
	_actualizar_camara(delta)

func _actualizar_camara(delta: float) -> void:
	if not jugador_1 or not jugador_2:
		return

	# 1. Punto medio de los jugadores
	var centro_x: float = (jugador_1.global_position.x + jugador_2.global_position.x) / 2.0
	var centro_y: float = (jugador_1.global_position.y + jugador_2.global_position.y) / 2.0

	var ancho_pantalla_mitad: float = (get_viewport_rect().size.x / 2.0) / zoom.x
	var alto_pantalla_mitad: float = (get_viewport_rect().size.y / 2.0) / zoom.y

	# 2. X exacto e instantáneo (Freno lateral automático en los bordes del escenario)
	var min_cam_x: float = limite_izquierdo + ancho_pantalla_mitad
	var max_cam_x: float = limite_derecho - ancho_pantalla_mitad
	var posicion_final_x: float = centro_x
	if min_cam_x <= max_cam_x:
		posicion_final_x = clampf(centro_x, min_cam_x, max_cam_x)
	else:
		posicion_final_x = (limite_izquierdo + limite_derecho) * 0.5

	# 3. Y dinámico para los saltos
	var min_cam_y: float = limite_superior + alto_pantalla_mitad
	var max_cam_y: float = limite_inferior - alto_pantalla_mitad
	var objetivo_y: float = centro_y - 100.0
	if min_cam_y <= max_cam_y:
		objetivo_y = clampf(centro_y - 100.0, min_cam_y, max_cam_y)
	else:
		objetivo_y = (limite_superior + limite_inferior) * 0.5

	# 4. Aplicar movimiento: X es rígido, Y es suave (lerp)
	global_position.x = posicion_final_x
	global_position.y = lerp(global_position.y, objetivo_y, 5.0 * delta)
