extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
# En el script principal de tu Escenario actual:
@onready var hud: Control = $HUD/Control

func _on_logica_combete_daño_recibido(datos_evento: Dictionary) -> void:
	# El escenario reenvía el evento hacia el HUD instanciado
	hud.on_combat_event(datos_evento)
