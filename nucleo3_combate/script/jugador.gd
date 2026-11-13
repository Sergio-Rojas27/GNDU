extends CharacterBody2D

signal on_combat_event(evento: Dictionary)

const SPEED = 300.0
const JUMP_VELOCITY = -750.0 

const ESCENA_PROYECTIL_HADOKEN := preload("res://escenas/proyectil_hadoken.tscn")

# Límites y tabla de daño por ataque (rango permitido: 1.5 a 5.0)
const DANIO_MINIMO := 1.5
const DANIO_MAXIMO := 5.0
const DANIO_LANZAMIENTO := 3.0
const DANIO_BLOQUEO := 0.5

const DANIOS_ATAQUE: Dictionary = {
	"ataque_punio_abajo": 1.5,
	"ataque_golpe": 2.0,
	"ataque_patada_abajo": 2.0,
	"ataque_aire_punio": 2.0,
	"ataque_combo_punio_2": 2.5,
	"ataque_combo_aba_2": 2.5,
	"ataque_patada": 2.5,
	"ataque_punio_arriba": 2.5,
	"ataque_aire_patada": 2.5,
	"ataque_patada_arriba": 3.0,
	"ataque_combo_patada_2": 3.0,
	"ataque_combo_punio_3": 3.5,
	"ataque_combo_aba_3": 3.5,
	"ataque_combo_aab_3": 3.5,
	"ataque_doble_patada": 3.5,
	"ataque_embestida": 3.5,
	"ataque_combo_patada_3": 4.0,
	"ataque_tatsumaki": 4.0,
	"ataque_hadoken": 4.0,
	"ataque_abajo_arriba": 4.5,
	"ataque_especial": 5.0,
}

# Empuje base (x, y) de cada ataque. La X se invierte según la mirada.
const EMPUJES_ATAQUE: Dictionary = {
	"ataque_golpe": Vector2(-110.0, 0.0),
	"ataque_patada": Vector2(280.0, 0.0),
	"ataque_punio_arriba": Vector2(180.0, -300.0),
	"ataque_patada_arriba": Vector2(160.0, -300.0),
	"ataque_punio_abajo": Vector2(160.0, 40.0),
	"ataque_patada_abajo": Vector2(240.0, 60.0),
	"ataque_aire_punio": Vector2(200.0, 120.0),
	"ataque_aire_patada": Vector2(240.0, 100.0),
	"ataque_especial": Vector2(250.0, -750.0),
	"ataque_combo_punio_2": Vector2(70.0, -250.0),
	"ataque_combo_punio_3": Vector2(480.0, -60.0),
	"ataque_combo_aba_2": Vector2(50.0, -195.0),
	"ataque_combo_aba_3": Vector2(560.0, -80.0),
	"ataque_combo_aab_3": Vector2(150.0, -480.0),
	"ataque_combo_patada_2": Vector2(280.0, 0.0),
	"ataque_combo_patada_3": Vector2(540.0, -80.0),
	"ataque_tatsumaki": Vector2(300.0, -100.0),
	"ataque_doble_patada": Vector2(130.0, -560.0),
	"ataque_embestida": Vector2(140.0, 0.0),
	"ataque_abajo_arriba": Vector2(520.0, -680.0),
}

# Dash y especiales
const VENTANA_DOBLE_TOQUE_MS := 280
const VENTANA_ESPECIAL_MS := 550
const DURACION_DASH := 0.22
const VELOCIDAD_DASH_ADELANTE := 850.0
const VELOCIDAD_DASH_ATRAS := 700.0
const IMPULSO_ESPECIAL_X := 320.0
const IMPULSO_ESPECIAL_Y := -750.0
const DURACION_TATSUMAKI := 0.9
const VELOCIDAD_TATSUMAKI := 1000.0
const DURACION_HADOKEN := 0.9
const MOMENTO_LANZAMIENTO_HADOKEN := 0.35
const DURACION_DOBLE_PATADA := 0.48
const DURACION_EMBESTIDA := 0.46
const VELOCIDAD_EMBESTIDA := 880.0
const IMPULSO_ABAJO_ARRIBA_RETROCESO_X := 380.0
const IMPULSO_ABAJO_ARRIBA_Y := -540.0

# Combos, stun, mareo, bloqueo y cooldown
const VENTANA_COMBO := 0.7
const DURACION_STUN := 0.5
const DURACION_MAREO := 1.4
const DURACION_RETROCESO_BLOQUEO := 0.18
const VELOCIDAD_RETROCESO_BLOQUEO := 260.0
const COOLDOWN_ATAQUE := 0.18
const COOLDOWN_ATAQUE_FINAL := 0.45
const COOLDOWN_ESPECIAL := 0.7

# Pushboxes estilo Mortal Kombat
const DISTANCIA_PUSHBOX := 150.0
const ALTURA_PUSHBOX := 170.0

# Capas: los cuerpos de los jugadores no colisionan entre sí (solo con el mundo);
# la separación entre jugadores la resuelve la pushbox.
const CAPA_JUGADOR := 4
const MASCARA_MUNDO := 1

# Escala del sprite según la hoja de animación utilizada
const ESCALA_SPRITE_BASE := Vector2(3.4045453, 3.1996799)
const ESCALA_ANIMACIONES: Dictionary = {
	"Hadoken": Vector2(1.6, 1.6),
	"Tatsumaki": Vector2(1.6, 1.6),
}

@export_group("Datos del Jugador")
@export var player_id: int = 1
@export var max_hp: float = 100.0
@export_range(1.5, 5.0, 0.5) var fuerza_golpe: float = 2.0
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
var current_hp: float = 100.0

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
var _tiempo_izquierda_antes_de_abajo: float = -1000.0
var _tiempo_derecha_antes_de_abajo: float = -1000.0
var _doble_toque_pendiente: float = 0.0
var _tiempo_ultimo_abajo: float = -1000.0
var _tiempo_ultimo_arriba: float = -1000.0
var _tiempo_abajo_antes_de_arriba: float = -1000.0
var _direccion_hadoken: float = 1.0
var _proyectil_lanzado: bool = false
var _tiempo_hadoken: float = 0.0
var _direccion_tatsumaki: float = 1.0
var _tiempo_tatsumaki: float = 0.0
var _direccion_doble_patada: float = 1.0
var _tiempo_doble_patada: float = 0.0
var _fase_doble_patada: int = 0
var _direccion_embestida: float = 1.0
var _tiempo_embestida: float = 0.0
var _direccion_abajo_arriba: float = 1.0
var _tiempo_abajo_arriba: float = 0.0
var _retroceso_abajo_arriba_aplicado: bool = false
var _cooldown_ataque: float = 0.0
var _combo_tipo: String = ""
var _combo_paso: int = 0
var _combo_secuencia: String = ""
var _tiempo_combo: float = 0.0
var _tiempo_en_ataque_combo: float = 0.0
var _input_combo_pendiente: String = ""
var _tiempo_stun: float = 0.0
var _en_mareo: bool = false
var _rebote_suave_pendiente: bool = false
var _tiempo_retroceso_bloqueo: float = 0.0
var _tiempo_efecto_bloqueo: float = 0.0
var _ataque_aereo_usado: bool = false
var _castigo_shoryuken_pendiente: bool = false
var _golpe_conectado_en_ataque: bool = false

# Contador de combo (golpes seguidos mientras el rival sigue en stun)
var combo_actual: int = 0
var combo_label: Label

var input_nucleo2: Dictionary = {
	"move_x": 0, "move_y": 0, "salto": false,
	"punch": false, "kick": false, "block": false, "grab": false
}
var _usar_reporte_externo_n2: bool = false
var _estado_previo_n2: Dictionary = {
	"move_y": 0, "punch": false, "kick": false
}
var _comando_n2_pendiente: String = ""

var depurador_label: Label
var debug_overlay: Node2D
var fx_overlay: Node2D
var mostrar_cajas_debug: bool = false:
	set(valor):
		mostrar_cajas_debug = valor
		if debug_overlay:
			debug_overlay.queue_redraw()

