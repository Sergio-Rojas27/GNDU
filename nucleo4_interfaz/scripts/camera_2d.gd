extends Camera2D

@export var camera_speed: float = 600.0

# Límites de la cámara (ajústalos en el Inspector según tu escenario)
@export var limite_izquierdo: float = 0.0
@export var limite_derecho: float = 1920.0
@export var limite_superior: float = 0.0
@export var limite_inferior: float = 650.0

func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	
	# Detectamos las teclas I, M, J, K
	if Input.is_key_pressed(KEY_I): # Arriba
		direction.y -= 1
	if Input.is_key_pressed(KEY_M): # Abajo
		direction.y += 1
	if Input.is_key_pressed(KEY_J): # Izquierda
		direction.x -= 1
	if Input.is_key_pressed(KEY_K): # Derecha
		direction.x += 1
		
	if direction != Vector2.ZERO:
		# Calculamos la nueva posición teórica
		var nueva_posicion = global_position + direction.normalized() * camera_speed * delta
		
		# Aplicamos "clamp" para que la cámara no sobrepase los límites
		nueva_posicion.x = clamp(nueva_posicion.x, limite_izquierdo, limite_derecho)
		nueva_posicion.y = clamp(nueva_posicion.y, limite_superior, limite_inferior)
		
		# Asignamos la posición final corregida
		global_position = nueva_posicion
