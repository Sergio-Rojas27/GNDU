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

# Hurtboxes segmentadas (Estandar y Baja)
@onready var hurtbox_estandar: Area2D = $"Hurtbox-Estandar"
@onready var hurtbox_estandar_collision: CollisionShape2D = $"Hurtbox-Estandar/HurtboxArea"
@onready var hurtbox_baja: Area2D = $"Hurtbox-Baja"
@onready var hurtbox_baja_collision: CollisionShape2D = $"Hurtbox-Baja/HurtboxArea-Baja"

# Hitboxes segmentadas (Alta, Media y Baja)
@onready var hitbox_alta: Area2D = $"Hitbox-Alta"
@onready var hitbox_alta_collision: CollisionShape2D = $"Hitbox-Alta/HitboxArea"
@onready var hitbox_media: Area2D = $"Hitbox-Media"
@onready var hitbox_media_collision: CollisionShape2D = $"Hitbox-Media/HitboxArea"
@onready var hitbox_baja: Area2D = $"Hitbox-Baja"
@onready var hitbox_baja_collision: CollisionShape2D = $"Hitbox-Baja/HitboxArea"

var estado_actual: String = "reposo"
var current_hp: int = 100

var rival_agarrado: CharacterBody2D = null
var tiempo_agarre: float = 0.0

var input_nucleo2: Dictionary = {
	"move_x": 0, "move_y": 0, "salto": false,
	"punch": false, "kick": false, "block": false, "grab": false
}

var depurador_label: Label
var debug_overlay: Node2D
var mostrar_cajas_debug: bool = false:
	set(valor):
		mostrar_cajas_debug = valor
		if debug_overlay:
			debug_overlay.queue_redraw()

func _ready() -> void:
	current_hp = max_hp
	desactivar_todas_hitboxes()
	_actualizar_hurtbox()
	
	if hitbox_alta: hitbox_alta.area_entered.connect(_on_hitbox_area_entered)
	if hitbox_media: hitbox_media.area_entered.connect(_on_hitbox_area_entered)
	if hitbox_baja: hitbox_baja.area_entered.connect(_on_hitbox_area_entered)
	
	if sprite:
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.animation_finished.connect(_on_sprite_animation_finished)
		
	depurador_label = Label.new()
	add_child(depurador_label)
	depurador_label.position = Vector2(-100, -120) 
	depurador_label.add_theme_color_override("font_color", Color(1, 0, 0))
	
	debug_overlay = Node2D.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.z_index = 10
	debug_overlay.draw.connect(_on_debug_overlay_draw)
	add_child(debug_overlay)

func desactivar_todas_hitboxes() -> void:
	if hitbox_alta_collision: hitbox_alta_collision.disabled = true
	if hitbox_media_collision: hitbox_media_collision.disabled = true
	if hitbox_baja_collision: hitbox_baja_collision.disabled = true

func activar_hitbox(altura: String) -> void:
	desactivar_todas_hitboxes()
	match altura:
		"ALTO":
			if hitbox_alta_collision: hitbox_alta_collision.disabled = false
		"MEDIO":
			if hitbox_media_collision: hitbox_media_collision.disabled = false
		"BAJO":
			if hitbox_baja_collision: hitbox_baja_collision.disabled = false

