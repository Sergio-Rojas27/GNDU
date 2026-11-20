extends Node2D

const ESCENA_JUGADOR := preload("res://scenes/jugador.tscn")

@onready var stage_container: Node2D = $StageContainer
@onready var spawn_p1: Marker2D = $SpawnP1
@onready var spawn_p2: Marker2D = $SpawnP2
@onready var camara: Camera2D = $Camera2D
@onready var simulador_hud: Node = $SimuladorHUD
@export var hud: Control

var jugador1: CharacterBody2D
var jugador2: CharacterBody2D
var pos_inicial_j1: Vector2 = Vector2(751, 919)
var pos_inicial_j2: Vector2 = Vector2(1119, 915)

func _ready() -> void:
	if not hud and has_node("HUD/Control"):
		hud = $HUD/Control
	DatosGlobales.aplicar_restriccion_fisicas(DatosGlobales.AppState.COMBATE)
	cargar_escenario()
	instanciar_jugadores()

	if simulador_hud:
		if "jugador1" in simulador_hud:
			simulador_hud.jugador1 = jugador1
		if "jugador2" in simulador_hud:
			simulador_hud.jugador2 = jugador2
		if "pos_inicial_j1" in simulador_hud:
			simulador_hud.pos_inicial_j1 = pos_inicial_j1
		if "pos_inicial_j2" in simulador_hud:
			simulador_hud.pos_inicial_j2 = pos_inicial_j2
		simulador_hud.combate_finalizado.connect(_on_combate_finalizado)

func instanciar_jugadores() -> void:
	var limites: Dictionary = _detectar_limites_escenario()
	var floor_y: float = float(limites["floor_y"])
	var lim_izq: float = float(limites["left_x"])
	var lim_der: float = float(limites["right_x"])
	var lim_inf: float = float(limites["bottom_y"])

	var centro_escenario_x: float = (lim_izq + lim_der) * 0.5
	pos_inicial_j1 = Vector2(centro_escenario_x - 185.0, floor_y - 125.0)
	pos_inicial_j2 = Vector2(centro_escenario_x + 185.0, floor_y - 125.0)
	if spawn_p1:
		spawn_p1.global_position = pos_inicial_j1
	if spawn_p2:
		spawn_p2.global_position = pos_inicial_j2

	jugador1 = ESCENA_JUGADOR.instantiate()
	jugador1.name = "Jugador1"
	jugador1.player_id = 1
	jugador1.accion_izquierda = &"p1_izquierda"
	jugador1.accion_derecha = &"p1_derecha"
	jugador1.accion_arriba = &"p1_arriba"
	jugador1.accion_abajo = &"p1_agachar"
	jugador1.accion_salto = &"p1_salto"
	jugador1.accion_golpe = &"p1_puno"
	jugador1.accion_patada = &"p1_patada"
	jugador1.accion_bloqueo = &"p1_bloquear"
	jugador1.accion_agarre = &"p1_agarre"
	jugador1.limite_escenario_izq = lim_izq
	jugador1.limite_escenario_der = lim_der
	jugador1.controles_habilitados = false

	jugador2 = ESCENA_JUGADOR.instantiate()
	jugador2.name = "Jugador2"
	jugador2.player_id = 2
	jugador2.accion_izquierda = &"p2_izquierda"
	jugador2.accion_derecha = &"p2_derecha"
	jugador2.accion_arriba = &"p2_arriba"
	jugador2.accion_abajo = &"p2_agachar"
	jugador2.accion_salto = &"p2_salto"
	jugador2.accion_golpe = &"p2_puno"
	jugador2.accion_patada = &"p2_patada"
	jugador2.accion_bloqueo = &"p2_bloquear"
	jugador2.accion_agarre = &"p2_agarre"
	jugador2.limite_escenario_izq = lim_izq
	jugador2.limite_escenario_der = lim_der
	jugador2.controles_habilitados = false

	jugador1.rival = jugador2
	jugador2.rival = jugador1

	add_child(jugador1)
	add_child(jugador2)

	jugador1.global_position = pos_inicial_j1
	jugador2.global_position = pos_inicial_j2

	if camara:
		if camara.has_method("configurar_limites"):
			camara.configurar_limites(lim_izq, lim_der, 0.0, lim_inf)
		if "jugador_1" in camara:
			camara.jugador_1 = jugador1
		if "jugador_2" in camara:
			camara.jugador_2 = jugador2
		if camara.has_method("_actualizar_camara"):
			camara._actualizar_camara(1.0)

