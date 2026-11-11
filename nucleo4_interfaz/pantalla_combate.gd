extends Node2D

@onready var stage_container: Node2D = $StageContainer
@onready var spawn_p1: Marker2D = $SpawnP1
@onready var spawn_p2: Marker2D = $SpawnP2

func _ready() -> void:
	cargar_escenario()
	cargar_personajes()

func cargar_escenario() -> void:
	var stage_id: String = DatosGlobales.escenario_seleccionado_id
	
	# Fallback si se prueba directamente la escena desde el editor
	if stage_id == "":
		stage_id = "escenario_uni"
		
	var stage_path: String = "res://nucleo4_interfaz/" + stage_id + ".tscn"
	
	if ResourceLoader.exists(stage_path):
		for child in stage_container.get_children():
			child.queue_free()
			
		var stage_scene: PackedScene = load(stage_path)
		var stage_instance: Node = stage_scene.instantiate()
		stage_container.add_child(stage_instance)
		print("Escenario cargado exitosamente: ", stage_id)
	else:
		print("ERROR: No se encontró el archivo del escenario en: ", stage_path)

func cargar_personajes() -> void:
	var p1_id: String = DatosGlobales.p1_fighter_id
	var p2_id: String = DatosGlobales.p2_fighter_id
	
	# Instanciar P1
	var path_p1: String = "res://assets/fighters/" + p1_id + "/" + p1_id + ".tscn"
	if ResourceLoader.exists(path_p1):
		var p1_node = load(path_p1).instantiate()
		p1_node.global_position = spawn_p1.global_position
		add_child(p1_node)
		print("Jugador 1 instanciado: ", p1_id)
	else:
		print("ERROR: No se encontró el personaje P1 en: ", path_p1)
		
	# Instanciar P2
	var path_p2: String = "res://assets/fighters/" + p2_id + "/" + p2_id + ".tscn"
	if ResourceLoader.exists(path_p2):
		var p2_node = load(path_p2).instantiate()
		p2_node.global_position = spawn_p2.global_position
		add_child(p2_node)
		print("Jugador 2 instanciado: ", p2_id)
	else:
		print("ERROR: No se encontró el personaje P2 en: ", path_p2)
