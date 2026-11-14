extends Node2D

@onready var stage_container: Node2D = $StageContainer
@onready var spawn_p1: Marker2D = $SpawnP1
@onready var spawn_p2: Marker2D = $SpawnP2
@export var hud: Control

func _ready() -> void:
	cargar_escenario()

	
	# Conectamos la señal del simulador
	$SimuladorHUD.combate_finalizado.connect(_on_combate_finalizado)

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
	capa_superior.layer = 100 # Un número alto para que quede sobre todo lo demás

	capa_superior.add_child(instancia_resultado)
	add_child(capa_superior)

func _on_logica_combete_daño_recibido(datos_evento: Dictionary) -> void:
	# El escenario reenvía el evento hacia el HUD instanciado
	hud.on_combat_event(datos_evento)

func cargar_escenario() -> void:
	var stage_id: String = DatosGlobales.escenario_seleccionado_id
	
	# Fallback si se prueba directamente la escena desde el editor
	if stage_id == "":
		stage_id = "escenario_uni"
		
	var stage_path: String = "res://nucleo4_interfaz/scenes/" + stage_id + ".tscn"
	
	if ResourceLoader.exists(stage_path):
		for child in stage_container.get_children():
			child.queue_free()
			
		var stage_scene: PackedScene = load(stage_path)
		var stage_instance: Node = stage_scene.instantiate()
		stage_container.add_child(stage_instance)
		print("Escenario cargado exitosamente: ", stage_id)
	else:
		print("ERROR: No se encontró el archivo del escenario en: ", stage_path)