func _ready() -> void:
	current_hp = max_hp
	collision_layer = CAPA_JUGADOR
	collision_mask = MASCARA_MUNDO
	desactivar_todas_hitboxes()
	_actualizar_hurtbox()
	
	if hitbox_alta: hitbox_alta.area_entered.connect(_on_hitbox_area_entered)
	if hitbox_media: hitbox_media.area_entered.connect(_on_hitbox_area_entered)
	if hitbox_baja: hitbox_baja.area_entered.connect(_on_hitbox_area_entered)
	
	if sprite:
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	var n2_core = get_node_or_null("/root/N2InputCore")
	if n2_core and n2_core.has_signal("report_emitted"):
		n2_core.connect("report_emitted", Callable(self, "recibir_reporte_entrada"))
		
	depurador_label = Label.new()
	add_child(depurador_label)
	depurador_label.position = Vector2(-100, -120) 
	depurador_label.add_theme_color_override("font_color", Color(1, 0, 0))
	
	combo_label = Label.new()
	add_child(combo_label)
	combo_label.position = Vector2(-125, -215)
	combo_label.size = Vector2(250, 45)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 30)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	combo_label.add_theme_constant_override("outline_size", 8)
	combo_label.visible = false
	
	debug_overlay = Node2D.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.z_index = 10
	debug_overlay.draw.connect(_on_debug_overlay_draw)
	add_child(debug_overlay)

	fx_overlay = Node2D.new()
	fx_overlay.name = "FxOverlay"
	fx_overlay.z_index = 9
	fx_overlay.draw.connect(_on_fx_overlay_draw)
	add_child(fx_overlay)

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
		"ALTO_MEDIO":
			if hitbox_alta_collision: hitbox_alta_collision.set_deferred("disabled", false)
			if hitbox_media_collision: hitbox_media_collision.set_deferred("disabled", false)
		"MEDIO_BAJO":
			if hitbox_media_collision: hitbox_media_collision.set_deferred("disabled", false)
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
	if _usar_reporte_externo_n2:
		_usar_reporte_externo_n2 = false
		return

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
	
	var ahora := float(Time.get_ticks_msec())
	if Input.is_action_just_pressed(accion_abajo):
		if ahora - _tiempo_ultima_derecha <= VENTANA_ESPECIAL_MS:
			_tiempo_derecha_antes_de_abajo = _tiempo_ultima_derecha
		if ahora - _tiempo_ultima_izquierda <= VENTANA_ESPECIAL_MS:
			_tiempo_izquierda_antes_de_abajo = _tiempo_ultima_izquierda
		_tiempo_ultimo_abajo = ahora
	elif Input.is_action_pressed(accion_abajo):
		_tiempo_ultimo_abajo = ahora

	if Input.is_action_just_pressed(accion_arriba):
		if ahora - _tiempo_ultimo_abajo <= VENTANA_ESPECIAL_MS:
			_tiempo_abajo_antes_de_arriba = _tiempo_ultimo_abajo
		_tiempo_ultimo_arriba = ahora

	if Input.is_action_just_pressed(accion_izquierda):
		if ahora - _tiempo_ultima_izquierda <= VENTANA_DOBLE_TOQUE_MS and _tiempo_ultimo_abajo < _tiempo_ultima_izquierda:
			_doble_toque_pendiente = -1.0
			_tiempo_ultima_izquierda = -1000.0
		else:
			_tiempo_ultima_izquierda = ahora
	if Input.is_action_just_pressed(accion_derecha):
		if ahora - _tiempo_ultima_derecha <= VENTANA_DOBLE_TOQUE_MS and _tiempo_ultimo_abajo < _tiempo_ultima_derecha:
			_doble_toque_pendiente = 1.0
			_tiempo_ultima_derecha = -1000.0
		else:
			_tiempo_ultima_derecha = ahora

func recibir_reporte_entrada(reporte_raw: Variant) -> void:
	var reporte: Dictionary = {}
	if typeof(reporte_raw) == TYPE_STRING:
		var parsed = JSON.parse_string(reporte_raw)
		if typeof(parsed) == TYPE_DICTIONARY:
			reporte = parsed
		else:
			return
	elif typeof(reporte_raw) == TYPE_DICTIONARY:
		reporte = reporte_raw
	else:
		return

	if int(reporte.get("player_id", -1)) != player_id:
		return

	var estado: Variant = reporte.get("state", {})
	if typeof(estado) != TYPE_DICTIONARY:
		return

	_usar_reporte_externo_n2 = true
	var move_x := int(estado.get("move_x", 0))
	var move_y := int(estado.get("move_y", 0))
	var punch_held := bool(estado.get("punch", false))
	var kick_held := bool(estado.get("kick", false))
	var block_held := bool(estado.get("block", false))

	var ahora := float(Time.get_ticks_msec())
	var prev_move_x := int(_estado_previo_n2.get("move_x", 0))
	var prev_move_y := int(_estado_previo_n2.get("move_y", 0))
	var prev_punch := bool(_estado_previo_n2.get("punch", false))
	var prev_kick := bool(_estado_previo_n2.get("kick", false))

	input_nucleo2["move_x"] = move_x
	input_nucleo2["move_y"] = move_y
	input_nucleo2["salto"] = (move_y == 1 and prev_move_y != 1)
	input_nucleo2["punch"] = (punch_held and not prev_punch)
	input_nucleo2["kick"] = (kick_held and not prev_kick)
	input_nucleo2["block"] = block_held
	input_nucleo2["grab"] = false

	if move_y == -1 and prev_move_y != -1:
		if ahora - _tiempo_ultima_derecha <= VENTANA_ESPECIAL_MS:
			_tiempo_derecha_antes_de_abajo = _tiempo_ultima_derecha
		if ahora - _tiempo_ultima_izquierda <= VENTANA_ESPECIAL_MS:
			_tiempo_izquierda_antes_de_abajo = _tiempo_ultima_izquierda
		_tiempo_ultimo_abajo = ahora
	elif move_y == -1:
		_tiempo_ultimo_abajo = ahora

	if estado_actual != "agarrando":
		if Input.is_action_just_pressed(accion_abajo):
			if ahora - _tiempo_ultima_derecha <= VENTANA_ESPECIAL_MS:
				_tiempo_derecha_antes_de_abajo = _tiempo_ultima_derecha
			if ahora - _tiempo_ultima_izquierda <= VENTANA_ESPECIAL_MS:
				_tiempo_izquierda_antes_de_abajo = _tiempo_ultima_izquierda
			_tiempo_ultimo_abajo = ahora
		elif Input.is_action_pressed(accion_abajo) and _tiempo_ultimo_abajo > 0.0:
			# Solo mantiene vivo el tiempo si la pulsación empezó fuera del agarre
			_tiempo_ultimo_abajo = ahora
	if move_y == 1 and prev_move_y != 1:
		if ahora - _tiempo_ultimo_abajo <= VENTANA_ESPECIAL_MS:
			_tiempo_abajo_antes_de_arriba = _tiempo_ultimo_abajo
		_tiempo_ultimo_arriba = ahora

	if move_x == -1 and prev_move_x != -1:
		_tiempo_ultima_izquierda = ahora
	elif move_x == 1 and prev_move_x != 1:
		_tiempo_ultima_derecha = ahora

	var cmd = reporte.get("command_detected", null)
	if typeof(cmd) == TYPE_STRING and cmd != "":
		_comando_n2_pendiente = cmd
		if cmd == "DASH_LEFT":
			_doble_toque_pendiente = -1.0
		elif cmd == "DASH_RIGHT":
			_doble_toque_pendiente = 1.0

	_estado_previo_n2 = {
		"move_x": move_x,
		"move_y": move_y,
		"punch": punch_held,
		"kick": kick_held
	}

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
	if estado_actual == "dash_adelante" and input_nucleo2["kick"]:
		var mirando_derecha := _direccion_dash > 0.0
		if _detectar_especiales(mirando_derecha, true) == "embestida":
			_iniciar_ataque_embestida(mirando_derecha)
			return

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
	_tiempo_ultimo_arriba = -1000.0
	_tiempo_abajo_antes_de_arriba = -1000.0
	_tiempo_ultima_izquierda = -1000.0
	_tiempo_ultima_derecha = -1000.0
	_tiempo_izquierda_antes_de_abajo = -1000.0
	_tiempo_derecha_antes_de_abajo = -1000.0
	_doble_toque_pendiente = 0.0
	_comando_n2_pendiente = ""

