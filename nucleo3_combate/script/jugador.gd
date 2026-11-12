extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -750.0 

const ESCENA_PROYECTIL_HADOKEN := preload("res://escenas/proyectil_hadoken.tscn")

# Empuje base (x, y) de cada ataque. La X se invierte según la mirada.
const EMPUJES_ATAQUE: Dictionary = {
	"ataque_golpe": Vector2(180.0, 0.0),
	"ataque_patada": Vector2(280.0, 0.0),
	"ataque_punio_arriba": Vector2(180.0, -300.0),
	"ataque_patada_arriba": Vector2(160.0, -300.0),
	"ataque_punio_abajo": Vector2(160.0, 40.0),
	"ataque_patada_abajo": Vector2(240.0, 60.0),
	"ataque_aire_punio": Vector2(200.0, 120.0),
	"ataque_aire_patada": Vector2(240.0, 100.0),
	"ataque_especial": Vector2(250.0, -750.0),
	"ataque_combo_punio_2": Vector2(220.0, 0.0),
	"ataque_combo_punio_3": Vector2(480.0, -60.0),
	"ataque_combo_patada_2": Vector2(280.0, 0.0),
	"ataque_combo_patada_3": Vector2(540.0, -80.0),
	"ataque_tatsumaki": Vector2(300.0, -100.0),
}

# Dash y especiales
const VENTANA_DOBLE_TOQUE_MS := 280
const VENTANA_ESPECIAL_MS := 500
const DURACION_DASH := 0.22
const VELOCIDAD_DASH_ADELANTE := 850.0
const VELOCIDAD_DASH_ATRAS := 700.0
const IMPULSO_ESPECIAL_X := 320.0
const IMPULSO_ESPECIAL_Y := -750.0
const DURACION_TATSUMAKI := 0.9
const VELOCIDAD_TATSUMAKI := 1000.0
const DURACION_HADOKEN := 0.9
const MOMENTO_LANZAMIENTO_HADOKEN := 0.35

# Combos y cooldown
const VENTANA_COMBO := 0.7
const COOLDOWN_ATAQUE := 0.18
const COOLDOWN_ATAQUE_FINAL := 0.45
const COOLDOWN_ESPECIAL := 0.7

# Pushboxes estilo Mortal Kombat
const DISTANCIA_PUSHBOX := 150.0
const ALTURA_PUSHBOX := 170.0

# Escala del sprite según la hoja de animación utilizada
const ESCALA_SPRITE_BASE := Vector2(3.4045453, 3.1996799)
const ESCALA_ANIMACIONES: Dictionary = {
	"Hadoken": Vector2(1.6, 1.6),
	"Tatsumaki": Vector2(1.6, 1.6),
}

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
var rebotes_restantes: int = 0
var _stun_seq: int = 0
var _lanzamiento_seq: int = 0

# Dash, especiales, combos y cooldown
var _tiempo_dash: float = 0.0
var _direccion_dash: float = 1.0
var _tiempo_ultima_izquierda: float = -1000.0
var _tiempo_ultima_derecha: float = -1000.0
var _doble_toque_pendiente: float = 0.0
var _tiempo_ultimo_abajo: float = -1000.0
var _direccion_hadoken: float = 1.0
var _proyectil_lanzado: bool = false
var _tiempo_hadoken: float = 0.0
var _direccion_tatsumaki: float = 1.0
var _tiempo_tatsumaki: float = 0.0
var _cooldown_ataque: float = 0.0
var _combo_tipo: String = ""
var _combo_paso: int = 0
var _tiempo_combo: float = 0.0

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
	if hitbox_alta_collision: hitbox_alta_collision.set_deferred("disabled", true)
	if hitbox_media_collision: hitbox_media_collision.set_deferred("disabled", true)
	if hitbox_baja_collision: hitbox_baja_collision.set_deferred("disabled", true)

