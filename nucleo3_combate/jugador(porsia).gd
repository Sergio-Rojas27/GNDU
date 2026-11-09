extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -800.0 

@export_group("Datos del Jugador")
@export var player_id: int = 1
@export var max_hp: int = 100
@export var fuerza_golpe: int = 15
@export var rival: CharacterBody2D 

@export_group("Controles (Demo Local)")
@export var accion_izquierda: StringName = "ui_left"
@export var accion_derecha: StringName = "ui_right"
@export var accion_arriba: StringName = "ui_up"
@export var accion_abajo: StringName = "ui_down"
@export var accion_salto: StringName = "ui_page_up" 
@export var accion_golpe: StringName = "ui_accept"
@export var accion_patada: StringName = "ui_select"
@export var accion_bloqueo: StringName = "ui_focus_next"
@export var accion_agarre: StringName = "ui_page_down"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_collision: CollisionShape2D = $Hitbox/HitboxArea

var estado_actual: String = "reposo"
var current_hp: int = 100

var rival_agarrado: CharacterBody2D = null
var tiempo_agarre: float = 0.0

var input_nucleo2: Dictionary = {
	"move_x": 0, "move_y": 0, "salto": false,
	"punch": false, "kick": false, "block": false, "grab": false
}

var depurador_label: Label

func _ready() -> void:
	current_hp = max_hp
	if hitbox_collision: hitbox_collision.disabled = true
	if hitbox: hitbox.area_entered.connect(_on_hitbox_area_entered)
	if sprite:
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.animation_finished.connect(_on_sprite_animation_finished)
		
	depurador_label = Label.new()
	add_child(depurador_label)
	depurador_label.position = Vector2(-100, -120) 
	depurador_label.add_theme_color_override("font_color", Color(1, 0, 0))

func _simular_entrada_nucleo2() -> void:
	input_nucleo2["move_x"] = Input.get_axis(accion_izquierda, accion_derecha)
	
	var move_y = 0
	if Input.is_action_pressed(accion_arriba): move_y = 1
	elif Input.is_action_pressed(accion_abajo): move_y = -1
	input_nucleo2["move_y"] = move_y
	
	input_nucleo2["salto"] = Input.is_action_just_pressed(accion_salto)
	input_nucleo2["punch"] = Input.is_action_just_pressed(accion_golpe)
	input_nucleo2["kick"] = Input.is_action_just_pressed(accion_patada)
	input_nucleo2["block"] = Input.is_action_pressed(accion_bloqueo)
	input_nucleo2["grab"] = Input.is_action_just_pressed(accion_agarre)

func _physics_process(delta: float) -> void:
	_simular_entrada_nucleo2()
	
	if depurador_label:
		depurador_label.text = "Estado: " + estado_actual
	