func _detectar_especiales(mirando_derecha: bool, ignorar_cooldown: bool = false) -> String:
	if not ignorar_cooldown and not _puede_iniciar_ataque():
		return ""

	if _comando_n2_pendiente != "":
		var cmd := _comando_n2_pendiente
		match cmd:
			"SPECIAL_ATTACK_1", "COMBO_LEFT_RIGHT_A", "HADOKEN":
				_limpiar_movimientos_especiales()
				return "hadoken"
			"SPECIAL_ATTACK_2", "SHORYUKEN":
				_limpiar_movimientos_especiales()
				return "shoryuken"
			"COMBO_DOWN_UP_A", "ABAJO_ARRIBA":
				_limpiar_movimientos_especiales()
				return "abajo_arriba"
			"COMBO_DOWN_RIGHT_B", "DOBLE_PATADA":
				_limpiar_movimientos_especiales()
				return "doble_patada"
			"COMBO_RIGHT_DOWN_RIGHT_B", "EMBESTIDA":
				_limpiar_movimientos_especiales()
				return "embestida"
			"TATSUMAKI":
				_limpiar_movimientos_especiales()
				return "tatsumaki"

	var ahora := float(Time.get_ticks_msec())
	var move_x: float = float(input_nucleo2["move_x"])
	var move_y: int = int(input_nucleo2["move_y"])

	# ABAJO ARRIBA + A
	var abajo_arriba_reciente := (
		ahora - _tiempo_abajo_antes_de_arriba <= VENTANA_ESPECIAL_MS
		and ahora - _tiempo_ultimo_arriba <= VENTANA_ESPECIAL_MS
		and _tiempo_ultimo_arriba >= _tiempo_abajo_antes_de_arriba
	)
	if abajo_arriba_reciente and input_nucleo2["punch"]:
		_limpiar_movimientos_especiales()
		return "abajo_arriba"

	if absf(move_x) < 0.2:
		return ""
	var direccion_adelante := 1.0 if mirando_derecha else -1.0
	var moviendo_adelante := signf(move_x) == signf(direccion_adelante)
	var moviendo_derecha := move_x > 0.0

	var tiempo_atras := _tiempo_ultima_izquierda if mirando_derecha else _tiempo_ultima_derecha
	var atras_reciente := ahora - tiempo_atras <= VENTANA_ESPECIAL_MS
	var abajo_reciente := ahora - _tiempo_ultimo_abajo <= VENTANA_ESPECIAL_MS

	var tiempo_adelante_antes_abajo := _tiempo_derecha_antes_de_abajo if mirando_derecha else _tiempo_izquierda_antes_de_abajo
	var adelante_antes_abajo_reciente := (
		ahora - tiempo_adelante_antes_abajo <= VENTANA_ESPECIAL_MS
		and _tiempo_ultimo_abajo >= tiempo_adelante_antes_abajo
	)
	var derecha_antes_abajo_reciente := (
		ahora - _tiempo_derecha_antes_de_abajo <= VENTANA_ESPECIAL_MS
		and _tiempo_ultimo_abajo >= _tiempo_derecha_antes_de_abajo
	)

	if input_nucleo2["kick"] and (moviendo_adelante or moviendo_derecha):
		if abajo_reciente and (adelante_antes_abajo_reciente or (moviendo_derecha and derecha_antes_abajo_reciente)):
			_limpiar_movimientos_especiales()
			return "embestida"
		if abajo_reciente:
			_limpiar_movimientos_especiales()
			return "doble_patada"
		if moviendo_adelante and atras_reciente:
			_limpiar_movimientos_especiales()
			return "tatsumaki"

	if input_nucleo2["punch"] and moviendo_adelante:
		if atras_reciente and (not abajo_reciente or tiempo_atras >= _tiempo_ultimo_abajo):
			_limpiar_movimientos_especiales()
			return "hadoken"
		if abajo_reciente:
			_limpiar_movimientos_especiales()
			return "shoryuken"

	return ""

func _en_combo_basico_cancelable() -> bool:
	var estados_combo_basico := [
		"ataque_golpe", "ataque_combo_punio_2", "ataque_combo_punio_3",
		"ataque_combo_aba_2", "ataque_combo_aba_3", "ataque_combo_aab_3",
		"ataque_patada", "ataque_combo_patada_2", "ataque_combo_patada_3",
	]
	return estado_actual in estados_combo_basico or (_tiempo_combo > 0.0 and _combo_paso > 0)

func _intentar_ejecutar_especial(mirando_derecha: bool, permitir_cancelar_combo: bool = false) -> bool:
	match _detectar_especiales(mirando_derecha, permitir_cancelar_combo):
		"hadoken":
			_iniciar_ataque_hadoken(mirando_derecha)
			return true
		"tatsumaki":
			_iniciar_ataque_tatsumaki(mirando_derecha)
			return true
		"shoryuken":
			_iniciar_ataque_especial(mirando_derecha)
			return true
		"doble_patada":
			_iniciar_ataque_doble_patada(mirando_derecha)
			return true
		"embestida":
			_iniciar_ataque_embestida(mirando_derecha)
			return true
		"abajo_arriba":
			_iniciar_ataque_abajo_arriba(mirando_derecha)
			return true
	return false

func _iniciar_ataque_especial(mirando_derecha: bool) -> void:
	estado_actual = "ataque_especial"
	_golpe_conectado_en_ataque = false
	_ataque_aereo_usado = false
	_castigo_shoryuken_pendiente = true
	_reset_combo()
	var direccion := 1.0 if mirando_derecha else -1.0
	velocity = Vector2(IMPULSO_ESPECIAL_X * direccion, IMPULSO_ESPECIAL_Y)
	actualizar_animacion("Shoryuken")
	activar_hitbox("ALTO")

# --- ABAJO DERECHA + B: DOBLE PATADA HACIA ARRIBA ---
func _iniciar_ataque_doble_patada(mirando_derecha: bool) -> void:
	estado_actual = "ataque_doble_patada"
	_golpe_conectado_en_ataque = false
	_reset_combo()
	_direccion_doble_patada = 1.0 if mirando_derecha else -1.0
	_tiempo_doble_patada = DURACION_DOBLE_PATADA
	_fase_doble_patada = 1
	velocity = Vector2(_direccion_doble_patada * 160.0, -270.0)
	actualizar_animacion("Patada_Arriba", true)
	activar_hitbox("ALTO_MEDIO")

func _procesar_ataque_doble_patada(delta: float) -> void:
	_tiempo_doble_patada -= delta
	if _fase_doble_patada == 1 and _tiempo_doble_patada <= DURACION_DOBLE_PATADA * 0.55:
		_fase_doble_patada = 2
		_golpe_conectado_en_ataque = false
		velocity = Vector2(_direccion_doble_patada * 120.0, -340.0)
		actualizar_animacion("Patada_Aire", true)
		activar_hitbox("ALTO_MEDIO")
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = move_toward(velocity.x, 0.0, 260.0 * delta)
	move_and_slide()
	_aplicar_limites_camara()
	_resolver_pushbox()
	if _tiempo_doble_patada <= 0.0 and is_on_floor():
		if not _golpe_conectado_en_ataque and _fase_doble_patada == 2:
			imprimir_evento_combate("WHIFF", player_id, null, 0, 0, null, false, "sfx_whiff")
		desactivar_todas_hitboxes()
		estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
		actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")
		_cooldown_ataque = COOLDOWN_ATAQUE_FINAL

