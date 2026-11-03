extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

#  Exportamos la información del personaje
@export_group("Datos del Jugador")
@export var player_id: int = 1
@export var max_hp: int = 100
@export var fuerza_golpe: int = 15

# Exportamos las acciones para configurarlas desde el Inspector
@export_group("Controles")
@export var accion_izquierda: StringName = "ui_left"
@export var accion_derecha: StringName = "ui_right"
@export var accion_salto: StringName = "ui_accept"
@export var accion_golpe: StringName = "ui_select" # Asignar una tecla para golpear

# Referencias a nodos de colisión
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_collision: CollisionShape2D = $Hitbox/HitboxArea

# Tiempos de las 3 fases del golpe en segundos
const Tiempo_Inicio: float = 0.1
const Tiempo_Activo: float = 0.15
const Tiempo_Recuperacion: float = 0.2

#Variables de estado (Acción del personaje)
var estado_actual: String = "reposo"
var current_hp: int = 100

func _ready() -> void:
	current_hp = max_hp
	# La Hitbox inicia apagada por defecto
	if hitbox_collision:
		hitbox_collision.disabled = true
	
	# Conectamos la señal de detección de golpe
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)

# Gravedad para los personajes (Viene default al crear el script gracias a dios)
func _physics_process(delta: float) -> void:
	# 1. Aplicar Gravedad y detectar caída
	if not is_on_floor():
		velocity += get_gravity() * delta
		if velocity.y > 0 and not estado_actual.begins_with("golpe") and estado_actual != "dano":
			estado_actual = "salto_caida"

	# Bloqueo de Acciones: Si ataca, recibe daño o perdió, no procesa movimientos
	if estado_actual.begins_with("golpe") or estado_actual in ["dano", "derrota"]:
		move_and_slide()
		return
		
	# 2. Comando de Golpe
	if Input.is_action_just_pressed(accion_golpe) and is_on_floor():
		ejecutar_golpe()
		return

	# 3. Comando de Salto: Usamos la variable sin comillas
	if Input.is_action_just_pressed(accion_salto) and is_on_floor():
		velocity.y = JUMP_VELOCITY
		estado_actual = "salto_subida"

	# 4. Dirección horizontal: Usamos las variables exportadas sin comillas
	var direction := Input.get_axis(accion_izquierda, accion_derecha)
	
	if direction != 0:
		velocity.x = direction * SPEED
		if is_on_floor():
			estado_actual = "caminar_adelante"
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor() and not estado_actual.begins_with("golpe"):
			estado_actual = "reposo"

	#4. Ejecución del arbitro de físicas (Una sola llamada)
	move_and_slide()
	
	
	# --- Lógica de las 3 fases de golpear ---
func ejecutar_golpe() -> void:
	velocity.x = 0
	
	# FASE 1: Iniciar el Golpe (Startup)
	estado_actual = "golpe_inicio"
	if hitbox_collision:
		hitbox_collision.disabled = true
	await get_tree().create_timer(Tiempo_Inicio).timeout
	
	if estado_actual == "dano":
		return

	# FASE 2: Golpe ya Activo (Active) - Enciende Hitbox
	estado_actual = "golpe_activo"
	if hitbox_collision:
		hitbox_collision.disabled = false
	await get_tree().create_timer(Tiempo_Activo).timeout
	
	# FASE 3: Recuperación del Golpe (Recovery) - Apaga Hitbox
	estado_actual = "golpe_recuperacion"
	if hitbox_collision:
		hitbox_collision.disabled = true
	await get_tree().create_timer(Tiempo_Recuperacion).timeout

	if estado_actual == "golpe_recuperacion":
		estado_actual = "reposo"

# (Detección de impacto en el oponente)
func _on_hitbox_area_entered(area_rival: Area2D) -> void:
	if area_rival.name == "Hurtbox" and area_rival.get_parent() != self:
		var rival = area_rival.get_parent()
		if rival.has_method("recibir_dano"):
			var direccion_empuje = 1 if global_position.x < rival.global_position.x else -1
			rival.recibir_dano(fuerza_golpe, direccion_empuje, player_id)

# (Reacción al recibir daño)
func recibir_dano(cantidad: int, direccion_empuje: int, atacante_id: int) -> void:
	current_hp = max(0, current_hp - cantidad)
	estado_actual = "dano"
	
	if hitbox_collision:
		hitbox_collision.disabled = true
	
	velocity.x = direccion_empuje * 150.0
	
	imprimir_evento_combate("HIT", atacante_id, player_id, cantidad)
	
	if current_hp <= 0:
		estado_actual = "derrota"
		imprimir_evento_combate("KO", atacante_id, player_id, 0)
	else:
		await get_tree().create_timer(0.3).timeout
		if estado_actual == "dano":
			estado_actual = "reposo"

# [Reportes y Eventos con JSON Oficiales (Contrato Núcleo 3)]
func imprimir_evento_combate(tipo_evento: String, atacante: int, defensor: int, dano: int) -> void:
	var evento_json = {
		"event_name": "on_combat_event",
		"source_core": "nucleo3_combate",
		"frame": Engine.get_process_frames(),
		"data": {
			"type": tipo_evento,
			"attacker": atacante,
			"defender": defensor,
			"damage": dano,
			"current_hp": current_hp,
			"is_ko": (current_hp <= 0),
			"sound_id": "sfx_heavy_hit" if tipo_evento == "HIT" else "voice_ko"
		}
	}
	print(JSON.stringify(evento_json))