# 1. Mirada Fija al Rival (Independiente y robusta)
	var mirando_derecha: bool = true
	
	if rival:
		# Si soy el P1, miro a la derecha si mi X es menor que la del rival.
		# Si soy el P2, la lógica se invierte de manera natural.
		if player_id == 1:
			mirando_derecha = global_position.x < rival.global_position.x
		else:
			mirando_derecha = global_position.x < rival.global_position.x
	else:
		mirando_derecha = (player_id == 1)

	if estado_actual not in ["dano", "derrota", "agarrado", "lanzado"]:
		# Si es Jugador 1: flip_h es false cuando mira a la derecha (sprite original).
		# Si es Jugador 2: si los sprites nativos miran por defecto a la derecha, 
		# debemos invertir el comportamiento para que se careen correctamente.
		if player_id == 1:
			sprite.flip_h = not mirando_derecha
			if hitbox:
				hitbox.scale.x = 1 if mirando_derecha else -1
		else:
			# Para el Jugador 2 invertimos la lógica del sprite para que apunte al P1
			sprite.flip_h = mirando_derecha
			if hitbox:
				hitbox.scale.x = -1 if mirando_derecha else 1
	# 2. ESTADOS RESTRICTIVOS
	if estado_actual == "agarrado":
		return

	if estado_actual in ["dano", "derrota", "lanzado"]:
		var estaba_en_aire = not is_on_floor()
		if not is_on_floor():
			velocity += get_gravity() * delta
		
		# Pushbox Suave pasiva
		if rival:
			var dist_x = global_position.x - rival.global_position.x
			if abs(dist_x) < 40 and global_position.y < rival.global_position.y - 10:
				velocity.x += (150.0 if dist_x > 0 else -150.0)
				
		# --- LÍMITE DE PANTALLA TIPO MORTAL KOMBAT ---
		if rival and estado_actual not in ["dano", "derrota", "agarrado", "lanzado"]:
			var distancia_al_rival = abs(global_position.x - rival.global_position.x)
			
			# Ajusta este número: es el ancho máximo que la cámara les permite separarse.
			# Con un zoom de 1.3, el valor ideal ronda los 1200 o 1300 píxeles.
			var distancia_maxima = 1300.0 
			
			if distancia_al_rival >= distancia_maxima:
				var estoy_a_la_izquierda = global_position.x < rival.global_position.x
				
				# Si estoy a la izquierda e intento caminar más a la izquierda, me freno
				if estoy_a_la_izquierda and velocity.x < 0:
					velocity.x = 0
				# Si estoy a la derecha e intento caminar más a la derecha, me freno
				elif not estoy_a_la_izquierda and velocity.x > 0:
					velocity.x = 0
					
		move_and_slide()
		
		if estado_actual == "lanzado" and estaba_en_aire and is_on_floor():
			velocity.y = -500 
			velocity.x *= 0.5 
			estado_actual = "dano" 
		return

	# 3. LÓGICA DE AGARRE (Atacante)
	if estado_actual == "agarrando":
		tiempo_agarre += delta
		
		if rival_agarrado:
			# Agarre seguro: Matemáticas puras basadas en hacia dónde miras, sin importar el sprite
			var direccion_mirada = 1 if mirando_derecha else -1
			var posicion_manos = global_position + Vector2(60 * direccion_mirada, 0)
			
			# lerp() suaviza el movimiento del rival hacia tus manos
			rival_agarrado.global_position = rival_agarrado.global_position.lerp(posicion_manos, 0.5)
			
			var direccion_lanzamiento = Vector2.ZERO
			if input_nucleo2["move_y"] == 1: 
				direccion_lanzamiento = Vector2(0, -900)
			elif input_nucleo2["move_y"] == -1: 
				direccion_lanzamiento = Vector2(0, 1000) 
			elif input_nucleo2["move_x"] != 0: 
				var empuja_adelante = (input_nucleo2["move_x"] > 0) == mirando_derecha
				if empuja_adelante:
					direccion_lanzamiento = Vector2(600 if mirando_derecha else -600, -300)
				else:
					direccion_lanzamiento = Vector2(-600 if mirando_derecha else 600, -300)
			elif input_nucleo2["punch"] or input_nucleo2["kick"]:
				direccion_lanzamiento = Vector2(600 if mirando_derecha else -600, -300)
			
			if direccion_lanzamiento != Vector2.ZERO:
				rival_agarrado.ser_lanzado(direccion_lanzamiento)
				estado_actual = "reposo"
				actualizar_animacion("Reposo")
				rival_agarrado = null
			elif tiempo_agarre >= 3.0: 
				rival_agarrado.liberar_agarre()
				estado_actual = "reposo"
				actualizar_animacion("Reposo")
				rival_agarrado = null
				
		move_and_slide()
		return

	if estado_actual.begins_with("ataque_") or estado_actual == "intentar_agarre":
		if is_on_floor():
			velocity.x = 0
			move_and_slide()
			return

	# 4. MÁQUINA DE ESTADOS PRINCIPAL
	if is_on_floor():
		if estado_actual.begins_with("salto_") or estado_actual.begins_with("ataque_aire_"):
			estado_actual = "reposo"
			if hitbox_collision: hitbox_collision.disabled = true
				
		if input_nucleo2["grab"]:
			velocity.x = 0
			estado_actual = "intentar_agarre"
			actualizar_animacion("Agarre")
		elif input_nucleo2["block"]:
			velocity.x = 0
			if input_nucleo2["move_y"] == -1:
				estado_actual = "bloqueo_bajo"
				actualizar_animacion("Bloqueo_Bajo")
			else:
				estado_actual = "bloqueo_alto"
				actualizar_animacion("Bloqueo_Alto")
		elif input_nucleo2["move_y"] == -1:
			velocity.x = 0
			if input_nucleo2["punch"]:
				estado_actual = "ataque_punio_abajo"
				actualizar_animacion("Punio_Abajo")
			elif input_nucleo2["kick"]:
				estado_actual = "ataque_patada_abajo"
				actualizar_animacion("Patada_Abajo")
			else:
				estado_actual = "agachado"
				actualizar_animacion("Agachado")
		elif input_nucleo2["punch"]:
			velocity.x = 0
			if input_nucleo2["move_y"] == 1:
				estado_actual = "ataque_punio_arriba"
				actualizar_animacion("Punio_Arriba")
			else:
				estado_actual = "ataque_golpe"
				actualizar_animacion("Golpear")
		elif input_nucleo2["kick"]:
			velocity.x = 0
			if input_nucleo2["move_y"] == 1:
				estado_actual = "ataque_patada_arriba"
				actualizar_animacion("Patada_Arriba")
			else:
				estado_actual = "ataque_patada"
				actualizar_animacion("Patada")
		elif input_nucleo2["salto"]:
			velocity.y = JUMP_VELOCITY
			var direction = input_nucleo2["move_x"]
			if direction == 0:
				estado_actual = "salto_estatico"
				actualizar_animacion("Salto_Subida")
			else:
				var moviendo_hacia_rival = false
				if rival:
					var dist_x_salto = rival.global_position.x - global_position.x
					moviendo_hacia_rival = (direction > 0 and dist_x_salto > 0) or (direction < 0 and dist_x_salto < 0)
				
				if moviendo_hacia_rival:
					estado_actual = "salto_adelante"
					actualizar_animacion("Salto_Adelante")
				else:
					estado_actual = "salto_atras"
					actualizar_animacion("Salto_Atras")
		else:
			var direction = input_nucleo2["move_x"]
			if direction != 0:
				velocity.x = direction * SPEED
				estado_actual = "caminar"
				
				var moviendo_hacia_rival = false
				if rival:
					var dist_x_camina = rival.global_position.x - global_position.x
					moviendo_hacia_rival = (direction > 0 and dist_x_camina > 0) or (direction < 0 and dist_x_camina < 0)
				
				if moviendo_hacia_rival:
					actualizar_animacion("Caminar_Adelante")
				else:
					actualizar_animacion("Caminar_Atras")
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				estado_actual = "reposo"
				actualizar_animacion("Reposo")
	else:
		# LÓGICA EN EL AIRE
		velocity += get_gravity() * delta
		if not estado_actual.begins_with("ataque_aire_"):
			if input_nucleo2["punch"]:
				estado_actual = "ataque_aire_punio"
				actualizar_animacion("Punio_Aire")
			elif input_nucleo2["kick"]:
				estado_actual = "ataque_aire_patada"
				actualizar_animacion("Patada_Aire")

	# PUSHBOX INTELIGENTE (Anti-Caminar en la cabeza)
	if rival:
		var distancia_horizontal = global_position.x - rival.global_position.x
		var distancia_vertical = rival.global_position.y - global_position.y 
		
		# Si estamos pisándolo (superposición X menor a 40 y estamos físicamente más arriba)
		if abs(distancia_horizontal) < 40 and distancia_vertical > 10 and distancia_vertical < 150:
			var direccion_desliz = 1 if distancia_horizontal > 0 else -1
			if distancia_horizontal == 0: direccion_desliz = 1 if mirando_derecha else -1
			
			# Inyectamos velocidad lateral para que resbale de forma fluida
			velocity.x += direccion_desliz * 150.0

	move_and_slide()
	
	# Lógica Anti-Caminar en la cabeza (Pushbox Aérea)
	if is_on_floor() and rival:
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			if col.get_collider() == rival:
				if global_position.y < rival.global_position.y - 10:
					var empuje_dir = sign(global_position.x - rival.global_position.x)
					if empuje_dir == 0: empuje_dir = 1
					global_position.x += empuje_dir * 10