# --- DERECHA ABAJO DERECHA + B: EMBESTIDA ROMPE-GUARDIA (MAREO) ---
func _iniciar_ataque_embestida(mirando_derecha: bool) -> void:
	estado_actual = "ataque_embestida"
	_golpe_conectado_en_ataque = false
	_reset_combo()
	_direccion_embestida = 1.0 if mirando_derecha else -1.0
	_tiempo_embestida = DURACION_EMBESTIDA
	velocity = Vector2(_direccion_embestida * VELOCIDAD_EMBESTIDA, 0.0)
	actualizar_animacion("Dash_Adelante", true)
	activar_hitbox("ALTO_MEDIO")

func _procesar_ataque_embestida(delta: float) -> void:
	_tiempo_embestida -= delta
	if _golpe_conectado_en_ataque:
		velocity.x = move_toward(velocity.x, 0.0, 2200.0 * delta)
		if _tiempo_embestida > 0.12:
			_tiempo_embestida = 0.12
	else:
		velocity.x = _direccion_embestida * VELOCIDAD_EMBESTIDA
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_aplicar_limites_camara()
	_resolver_pushbox()
	if _tiempo_embestida <= 0.0:
		if not _golpe_conectado_en_ataque:
			imprimir_evento_combate("WHIFF", player_id, null, 0, 0, null, false, "sfx_whiff")
		desactivar_todas_hitboxes()
		estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
		actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")
		_cooldown_ataque = COOLDOWN_ESPECIAL

# --- ABAJO ARRIBA: PUÑO FUERTE HACIA ARRIBA CON RETROCESO AL EJECUTOR ---
func _iniciar_ataque_abajo_arriba(mirando_derecha: bool) -> void:
	estado_actual = "ataque_abajo_arriba"
	_golpe_conectado_en_ataque = false
	_ataque_aereo_usado = false
	_reset_combo()
	_direccion_abajo_arriba = 1.0 if mirando_derecha else -1.0
	_tiempo_abajo_arriba = 0.0
	_retroceso_abajo_arriba_aplicado = false
	velocity = Vector2.ZERO
	actualizar_animacion("Shoryuken", true)
	activar_hitbox("ALTO_MEDIO")

func _aplicar_retroceso_abajo_arriba() -> void:
	if _retroceso_abajo_arriba_aplicado:
		return
	_retroceso_abajo_arriba_aplicado = true
	velocity = Vector2(-_direccion_abajo_arriba * IMPULSO_ABAJO_ARRIBA_RETROCESO_X, IMPULSO_ABAJO_ARRIBA_Y)

func _procesar_ataque_abajo_arriba(delta: float) -> void:
	_tiempo_abajo_arriba += delta
	if not _retroceso_abajo_arriba_aplicado and (_tiempo_abajo_arriba >= 0.04 or _golpe_conectado_en_ataque):
		_aplicar_retroceso_abajo_arriba()
	if _retroceso_abajo_arriba_aplicado:
		if not is_on_floor():
			velocity += get_gravity() * delta
		velocity.x = move_toward(velocity.x, 0.0, 220.0 * delta)
		if velocity.y >= 0.0:
			desactivar_todas_hitboxes()
	move_and_slide()
	_aplicar_limites_camara()
	_resolver_pushbox()
	if _retroceso_abajo_arriba_aplicado and is_on_floor() and velocity.y >= 0.0 and _tiempo_abajo_arriba > 0.12:
		if not _golpe_conectado_en_ataque:
			imprimir_evento_combate("WHIFF", player_id, null, 0, 0, null, false, "sfx_whiff")
		desactivar_todas_hitboxes()
		estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
		actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")
		_cooldown_ataque = COOLDOWN_ATAQUE_FINAL

func _intentar_ataque_aereo() -> bool:
	if _ataque_aereo_usado:
		return false
	if input_nucleo2["punch"]:
		_ataque_aereo_usado = true
		_golpe_conectado_en_ataque = false
		_reset_combo()
		estado_actual = "ataque_aire_punio"
		actualizar_animacion("Punio_Aire", true)
		activar_hitbox("MEDIO")
		return true
	elif input_nucleo2["kick"]:
		_ataque_aereo_usado = true
		_golpe_conectado_en_ataque = false
		_reset_combo()
		estado_actual = "ataque_aire_patada"
		actualizar_animacion("Patada_Aire", true)
		activar_hitbox("BAJO")
		return true
	return false

func _procesar_ataque_especial(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		if not _ataque_aereo_usado and _intentar_ataque_aereo():
			move_and_slide()
			_aplicar_limites_camara()
			_resolver_pushbox()
			return
	velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)
	if velocity.y >= 0.0:
		desactivar_todas_hitboxes()
	move_and_slide()
	_aplicar_limites_camara()
	_resolver_pushbox()
	if is_on_floor() and velocity.y >= 0.0:
		if not _golpe_conectado_en_ataque:
			imprimir_evento_combate("WHIFF", player_id, null, 0, 0, null, false, "sfx_whiff")
		estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
		actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")
		_cooldown_ataque = COOLDOWN_ESPECIAL
		_castigo_shoryuken_pendiente = false

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
	proyectil.dueno = self
	proyectil.dueno_id = player_id
	proyectil.direccion = _direccion_hadoken
	get_parent().add_child(proyectil)
	proyectil.global_position = global_position + Vector2(100.0 * _direccion_hadoken, -40.0)

# --- TATSUMAKI ---
func _iniciar_ataque_tatsumaki(mirando_derecha: bool) -> void:
	estado_actual = "ataque_tatsumaki"
	_golpe_conectado_en_ataque = false
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
		if not _golpe_conectado_en_ataque:
			imprimir_evento_combate("WHIFF", player_id, null, 0, 0, null, false, "sfx_whiff")
		estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
		actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")
		desactivar_todas_hitboxes()
		_cooldown_ataque = COOLDOWN_ESPECIAL

# --- COMBOS (AAA / BBB / ABA / AAB) ---
func _reset_combo() -> void:
	_combo_tipo = ""
	_combo_paso = 0
	_combo_secuencia = ""
	_tiempo_combo = 0.0
	_tiempo_en_ataque_combo = 0.0
	_input_combo_pendiente = ""

func _siguiente_secuencia_combo(tipo: String, en_encadenamiento: bool = false) -> String:
	var letra := "A" if tipo == "punio" else "B"
	if en_encadenamiento or (_tiempo_combo > 0.0 and _combo_secuencia != ""):
		var candidata := _combo_secuencia + letra
		if candidata in ["AA", "AAA", "AB", "ABA", "AAB", "BB", "BBB"]:
			return candidata
	return letra

func _iniciar_combo(tipo: String, secuencia_forzada: String = "") -> void:
	var secuencia := secuencia_forzada if secuencia_forzada != "" else _siguiente_secuencia_combo(tipo, false)
	if secuencia.length() == 1 and not _puede_iniciar_ataque():
		return

	_combo_secuencia = secuencia
	_combo_paso = secuencia.length()
	_combo_tipo = "punio" if secuencia.begins_with("A") else "patada"
	_tiempo_combo = 0.0
	_tiempo_en_ataque_combo = 0.0
	_input_combo_pendiente = ""
	_golpe_conectado_en_ataque = false
	velocity.x = 0.0
	desactivar_todas_hitboxes()

	match secuencia:
		"A":
			estado_actual = "ataque_golpe"
			actualizar_animacion("Golpear", true)
			activar_hitbox("MEDIO")
		"AA":
			estado_actual = "ataque_combo_punio_2"
			actualizar_animacion("Punio_Arriba", true)
			activar_hitbox("ALTO_MEDIO")
		"AAA":
			estado_actual = "ataque_combo_punio_3"
			actualizar_animacion("Golpear", true)
			activar_hitbox("ALTO_MEDIO")
		"AB":
			estado_actual = "ataque_combo_aba_2"
			actualizar_animacion("Patada_Abajo", true)
			activar_hitbox("MEDIO_BAJO")
		"ABA":
			estado_actual = "ataque_combo_aba_3"
			actualizar_animacion("Golpear", true)
			activar_hitbox("ALTO_MEDIO")
		"AAB":
			estado_actual = "ataque_combo_aab_3"
			actualizar_animacion("Patada_Arriba", true)
			activar_hitbox("ALTO_MEDIO")
		"B":
			estado_actual = "ataque_patada"
			actualizar_animacion("Patada", true)
			activar_hitbox("MEDIO")
		"BB":
			estado_actual = "ataque_combo_patada_2"
			actualizar_animacion("Patada", true)
			activar_hitbox("MEDIO")
		"BBB":
			estado_actual = "ataque_combo_patada_3"
			actualizar_animacion("Patada", true)
			activar_hitbox("MEDIO")