func _actualizar_hurtbox() -> void:
	if estado_actual in ["derrota", "en_suelo"]:
		if hurtbox_estandar_collision: hurtbox_estandar_collision.disabled = true
		if hurtbox_baja_collision: hurtbox_baja_collision.disabled = true
		return
	var esta_agachado = estado_actual in ["agachado", "bloqueo_bajo", "ataque_punio_abajo", "ataque_patada_abajo"]
	if hurtbox_estandar_collision:
		hurtbox_estandar_collision.disabled = esta_agachado
	if hurtbox_baja_collision:
		hurtbox_baja_collision.disabled = not esta_agachado

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
	_actualizar_hurtbox()
	if mostrar_cajas_debug and debug_overlay:
		debug_overlay.queue_redraw()
	
	if depurador_label:
		depurador_label.text = "Estado: " + estado_actual
	
	# 1. Mirada Fija al Rival (Independiente y robusta)
	var mirando_derecha: bool = true
	
	if rival:
		mirando_derecha = global_position.x < rival.global_position.x
	else:
		mirando_derecha = (player_id == 1)

	if estado_actual not in ["dano", "derrota", "agarrado", "lanzado", "caida_rebote", "en_suelo"]:
		sprite.flip_h = not mirando_derecha
		var dir_x = 1.0 if mirando_derecha else -1.0
		if hitbox_alta: hitbox_alta.scale.x = dir_x
		if hitbox_media: hitbox_media.scale.x = dir_x
		if hitbox_baja: hitbox_baja.scale.x = dir_x
	# 2. ESTADOS RESTRICTIVOS
	if estado_actual == "agarrado":
		return

	if estado_actual in ["dano", "derrota", "lanzado", "caida_rebote", "en_suelo"]:
		var estaba_en_aire = not is_on_floor()
		if not is_on_floor():
			velocity += get_gravity() * delta
		else:
			velocity.x = move_toward(velocity.x, 0, 600.0 * delta)
		
		# Pushbox Suave pasiva
		if rival:
			var dist_x = global_position.x - rival.global_position.x
			if abs(dist_x) < 40 and global_position.y < rival.global_position.y - 10:
				velocity.x += (150.0 if dist_x > 0 else -150.0)
				
		move_and_slide()
		_aplicar_limites_camara()
		
		# Impacto contra el suelo al ser lanzado
		if estado_actual == "lanzado" and is_on_floor():
			if current_hp <= 0:
				estado_actual = "derrota"
				velocity = Vector2.ZERO
				actualizar_animacion("Tumbar")
			else:
				velocity.y = -350.0
				velocity.x *= 0.4
				estado_actual = "caida_rebote"
			return
			
		# Impacto tras el rebote: se frena y comienza a levantarse
		if estado_actual == "caida_rebote" and is_on_floor() and velocity.y >= 0:
			if current_hp <= 0:
				estado_actual = "derrota"
				velocity = Vector2.ZERO
				actualizar_animacion("Tumbar")
			else:
				_iniciar_levantarse_del_suelo()
			return
			
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
		_aplicar_limites_camara()
		return

	if estado_actual.begins_with("ataque_") or estado_actual == "intentar_agarre":
		if is_on_floor():
			velocity.x = 0
			move_and_slide()
			_aplicar_limites_camara()
			return

	# 4. MÁQUINA DE ESTADOS PRINCIPAL
	if is_on_floor():
		if estado_actual.begins_with("salto_") or estado_actual.begins_with("ataque_aire_"):
			estado_actual = "reposo"
			desactivar_todas_hitboxes()
				
		if input_nucleo2["grab"]:
			velocity.x = 0
			estado_actual = "intentar_agarre"
			actualizar_animacion("Agarre")
			desactivar_todas_hitboxes()
		elif input_nucleo2["block"]:
			velocity.x = 0
			desactivar_todas_hitboxes()
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
				desactivar_todas_hitboxes()
			elif input_nucleo2["kick"]:
				estado_actual = "ataque_patada_abajo"
				actualizar_animacion("Patada_Abajo")
				activar_hitbox("BAJO")
			else:
				estado_actual = "agachado"
				actualizar_animacion("Agachado")
				desactivar_todas_hitboxes()
		elif input_nucleo2["punch"]:
			velocity.x = 0
			if input_nucleo2["move_y"] == 1:
				estado_actual = "ataque_punio_arriba"
				actualizar_animacion("Punio_Arriba")
				desactivar_todas_hitboxes()
			else:
				estado_actual = "ataque_golpe"
				actualizar_animacion("Golpear")
				desactivar_todas_hitboxes()
		elif input_nucleo2["kick"]:
			velocity.x = 0
			if input_nucleo2["move_y"] == 1:
				estado_actual = "ataque_patada_arriba"
				actualizar_animacion("Patada_Arriba")
				desactivar_todas_hitboxes()
			else:
				estado_actual = "ataque_patada"
				actualizar_animacion("Patada")
				activar_hitbox("MEDIO")
		elif input_nucleo2["salto"]:
			desactivar_todas_hitboxes()
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
				desactivar_todas_hitboxes()
				
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
				desactivar_todas_hitboxes()
	else:
		# LÓGICA EN EL AIRE
		velocity += get_gravity() * delta
		if not estado_actual.begins_with("ataque_aire_"):
			if input_nucleo2["punch"]:
				estado_actual = "ataque_aire_punio"
				actualizar_animacion("Punio_Aire")
				activar_hitbox("MEDIO")
			elif input_nucleo2["kick"]:
				estado_actual = "ataque_aire_patada"
				actualizar_animacion("Patada_Aire")
				desactivar_todas_hitboxes()

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

	_aplicar_limites_camara()


# --- ANIMACIONES Y FOTOGRAMAS ---
func actualizar_animacion(nombre_anim: String) -> void:
	if sprite:
		if sprite.animation != nombre_anim or not sprite.is_playing():
			sprite.play(nombre_anim)