# --- ANIMACIONES Y FOTOGRAMAS ---
func actualizar_animacion(nombre_anim: String) -> void:
	if sprite and sprite.animation != nombre_anim:
		sprite.play(nombre_anim)

func _on_sprite_frame_changed() -> void:
	if hitbox_collision:
		# Activar hitbox solo en el frame 1 (cambia el 1 si el impacto en tu dibujo es en otro fotograma)
		if estado_actual == "ataque_golpe" and sprite.animation == "Golpear":
			hitbox_collision.disabled = (sprite.frame != 1)
		elif estado_actual == "ataque_patada" and sprite.animation == "Patada":
			hitbox_collision.disabled = (sprite.frame != 1)
		elif estado_actual == "ataque_punio_arriba" and sprite.animation == "Punio_Arriba":
			hitbox_collision.disabled = (sprite.frame != 1)
		elif estado_actual == "ataque_punio_abajo" and sprite.animation == "Punio_Abajo":
			hitbox_collision.disabled = (sprite.frame != 1)
		elif estado_actual == "ataque_patada_abajo" and sprite.animation == "Patada_Abajo":
			hitbox_collision.disabled = (sprite.frame != 1)
		elif estado_actual == "ataque_patada_arriba" and sprite.animation == "Patada_Arriba":
			hitbox_collision.disabled = (sprite.frame != 1)
		elif estado_actual == "ataque_aire_punio" and sprite.animation == "Punio_Aire":
			hitbox_collision.disabled = (sprite.frame != 1)
		elif estado_actual == "ataque_aire_patada" and sprite.animation == "Patada_Aire":
			hitbox_collision.disabled = (sprite.frame != 1)
		elif estado_actual == "intentar_agarre" and sprite.animation == "Agarre":
			hitbox_collision.disabled = (sprite.frame != 1) 