func _intentar_encadenar_combo() -> bool:
	var estados_encadenables := [
		"ataque_golpe", "ataque_combo_punio_2", "ataque_combo_aba_2",
		"ataque_patada", "ataque_combo_patada_2"
	]
	if estado_actual not in estados_encadenables:
		return false
	if _combo_paso >= 3:
		return false

	if _comando_n2_pendiente in ["COMBO_ABA", "COMBO_AAB", "COMBO_AAA", "COMBO_BBB"]:
		var sec_cmd := _comando_n2_pendiente.trim_prefix("COMBO_")
		_comando_n2_pendiente = ""
		if _golpe_conectado_en_ataque or _tiempo_en_ataque_combo >= 0.1:
			_iniciar_combo("punio" if sec_cmd.ends_with("A") else "patada", sec_cmd)
			return true
		else:
			_input_combo_pendiente = "punio" if sec_cmd.ends_with("A") else "patada"

	var tipo := ""
	if input_nucleo2["punch"] and input_nucleo2["move_y"] != 1:
		tipo = "punio"
	elif input_nucleo2["kick"] and input_nucleo2["move_y"] != 1:
		tipo = "patada"

	if tipo != "":
		_input_combo_pendiente = tipo

	if _input_combo_pendiente == "":
		return false

	# Permitir que el golpe actual conecte o cumpla un tiempo mínimo antes de pasar al siguiente paso
	if not _golpe_conectado_en_ataque and _tiempo_en_ataque_combo < 0.12:
		return false

	var siguiente := _siguiente_secuencia_combo(_input_combo_pendiente, true)
	_input_combo_pendiente = ""
	if siguiente.length() <= _combo_paso:
		return false

	_iniciar_combo(tipo if tipo != "" else ("punio" if siguiente.ends_with("A") else "patada"), siguiente)
	return true

# --- CONTADOR DE COMBO ---
func _actualizar_contador_combo() -> void:
	if combo_actual > 0:
		var est_rival = rival.get("estado_actual") if rival and is_instance_valid(rival) else null
		if est_rival != "dano" and est_rival != "derrota":
			combo_actual = 0
	if combo_label:
		combo_label.visible = combo_actual > 0
		if combo_actual > 0:
			combo_label.text = "%d HITS" % combo_actual

func registrar_golpe_externo(objetivo: Node, estaba_en_stun: bool) -> void:
	if objetivo == null:
		return
	var est = objetivo.get("estado_actual")
	if est == "dano" or est == "derrota":
		if estaba_en_stun:
			combo_actual += 1
		else:
			combo_actual = 1
	elif est == "bloqueo_alto" or est == "bloqueo_bajo":
		combo_actual = 0

func reiniciar_contador_combo() -> void:
	combo_actual = 0
	if combo_label:
		combo_label.visible = false

func _physics_process(delta: float) -> void:
	_simular_entrada_nucleo2()
	_actualizar_hurtbox()
	_verificar_colision_hitboxes_activas()
	if is_on_floor():
		_ataque_aereo_usado = false
	_actualizar_contador_combo()

	if _cooldown_ataque > 0.0:
		_cooldown_ataque = max(0.0, _cooldown_ataque - delta)
	if _tiempo_combo > 0.0:
		_tiempo_combo = max(0.0, _tiempo_combo - delta)
		if _tiempo_combo == 0.0 and not estado_actual.begins_with("ataque_"):
			_combo_tipo = ""
			_combo_paso = 0
			_combo_secuencia = ""
	if estado_actual.begins_with("ataque_"):
		_tiempo_en_ataque_combo += delta
	if _tiempo_retroceso_bloqueo > 0.0:
		_tiempo_retroceso_bloqueo = maxf(0.0, _tiempo_retroceso_bloqueo - delta)
	if _tiempo_efecto_bloqueo > 0.0:
		_tiempo_efecto_bloqueo = maxf(0.0, _tiempo_efecto_bloqueo - delta)

	_actualizar_efectos_visuales()

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

	if estado_actual not in [
		"dano", "derrota", "agarrado", "lanzado", "caida_rebote", "en_suelo",
		"dash_adelante", "dash_atras", "ataque_especial", "ataque_hadoken",
		"ataque_tatsumaki", "ataque_doble_patada", "ataque_embestida", "ataque_abajo_arriba"
	]:
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
			if estado_actual == "dano":
				_tiempo_stun = max(0.15, _tiempo_stun - delta)
		else:
			if estado_actual == "dano" and _rebote_suave_pendiente and velocity.y >= 0.0:
				_rebote_suave_pendiente = false
				velocity.y = -195.0
				velocity.x *= 0.4
			else:
				velocity.x = move_toward(velocity.x, 0, 600.0 * delta)
				if estado_actual == "dano" and velocity.y >= 0.0:
					_tiempo_stun = max(0.0, _tiempo_stun - delta)
					if _en_mareo and _tiempo_stun > 0.0 and sprite and not sprite.is_playing():
						actualizar_animacion("Stun", true)
					if _tiempo_stun <= 0.0:
						_en_mareo = false
						estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
						actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")
						_actualizar_contador_combo()

		# Si un golpe acerca al jugador hacia el rival, evitar que lo atraviese
		if estado_actual == "dano" and rival and is_instance_valid(rival):
			var dist_al_rival := rival.global_position.x - global_position.x
			if absf(dist_al_rival) < 95.0 and velocity.x * dist_al_rival > 0.0:
				velocity.x = 0.0
		
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
				_limpiar_movimientos_especiales()
				estado_actual = "reposo"
				actualizar_animacion("Reposo")
				rival_agarrado = null
			elif tiempo_agarre >= 1.5: 
				rival_agarrado.liberar_agarre()
				_limpiar_movimientos_especiales()
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

	if estado_actual == "ataque_doble_patada":
		_procesar_ataque_doble_patada(delta)
		return

	if estado_actual == "ataque_embestida":
		_procesar_ataque_embestida(delta)
		return

	if estado_actual == "ataque_abajo_arriba":
		_procesar_ataque_abajo_arriba(delta)
		return

	if estado_actual in ["dash_adelante", "dash_atras"]:
		_procesar_dash(delta)
		return

	if is_on_floor() and not input_nucleo2["block"] and not estado_actual.begins_with("ataque_") and estado_actual != "intentar_agarre":
		if _intentar_ejecutar_especial(mirando_derecha, _en_combo_basico_cancelable()):
			return
		if _detectar_dash(mirando_derecha):
			_procesar_dash(delta)
			return

	# 3.6 CANCELACIÓN DE COMBO BÁSICO EN ESPECIAL Y ENCADENAMIENTO (AAA / BBB / ABA / AAB)
	if estado_actual.begins_with("ataque_") and is_on_floor():
		if not input_nucleo2["block"] and _en_combo_basico_cancelable():
			if _intentar_ejecutar_especial(mirando_derecha, true):
				return
		if _intentar_encadenar_combo():
			return

	if (estado_actual.begins_with("ataque_") and not estado_actual.begins_with("ataque_aire_")) or estado_actual == "intentar_agarre":
		if is_on_floor():
			velocity.x = 0
			move_and_slide()
			_aplicar_limites_camara()
			_resolver_pushbox()
			return

	# 4. MÁQUINA DE ESTADOS PRINCIPAL
	if is_on_floor():
		if estado_actual.begins_with("salto_") or estado_actual.begins_with("ataque_aire_"):
			if estado_actual.begins_with("ataque_aire_") and not _golpe_conectado_en_ataque:
				imprimir_evento_combate("WHIFF", player_id, null, 0, 0, null, false, "sfx_whiff")
			estado_actual = "reposo"
			desactivar_todas_hitboxes()
		if _castigo_shoryuken_pendiente:
			_cooldown_ataque = COOLDOWN_ESPECIAL
			_castigo_shoryuken_pendiente = false
				
		if input_nucleo2["grab"]:
			velocity.x = 0
			_golpe_conectado_en_ataque = false
			estado_actual = "intentar_agarre"
			actualizar_animacion("Agarre")
			desactivar_todas_hitboxes()
		elif input_nucleo2["block"]:
			if _tiempo_retroceso_bloqueo > 0.0:
				velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
			else:
				velocity.x = 0.0
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
				_golpe_conectado_en_ataque = false
				estado_actual = "ataque_punio_abajo"
				actualizar_animacion("Punio_Abajo")
				desactivar_todas_hitboxes()
			elif input_nucleo2["kick"] and _puede_iniciar_ataque():
				_reset_combo()
				_golpe_conectado_en_ataque = false
				estado_actual = "ataque_patada_abajo"
				actualizar_animacion("Patada_Abajo")
				activar_hitbox("BAJO")
			else:
				estado_actual = "agachado"
				actualizar_animacion("Agachado")
				desactivar_todas_hitboxes()
		elif input_nucleo2["punch"] and _puede_iniciar_ataque():
			velocity.x = 0
			if _intentar_ejecutar_especial(mirando_derecha):
				pass
			elif input_nucleo2["move_y"] == 1:
				_reset_combo()
				_golpe_conectado_en_ataque = false
				estado_actual = "ataque_punio_arriba"
				actualizar_animacion("Punio_Arriba")
				desactivar_todas_hitboxes()
			else:
				_iniciar_combo("punio")
		elif input_nucleo2["kick"] and _puede_iniciar_ataque():
			velocity.x = 0
			if input_nucleo2["move_y"] == 1:
				_reset_combo()
				_golpe_conectado_en_ataque = false
				estado_actual = "ataque_patada_arriba"
				actualizar_animacion("Patada_Arriba")
				desactivar_todas_hitboxes()
			else:
				_iniciar_combo("patada")
		elif input_nucleo2["salto"]:
			_ataque_aereo_usado = false
			desactivar_todas_hitboxes()
			velocity.y = JUMP_VELOCITY
			var direction = float(input_nucleo2["move_x"])
			if direction == 0.0:
				velocity.x = 0.0
				estado_actual = "salto_estatico"
				actualizar_animacion("Salto_Subida")
			else:
				velocity.x = signf(direction) * SPEED
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
		# LÓGICA EN EL AIRE (solo se permite un ataque por salto)
		# Permitir cancelar el inicio del salto en ABAJO ARRIBA + A si se pulsa A justo tras despegar
		if not _castigo_shoryuken_pendiente and velocity.y < JUMP_VELOCITY * 0.75:
			if _detectar_especiales(mirando_derecha, true) == "abajo_arriba":
				_iniciar_ataque_abajo_arriba(mirando_derecha)
				_procesar_ataque_abajo_arriba(delta)
				return

		# Si saltó estático y en los primeros fotogramas de despegue pulsa dirección, impulsar hacia ese lado
		if estado_actual == "salto_estatico" and velocity.y < JUMP_VELOCITY * 0.65 and float(input_nucleo2["move_x"]) != 0.0:
			var dir_aire := float(input_nucleo2["move_x"])
			velocity.x = signf(dir_aire) * SPEED
			var hacia_rival := (dir_aire > 0.0) == mirando_derecha
			estado_actual = "salto_adelante" if hacia_rival else "salto_atras"
			actualizar_animacion("Salto_Adelante" if hacia_rival else "Salto_Atras")
		elif estado_actual in ["salto_adelante", "salto_atras"] and absf(velocity.x) < SPEED * 0.5 and not _castigo_shoryuken_pendiente:
			var dir_salto := (1.0 if mirando_derecha else -1.0) if estado_actual == "salto_adelante" else (-1.0 if mirando_derecha else 1.0)
			velocity.x = dir_salto * SPEED

		velocity += get_gravity() * delta
		if _castigo_shoryuken_pendiente:
			velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)
		if not estado_actual.begins_with("ataque_aire_") and not _ataque_aereo_usado:
			_intentar_ataque_aereo()

	move_and_slide()
	_resolver_pushbox()
	_aplicar_limites_camara()