func _on_sprite_frame_changed() -> void:
	if not sprite:
		return
		
	# Para ataques de múltiples frames, activar la hitbox correspondiente en frame 1
	if sprite.frame == 1:
		match estado_actual:
			"ataque_golpe":
				activar_hitbox("MEDIO")
			"ataque_punio_arriba", "ataque_patada_arriba":
				activar_hitbox("ALTO")
			"ataque_punio_abajo":
				activar_hitbox("BAJO")
			"ataque_aire_patada":
				activar_hitbox("MEDIO")
			"intentar_agarre":
				activar_hitbox("MEDIO")
	else:
		# En fotogramas de recuperación o viento, apagar hitboxes
		if estado_actual.begins_with("ataque_") or estado_actual == "intentar_agarre":
			desactivar_todas_hitboxes()

func _on_sprite_animation_finished() -> void:
	if estado_actual.begins_with("ataque_") or estado_actual == "intentar_agarre":
		desactivar_todas_hitboxes()
		
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
			actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")


# --- DETECCIÓN DE IMPACTO Y COMBATE ---
func _on_hitbox_area_entered(area_rival: Area2D) -> void:
	var es_hurtbox = area_rival.name in ["Hurtbox-Estandar", "Hurtbox-Baja", "Hurtbox"]
	if es_hurtbox and area_rival.get_parent() != self:
		var rival_atacado = area_rival.get_parent()
		if rival_atacado.has_method("recibir_ataque"):
			var direccion_empuje = 1 if global_position.x < rival_atacado.global_position.x else -1
			
			var es_agarre = (estado_actual == "intentar_agarre")
			var altura_ataque = "MEDIO" 
			
			if estado_actual in ["ataque_punio_abajo", "ataque_patada_abajo"]: 
				altura_ataque = "BAJO"
			elif estado_actual in ["ataque_aire_punio", "ataque_aire_patada", "ataque_patada_arriba", "ataque_punio_arriba"]: 
				altura_ataque = "ALTO"
			
			desactivar_todas_hitboxes()
			
			if es_agarre and rival_atacado.estado_actual != "agarrado":
				estado_actual = "agarrando"
				rival_agarrado = rival_atacado
				tiempo_agarre = 0.0
				
			rival_atacado.recibir_ataque(fuerza_golpe, direccion_empuje, player_id, altura_ataque, es_agarre)

func recibir_ataque(cantidad: int, direccion_empuje: int, atacante_id: int, altura: String, es_agarre: bool) -> void:
	if estado_actual in ["derrota", "lanzado", "caida_rebote", "en_suelo"]:
		return

	if es_agarre:
		if not is_on_floor() or estado_actual == "agarrado": return 
		estado_actual = "agarrado"
		velocity = Vector2.ZERO
		collision_layer = 0 
		collision_mask = 0
		desactivar_todas_hitboxes()
		actualizar_animacion("Agarrado") 
		return

	var fue_bloqueado = false
	if estado_actual == "bloqueo_alto" and altura != "BAJO":
		fue_bloqueado = true
	elif estado_actual == "bloqueo_bajo" and altura != "ALTO":
		fue_bloqueado = true

	desactivar_todas_hitboxes()

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
				estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
				actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")

func ser_lanzado(fuerza_vector: Vector2) -> void:
	estado_actual = "lanzado"
	velocity = fuerza_vector
	current_hp = max(0, current_hp - 10)
	
	collision_layer = 1
	collision_mask = 1
	desactivar_todas_hitboxes()
	
	imprimir_evento_combate("HIT", rival.player_id if rival else 0, player_id, 10)
	actualizar_animacion("Tumbar")
	
	if current_hp <= 0:
		estado_actual = "derrota"
		imprimir_evento_combate("KO", rival.player_id if rival else 0, player_id, 0)
	else:
		_seguridad_levantarse()

func _seguridad_levantarse() -> void:
	await get_tree().create_timer(1.8).timeout
	if estado_actual in ["lanzado", "caida_rebote"]:
		if current_hp > 0:
			_iniciar_levantarse_del_suelo()

func _iniciar_levantarse_del_suelo() -> void:
	estado_actual = "en_suelo"
	velocity = Vector2.ZERO
	desactivar_todas_hitboxes()
	actualizar_animacion("Tumbar")
	
	await get_tree().create_timer(0.5).timeout
	if estado_actual != "en_suelo":
		return
		
	estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
	actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")