func activar_hitbox(altura: String) -> void:
	desactivar_todas_hitboxes()
	match altura:
		"ALTO":
			if hitbox_alta_collision: hitbox_alta_collision.set_deferred("disabled", false)
		"MEDIO":
			if hitbox_media_collision: hitbox_media_collision.set_deferred("disabled", false)
		"BAJO":
			if hitbox_baja_collision: hitbox_baja_collision.set_deferred("disabled", false)

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
	
	if Input.is_action_just_pressed(accion_abajo):
		_tiempo_ultimo_abajo = Time.get_ticks_msec()

	var ahora := Time.get_ticks_msec()
	if Input.is_action_just_pressed(accion_izquierda):
		if ahora - _tiempo_ultima_izquierda <= VENTANA_DOBLE_TOQUE_MS:
			_doble_toque_pendiente = -1.0
			_tiempo_ultima_izquierda = -1000.0
		else:
			_tiempo_ultima_izquierda = float(ahora)
	if Input.is_action_just_pressed(accion_derecha):
		if ahora - _tiempo_ultima_derecha <= VENTANA_DOBLE_TOQUE_MS:
			_doble_toque_pendiente = 1.0
			_tiempo_ultima_derecha = -1000.0
		else:
			_tiempo_ultima_derecha = float(ahora)

# --- DASH ---
func _detectar_dash(mirando_derecha: bool) -> bool:
	if _doble_toque_pendiente == 0.0:
		return false
	var direccion := _doble_toque_pendiente
	_doble_toque_pendiente = 0.0
	_iniciar_dash(direccion, mirando_derecha)
	return true

func _iniciar_dash(direccion: float, mirando_derecha: bool) -> void:
	var hacia_adelante := (direccion > 0.0) == mirando_derecha
	_direccion_dash = direccion
	_tiempo_dash = DURACION_DASH
	_reset_combo()
	desactivar_todas_hitboxes()
	if hacia_adelante:
		estado_actual = "dash_adelante"
		velocity.x = VELOCIDAD_DASH_ADELANTE * direccion
		actualizar_animacion("Dash_Adelante")
	else:
		estado_actual = "dash_atras"
		velocity.x = VELOCIDAD_DASH_ATRAS * direccion
		actualizar_animacion("Dash_Atras")

func _procesar_dash(delta: float) -> void:
	_tiempo_dash -= delta
	var velocidad := VELOCIDAD_DASH_ADELANTE if estado_actual == "dash_adelante" else VELOCIDAD_DASH_ATRAS
	velocity.x = _direccion_dash * velocidad
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_aplicar_limites_camara()
	_resolver_pushbox()
	if _tiempo_dash <= 0.0:
		estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
		actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")

# --- ESPECIALES ---
func _puede_iniciar_ataque() -> bool:
	return _cooldown_ataque <= 0.0

func _limpiar_movimientos_especiales() -> void:
	_tiempo_ultimo_abajo = -1000.0
	_tiempo_ultima_izquierda = -1000.0
	_tiempo_ultima_derecha = -1000.0

func _detectar_especiales(mirando_derecha: bool) -> String:
	if not _puede_iniciar_ataque():
		return ""

	var move_x: float = input_nucleo2["move_x"]
	if abs(move_x) < 0.2:
		return ""
	var direccion_adelante := 1.0 if mirando_derecha else -1.0
	if sign(move_x) != sign(direccion_adelante):
		return ""

	var ahora := Time.get_ticks_msec()
	var tiempo_atras := _tiempo_ultima_izquierda if mirando_derecha else _tiempo_ultima_derecha
	var atras_reciente := ahora - tiempo_atras <= VENTANA_ESPECIAL_MS
	var abajo_reciente := ahora - _tiempo_ultimo_abajo <= VENTANA_ESPECIAL_MS

	if input_nucleo2["kick"] and atras_reciente:
		_limpiar_movimientos_especiales()
		return "tatsumaki"

	if input_nucleo2["punch"]:
		if atras_reciente and (not abajo_reciente or tiempo_atras >= _tiempo_ultimo_abajo):
			_limpiar_movimientos_especiales()
			return "hadoken"
		if abajo_reciente:
			_limpiar_movimientos_especiales()
			return "shoryuken"

	return ""