# --- PUSHBOXES ESTILO MORTAL KOMBAT ---
func _resolver_pushbox() -> void:
	if not rival or not is_instance_valid(rival):
		return
	# La pushbox solo actúa cuando ambos están apoyados en el suelo;
	# en el aire o al despegar en un salto los cuerpos no deben frenarse entre sí.
	if not is_on_floor() or not rival.is_on_floor():
		return
	if velocity.y < 0.0 or (rival is CharacterBody2D and rival.velocity.y < 0.0):
		return
	var estado_rival = rival.get("estado_actual")
	if estado_rival == null:
		return

	var estados_ignorados := [
		"dano", "agarrado", "agarrando", "lanzado", "caida_rebote", "en_suelo", "derrota",
		"salto_estatico", "salto_adelante", "salto_atras"
	]
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
	if estado_actual in ["ataque_especial", "ataque_tatsumaki", "ataque_doble_patada", "ataque_embestida", "ataque_abajo_arriba"]:
		return

	# Para ataques de múltiples frames, activar la hitbox correspondiente en frame 1
	# únicamente si el ataque actual aún no ha conectado en el fotograma inicial.
	if sprite.frame == 1 and not _golpe_conectado_en_ataque:
		match estado_actual:
			"ataque_golpe", "ataque_patada", "ataque_combo_patada_2", "ataque_combo_patada_3":
				activar_hitbox("MEDIO")
			"ataque_combo_punio_2", "ataque_combo_punio_3", "ataque_combo_aba_3", "ataque_combo_aab_3":
				activar_hitbox("ALTO_MEDIO")
			"ataque_combo_aba_2":
				activar_hitbox("MEDIO_BAJO")
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
	# Hadoken, Tatsumaki, Doble Patada, Embestida y Abajo-Arriba se controlan por su propia lógica
	if estado_actual in ["ataque_hadoken", "ataque_tatsumaki", "ataque_doble_patada", "ataque_embestida", "ataque_abajo_arriba"]:
		return

	if estado_actual in ["ataque_especial", "dash_adelante", "dash_atras"]:
		return
	if estado_actual.begins_with("ataque_") or estado_actual == "intentar_agarre":
		desactivar_todas_hitboxes()
		if not _golpe_conectado_en_ataque:
			imprimir_evento_combate("WHIFF", player_id, null, 0, 0, null, false, "sfx_whiff")

		# Si hay un botón de combo en búfer, encadenarlo antes de cerrar el estado
		if _input_combo_pendiente != "" and _intentar_encadenar_combo():
			return

		# El tercer golpe del combo cierra la secuencia y aplica más recuperación
		if _castigo_shoryuken_pendiente:
			_cooldown_ataque = COOLDOWN_ESPECIAL
		elif estado_actual in ["ataque_combo_punio_3", "ataque_combo_patada_3", "ataque_combo_aba_3", "ataque_combo_aab_3"]:
			_cooldown_ataque = COOLDOWN_ATAQUE_FINAL
			_reset_combo()
		else:
			_cooldown_ataque = COOLDOWN_ATAQUE
			# Mantener viva la ventana para encadenar el siguiente golpe
			if estado_actual in ["ataque_golpe", "ataque_combo_punio_2", "ataque_combo_aba_2", "ataque_patada", "ataque_combo_patada_2"]:
				_tiempo_combo = VENTANA_COMBO
		
		if not is_on_floor():
			if _castigo_shoryuken_pendiente:
				# Mantener el estado de caída vulnerable del Shoryuken hasta tocar el suelo
				estado_actual = "ataque_especial"
				_golpe_conectado_en_ataque = true
				actualizar_animacion("Shoryuken")
			elif velocity.x == 0:
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
			if _castigo_shoryuken_pendiente:
				_cooldown_ataque = COOLDOWN_ESPECIAL
				_castigo_shoryuken_pendiente = false
			estado_actual = "agachado" if input_nucleo2["move_y"] == -1 else "reposo"
			actualizar_animacion("Agachado" if input_nucleo2["move_y"] == -1 else "Reposo")


