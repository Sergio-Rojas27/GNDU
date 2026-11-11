extends Node2D

@export_group("Jugadores")
@export var jugador1: CharacterBody2D
@export var jugador2: CharacterBody2D

@export_group("Cámara")
@export var camara: Camera2D

@export_group("Elementos de UI")
@export var texto_tiempo: Label
@export var reloj_combate: Timer
@export var barra_vida_j1: ProgressBar
@export var barra_vida_j2: ProgressBar
@export var texto_victoria: Label

@export_group("Rounds y Debug")
@export var label_rounds_j1: Label
@export var label_rounds_j2: Label
@export var boton_hitboxes: Button
@export var boton_reiniciar: Button

const MAX_ROUNDS: int = 2

var tiempo_restante: int = 99
var combate_finalizado: bool = false
var round_terminado: bool = false
var round_actual: int = 1
var rounds_j1: int = 0
var rounds_j2: int = 0

var altura_fija_camara: float = 0.0
var pos_inicial_j1: Vector2 = Vector2.ZERO
var pos_inicial_j2: Vector2 = Vector2.ZERO
var mostrar_hitboxes: bool = false

func _ready() -> void:
	tiempo_restante = 99
	combate_finalizado = false
	round_terminado = false
	round_actual = 1
	rounds_j1 = 0
	rounds_j2 = 0
	
	if jugador1:
		pos_inicial_j1 = jugador1.global_position
		barra_vida_j1.max_value = jugador1.max_hp
		barra_vida_j1.value = jugador1.current_hp
	if jugador2:
		pos_inicial_j2 = jugador2.global_position
		barra_vida_j2.max_value = jugador2.max_hp
		barra_vida_j2.value = jugador2.current_hp

	if texto_tiempo:
		texto_tiempo.text = str(tiempo_restante)
	if reloj_combate:
		reloj_combate.timeout.connect(_on_reloj_combate_timeout)
	if texto_victoria:
		texto_victoria.text = ""
		
	if boton_hitboxes:
		boton_hitboxes.pressed.connect(_on_boton_hitboxes_pressed)
		_actualizar_texto_boton_hitboxes()

	if boton_reiniciar:
		boton_reiniciar.visible = false
		boton_reiniciar.pressed.connect(_on_boton_reiniciar_pressed)
		
	_actualizar_labels_rounds()

	if camara:
		altura_fija_camara = camara.global_position.y

func _process(_delta: float) -> void:
	# --- LÓGICA DE CÁMARA DINÁMICA ---
	if camara and jugador1 and jugador2:
		var punto_medio_x = (jugador1.global_position.x + jugador2.global_position.x) / 2.0
		camara.global_position = Vector2(punto_medio_x, altura_fija_camara)

	if combate_finalizado:
		return

	# Actualizar barras de vida
	if jugador1 and barra_vida_j1:
		barra_vida_j1.value = jugador1.current_hp
	if jugador2 and barra_vida_j2:
		barra_vida_j2.value = jugador2.current_hp

	# Verificar si un jugador perdió toda su vida en el round actual
	if not round_terminado:
		if jugador1 and jugador1.current_hp <= 0 and jugador2 and jugador2.current_hp <= 0:
			_finalizar_round(0) # Doble KO
		elif jugador1 and jugador1.current_hp <= 0:
			_finalizar_round(2) # Ganó J2
		elif jugador2 and jugador2.current_hp <= 0:
			_finalizar_round(1) # Ganó J1

func _finalizar_round(ganador_id: int) -> void:
	round_terminado = true
	if reloj_combate:
		reloj_combate.stop()

	if ganador_id == 1:
		rounds_j1 += 1
	elif ganador_id == 2:
		rounds_j2 += 1
	else:
		rounds_j1 += 1
		rounds_j2 += 1

	_actualizar_labels_rounds()

	var j1_gana_combate = (rounds_j1 >= MAX_ROUNDS)
	var j2_gana_combate = (rounds_j2 >= MAX_ROUNDS)

	if j1_gana_combate and j2_gana_combate:
		finalizar_combate("¡EMPATE DEFINITIVO!\n¡DOBLE KO!")
	elif j1_gana_combate:
		finalizar_combate("¡SE ACABÓ EL COMBATE!\n¡GANADOR DEFINITIVO: JUGADOR 1!")
	elif j2_gana_combate:
		finalizar_combate("¡SE ACABÓ EL COMBATE!\n¡GANADOR DEFINITIVO: JUGADOR 2!")
	else:
		if texto_victoria:
			if ganador_id == 1:
				texto_victoria.text = "¡ROUND " + str(round_actual) + "!\n¡PUNTO PARA EL JUGADOR 1!"
			elif ganador_id == 2:
				texto_victoria.text = "¡ROUND " + str(round_actual) + "!\n¡PUNTO PARA EL JUGADOR 2!"
			else:
				texto_victoria.text = "¡ROUND " + str(round_actual) + "!\n¡EMPATE EN EL ROUND!"
		
		await get_tree().create_timer(2.5).timeout
		if not combate_finalizado:
			_iniciar_siguiente_round()

