extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	# Comprueba si la tecla presionada es, por ejemplo, la letra "N" o la barra espaciadora
	if event.is_action_pressed("ui_accept"): # O usa una tecla específica como se muestra abajo
		cambiar_escena()

func cambiar_escena() -> void:
	# Reemplaza la ruta con la ubicación exacta de tu escena de destino
	var nueva_escena = "res://nucleo4_interfaz/menu_seleccion_personajes.tscn"
	
	var error = get_tree().change_scene_to_file(nueva_escena)
	if error != OK:
		print("Error al cambiar de escena: ", error)
