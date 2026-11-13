extends Control

@onready var personaje_rect = $Personaje
@onready var label_nombre = $TimerLabel 
@onready var btn_menu = $Salir# Asegúrate de que apunte a tu botón real

func _ready():
	# Conectamos el botón
	if btn_menu:
		btn_menu.pressed.connect(_on_btn_menu_pressed)
		
	# Obtenemos el ganador guardado
	var ganador = DatosGlobales.ganador_id
	
	if ganador == "empate":
		label_nombre.text = "EMPATE"
		personaje_rect.hide()
	else:
		label_nombre.text = ganador.capitalize()
		var ruta_imagen = "res://assets/Fighters/" + ganador + "/preview.png"
		
		if ResourceLoader.exists(ruta_imagen):
			personaje_rect.texture = load(ruta_imagen)

func _on_btn_menu_pressed() -> void:
	# Ruta para volver al menú o a la selección de personajes
	get_tree().change_scene_to_file("res://nucleo4_interfaz/scenes/Menu_Principal.tscn")
