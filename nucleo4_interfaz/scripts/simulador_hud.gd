extends Node

@export var hud: Control
var jugador1: CharacterBody2D
var jugador2: CharacterBody2D
var pos_inicial_j1: Vector2 = Vector2(751, 919)
var pos_inicial_j2: Vector2 = Vector2(1119, 915)

var timer_bucle: Timer 
var combate_activo: bool = false # Evita que los jugadores ataquen o el tiempo corra antes de "FIGHT"

var tiempo_actual: int = 99
var vida_p1: float = 100.0
var vida_p2: float = 100.0
var ronda_actual: int = 1
var partida_terminada: bool = false
var victorias_p1: int = 0
var victorias_p2: int = 0
signal combate_finalizado(ganador_id: String)

func _ready() -> void:
	if hud:
		hud.fight_begins.connect(_on_fight_begins)

	timer_bucle = Timer.new()
	timer_bucle.wait_time = 1.0
	timer_bucle.autostart = false
	timer_bucle.timeout.connect(_on_segundo_transcurrido)
	add_child(timer_bucle)
	
	await get_tree().create_timer(0.3).timeout
	
	if DatosGlobales.p1_fighter_id == "":
		DatosGlobales.p1_fighter_id = "estudiante_Base"
	if DatosGlobales.p2_fighter_id == "":
		DatosGlobales.p2_fighter_id = "estudiante_Base"
	if DatosGlobales.escenario_seleccionado_id == "":
		DatosGlobales.escenario_seleccionado_id = "Escenario_Uni"
	
	var state_change = {
		"event_name": "on_state_change",
		"source_core": "nucleo4_interfaz",
		"data": {
			"previous_screen": "SELECCION",
			"current_screen": "COMBATE"
		}
	}
	_enrutar_evento(state_change)
	
	print("--- DATOS RECIBIDOS EN EL ORQUESTADOR DE COMBATE ---")
	print("P1: ", DatosGlobales.p1_fighter_id)
	print("P2: ", DatosGlobales.p2_fighter_id)
	print("Escenario: ", DatosGlobales.escenario_seleccionado_id)
	
	var match_start = {
		"event_name": "on_match_start",
		"source_core": "nucleo4_interfaz",
		"frame": 0,
		"data": {
			"player_1_fighter_id": DatosGlobales.p1_fighter_id, 
			"player_2_fighter_id": DatosGlobales.p2_fighter_id,
			"stage_id": DatosGlobales.escenario_seleccionado_id, 
			"round_time": tiempo_actual,
			"rounds_to_win": 2
		}
	}
	_enrutar_evento(match_start)
	
	var bus := get_node_or_null("/root/EventBus")
	if bus and bus.has_signal("on_match_start"):
		bus.emit_signal("on_match_start", match_start)
	
	if hud:
		hud.on_combat_event({
			"event_type": "setup_players",
			"player_1_fighter_id": DatosGlobales.p1_fighter_id,
			"player_2_fighter_id": DatosGlobales.p2_fighter_id
		})
		hud.on_combat_event({"event_type": "start_round_sequence", "round": ronda_actual})

func _on_fight_begins() -> void:
	combate_activo = true
	if jugador1:
		jugador1.controles_habilitados = true
	if jugador2:
		jugador2.controles_habilitados = true
	timer_bucle.start()

func _process(_delta: float) -> void:
	if partida_terminada or not combate_activo:
		return
	if jugador1 and is_instance_valid(jugador1) and jugador2 and is_instance_valid(jugador2):
		vida_p1 = jugador1.current_hp
		vida_p2 = jugador2.current_hp
		if vida_p1 <= 0.0 or vida_p2 <= 0.0:
			_verificar_vida_jugadores()

func _on_segundo_transcurrido() -> void:
	if partida_terminada or not combate_activo:
		return
	
	if tiempo_actual > 0:
		tiempo_actual -= 1
		if hud:
			hud.on_combat_event({
				"event_type": "timer_update",
				"time_left": tiempo_actual
			})
	else:
		_emitir_time_over()
		_verificar_fin_por_tiempo()

func _emitir_time_over() -> void:
	var evento_json: Dictionary = {
		"event_name": "on_combat_event",
		"source_core": "nucleo3_combate",
		"frame": Engine.get_process_frames(),
		"data": {
			"type": "TIME_OVER",
			"attacker": null,
			"defender": null,
			"damage": 0,
			"current_hp": null,
			"combo_count": 0,
			"is_ko": false,
			"sound_id": "voice_time_over"
		}
	}
	print(JSON.stringify(evento_json))
	var bus := get_node_or_null("/root/EventBus")
	if bus and bus.has_signal("on_combat_event"):
		bus.emit_signal("on_combat_event", evento_json)

func _unhandled_input(event: InputEvent) -> void:
	if partida_terminada or not combate_activo:
		return

	# Si hay jugadores reales en escena, el combate real maneja el daño y los combos
	if jugador1 != null and jugador2 != null:
		return

	# Modo simulador aislado (solo cuando se ejecuta sin luchadores de N3)
	if event.is_action_pressed("ui_accept"):
		vida_p1 = max(0.0, vida_p1 - 25.0)
		hud.on_combat_event({
			"event_type": "health_update",
			"player": "p1",
			"current_health": vida_p1
		})
		_verificar_vida_jugadores()

	if event.is_action_pressed("ui_right"):
		vida_p2 = max(0.0, vida_p2 - 25.0)
		hud.on_combat_event({
			"event_type": "health_update",
			"player": "p2",
			"current_health": vida_p2
		})
		_verificar_vida_jugadores()

	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		hud.on_combat_event({
			"event_type": "combo_update",
			"player": "p1",
			"hits": 5
		})
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		hud.on_combat_event({
			"event_type": "combo_update",
			"player": "p2",
			"hits": 2
		})

