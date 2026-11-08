extends Control

# Referencias existentes...
@onready var health_bar_p1: ProgressBar = $RedDamageBarP1/HealthBarP1
@onready var damage_bar_p1: ProgressBar = $RedDamageBarP1
@onready var health_bar_p2: ProgressBar = $RedDamageBarP2/HealthBarP2
@onready var damage_bar_p2: ProgressBar = $RedDamageBarP2
@onready var timer_label: Label = $TimerLabel
@onready var combo_label_p1: Label = $ComboLabelP1
@onready var combo_label_p2: Label = $ComboLabelP2

# NUEVO: Referencia al TextureRect central para los estados de la pelea
@onready var status_texture: TextureRect = $StatusAnnouncementTexture

# Variables para cargar imágenes de las gemas
@export var gem: Texture2D
@export var gem_Verde: Texture2D
@export var gem_Roja: Texture2D
@export var gem_Amarilla: Texture2D

# Arreglos que guardan los nodos de las gemas de cada jugador
@onready var p1_gems: Array = [$GemasP1/GemaP1R1, $GemasP1/GemaP1R2, $GemasP1/GemaP1R3]
@onready var p2_gems: Array = [$GemasP2/GemaP2R1, $GemasP2/GemaP2R2, $GemasP2/GemaP2R3]

# Referencias a los iconos y nombres
@onready var icon_p1: TextureRect = $PortraitP1
@onready var icon_p2: TextureRect = $PortraitP2
@onready var name_label_p1: Label = $NombreP1
@onready var name_label_p2: Label = $NombreP2

var tween_p1: Tween
var tween_p2: Tween
var tween_status: Tween
var rondas_jugadas: int = 0

# Rutas o precarga de tus imágenes de estado (reemplaza con las rutas reales de tus assets)
const TEXTURES_ESTADOS = {
	"round_1": preload("res://assets/States_Hud/round1.jpg"),
	"round_2": preload("res://assets/States_Hud/round2.jpg"),
	"round_3": preload("res://assets/States_Hud/round3.jpg"),
	"fight": preload("res://assets/States_Hud/fight.jpg"),
	"ko": preload("res://assets/States_Hud/ko.jpg"),
	"draw": preload("res://assets/States_Hud/draw.jpg"),
	"Gema_Verde": preload("res://assets/States_Hud/Gema_Ganada.png"),
	"Gema_Amarilla": preload("res://assets/States_Hud/Gema_Draw.png"),
	"Gema_Roja": preload("res://assets/States_Hud/Gema_Perdida.png")
}

# Guardamos solo el texto de la ruta, no la imagen pesada
const PERSONAJES = {
	"estudiante": {
		"nombre": "Estudiante",
		"foto_path": "res://assets/Fighters/Portraits/P1.png" 
	},
	"profesor": {
		"nombre": "Profesor",
		"foto_path": "res://assets/Fighters/Portraits/P2.png"
	},
	"nuevo": {
		"nombre": "NINJA",
		"foto": "res://assets/Fighters/Portraits/Default.png"
	}
}

func _ready() -> void:
	combo_label_p1.text = ""
	combo_label_p2.text = ""
	status_texture.visible = false
	
	health_bar_p1.max_value = 100.0
	damage_bar_p1.max_value = 100.0
	health_bar_p2.max_value = 100.0
	damage_bar_p2.max_value = 100.0

## Punto de entrada único para la interfaz reactiva
func on_combat_event(json_data: Variant) -> void:
	var event_data: Dictionary = {}
	
	if typeof(json_data) == TYPE_STRING:
		var parsed = JSON.new()
		if parsed.parse(json_data) == OK:
			event_data = parsed.data
		else:
			return
	elif typeof(json_data) == TYPE_DICTIONARY:
		event_data = json_data
	else:
		return

	match event_data.get("event_type", ""):
		"setup_players":
			_setup_players(event_data)
		"health_update":
			_update_health(event_data)
		"combo_update":
			_update_combo(event_data)
		"timer_update":
			_update_timer(event_data)
		"match_state":
			_update_match_state(event_data)
		"round_end":
			# Ahora recibimos quién ganó y actualizamos todo de un golpe
			var winner = event_data.get("winner", "")
			_on_round_end(winner)
			

