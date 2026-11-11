extends Node

@onready var hud: Control = $"../HUD/Control"
var timer_bucle: Timer 
var combate_activo: bool = false # Evita que los jugadores ataquen o el tiempo corra antes de "FIGHT"

var tiempo_actual: int = 99
var vida_p1: float = 100.0
var vida_p2: float = 100.0
var ronda_actual: int = 1
var partida_terminada: bool = false
var victorias_p1: int = 0
var victorias_p2: int = 0

func _ready() -> void:
	# 1. Conectamos la señal del HUD para saber cuándo arrancar la pelea
	hud.fight_begins.connect(_on_fight_begins)
	
	# 2. Inicializamos el Timer del reloj pero NO lo iniciamos todavía
	timer_bucle = Timer.new()
	timer_bucle.wait_time = 1.0
	timer_bucle.autostart = false # Importante: Falso para esperar al cartel de Fight
	timer_bucle.timeout.connect(_on_segundo_transcurrido)
	add_child(timer_bucle)
	
	await get_tree().create_timer(0.3).timeout
	
	# 3. Emitir eventos de inicialización del núcleo
	var state_change = {
		"event_name": "on_state_change",
		"source_core": "nucleo4_interfaz",
		"data": {
			"previous_screen": "SELECCION",
			"current_screen": "COMBATE"
		}
	}
	_enrutar_evento(state_change)
	
	var match_start = {
		"event_name": "on_match_start",
		"source_core": "nucleo4_interfaz",
		"frame": 0,
		"data": {
			"player_1_fighter_id": "Prueba_1", 
			"player_2_fighter_id": "Prueba_2",
			"stage_id": "escenario_uni",
			"round_time": tiempo_actual,
			"rounds_to_win": 2
		}
	}
	_enrutar_evento(match_start)
	
	# 4. Configurar HUD inicial
	hud.on_combat_event({
		"event_type": "setup_players",
		"player_1_fighter_id": "Prueba_1",
		"player_2_fighter_id": "Prueba_2"
	})
	
	# 5. Disparamos la secuencia animada delegada al HUD (Round 1 -> Ready -> Fight)
	hud.on_combat_event({"event_type": "start_round_sequence", "round": ronda_actual})

# Se ejecuta automáticamente cuando el HUD avisa que terminó de decir "FIGHT"
func _on_fight_begins() -> void:
	combate_activo = true
	timer_bucle.start()

func _input(event):
	if event.is_action_pressed("ui_cancel"): # Por defecto es la tecla Escape
		var nuevo_estado_pausa = not get_tree().paused
		EventBus.emit_signal("estado_pausa_cambiado", nuevo_estado_pausa)

func _on_segundo_transcurrido() -> void:
	if partida_terminada or not combate_activo: return
	
	if tiempo_actual > 0:
		tiempo_actual -= 1
		hud.on_combat_event({
			"event_type": "timer_update",
			"time_left": tiempo_actual
		})
	else:
		_verificar_fin_por_tiempo()

func _unhandled_input(event: InputEvent) -> void:
	# Si la partida terminó o están en la pantalla "READY", ignorar los botones de daño
	if partida_terminada or not combate_activo: return

	# Tecla Enter / Espacio: Dañar a P1 (-25 de vida)
	if event.is_action_pressed("ui_accept"):
		vida_p1 = max(0.0, vida_p1 - 25.0)
		hud.on_combat_event({
			"event_type": "health_update",
			"player": "p1",
			"current_health": vida_p1
		})
		_verificar_vida_jugadores()

	# Tecla Flecha Derecha: Dañar a P2 (-25 de vida)
	if event.is_action_pressed("ui_right"):
		vida_p2 = max(0.0, vida_p2 - 25.0)
		hud.on_combat_event({
			"event_type": "health_update",
			"player": "p2",
			"current_health": vida_p2
		})
		_verificar_vida_jugadores()

	# Tecla C: Simular Combo P1
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		hud.on_combat_event({
			"event_type": "combo_update",
			"player": "p1",
			"hits": 5
		})
	
	# Tecla V: Simular Combo P2
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		hud.on_combat_event({
			"event_type": "combo_update",
			"player": "p2",
			"hits": 2
		})