func _iniciar_ataque_especial(mirando_derecha: bool) -> void:
	estado_actual = "ataque_especial"
	_reset_combo()
	var direccion := 1.0 if mirando_derecha else -1.0
	velocity = Vector2(IMPULSO_ESPECIAL_X * direccion, IMPULSO_ESPECIAL_Y)
	actualizar_animacion("Shoryuken")
	activar_hitbox("ALTO")

func _procesar_ataque_especial(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)
	if velocity.y >= 0.0:
		desactivar_todas_hitboxes()
	move_and_slide()
	_aplicar_limites_camara()
	_resolver_pushbox()
	if is_on_floor() and velocity.y >= 0.0:
		estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
		actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")
		_cooldown_ataque = COOLDOWN_ESPECIAL

# --- HADOKEN ---
func _iniciar_ataque_hadoken(mirando_derecha: bool) -> void:
	estado_actual = "ataque_hadoken"
	_reset_combo()
	_direccion_hadoken = 1.0 if mirando_derecha else -1.0
	_proyectil_lanzado = false
	_tiempo_hadoken = DURACION_HADOKEN
	velocity.x = 0.0
	desactivar_todas_hitboxes()
	actualizar_animacion("Hadoken")

func _procesar_ataque_hadoken(delta: float) -> void:
	_tiempo_hadoken -= delta
	velocity.x = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta
	if not _proyectil_lanzado and _tiempo_hadoken <= DURACION_HADOKEN - MOMENTO_LANZAMIENTO_HADOKEN:
		_proyectil_lanzado = true
		_lanzar_proyectil_hadoken()
	move_and_slide()
	_aplicar_limites_camara()
	_resolver_pushbox()
	if _tiempo_hadoken <= 0.0:
		desactivar_todas_hitboxes()
		estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
		actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")
		_cooldown_ataque = COOLDOWN_ESPECIAL

func _lanzar_proyectil_hadoken() -> void:
	var proyectil = ESCENA_PROYECTIL_HADOKEN.instantiate()
	proyectil.dueno_id = player_id
	proyectil.direccion = _direccion_hadoken
	get_parent().add_child(proyectil)
	proyectil.global_position = global_position + Vector2(100.0 * _direccion_hadoken, -40.0)

# --- TATSUMAKI ---
func _iniciar_ataque_tatsumaki(mirando_derecha: bool) -> void:
	estado_actual = "ataque_tatsumaki"
	_reset_combo()
	_direccion_tatsumaki = 1.0 if mirando_derecha else -1.0
	_tiempo_tatsumaki = DURACION_TATSUMAKI
	velocity = Vector2(_direccion_tatsumaki * VELOCIDAD_TATSUMAKI, 0.0)
	actualizar_animacion("Tatsumaki")
	activar_hitbox("MEDIO")

func _procesar_ataque_tatsumaki(delta: float) -> void:
	_tiempo_tatsumaki -= delta
	velocity.x = _direccion_tatsumaki * VELOCIDAD_TATSUMAKI
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_aplicar_limites_camara()
	_resolver_pushbox()
	if _tiempo_tatsumaki <= 0.0:
		estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
		actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")
		desactivar_todas_hitboxes()
		_cooldown_ataque = COOLDOWN_ESPECIAL

# --- COMBOS (AAA / BBB) ---
func _reset_combo() -> void:
	_combo_tipo = ""
	_combo_paso = 0
	_tiempo_combo = 0.0

func _siguiente_paso_combo(tipo: String) -> int:
	if _combo_tipo == tipo and _tiempo_combo > 0.0 and _combo_paso in [1, 2]:
		return _combo_paso + 1
	return 1

func _iniciar_combo(tipo: String, paso: int = 0) -> void:
	if not _puede_iniciar_ataque():
		return
	if paso == 0:
		paso = _siguiente_paso_combo(tipo)

	_combo_tipo = tipo
	_combo_paso = paso
	_tiempo_combo = 0.0
	velocity.x = 0.0
	desactivar_todas_hitboxes()

	if tipo == "punio":
		estado_actual = "ataque_golpe" if paso == 1 else "ataque_combo_punio_%d" % paso
		actualizar_animacion("Golpear", true)
	else:
		estado_actual = "ataque_patada" if paso == 1 else "ataque_combo_patada_%d" % paso
		actualizar_animacion("Patada", true)

	activar_hitbox("MEDIO")