func _verificar_vida_jugadores() -> void:
	if vida_p1 <= 0.0 or vida_p2 <= 0.0:
		partida_terminada = true
		combate_activo = false
		if jugador1:
			jugador1.controles_habilitados = false
		if jugador2:
			jugador2.controles_habilitados = false
		timer_bucle.stop()
		
		if hud:
			hud.on_combat_event({"event_type": "match_state", "state": "ko"})
		
		if vida_p1 <= 0.0 and vida_p2 > 0.0:
			victorias_p2 += 1
			if hud:
				hud.on_combat_event({"event_type": "round_end", "winner": "p2"})
		elif vida_p2 <= 0.0 and vida_p1 > 0.0:
			victorias_p1 += 1
			if hud:
				hud.on_combat_event({"event_type": "round_end", "winner": "p1"})
		elif vida_p1 <= 0.0 and vida_p2 <= 0.0:
			victorias_p1 += 1
			victorias_p2 += 1
			if hud:
				hud.on_combat_event({"event_type": "round_end", "winner": "draw"})
			
		await get_tree().create_timer(2.0).timeout
		if hud:
			hud.on_combat_event({"event_type": "match_state", "state": "clear"})
		
		if victorias_p1 >= 2 or victorias_p2 >= 2:
			var ganador_definitivo = ""
			if victorias_p1 > victorias_p2:
				ganador_definitivo = DatosGlobales.p1_fighter_id
			elif victorias_p2 > victorias_p1:
				ganador_definitivo = DatosGlobales.p2_fighter_id
			else:
				ganador_definitivo = "empate"
				
			print("¡Pelea terminada! Ganador definitivo: ", ganador_definitivo)
			emit_signal("combate_finalizado", ganador_definitivo)
			return
			
		ronda_actual += 1
		_preparar_siguiente_ronda()

func _verificar_fin_por_tiempo() -> void:
	partida_terminada = true
	combate_activo = false
	if jugador1:
		jugador1.controles_habilitados = false
	if jugador2:
		jugador2.controles_habilitados = false
	timer_bucle.stop()
	
	if jugador1 and jugador2:
		vida_p1 = jugador1.current_hp
		vida_p2 = jugador2.current_hp

	if vida_p1 == vida_p2:
		if hud:
			hud.on_combat_event({"event_type": "match_state", "state": "draw"})
		victorias_p1 += 1
		victorias_p2 += 1
		if hud:
			hud.on_combat_event({"event_type": "round_end", "winner": "draw"})
	elif vida_p1 > vida_p2:
		if hud:
			hud.on_combat_event({"event_type": "match_state", "state": "ko"})
		victorias_p1 += 1
		if hud:
			hud.on_combat_event({"event_type": "round_end", "winner": "p1"})
	else:
		if hud:
			hud.on_combat_event({"event_type": "match_state", "state": "ko"})
		victorias_p2 += 1
		if hud:
			hud.on_combat_event({"event_type": "round_end", "winner": "p2"})

	await get_tree().create_timer(2.0).timeout
	if hud:
		hud.on_combat_event({"event_type": "match_state", "state": "clear"})
	
	if victorias_p1 >= 2 or victorias_p2 >= 2:
		var ganador_definitivo = ""
		if victorias_p1 > victorias_p2:
			ganador_definitivo = DatosGlobales.p1_fighter_id
		elif victorias_p2 > victorias_p1:
			ganador_definitivo = DatosGlobales.p2_fighter_id
		else:
			ganador_definitivo = "empate"
			
		print("¡Pelea terminada! Ganador definitivo: ", ganador_definitivo)
		emit_signal("combate_finalizado", ganador_definitivo)
		return
		
	ronda_actual += 1
	_preparar_siguiente_ronda()

func _preparar_siguiente_ronda() -> void:
	vida_p1 = 100.0
	vida_p2 = 100.0
	tiempo_actual = 99
	partida_terminada = false
	combate_activo = false
	
	var padre := get_parent()
	if padre and padre.has_method("_limpiar_proyectiles_activos"):
		padre._limpiar_proyectiles_activos()

	if jugador1 and jugador1.has_method("reiniciar_para_round"):
		jugador1.controles_habilitados = false
		jugador1.reiniciar_para_round(pos_inicial_j1)
	if jugador2 and jugador2.has_method("reiniciar_para_round"):
		jugador2.controles_habilitados = false
		jugador2.reiniciar_para_round(pos_inicial_j2)
	
	if hud:
		hud.on_combat_event({"event_type": "health_update", "player": "p1", "current_health": 100.0})
		hud.on_combat_event({"event_type": "health_update", "player": "p2", "current_health": 100.0})
		hud.on_combat_event({"event_type": "timer_update", "time_left": 99})
		hud.on_combat_event({"event_type": "start_round_sequence", "round": ronda_actual})

func _enrutar_evento(resultado: Dictionary) -> void:
	if resultado.get("event_name") == "on_state_change":
		var d = resultado.get("data", {})
		print("BUS CENTRAL: Cambiando estado de ", d.get("previous_screen", ""), " a ", d.get("current_screen", ""))
		
	elif resultado.get("event_name") == "on_match_start":
		print("BUS CENTRAL: Iniciando combate.")
		var datos_partida = resultado.get("data", {})
		tiempo_actual = datos_partida.get("round_time", 99)
		
		if hud:
			hud.on_combat_event({
				"event_type": "setup_players",
				"player_1_fighter_id": datos_partida.get("player_1_fighter_id", ""),
				"player_2_fighter_id": datos_partida.get("player_2_fighter_id", "")
			})
			hud.on_combat_event({
				"event_type": "timer_update",
				"time_left": tiempo_actual
			})