func _aplicar_limites_camara() -> void:
	var cam = get_viewport().get_camera_2d()
	var tam_vp = get_viewport_rect().size
	var zoom_cam = cam.zoom.x if cam else 1.3
	var mitad_ancho_cam = (tam_vp.x / 2.0) / zoom_cam
	var margen = 80.0
	
	# 1. Muro invisible cuando los rivales van en direcciones opuestas
	if rival:
		var distancia_maxima = (mitad_ancho_cam - margen) * 2.0
		var delta_x = global_position.x - rival.global_position.x
		if abs(delta_x) > distancia_maxima:
			var dir_desde_rival = 1.0 if delta_x > 0 else -1.0
			global_position.x = rival.global_position.x + dir_desde_rival * distancia_maxima
			if (dir_desde_rival > 0 and velocity.x > 0) or (dir_desde_rival < 0 and velocity.x < 0):
				velocity.x = 0
		elif abs(delta_x) >= distancia_maxima - 1.0:
			if (delta_x > 0 and velocity.x > 0) or (delta_x < 0 and velocity.x < 0):
				velocity.x = 0

	# 2. Muro invisible para los bordes del visor de la cámara
	var cam_x = cam.global_position.x if cam else 960.0
	if rival:
		var centro_estimado = (global_position.x + rival.global_position.x) / 2.0
		var cam_tope_izq = 0.0 + mitad_ancho_cam
		var cam_tope_der = 1920.0 - mitad_ancho_cam
		cam_x = clamp(centro_estimado, cam_tope_izq, cam_tope_der)

	var limite_izq = cam_x - mitad_ancho_cam + margen
	var limite_der = cam_x + mitad_ancho_cam - margen
	
	limite_izq = max(limite_izq, 0.0 + margen)
	limite_der = min(limite_der, 1920.0 - margen)
	
	if global_position.x < limite_izq:
		global_position.x = limite_izq
		if velocity.x < 0:
			velocity.x = 0
	elif global_position.x > limite_der:
		global_position.x = limite_der
		if velocity.x > 0:
			velocity.x = 0

func liberar_agarre() -> void:
	estado_actual = "reposo"
	actualizar_animacion("Reposo")
	
	collision_layer = 1
	collision_mask = 1
	desactivar_todas_hitboxes()
	
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

# --- REINICIO DE ROUND Y VISUALIZADOR DEBUG ---
func reiniciar_para_round(posicion_inicial: Vector2) -> void:
	global_position = posicion_inicial
	velocity = Vector2.ZERO
	current_hp = max_hp
	estado_actual = "reposo"
	collision_layer = 1
	collision_mask = 1
	rival_agarrado = null
	tiempo_agarre = 0.0
	desactivar_todas_hitboxes()
	_actualizar_hurtbox()
	actualizar_animacion("Reposo")
	if debug_overlay:
		debug_overlay.queue_redraw()

func _on_debug_overlay_draw() -> void:
	if not mostrar_cajas_debug:
		return
	
	# 1. Pushbox (Cian semitransparente)
	var pushbox = get_node_or_null("Pushbox") as CollisionShape2D
	if pushbox and pushbox.shape is RectangleShape2D:
		_dibujar_forma_rect(pushbox, Color(0.0, 1.0, 0.8, 0.12), Color(0.0, 1.0, 0.8, 0.85))
	
	# 2. Hurtbox activa (Verde semitransparente)
	if hurtbox_estandar_collision and not hurtbox_estandar_collision.disabled:
		_dibujar_forma_rect(hurtbox_estandar_collision, Color(0.0, 0.85, 0.25, 0.25), Color(0.0, 1.0, 0.35, 0.95))
	if hurtbox_baja_collision and not hurtbox_baja_collision.disabled:
		_dibujar_forma_rect(hurtbox_baja_collision, Color(0.0, 0.85, 0.25, 0.25), Color(0.0, 1.0, 0.35, 0.95))
		
	# 3. Hitboxes activas (Rojo semitransparente)
	if hitbox_alta_collision and not hitbox_alta_collision.disabled:
		_dibujar_forma_rect(hitbox_alta_collision, Color(1.0, 0.1, 0.1, 0.35), Color(1.0, 0.2, 0.2, 0.95))
	if hitbox_media_collision and not hitbox_media_collision.disabled:
		_dibujar_forma_rect(hitbox_media_collision, Color(1.0, 0.1, 0.1, 0.35), Color(1.0, 0.2, 0.2, 0.95))
	if hitbox_baja_collision and not hitbox_baja_collision.disabled:
		_dibujar_forma_rect(hitbox_baja_collision, Color(1.0, 0.1, 0.1, 0.35), Color(1.0, 0.2, 0.2, 0.95))

func _dibujar_forma_rect(col: CollisionShape2D, color_relleno: Color, color_borde: Color) -> void:
	if not col or not col.shape or not debug_overlay:
		return
	if col.shape is RectangleShape2D:
		var tam = col.shape.size
		var centro = debug_overlay.to_local(col.global_position)
		var r = Rect2(centro - tam / 2.0, tam)
		debug_overlay.draw_rect(r, color_relleno, true)
		debug_overlay.draw_rect(r, color_borde, false, 2.5)
