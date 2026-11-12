extends Node

# Variables globales accesibles desde cualquier escena del proyecto

enum AppState {
	MENU_PRINCIPAL,
	MENU_SELECCION_ESCENARIO,
	MENU_SELECCION_PERSONAJES,
	COMBATE
}

signal on_state_change(event_data: Dictionary)

var estado_actual: AppState = AppState.MENU_PRINCIPAL

# Datos persistentes de la partida
var escenario_seleccionado_id: String = ""
var escenario_seleccionado_nombre: String = ""
var p1_fighter_id: String = ""
var p2_fighter_id: String = ""

func _ready() -> void:
	# Iniciar en menú principal con las físicas desactivadas
	aplicar_restriccion_fisicas(AppState.MENU_PRINCIPAL)

func cambiar_estado(nuevo_estado: AppState, ruta_escena: String = "") -> void:
	var estado_anterior_str: String = AppState.keys()[estado_actual]
	var estado_nuevo_str: String = AppState.keys()[nuevo_estado]
	estado_actual = nuevo_estado
	
	# 1. Bloquear o habilitar físicas según el estado
	aplicar_restriccion_fisicas(estado_actual)
	
	# 2. Emitir el evento global oficial
	var state_change_event: Dictionary = {
		"event_name": "on_state_change",
		"source_core": "nucleo4_interfaz",
		"data": {
			"previous_screen": estado_anterior_str,
			"current_screen": estado_nuevo_str
		}
	}
	
	print("--- EMITIENDO EVENTO GLOBAL: on_state_change ---")
	print(JSON.stringify(state_change_event, "\t"))
	on_state_change.emit(state_change_event)
	
	# 3. Cambiar de escena si se proporcionó ruta
	if ruta_escena != "":
		var error := get_tree().change_scene_to_file(ruta_escena)
		if error != OK:
			push_error("Error al cambiar a la escena: " + ruta_escena + " (Código: " + str(error) + ")")

func aplicar_restriccion_fisicas(estado: AppState) -> void:
	var permitir_fisicas: bool = (estado == AppState.COMBATE)
	PhysicsServer2D.set_active(permitir_fisicas)
	PhysicsServer3D.set_active(permitir_fisicas)