func _intentar_encadenar_combo() -> bool:
	if not _puede_iniciar_ataque():
		return false
	var estados_encadenables := [
		"ataque_golpe", "ataque_combo_punio_2",
		"ataque_patada", "ataque_combo_patada_2"
	]
	if estado_actual not in estados_encadenables:
		return false

	var tipo := ""
	if input_nucleo2["punch"] and input_nucleo2["move_y"] != 1:
		tipo = "punio"
	elif input_nucleo2["kick"] and input_nucleo2["move_y"] != 1:
		tipo = "patada"
	if tipo == "" or tipo != _combo_tipo:
		return false
	if _combo_paso >= 3:
		return false

	_iniciar_combo(tipo, _combo_paso + 1)
	return true

func _physics_process(delta: float) -> void:
	_simular_entrada_nucleo2()
	_actualizar_hurtbox()

	if _cooldown_ataque > 0.0:
		_cooldown_ataque = max(0.0, _cooldown_ataque - delta)
	if _tiempo_combo > 0.0:
		_tiempo_combo = max(0.0, _tiempo_combo - delta)
		if _tiempo_combo == 0.0 and not estado_actual.begins_with("ataque_"):
			_combo_tipo = ""
			_combo_paso = 0

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

	if estado_actual not in ["dano", "derrota", "agarrado", "lanzado", "caida_rebote", "en_suelo", "dash_adelante", "dash_atras", "ataque_especial", "ataque_hadoken", "ataque_tatsumaki"]:
		sprite.flip_h = not mirando_derecha
		var dir_x = 1.0 if mirando_derecha else -1.0
		if hitbox_alta: hitbox_alta.scale.x = dir_x
		if hitbox_media: hitbox_media.scale.x = dir_x
		if hitbox_baja: hitbox_baja.scale.x = dir_x
	# 2. ESTADOS RESTRICTIVOS
	if estado_actual == "agarrado":
		return

	if estado_actual in ["dano", "derrota", "lanzado", "caida_rebote", "en_suelo"]:
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
		_resolver_pushbox()
		
		# Impacto contra el suelo: rebote o levantarse
		if estado_actual in ["lanzado", "caida_rebote"] and is_on_floor() and velocity.y >= 0:
			if current_hp <= 0:
				estado_actual = "derrota"
				velocity = Vector2.ZERO
				actualizar_animacion("Tumbar")
			elif rebotes_restantes > 0:
				rebotes_restantes -= 1
				velocity.y = -400.0
				velocity.x *= 0.5
				estado_actual = "caida_rebote"
			else:
				_iniciar_levantarse_del_suelo()
			return
			
		return

	# 3. LÓGICA DE AGARRE (Atacante)
	if estado_actual == "agarrando":
		tiempo_agarre += delta
		
		if rival_agarrado:
			var direccion_mirada = 1 if mirando_derecha else -1
			var posicion_manos = global_position + Vector2(60 * direccion_mirada, 0)

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
					# Lanzamiento hacia atrás: colocamos al rival detrás para
					# garantizar el cambio de lado antes de impulsarlo.
					rival_agarrado.global_position.x = global_position.x - 60.0 * direccion_mirada
					direccion_lanzamiento = Vector2(-600 if mirando_derecha else 600, -300)
			elif input_nucleo2["punch"] or input_nucleo2["kick"]:
				direccion_lanzamiento = Vector2(600 if mirando_derecha else -600, -300)
			
			if direccion_lanzamiento != Vector2.ZERO:
				rival_agarrado.ser_lanzado(direccion_lanzamiento)
				estado_actual = "reposo"
				actualizar_animacion("Reposo")
				rival_agarrado = null
			elif tiempo_agarre >= 1.5: 
				rival_agarrado.liberar_agarre()
				estado_actual = "reposo"
				actualizar_animacion("Reposo")
				rival_agarrado = null
				
		move_and_slide()
		_aplicar_limites_camara()
		_resolver_pushbox()
		return

	# 3.5 DASH Y ATAQUES ESPECIALES
	if estado_actual == "ataque_especial":
		_procesar_ataque_especial(delta)
		return

	if estado_actual == "ataque_tatsumaki":
		_procesar_ataque_tatsumaki(delta)
		return

	if estado_actual == "ataque_hadoken":
		_procesar_ataque_hadoken(delta)
		return

	if estado_actual in ["dash_adelante", "dash_atras"]:
		_procesar_dash(delta)
		return

	if is_on_floor() and not input_nucleo2["block"] and not estado_actual.begins_with("ataque_") and estado_actual != "intentar_agarre":
		if _puede_iniciar_ataque():
			match _detectar_especiales(mirando_derecha):
				"hadoken":
					_iniciar_ataque_hadoken(mirando_derecha)
					return
				"tatsumaki":
					_iniciar_ataque_tatsumaki(mirando_derecha)
					return
				"shoryuken":
					_iniciar_ataque_especial(mirando_derecha)
					return
		if _detectar_dash(mirando_derecha):
			_procesar_dash(delta)
			return

	# 3.6 ENCADENAMIENTO DE COMBOS (AAA / BBB)
	if estado_actual.begins_with("ataque_") and is_on_floor():
		if _intentar_encadenar_combo():
			return

	if estado_actual.begins_with("ataque_") or estado_actual == "intentar_agarre":
		if is_on_floor():
			velocity.x = 0
			move_and_slide()
			_aplicar_limites_camara()
			_resolver_pushbox()
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
			if input_nucleo2["punch"] and _puede_iniciar_ataque():
				_reset_combo()
				estado_actual = "ataque_punio_abajo"
				actualizar_animacion("Punio_Abajo")
				desactivar_todas_hitboxes()
			elif input_nucleo2["kick"] and _puede_iniciar_ataque():
				_reset_combo()
				estado_actual = "ataque_patada_abajo"
				actualizar_animacion("Patada_Abajo")
				activar_hitbox("BAJO")
			else:
				estado_actual = "agachado"
				actualizar_animacion("Agachado")
				desactivar_todas_hitboxes()
		elif input_nucleo2["punch"] and _puede_iniciar_ataque():
			velocity.x = 0
			if input_nucleo2["move_y"] == 1:
				_reset_combo()
				estado_actual = "ataque_punio_arriba"
				actualizar_animacion("Punio_Arriba")
				desactivar_todas_hitboxes()
			else:
				_iniciar_combo("punio")
		elif input_nucleo2["kick"] and _puede_iniciar_ataque():
			velocity.x = 0
			if input_nucleo2["move_y"] == 1:
				_reset_combo()
				estado_actual = "ataque_patada_arriba"
				actualizar_animacion("Patada_Arriba")
				desactivar_todas_hitboxes()
			else:
				_iniciar_combo("patada")
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
				activar_hitbox("BAJO")

	move_and_slide()
	_resolver_pushbox()
	_aplicar_limites_camara()