func _on_sprite_animation_finished() -> void:
	if estado_actual.begins_with("ataque_") or estado_actual == "intentar_agarre":
		if hitbox_collision: hitbox_collision.disabled = true
		
		if not is_on_floor():
			if velocity.x == 0:
				estado_actual = "salto_estatico"
				actualizar_animacion("Salto_Subida")
			else:
				var moviendo_derecha = (velocity.x > 0)
				var mirando_derecha = not sprite.flip_h
				if moviendo_derecha == mirando_derecha:
					estado_actual = "salto_adelante"
					actualizar_animacion("Salto_Adelante")
				else:
					estado_actual = "salto_atras"
					actualizar_animacion("Salto_Atras")
		else:
			estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"


# --- DETECCIÓN DE IMPACTO Y COMBATE ---
func _on_hitbox_area_entered(area_rival: Area2D) -> void:
	if area_rival.name == "Hurtbox" and area_rival.get_parent() != self:
		var rival_atacado = area_rival.get_parent()
		if rival_atacado.has_method("recibir_ataque"):
			var direccion_empuje = 1 if global_position.x < rival_atacado.global_position.x else -1
			
			var es_agarre = (estado_actual == "intentar_agarre")
			var altura_ataque = "MEDIO" 
			
			if estado_actual in ["ataque_punio_abajo", "ataque_patada_abajo"]: 
				altura_ataque = "BAJO"
			elif estado_actual in ["ataque_aire_punio", "ataque_aire_patada", "ataque_patada_arriba", "ataque_punio_arriba"]: 
				altura_ataque = "ALTO"
			
			if es_agarre and rival_atacado.estado_actual != "agarrado":
				estado_actual = "agarrando"
				rival_agarrado = rival_atacado
				tiempo_agarre = 0.0
				if hitbox_collision: hitbox_collision.disabled = true 
				
			rival_atacado.recibir_ataque(fuerza_golpe, direccion_empuje, player_id, altura_ataque, es_agarre)

func recibir_ataque(cantidad: int, direccion_empuje: int, atacante_id: int, altura: String, es_agarre: bool) -> void:
	if es_agarre:
		if not is_on_floor(): return 
		estado_actual = "agarrado"
		velocity = Vector2.ZERO
		collision_layer = 0 
		collision_mask = 0
		actualizar_animacion("Agarrado") 
		return

	var fue_bloqueado = false
	if estado_actual == "bloqueo_alto" and altura != "BAJO":
		fue_bloqueado = true
	elif estado_actual == "bloqueo_bajo" and altura != "ALTO":
		fue_bloqueado = true

	if hitbox_collision:
		hitbox_collision.disabled = true

	if fue_bloqueado:
		velocity.x = direccion_empuje * 50.0 
		imprimir_evento_combate("BLOCK", atacante_id, player_id, 0)
	else:
		current_hp = max(0, current_hp - cantidad)
		estado_actual = "dano"
		velocity.x = direccion_empuje * 150.0
		imprimir_evento_combate("HIT", atacante_id, player_id, cantidad)
		actualizar_animacion("Stun")
		
		if current_hp <= 0:
			estado_actual = "derrota"
			imprimir_evento_combate("KO", atacante_id, player_id, 0)
			actualizar_animacion("Tumbar")
		else:
			await get_tree().create_timer(0.3).timeout
			if estado_actual == "dano":
				estado_actual = "reposo"

func ser_lanzado(fuerza_vector: Vector2) -> void:
	estado_actual = "lanzado"
	velocity = fuerza_vector
	current_hp = max(0, current_hp - 10)
	
	collision_layer = 1
	collision_mask = 1
	
	imprimir_evento_combate("HIT", rival.player_id if rival else 0, player_id, 10)
	actualizar_animacion("Tumbar")
	
	if current_hp <= 0:
		estado_actual = "derrota"
		imprimir_evento_combate("KO", rival.player_id if rival else 0, player_id, 0)

func liberar_agarre() -> void:
	estado_actual = "reposo"
	actualizar_animacion("Reposo")
	
	collision_layer = 1
	collision_mask = 1
	
	velocity.x = (1 if sprite.flip_h else -1) * 200.0 


# --- COMUNICACIÓN CON EL BUS CENTRAL ---
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
			"sound_id": "sfx_heavy_hit" if tipo_evento == "HIT" else "voice_ko" if tipo_evento == "KO" else "sfx_block"
		}
	}
	print(JSON.stringify(evento_json))
