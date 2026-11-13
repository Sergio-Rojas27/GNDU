extends CanvasLayer

@onready var btn_reanudar = $Reanudar
@onready var btn_opciones = $Opciones
@onready var btn_salir = $Salir

func _ready() -> void:
	hide()
	
	# NUEVO: Godot avisará a esta función cada vez que el menú se muestre u oculte
	visibility_changed.connect(_al_cambiar_visibilidad)
	
	btn_reanudar.pressed.connect(_on_reanudar_pressed)
	btn_opciones.pressed.connect(_on_opciones_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)
	
	btn_reanudar.focus_neighbor_bottom = btn_opciones.get_path()
	btn_opciones.focus_neighbor_top = btn_reanudar.get_path()
	btn_opciones.focus_neighbor_bottom = btn_salir.get_path()
	btn_salir.focus_neighbor_top = btn_opciones.get_path()

# Esta función garantiza que el teclado funcione sin importar si pausas 
# desde el EventBus (Núcleo 2) o desde aquí.
func _al_cambiar_visibilidad() -> void:
	if visible:
		btn_reanudar.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pausa()

func toggle_pausa() -> void:
	var nuevo_estado = not get_tree().paused
	get_tree().paused = nuevo_estado
	visible = nuevo_estado

func _on_reanudar_pressed() -> void:
	toggle_pausa()

func _on_opciones_pressed() -> void:
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://nucleo4_interfaz/scenes/Pantalla_InfoControles.tscn")

func _on_salir_pressed() -> void:
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://nucleo4_interfaz/scenes/Menu_Principal.tscn")