func _verificar_vida_jugadores() -> void:
	if vida_p1 <= 0.0 or vida_p2 <= 0.0:
		partida_terminada = true
		combate_activo = false # Detener inputs
		timer_bucle.stop() # Detener reloj
		
		hud.on_combat_event({"event_type": "match_state", "state": "ko"})
		
		# 1. Determinar quién ganó la ronda actual
		if vida_p1 <= 0.0 and vida_p2 > 0.0:
			victorias_p2 += 1
			hud.on_combat_event({"event_type": "round_end", "winner": "p2"})
			
		elif vida_p2 <= 0.0 and vida_p1 > 0.0:
			victorias_p1 += 1
			hud.on_combat_event({"event_type": "round_end", "winner": "p1"})
			
		elif vida_p1 <= 0.0 and vida_p2 <= 0.0:
			# Double KO / Draw
			victorias_p1 += 1
			victorias_p2 += 1
			hud.on_combat_event({"event_type": "round_end", "winner": "draw"})
			
		await get_tree().create_timer(2.0).timeout
		hud.on_combat_event({"event_type": "match_state", "state": "clear"})
		
		# 2. Comprobar si alguien ya ganó la partida completa
		if victorias_p1 >= 2 or victorias_p2 >= 2:
			print("¡Pelea terminada! Ganador definitivo: ", "P1" if victorias_p1 > victorias_p2 else ("Empate" if victorias_p1 == victorias_p2 else "P2"))
			return
			
		# 3. Siguiente ronda
		ronda_actual += 1
		_preparar_siguiente_ronda()


func _verificar_fin_por_tiempo() -> void:
	partida_terminada = true
	combate_activo = false
	timer_bucle.stop()
	
	if vida_p1 == vida_p2:
		hud.on_combat_event({"event_type": "match_state", "state": "draw"})
		victorias_p1 += 1
		victorias_p2 += 1
		hud.on_combat_event({"event_type": "round_end", "winner": "draw"})
	elif vida_p1 > vida_p2:
		hud.on_combat_event({"event_type": "match_state", "state": "ko"})
		victorias_p1 += 1
		hud.on_combat_event({"event_type": "round_end", "winner": "p1"})
	else:
		hud.on_combat_event({"event_type": "match_state", "state": "ko"})
		victorias_p2 += 1
		hud.on_combat_event({"event_type": "round_end", "winner": "p2"})

	await get_tree().create_timer(2.0).timeout
	hud.on_combat_event({"event_type": "match_state", "state": "clear"})
	
	if victorias_p1 >= 2 or victorias_p2 >= 2:
		print("¡Pelea por tiempo terminada! Ganador definitivo: ", "P1" if victorias_p1 > victorias_p2 else ("Empate" if victorias_p1 == victorias_p2 else "P2"))
		return
		
	ronda_actual += 1
	_preparar_siguiente_ronda()

func _preparar_siguiente_ronda() -> void:
	# 1. Reiniciamos variables lógicas y de bloqueo
	vida_p1 = 100.0
	vida_p2 = 100.0
	tiempo_actual = 99
	partida_terminada = false
	combate_activo = false # Sigue bloqueado hasta que termine la nueva animación
	
	# 2. Restaurar UI visualmente
	hud.on_combat_event({"event_type": "health_update", "player": "p1", "current_health": 100.0})
	hud.on_combat_event({"event_type": "health_update", "player": "p2", "current_health": 100.0})
	hud.on_combat_event({"event_type": "timer_update", "time_left": 99})
	
	# 3. Delegamos la animación del siguiente Round al HUD
	hud.on_combat_event({"event_type": "start_round_sequence", "round": ronda_actual})

func _enrutar_evento(resultado: Dictionary) -> void:
	if resultado.get("event_name") == "on_state_change":
		print("BUS CENTRAL: Cambiando estado de ", resultado.data.previous_screen, " a ", resultado.data.current_screen)
		
	elif resultado.get("event_name") == "on_match_start":
		print("BUS CENTRAL: Iniciando combate.")
		var datos_partida = resultado.get("data", {})
		tiempo_actual = datos_partida.get("round_time", 99)
		
		hud.on_combat_event({
			"event_type": "setup_players",
			"player_1_fighter_id": datos_partida.get("player_1_fighter_id", ""),
			"player_2_fighter_id": datos_partida.get("player_2_fighter_id", "")
		})
		
		hud.on_combat_event({
			"event_type": "timer_update",
			"time_left": tiempo_actual
		})
