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
	
	# 2. Cambiamos completamente a la escena de victoria
	# Revisa que la ruta coincida con la ubicación real de tu archivo
	get_tree().change_scene_to_file("res://nucleo4_interfaz/scenes/Pantalla_Ganador.tscn")

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