# --- PUSHBOXES ESTILO MORTAL KOMBAT ---
func _resolver_pushbox() -> void:
	if not rival or not is_instance_valid(rival):
		return
	var estado_rival = rival.get("estado_actual")
	if estado_rival == null:
		return

	var estados_ignorados := ["agarrado", "agarrando", "lanzado", "caida_rebote", "en_suelo", "derrota"]
	if estado_actual in estados_ignorados or estado_rival in estados_ignorados:
		return

	var distancia_vertical: float = rival.global_position.y - global_position.y
	if abs(distancia_vertical) > ALTURA_PUSHBOX:
		return

	var distancia_horizontal: float = rival.global_position.x - global_position.x
	var distancia: float = absf(distancia_horizontal)
	if distancia >= DISTANCIA_PUSHBOX:
		return

	var direccion: float = signf(distancia_horizontal)
	if direccion == 0.0:
		direccion = -1.0 if player_id < int(rival.get("player_id")) else 1.0

	var correccion: float = (DISTANCIA_PUSHBOX - distancia) * 0.5
	global_position.x -= direccion * correccion
	rival.global_position.x += direccion * correccion

	# Frenar la velocidad que empuja contra el rival, como un muro
	if velocity.x * direccion > 0.0:
		velocity.x = 0.0
	if rival is CharacterBody2D and rival.velocity.x * direccion < 0.0:
		rival.velocity.x = 0.0


