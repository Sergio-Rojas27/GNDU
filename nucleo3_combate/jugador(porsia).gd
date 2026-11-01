extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

#Variable de estado (Ación del personaje)
var estado_actual = "reposo"

# Gravedad para los personajes (Viene default al crear el script gracias a dios)
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Comando de salto (como no tenemos tecla asignada, en Proyecto/Config/Mapa de entrada/Acciones integradas, se ven unas teclas default)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		estado_actual = "salto_subida"

	# Comando de dirección en X
	var direction := Input.get_axis("ui_left", "ui_right")
	
	# Validación de acción de movimiento (Hay que agregar DIRECCIONES)
	if direction:
		velocity.x = direction * SPEED
		estado_actual = "caminar_adelante"
	# Estado de reposo si el personaje no tiene velocidad y está en el suelo (quieto)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor():
			estado_actual = "reposo"

	# 2. Ejecución del Árbitro
	move_and_slide()