func _detectar_limites_escenario() -> Dictionary:
	var mejor_floor_y: float = 950.0
	var floor_encontrado: bool = false
	var floor_min_x: float = 0.0
	var floor_max_x: float = 1920.0
	var paredes: Array[Dictionary] = []

	for col in stage_container.find_children("*", "CollisionShape2D", true, false):
		if not (col.get_parent() is StaticBody2D or col.get_parent() is CollisionShape2D):
			continue
		if not (col.shape is RectangleShape2D):
			continue
		var rect_shape := col.shape as RectangleShape2D
		var tf: Transform2D = col.global_transform
		var half: Vector2 = rect_shape.size * 0.5
		var p1 := tf * Vector2(-half.x, -half.y)
		var p2 := tf * Vector2(half.x, -half.y)
		var p3 := tf * Vector2(half.x, half.y)
		var p4 := tf * Vector2(-half.x, half.y)
		var min_x := minf(minf(p1.x, p2.x), minf(p3.x, p4.x))
		var max_x := maxf(maxf(p1.x, p2.x), maxf(p3.x, p4.x))
		var min_y := minf(minf(p1.y, p2.y), minf(p3.y, p4.y))
		var max_y := maxf(maxf(p1.y, p2.y), maxf(p3.y, p4.y))
		var ancho := max_x - min_x
		var alto := max_y - min_y

		if ancho > alto:
			# Colisionador horizontal (suelo)
			if not floor_encontrado or min_y < mejor_floor_y:
				mejor_floor_y = min_y
				floor_min_x = min_x
				floor_max_x = max_x
				floor_encontrado = true
		else:
			# Colisionador vertical (pared lateral delimitada en el escenario)
			paredes.append({
				"min_x": min_x,
				"max_x": max_x,
				"center_x": (min_x + max_x) * 0.5
			})

	var left_x: float = floor_min_x
	var right_x: float = floor_max_x

	if paredes.size() >= 2:
		paredes.sort_custom(func(a, b): return a["center_x"] < b["center_x"])
		var pared_izq: Dictionary = paredes[0]
		var pared_der: Dictionary = paredes[paredes.size() - 1]
		# El borde interior de la pared izquierda es su max_x, y el de la derecha es su min_x
		if float(pared_der["min_x"]) - float(pared_izq["max_x"]) > 800.0:
			left_x = float(pared_izq["max_x"])
			right_x = float(pared_der["min_x"])

	var bottom_y: float = 1080.0
	var ground_bottoms: Array[float] = []
	for body in stage_container.find_children("*", "StaticBody2D", true, false):
		for sp in body.find_children("*", "Sprite2D", true, false):
			if sp.texture and sp.visible:
				var tf_sp: Transform2D = sp.global_transform
				var sz: Vector2 = sp.texture.get_size()
				var rect_min := -sz * 0.5 if sp.centered else Vector2.ZERO
				var rect_max := sz * 0.5 if sp.centered else sz
				var c1 := tf_sp * rect_min
				var c2 := tf_sp * Vector2(rect_max.x, rect_min.y)
				var c3 := tf_sp * rect_max
				var c4 := tf_sp * Vector2(rect_min.x, rect_max.y)
				var sp_min_x := minf(minf(c1.x, c2.x), minf(c3.x, c4.x))
				var sp_max_x := maxf(maxf(c1.x, c2.x), maxf(c3.x, c4.x))
				var sp_max_y := maxf(maxf(c1.y, c2.y), maxf(c3.y, c4.y))
				if (sp_max_x - sp_min_x) >= 350.0 and sp_max_y >= mejor_floor_y:
					ground_bottoms.append(sp_max_y)

	if not ground_bottoms.is_empty():
		var min_ground_bottom: float = ground_bottoms[0]
		for gb in ground_bottoms:
			min_ground_bottom = minf(min_ground_bottom, gb)
		# Nunca bajar la cámara más allá del borde inferior del sprite de suelo más corto
		bottom_y = minf(1080.0, min_ground_bottom)
	else:
		# Escenarios sin sprite dentro de StaticBody2D (ej. CampoEntrenamiento cuya imagen termina en Y=1075)
		var bg_bottoms: Array[float] = []
		for sp in stage_container.find_children("*", "Sprite2D", true, false):
			if sp.texture and sp.visible:
				var tf_sp: Transform2D = sp.global_transform
				var sz: Vector2 = sp.texture.get_size()
				var rect_min := -sz * 0.5 if sp.centered else Vector2.ZERO
				var rect_max := sz * 0.5 if sp.centered else sz
				var c3 := tf_sp * rect_max
				var c4 := tf_sp * Vector2(rect_min.x, rect_max.y)
				var sp_max_y := maxf(c3.y, c4.y)
				if sp_max_y >= mejor_floor_y:
					bg_bottoms.append(sp_max_y)
		if not bg_bottoms.is_empty():
			var min_bg_bottom: float = bg_bottoms[0]
			for bb in bg_bottoms:
				min_bg_bottom = minf(min_bg_bottom, bb)
			bottom_y = minf(1080.0, min_bg_bottom)

	return {
		"floor_y": mejor_floor_y,
		"left_x": left_x,
		"right_x": right_x,
		"bottom_y": bottom_y
	}