func _iniciar_siguiente_round() -> void:
	round_actual += 1
	tiempo_restante = 99
	if texto_tiempo:
		texto_tiempo.text = str(tiempo_restante)

	if jugador1 and jugador1.has_method("reiniciar_para_round"):
		jugador1.reiniciar_para_round(pos_inicial_j1)
	if jugador2 and jugador2.has_method("reiniciar_para_round"):
		jugador2.reiniciar_para_round(pos_inicial_j2)

	if barra_vida_j1 and jugador1:
		barra_vida_j1.value = jugador1.current_hp
	if barra_vida_j2 and jugador2:
		barra_vida_j2.value = jugador2.current_hp

	if texto_victoria:
		texto_victoria.text = "¡ROUND " + str(round_actual) + "!\n¡PELEEN!"

	await get_tree().create_timer(1.2).timeout

	if texto_victoria:
		texto_victoria.text = ""

	round_terminado = false
	if reloj_combate:
		reloj_combate.start()

func finalizar_combate(mensaje: String) -> void:
	combate_finalizado = true
	if reloj_combate:
		reloj_combate.stop()
	if texto_victoria:
		texto_victoria.text = mensaje
	if boton_reiniciar:
		boton_reiniciar.visible = true

func _on_boton_reiniciar_pressed() -> void:
	reiniciar_combate_completo()

func reiniciar_combate_completo() -> void:
	combate_finalizado = false
	round_terminado = false
	round_actual = 1
	rounds_j1 = 0
	rounds_j2 = 0
	tiempo_restante = 99
	
	if boton_reiniciar:
		boton_reiniciar.visible = false
		
	if texto_tiempo:
		texto_tiempo.text = str(tiempo_restante)
		
	_actualizar_labels_rounds()
	
	if jugador1 and jugador1.has_method("reiniciar_para_round"):
		jugador1.reiniciar_para_round(pos_inicial_j1)
	if jugador2 and jugador2.has_method("reiniciar_para_round"):
		jugador2.reiniciar_para_round(pos_inicial_j2)
		
	if barra_vida_j1 and jugador1:
		barra_vida_j1.value = jugador1.current_hp
	if barra_vida_j2 and jugador2:
		barra_vida_j2.value = jugador2.current_hp
		
	if texto_victoria:
		texto_victoria.text = "¡ROUND 1!\n¡PELEEN!"
		
	await get_tree().create_timer(1.2).timeout
	if combate_finalizado:
		return
		
	if texto_victoria:
		texto_victoria.text = ""
		
	if reloj_combate:
		reloj_combate.start()

func _on_reloj_combate_timeout() -> void:
	if round_terminado or combate_finalizado:
		return
		
	if tiempo_restante > 0:
		tiempo_restante -= 1
		if texto_tiempo:
			texto_tiempo.text = str(tiempo_restante)
	else:
		reloj_combate.stop()
		# Evaluar ganador del round por tiempo si expiran los 99s
		if jugador1.current_hp > jugador2.current_hp:
			_finalizar_round(1)
		elif jugador2.current_hp > jugador1.current_hp:
			_finalizar_round(2)
		else:
			_finalizar_round(0)

func _actualizar_labels_rounds() -> void:
	if label_rounds_j1:
		var p1_icon1 = "●" if rounds_j1 >= 1 else "○"
		var p1_icon2 = "●" if rounds_j1 >= 2 else "○"
		label_rounds_j1.text = "ROUNDS: " + p1_icon1 + " " + p1_icon2
	if label_rounds_j2:
		var p2_icon1 = "●" if rounds_j2 >= 1 else "○"
		var p2_icon2 = "●" if rounds_j2 >= 2 else "○"
		label_rounds_j2.text = "ROUNDS: " + p2_icon1 + " " + p2_icon2

func _on_boton_hitboxes_pressed() -> void:
	mostrar_hitboxes = not mostrar_hitboxes
	if jugador1:
		jugador1.mostrar_cajas_debug = mostrar_hitboxes
	if jugador2:
		jugador2.mostrar_cajas_debug = mostrar_hitboxes
	get_tree().debug_collisions_hint = mostrar_hitboxes
	_actualizar_texto_boton_hitboxes()

func _actualizar_texto_boton_hitboxes() -> void:
	if boton_hitboxes:
		boton_hitboxes.text = "Hitboxes: ON" if mostrar_hitboxes else "Hitboxes: OFF"