# --- ANIMACIONES Y FOTOGRAMAS ---
func actualizar_animacion(nombre_anim: String, forzar: bool = false) -> void:
	if not sprite:
		return
	sprite.scale = ESCALA_ANIMACIONES.get(nombre_anim, ESCALA_SPRITE_BASE)
	if forzar:
		sprite.play(nombre_anim)
		sprite.frame = 0
	elif sprite.animation != nombre_anim or not sprite.is_playing():
		sprite.play(nombre_anim)

func _on_sprite_frame_changed() -> void:
	if not sprite:
		return

	# El proyectil sale en el fotograma de lanzamiento del Hadoken
	if estado_actual == "ataque_hadoken":
		if sprite.frame >= 2 and not _proyectil_lanzado:
			_proyectil_lanzado = true
			_lanzar_proyectil_hadoken()
		return

	# Los especiales gestionan sus propias hitboxes
	if estado_actual in ["ataque_especial", "ataque_tatsumaki"]:
		return

	# Para ataques de múltiples frames, activar la hitbox correspondiente en frame 1
	if sprite.frame == 1:
		match estado_actual:
			"ataque_golpe", "ataque_combo_punio_2", "ataque_combo_punio_3", \
			"ataque_patada", "ataque_combo_patada_2", "ataque_combo_patada_3":
				activar_hitbox("MEDIO")
			"ataque_punio_arriba", "ataque_patada_arriba":
				activar_hitbox("ALTO")
			"ataque_punio_abajo":
				activar_hitbox("BAJO")
			"ataque_aire_patada":
				activar_hitbox("BAJO")
			"intentar_agarre":
				activar_hitbox("MEDIO")
	elif sprite.frame > 1:
		# En fotogramas de recuperación o viento, apagar hitboxes
		if estado_actual.begins_with("ataque_") or estado_actual == "intentar_agarre":
			desactivar_todas_hitboxes()

func _on_sprite_animation_finished() -> void:
	# Hadoken y Tatsumaki se controlan por temporizador para no depender
	# de que la animación tenga fotogramas configurados.
	if estado_actual in ["ataque_hadoken", "ataque_tatsumaki"]:
		return

	if estado_actual in ["ataque_especial", "dash_adelante", "dash_atras"]:
		return
	if estado_actual.begins_with("ataque_") or estado_actual == "intentar_agarre":
		desactivar_todas_hitboxes()

		# El tercer golpe del combo cierra la secuencia y aplica más recuperación
		if estado_actual in ["ataque_combo_punio_3", "ataque_combo_patada_3"]:
			_cooldown_ataque = COOLDOWN_ATAQUE_FINAL
			_reset_combo()
		else:
			_cooldown_ataque = COOLDOWN_ATAQUE
			# Mantener viva la ventana para encadenar el siguiente golpe
			if estado_actual in ["ataque_golpe", "ataque_combo_punio_2", "ataque_patada", "ataque_combo_patada_2"]:
				_tiempo_combo = VENTANA_COMBO
		
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
func _empuje_segun_ataque() -> Vector2:
	var direccion := -1.0 if (sprite and sprite.flip_h) else 1.0
	var empuje_base: Vector2 = EMPUJES_ATAQUE.get(estado_actual, Vector2(150.0, 0.0))
	return Vector2(empuje_base.x * direccion, empuje_base.y)