# --- DETECCIÓN DE IMPACTO Y COMBATE ---
func _verificar_colision_hitboxes_activas() -> void:
	if _golpe_conectado_en_ataque:
		return
	for par in [
		[hitbox_alta, hitbox_alta_collision],
		[hitbox_media, hitbox_media_collision],
		[hitbox_baja, hitbox_baja_collision],
	]:
		var area: Area2D = par[0]
		var col: CollisionShape2D = par[1]
		if area and col and not col.disabled:
			for area_rival in area.get_overlapping_areas():
				_on_hitbox_area_entered(area_rival)
				if _golpe_conectado_en_ataque:
					return

func _danio_segun_ataque() -> float:
	if estado_actual == "ataque_doble_patada":
		return 1.5 if _fase_doble_patada == 1 else 2.5
	var danio_base: float = float(DANIOS_ATAQUE.get(estado_actual, fuerza_golpe))
	return clampf(danio_base, DANIO_MINIMO, DANIO_MAXIMO)

func _empuje_segun_ataque() -> Vector2:
	var direccion := -1.0 if (sprite and sprite.flip_h) else 1.0
	if estado_actual == "ataque_doble_patada" and _fase_doble_patada == 1:
		return Vector2(60.0 * direccion, -240.0)
	var empuje_base: Vector2 = EMPUJES_ATAQUE.get(estado_actual, Vector2(150.0, 0.0))
	return Vector2(empuje_base.x * direccion, empuje_base.y)

func _on_hitbox_area_entered(area_rival: Area2D) -> void:
	if _golpe_conectado_en_ataque:
		return
	var es_hurtbox = area_rival.name in ["Hurtbox-Estandar", "Hurtbox-Baja", "Hurtbox"]
	if es_hurtbox and area_rival.get_parent() != self:
		var rival_atacado = area_rival.get_parent()
		if rival_atacado and rival_atacado.has_method("recibir_ataque"):
			_golpe_conectado_en_ataque = true
			var es_agarre = (estado_actual == "intentar_agarre")
			var danio_ataque := 0.0 if es_agarre else _danio_segun_ataque()
			var empuje_ataque = Vector2.ZERO if es_agarre else _empuje_segun_ataque()
			var altura_ataque = "MEDIO" 
			
			if estado_actual == "ataque_embestida":
				altura_ataque = "ROMPE_GUARDIA"
			elif estado_actual == "ataque_combo_aba_2":
				altura_ataque = "REBOTE_SUAVE"
			elif estado_actual in ["ataque_punio_abajo", "ataque_patada_abajo", "ataque_aire_patada"]: 
				altura_ataque = "BAJO"
			elif estado_actual in ["ataque_aire_punio", "ataque_patada_arriba", "ataque_punio_arriba", "ataque_especial", "ataque_abajo_arriba"]: 
				altura_ataque = "ALTO"
			
			if estado_actual == "ataque_abajo_arriba":
				_aplicar_retroceso_abajo_arriba()
			
			desactivar_todas_hitboxes()
			
			var estado_objetivo_antes: String = rival_atacado.estado_actual
			var estaba_en_stun := estado_objetivo_antes == "dano"
			var estados_no_agarrables = ["agarrado", "derrota", "en_suelo", "lanzado", "caida_rebote"]
			if es_agarre and rival_atacado.is_on_floor() and rival_atacado.estado_actual not in estados_no_agarrables:
				estado_actual = "agarrando"
				rival_agarrado = rival_atacado
				tiempo_agarre = 0.0
				
			rival_atacado.recibir_ataque(danio_ataque, empuje_ataque, player_id, altura_ataque, es_agarre)

			if not es_agarre and rival_atacado.get("rival") != self and estado_objetivo_antes not in ["derrota", "en_suelo", "agarrado"]:
				registrar_golpe_externo(rival_atacado, estaba_en_stun)

func recibir_ataque(cantidad: float, empuje: Vector2, atacante_id: int, altura: String, es_agarre: bool) -> void:
	if estado_actual in ["derrota", "en_suelo", "agarrado"]:
		return

	var estaba_en_stun := (estado_actual == "dano")
	_castigo_shoryuken_pendiente = false
	reiniciar_contador_combo()
	_reset_combo()

	if es_agarre:
		if not is_on_floor() or estado_actual == "agarrado": return 
		_en_mareo = false
		_rebote_suave_pendiente = false
		estado_actual = "agarrado"
		velocity = Vector2.ZERO
		collision_layer = 0 
		collision_mask = 0
		desactivar_todas_hitboxes()
		actualizar_animacion("Agarrado") 
		return

	var fue_bloqueado = false
	if altura != "ROMPE_GUARDIA":
		if estado_actual == "bloqueo_alto" and altura != "BAJO":
			fue_bloqueado = true
		elif estado_actual == "bloqueo_bajo" and altura != "ALTO":
			fue_bloqueado = true

	desactivar_todas_hitboxes()

	if fue_bloqueado:
		var danio_bloqueo := DANIO_BLOQUEO
		current_hp = maxf(0.0, current_hp - danio_bloqueo)
		var dir_retroceso := -1.0 if (rival and global_position.x < rival.global_position.x) else (1.0 if rival else signf(empuje.x))
		if dir_retroceso == 0.0:
			dir_retroceso = -1.0 if (sprite and not sprite.flip_h) else 1.0
		var magnitud_retroceso := maxf(absf(empuje.x) * 0.55, VELOCIDAD_RETROCESO_BLOQUEO)
		velocity = Vector2(dir_retroceso * magnitud_retroceso, 0.0)
		_tiempo_retroceso_bloqueo = DURACION_RETROCESO_BLOQUEO
		_tiempo_efecto_bloqueo = DURACION_RETROCESO_BLOQUEO
		if rival and rival.has_method("registrar_golpe_externo"):
			rival.registrar_golpe_externo(self, false)
		imprimir_evento_combate("BLOCK", atacante_id, player_id, danio_bloqueo, 0)
		if current_hp <= 0.0:
			_tiempo_stun = 0.0
			_en_mareo = false
			estado_actual = "derrota"
			imprimir_evento_combate("KO", atacante_id, player_id, danio_bloqueo, 0)
			actualizar_animacion("Tumbar")
	else:
		var danio_aplicado := clampf(float(cantidad), DANIO_MINIMO, DANIO_MAXIMO)
		current_hp = maxf(0.0, current_hp - danio_aplicado)
		estado_actual = "dano"
		velocity = empuje
		_en_mareo = (altura == "ROMPE_GUARDIA")
		if altura == "REBOTE_SUAVE":
			if not is_on_floor():
				velocity.y = 320.0
				_rebote_suave_pendiente = true
			else:
				velocity.y = -195.0
				_rebote_suave_pendiente = false
		else:
			_rebote_suave_pendiente = false

		if rival and rival.has_method("registrar_golpe_externo"):
			rival.registrar_golpe_externo(self, estaba_en_stun)
		var combo_atacante: int = int(rival.combo_actual) if rival else (2 if estaba_en_stun else 1)
		imprimir_evento_combate("HIT", atacante_id, player_id, danio_aplicado, combo_atacante)
		actualizar_animacion("Stun", true)
		
		if current_hp <= 0:
			_tiempo_stun = 0.0
			_en_mareo = false
			estado_actual = "derrota"
			imprimir_evento_combate("KO", atacante_id, player_id, 0, combo_atacante)
			actualizar_animacion("Tumbar")
		else:
			_stun_seq += 1
			if _en_mareo:
				_tiempo_stun = DURACION_MAREO
			elif empuje.y < -150.0 or altura == "REBOTE_SUAVE":
				_tiempo_stun = maxf(DURACION_STUN, 0.65)
			else:
				_tiempo_stun = DURACION_STUN

