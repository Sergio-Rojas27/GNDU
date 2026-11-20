extends Node

# Señal para la pausa (comunicación Núcleo 2 -> Núcleo 4)
signal estado_pausa_cambiado(pausado: bool)

# Señales oficiales de la Matriz Maestra de Comunicación (BCE)
signal on_match_start(datos: Dictionary)
signal on_combat_event(datos: Dictionary)
signal on_state_change(datos: Dictionary)