func _limpiar_proyectiles_activos() -> void:
	for hijo in get_children():
		if hijo is Area2D and hijo != jugador1 and hijo != jugador2:
			hijo.queue_free()

func _on_jugador_combat_event(_evento_json: Dictionary) -> void:
	pass

func _on_combate_finalizado(ganador_id_recibido: String) -> void:
	# 1. Guardamos quién ganó en el Singleton
	DatosGlobales.ganador_id = ganador_id_recibido

	# 2. Cambiar estado a RESULTADO (desactiva físicas y emite on_state_change)
	DatosGlobales.cambiar_estado(DatosGlobales.AppState.RESULTADO)

	# 3. Preparamos una variable para la escena que vamos a cargar
	var escena_resultado: PackedScene

	# 4. Decidimos qué escena cargar según el resultado
	if ganador_id_recibido == "empate":
		escena_resultado = load("res://nucleo4_interfaz/scenes/Pantalla_Empate.tscn")
	else:
		escena_resultado = load("res://nucleo4_interfaz/scenes/Pantalla_Ganador.tscn")

	# 5. Instanciamos la escena elegida
	var instancia_resultado = escena_resultado.instantiate()

	# 6. Creamos un CanvasLayer por código para asegurarnos de que la pantalla
	#    aparezca por encima de los personajes, el escenario y el HUD.
	var capa_superior = CanvasLayer.new()
	capa_superior.layer = 100

	capa_superior.add_child(instancia_resultado)
	add_child(capa_superior)

func _on_logica_combete_daño_recibido(datos_evento: Dictionary) -> void:
	if hud:
		hud.on_combat_event(datos_evento)

func cargar_escenario() -> void:
	var stage_id: String = DatosGlobales.escenario_seleccionado_id
	if stage_id == "":
		stage_id = "Escenario_Uni"

	var stage_path: String = "res://nucleo4_interfaz/scenes/" + stage_id + ".tscn"
	if not ResourceLoader.exists(stage_path):
		# Respaldo por si stage_id viene en minúsculas (ej. "escenario_uni")
		for candidato in [
			"Escenario_Uni", "Escenario_CampoEntrenamiento", "Escenario_Playa",
			"Escenario_Ciudad", "Escenario_Espacio", "Escenario_Jungla",
			"Escenario_Sakura", "Escenario_Desierto", "Escenario_Navidad"
		]:
			if candidato.to_lower() == stage_id.to_lower():
				stage_id = candidato
				stage_path = "res://nucleo4_interfaz/scenes/" + stage_id + ".tscn"
				break

	if ResourceLoader.exists(stage_path):
		for child in stage_container.get_children():
			child.queue_free()

		var stage_scene: PackedScene = load(stage_path)
		var stage_instance: Node = stage_scene.instantiate()
		stage_container.add_child(stage_instance)
		print("Escenario cargado exitosamente: ", stage_id)
	else:
		print("ERROR: No se encontró el archivo del escenario en: ", stage_path)