func ser_lanzado(fuerza_vector: Vector2) -> void:
	var estaba_en_stun := (estado_actual == "dano")
	estado_actual = "lanzado"
	_tiempo_stun = 0.0
	_en_mareo = false
	_rebote_suave_pendiente = false
	_castigo_shoryuken_pendiente = false
	reiniciar_contador_combo()
	_reset_combo()
	velocity = fuerza_vector
	var danio_lanzamiento := clampf(DANIO_LANZAMIENTO, DANIO_MINIMO, DANIO_MAXIMO)
	current_hp = maxf(0.0, current_hp - danio_lanzamiento)
	rebotes_restantes = 1
	_stun_seq += 1
	_lanzamiento_seq += 1
	
	collision_layer = CAPA_JUGADOR
	collision_mask = MASCARA_MUNDO
	desactivar_todas_hitboxes()
	
	var combo_atacante: int = int(rival.combo_actual) if rival and estaba_en_stun else 1
	imprimir_evento_combate("HIT", rival.player_id if rival else 0, player_id, danio_lanzamiento, combo_atacante)
	actualizar_animacion("Tumbar")
	
	if current_hp <= 0:
		estado_actual = "derrota"
		imprimir_evento_combate("KO", rival.player_id if rival else 0, player_id, 0, combo_atacante)
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
	
	collision_layer = CAPA_JUGADOR
	collision_mask = MASCARA_MUNDO
	desactivar_todas_hitboxes()
	
	velocity.x = (1 if sprite.flip_h else -1) * 200.0 


# --- COMUNICACIÓN CON EL BUS CENTRAL ---
func imprimir_evento_combate(
	tipo_evento: String,
	atacante: Variant,
	defensor: Variant,
	dano: Variant,
	combo: int = 0,
	hp_override: Variant = null,
	es_ko_override: Variant = null,
	sound_override: String = ""
) -> Dictionary:
	var hp_val: Variant = current_hp
	if tipo_evento in ["WHIFF", "TIME_OVER"]:
		hp_val = hp_override
	elif hp_override != null:
		hp_val = hp_override

	var ko_val: bool = false
	if tipo_evento not in ["WHIFF", "TIME_OVER", "BLOCK"]:
		ko_val = (current_hp <= 0)
	if es_ko_override != null:
		ko_val = bool(es_ko_override)

	var sound_id := sound_override
	if sound_id == "":
		match tipo_evento:
			"HIT":
				sound_id = "sfx_heavy_hit"
			"BLOCK":
				sound_id = "sfx_block"
			"WHIFF":
				sound_id = "sfx_whiff"
			"KO":
				sound_id = "voice_ko"
			"TIME_OVER":
				sound_id = "voice_time_over"
			_:
				sound_id = "sfx_heavy_hit"

	var evento_json: Dictionary = {
		"event_name": "on_combat_event",
		"source_core": "nucleo3_combate",
		"frame": Engine.get_process_frames(),
		"data": {
			"type": tipo_evento,
			"attacker": atacante,
			"defender": defensor,
			"damage": dano,
			"current_hp": hp_val,
			"combo_count": combo,
			"is_ko": ko_val,
			"sound_id": sound_id
		}
	}
	print(JSON.stringify(evento_json))
	on_combat_event.emit(evento_json)
	_publicar_en_bus_central(evento_json)
	return evento_json

func _publicar_en_bus_central(evento_json: Dictionary) -> void:
	if not is_inside_tree():
		return
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		if bus.has_signal("on_combat_event"):
			bus.emit_signal("on_combat_event", evento_json)
		elif bus.has_method("on_combat_event"):
			bus.call("on_combat_event", evento_json)
	var padre = get_parent()
	if padre and padre.has_method("_on_jugador_combat_event"):
		padre.call("_on_jugador_combat_event", evento_json)

# --- REINICIO DE ROUND Y VISUALIZADOR DEBUG ---
func reiniciar_para_round(posicion_inicial: Vector2) -> void:
	global_position = posicion_inicial
	velocity = Vector2.ZERO
	current_hp = max_hp
	estado_actual = "reposo"
	collision_layer = CAPA_JUGADOR
	collision_mask = MASCARA_MUNDO
	rival_agarrado = null
	tiempo_agarre = 0.0
	rebotes_restantes = 0
	_tiempo_dash = 0.0
	_doble_toque_pendiente = 0.0
	_tiempo_ultima_izquierda = -1000.0
	_tiempo_ultima_derecha = -1000.0
	_tiempo_izquierda_antes_de_abajo = -1000.0
	_tiempo_derecha_antes_de_abajo = -1000.0
	_tiempo_ultimo_abajo = -1000.0
	_tiempo_ultimo_arriba = -1000.0
	_tiempo_abajo_antes_de_arriba = -1000.0
	_cooldown_ataque = 0.0
	_tiempo_tatsumaki = 0.0
	_tiempo_hadoken = 0.0
	_tiempo_doble_patada = 0.0
	_fase_doble_patada = 0
	_tiempo_embestida = 0.0
	_tiempo_abajo_arriba = 0.0
	_retroceso_abajo_arriba_aplicado = false
	_tiempo_stun = 0.0
	_en_mareo = false
	_rebote_suave_pendiente = false
	_tiempo_retroceso_bloqueo = 0.0
	_tiempo_efecto_bloqueo = 0.0
	_proyectil_lanzado = false
	_ataque_aereo_usado = false
	_castigo_shoryuken_pendiente = false
	_golpe_conectado_en_ataque = false
	_reset_combo()
	reiniciar_contador_combo()
	desactivar_todas_hitboxes()
	_actualizar_hurtbox()
	actualizar_animacion("Reposo")
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	if fx_overlay:
		fx_overlay.queue_redraw()
	if debug_overlay:
		debug_overlay.queue_redraw()

func _actualizar_efectos_visuales() -> void:
	if sprite:
		if _tiempo_efecto_bloqueo > 0.0:
			var t := _tiempo_efecto_bloqueo / DURACION_RETROCESO_BLOQUEO
			sprite.modulate = Color(1.0 - 0.35 * t, 1.0 - 0.05 * t, 1.0 + 0.35 * t, 1.0)
		elif _en_mareo and estado_actual == "dano" and _tiempo_stun > 0.0:
			var pulso := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.018)
			sprite.modulate = Color(1.0, 0.92 + 0.08 * pulso, 0.45 + 0.35 * pulso, 1.0)
		else:
			sprite.modulate = Color(1, 1, 1, 1)
	if fx_overlay:
		fx_overlay.queue_redraw()

func _on_fx_overlay_draw() -> void:
	# Efecto visual leve al bloquear un ataque (arco de guardia energético)
	if _tiempo_efecto_bloqueo > 0.0:
		var progreso := 1.0 - (_tiempo_efecto_bloqueo / DURACION_RETROCESO_BLOQUEO)
		var alpha := (1.0 - progreso) * 0.75
		var dir_mirada := -1.0 if (sprite and sprite.flip_h) else 1.0
		var altura_centro := 30.0 if estado_actual == "bloqueo_bajo" else -25.0
		var centro := Vector2(48.0 * dir_mirada, altura_centro)
		var radio := 38.0 + progreso * 26.0
		var ang_base := 0.0 if dir_mirada > 0.0 else PI
		fx_overlay.draw_arc(centro, radio, ang_base - 1.15, ang_base + 1.15, 20, Color(0.45, 0.88, 1.0, alpha), 4.0)
		fx_overlay.draw_arc(centro, radio * 0.72, ang_base - 0.85, ang_base + 0.85, 16, Color(0.85, 0.97, 1.0, alpha * 0.85), 2.5)

	# Efecto visual de mareo al romper guardia con la embestida
	if _en_mareo and estado_actual == "dano" and _tiempo_stun > 0.0:
		var t := float(Time.get_ticks_msec()) * 0.008
		for i in range(3):
			var ang := t + float(i) * (TAU / 3.0)
			var pos_estrella := Vector2(cos(ang) * 34.0, -145.0 + sin(ang) * 10.0)
			fx_overlay.draw_circle(pos_estrella, 5.5, Color(1.0, 0.9, 0.2, 0.9))

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
