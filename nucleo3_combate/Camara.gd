extends Camera2D

@export var jugador_1: CharacterBody2D
@export var jugador_2: CharacterBody2D

# Límites del escenario en píxeles (ajusta estos valores según el tamaño de tu fondo)
@export var limite_izquierdo: float = 0.0
@export var limite_derecho: float = 1920.0

# Distancias de zoom
@export var zoom_minimo: float = 1.0  
@export var zoom_maximo: float = 1.3  
@export var distancia_base_zoom: float = 600.0 

# Compensación de altura (baja el número hacia -300 si quieres la cámara más arriba)
@export var offset_altura: float = -150.0

func _ready() -> void:
	make_current()

func _process(_delta: float) -> void:
	if not jugador_1 or not jugador_2:
		return

	# 1. Calcular puntos medios
	var centro_x = (jugador_1.global_position.x + jugador_2.global_position.x) / 2.0
	var centro_y = (jugador_1.global_position.y + jugador_2.global_position.y) / 2.0

	# 2. Calcular la distancia para el zoom
	var distancia_entre_ellos = abs(jugador_1.global_position.x - jugador_2.global_position.x)
	AnimatorZoom(distancia_entre_ellos)

	# 3. Restringir la cámara en los bordes X
	var ancho_pantalla_mitad = (get_viewport_rect().size.x / 2.0) / zoom.x
	var posicion_final_x = clamp(
		centro_x, 
		limite_izquierdo + ancho_pantalla_mitad, 
		limite_derecho - ancho_pantalla_mitad
	)

	# 4. Aplicar posición suavizada con compensación de altura
	global_position = global_position.lerp(Vector2(posicion_final_x, centro_y + offset_altura), 0.2)

func AnimatorZoom(distancia: float) -> void:
	var factor = clamp(distancia / distancia_base_zoom, 0.8, 1.2)
	var valor_zoom = remap(factor, 0.8, 1.2, zoom_maximo, zoom_minimo)
	valor_zoom = clamp(valor_zoom, zoom_minimo, zoom_maximo)
	
	zoom = zoom.lerp(Vector2(valor_zoom, valor_zoom), 0.1)