func _on_hitbox_area_entered(area_rival: Area2D) -> void:
	var es_hurtbox = area_rival.name in ["Hurtbox-Estandar", "Hurtbox-Baja", "Hurtbox"]
	if es_hurtbox and area_rival.get_parent() != self:
		var rival_atacado = area_rival.get_parent()
		if rival_atacado and rival_atacado.has_method("recibir_ataque"):
			var es_agarre = (estado_actual == "intentar_agarre")
			var empuje_ataque = Vector2.ZERO if es_agarre else _empuje_segun_ataque()
			var altura_ataque = "MEDIO" 
			
			if estado_actual in ["ataque_punio_abajo", "ataque_patada_abajo", "ataque_aire_patada"]: 
				altura_ataque = "BAJO"
			elif estado_actual in ["ataque_aire_punio", "ataque_patada_arriba", "ataque_punio_arriba", "ataque_especial"]: 
				altura_ataque = "ALTO"
			
			desactivar_todas_hitboxes()
			
			var estados_no_agarrables = ["agarrado", "derrota", "en_suelo", "lanzado", "caida_rebote"]
			if es_agarre and rival_atacado.is_on_floor() and rival_atacado.estado_actual not in estados_no_agarrables:
				estado_actual = "agarrando"
				rival_agarrado = rival_atacado
				tiempo_agarre = 0.0
				
			rival_atacado.recibir_ataque(fuerza_golpe, empuje_ataque, player_id, altura_ataque, es_agarre)

func recibir_ataque(cantidad: int, empuje: Vector2, atacante_id: int, altura: String, es_agarre: bool) -> void:
	if estado_actual in ["derrota", "en_suelo", "agarrado"]:
		return

	_reset_combo()

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
		velocity = Vector2(empuje.x * 0.35, 0.0)
		imprimir_evento_combate("BLOCK", atacante_id, player_id, 0)
	else:
		current_hp = max(0, current_hp - cantidad)
		estado_actual = "dano"
		velocity = empuje
		imprimir_evento_combate("HIT", atacante_id, player_id, cantidad)
		actualizar_animacion("Stun")
		
		if current_hp <= 0:
			estado_actual = "derrota"
			imprimir_evento_combate("KO", atacante_id, player_id, 0)
			actualizar_animacion("Tumbar")
		else:
			_stun_seq += 1
			var mi_stun := _stun_seq
			await get_tree().create_timer(0.3).timeout
			while estado_actual == "dano" and not is_on_floor():
				await get_tree().physics_frame
			if estado_actual == "dano" and mi_stun == _stun_seq:
				estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
				actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")

func ser_lanzado(fuerza_vector: Vector2) -> void:
	estado_actual = "lanzado"
	_reset_combo()
	velocity = fuerza_vector
	current_hp = max(0, current_hp - 10)
	rebotes_restantes = 1
	_stun_seq += 1
	_lanzamiento_seq += 1
	
	collision_layer = 1
	collision_mask = 1
	desactivar_todas_hitboxes()
	
	imprimir_evento_combate("HIT", rival.player_id if rival else 0, player_id, 10)
	actualizar_animacion("Tumbar")
	
	if current_hp <= 0:
		estado_actual = "derrota"
		imprimir_evento_combate("KO", rival.player_id if rival else 0, player_id, 0)
	else:
		_seguridad_levantarse(_lanzamiento_seq)

func _seguridad_levantarse(numero_lanzamiento: int) -> void:
	await get_tree().create_timer(1.5).timeout
	if numero_lanzamiento != _lanzamiento_seq:
		return
	if estado_actual in ["lanzado", "caida_rebote"] and is_on_floor():
		if current_hp > 0:
			_iniciar_levantarse_del_suelo()

func _iniciar_levantarse_del_suelo() -> void:
	rebotes_restantes = 0
	estado_actual = "en_suelo"
	velocity = Vector2.ZERO
	desactivar_todas_hitboxes()
	actualizar_animacion("Tumbar")
	
	await get_tree().create_timer(0.3).timeout
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
	rebotes_restantes = 0
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
	rebotes_restantes = 0
	_tiempo_dash = 0.0
	_doble_toque_pendiente = 0.0
	_tiempo_ultima_izquierda = -1000.0
	_tiempo_ultima_derecha = -1000.0
	_tiempo_ultimo_abajo = -1000.0
	_cooldown_ataque = 0.0
	_tiempo_tatsumaki = 0.0
	_tiempo_hadoken = 0.0
	_proyectil_lanzado = false
	_reset_combo()
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
