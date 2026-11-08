extends Node

@onready var hud: Control = $"../HUD/Control"
var tiempo_actual: int = 99
var vida_p1: float = 100.0
var vida_p2: float = 100.0
var ronda_actual: int = 1
var partida_terminada: bool = false
var victorias_p1: int = 0
var victorias_p2: int = 0

func _ready() -> void:
	await get_tree().create_timer(0.3).timeout
	
	# 1. Iniciar evento de la partida y mostrar cartel de Round 1
	var match_start = {
		"event_name": "on_match_start",
		"source_core": "nucleo4_interfaz",
		"frame": 0,
		"data": {
			"player_1_fighter_id": "estudiante_juan",
			"player_2_fighter_id": "profesor_carlos",
			"stage_id": "escenario_laboratorio",
			"round_time": tiempo_actual,
			"rounds_to_win": 2
		}
	}
	_enrutar_evento(match_start)
	
	hud.on_combat_event({
		"event_type": "setup_players",
		"player_1_fighter_id": "profesor",
		"player_2_fighter_id": "estudiante"
	})
	# Mostrar cartel de Round 1 al arrancar
	hud.on_combat_event({"event_type": "match_state", "state": "round_1"})
	
	# A los 1 segundos lanzar el "FIGHT!" automáticamente
	await get_tree().create_timer(1.0).timeout
	hud.on_combat_event({"event_type": "match_state", "state": "fight"})
	
	# A los 2 segundos quitar el "FIGHT!" automáticamente
	await get_tree().create_timer(2.0).timeout
	hud.on_combat_event({"event_type": "match_state", "state": "clear"})
	
	# 2. Iniciar bucle del reloj cada 1 segundo real
	var timer_bucle = Timer.new()
	timer_bucle.wait_time = 1.0
	timer_bucle.autostart = true
	timer_bucle.timeout.connect(_on_segundo_transcurrido)
	add_child(timer_bucle)

func _on_segundo_transcurrido() -> void:
	if partida_terminada: return
	
	if tiempo_actual > 0:
		tiempo_actual -= 1
		hud.on_combat_event({
			"event_type": "timer_update",
			"time_left": tiempo_actual
		})
	else:
		# Si el tiempo llega a 0, se evalúa empate o ganador por vida
		_verificar_fin_por_tiempo()

func _unhandled_input(event: InputEvent) -> void:
	if partida_terminada: return

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
	
	# Tecla V: Simular Combo P1
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		hud.on_combat_event({
			"event_type": "combo_update",
			"player": "p2",
			"hits": 2
		})

func _verificar_vida_jugadores() -> void:
	# Corregido: Solo termina si alguien muere (o si ambos mueren a la vez)
	if vida_p1 <= 0.0 or vida_p2 <= 0.0:
		partida_terminada = true
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
		
		# 2. Comprobar si alguien ya ganó la partida completa
		if victorias_p1 >= 2 or victorias_p2 >= 2:
			print("¡Pelea terminada! Ganador definitivo: ", "P1" if victorias_p1 > victorias_p2 else ("Empate" if victorias_p1 == victorias_p2 else "P2"))
			return
			
		# 3. Siguiente ronda
		ronda_actual += 1
		_preparar_siguiente_ronda()


func _verificar_fin_por_tiempo() -> void:
	partida_terminada = true
	
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
	
	# Verificar si alguien ya ganó la partida completa (2 victorias)
	if victorias_p1 >= 2 or victorias_p2 >= 2:
		print("¡Pelea por tiempo terminada! Ganador definitivo: ", "P1" if victorias_p1 > victorias_p2 else ("Empate" if victorias_p1 == victorias_p2 else "P2"))
		return
		
	# Si nadie tiene las victorias necesarias, pasar a la siguiente ronda
	ronda_actual += 1
	_preparar_siguiente_ronda()

# Separamos la lógica de reiniciar para mantener el código limpio
func _preparar_siguiente_ronda() -> void:
	vida_p1 = 100.0
	vida_p2 = 100.0
	tiempo_actual = 99
	partida_terminada = false
	
	# Restaurar UI
	hud.on_combat_event({"event_type": "health_update", "player": "p1", "current_health": 100.0})
	hud.on_combat_event({"event_type": "health_update", "player": "p2", "current_health": 100.0})
	hud.on_combat_event({"event_type": "timer_update", "time_left": 99})
	
	# Anunciar la ronda dinámica (Round 2 o Round 3)
	var estado = "round_" + str(ronda_actual)
	hud.on_combat_event({"event_type": "match_state", "state": estado})
	
	await get_tree().create_timer(1.5).timeout
	hud.on_combat_event({"event_type": "match_state", "state": "fight"})
	await get_tree().create_timer(2.0).timeout
	hud.on_combat_event({"event_type": "match_state", "state": "clear"})


func _enrutar_evento(resultado: Dictionary) -> void:
	if resultado.get("event_name") == "on_match_start":
		var datos_partida = resultado.get("data", {})
		tiempo_actual = datos_partida.get("round_time", 99)
		hud.on_combat_event({
			"event_type": "timer_update",
			"time_left": tiempo_actual
		})