func _setup_players(data: Dictionary) -> void:
	var player_1_fighter_id = data.get("player_1_fighter_id", "")
	var player_2_fighter_id = data.get("player_2_fighter_id", "")
	
	if PERSONAJES.has(player_1_fighter_id):
		name_label_p1.text = PERSONAJES[player_1_fighter_id]["nombre"]
		# Carga la imagen a la memoria RAM solo en este momento
		icon_p1.texture = load(PERSONAJES[player_1_fighter_id]["foto_path"])
		
	if PERSONAJES.has(player_2_fighter_id):
		name_label_p2.text = PERSONAJES[player_2_fighter_id]["nombre"]
		icon_p2.texture = load(PERSONAJES[player_2_fighter_id]["foto_path"])
		
func _update_health(data: Dictionary) -> void:
	var player: String = str(data.get("player", "p1")).to_lower()
	var new_health: float = clamp(float(data.get("current_health", 100.0)), 0.0, 100.0)
	
	if player == "p1" or player == "1":
		# 1. La barra verde baja al instante
		health_bar_p1.value = new_health
		
		# 2. Cancelamos la animación anterior si el jugador recibe varios golpes seguidos
		if tween_p1 and tween_p1.is_valid(): 
			tween_p1.kill()
			
		# 3. Animamos la barra roja (que ahora está por detrás) para que alcance a la verde
		tween_p1 = create_tween()
		tween_p1.tween_property(damage_bar_p1, "value", new_health, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	elif player == "p2" or player == "2":
		health_bar_p2.value = new_health
		
		if tween_p2 and tween_p2.is_valid(): 
			tween_p2.kill()
			
		tween_p2 = create_tween()
		tween_p2.tween_property(damage_bar_p2, "value", new_health, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Ahora recibe un segundo parámetro opcional para el tipo de resultado
func _on_round_end(winner: String) -> void:
	if rondas_jugadas >= p1_gems.size(): 
		return
		
	if winner == "p1":
		p1_gems[rondas_jugadas].texture = gem_Verde
		p2_gems[rondas_jugadas].texture = gem_Roja
	elif winner == "p2":
		p1_gems[rondas_jugadas].texture = gem_Roja
		p2_gems[rondas_jugadas].texture = gem_Verde
	elif winner == "draw":
		p1_gems[rondas_jugadas].texture = gem_Amarilla
		p2_gems[rondas_jugadas].texture = gem_Amarilla
		
	rondas_jugadas += 1

func _update_combo(data: Dictionary) -> void:
	var player: String = data.get("player", "p1")
	var combo_count: int = data.get("hits", 0)
	var label: Label = combo_label_p1 if player == "p1" else combo_label_p2
	
	if combo_count > 1:
		label.text = str(combo_count) + " HITS!"
		var t = create_tween()
		label.scale = Vector2(1.3, 1.3)
		t.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)
	else:
		label.text = ""

func _update_timer(data: Dictionary) -> void:
	var time_left: int = data.get("time_left", 99)
	timer_label.text = str(time_left)

# NUEVO: Manejo visual de estados mediante imágenes animadas con Tween
func _update_match_state(data: Dictionary) -> void:
	var state: String = data.get("state", "")
	
	# Verificar si el estado tiene una imagen asociada en el diccionario
	if TEXTURES_ESTADOS.has(state):
		status_texture.texture = TEXTURES_ESTADOS[state]
		status_texture.visible = true
		
		# Centrar el pivote de la imagen para que crezca y se reduzca desde su propio centro
		status_texture.pivot_offset = status_texture.size / 2.0
		
		# Animación estilo arcade: Empieza grande y transparente, se encoge rápido con efecto rebote
		status_texture.scale = Vector2(2.5, 2.5)
		status_texture.modulate.a = 0.0
		
		if tween_status: 
			tween_status.kill()
			
		tween_status = create_tween().set_parallel(true)
		tween_status.tween_property(status_texture, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween_status.tween_property(status_texture, "modulate:a", 1.0, 0.15)
		
		# Opcional: Si es un K.O. o Ganador, podemos hacer que se quede más tiempo visible o añadir un efecto extra
	elif state == "clear":
		# Ocultar el letrero si se requiere
		status_texture.visible = false
