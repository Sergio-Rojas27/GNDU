extends Control

# SEÑAL: Avisa al juego que ya se puede pelear y el tiempo debe correr
signal fight_begins 

@onready var Menu_Pausa = $Menu_Pausa 
@onready var health_bar_p1: ProgressBar = $RedDamageBarP1/HealthBarP1
@onready var damage_bar_p1: ProgressBar = $RedDamageBarP1
@onready var health_bar_p2: ProgressBar = $RedDamageBarP2/HealthBarP2
@onready var damage_bar_p2: ProgressBar = $RedDamageBarP2
@onready var timer_label: Label = $TimerLabel
@onready var combo_label_p1: Label = $ComboLabelP1
@onready var combo_label_p2: Label = $ComboLabelP2
@onready var num_hit_p1: Label = $ComboLabelP1/NumHitP1
@onready var num_hit_p2: Label = $ComboLabelP2/NumHitP2

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

const TEXTURES_ESTADOS = {
	"round_1": preload("res://assets/States_Hud/round1.png"),
	"round_2": preload("res://assets/States_Hud/round2.png"),
	"round_3": preload("res://assets/States_Hud/round3.png"),
	"ready": preload("res://assets/States_Hud/ready.png"),
	"fight": preload("res://assets/States_Hud/fight.png"),
	"ko": preload("res://assets/States_Hud/ko.png"),
	"draw": preload("res://assets/States_Hud/draw.png"),
	"Gema_Verde": preload("res://assets/States_Hud/Gema_Ganada.png"),
	"Gema_Amarilla": preload("res://assets/States_Hud/Gema_Draw.png"),
	"Gema_Roja": preload("res://assets/States_Hud/Gema_Perdida.png")
}

const BASE_FIGHTERS_DIR = "res://assets/fighters/"
const DEFAULT_PORTRAIT = preload("res://assets/Fighters/Default/Default.png")

func _ready() -> void:
	EventBus.connect("estado_pausa_cambiado", Callable(self, "_on_pausa_solicitada"))
	
	process_mode = Node.PROCESS_MODE_ALWAYS 
	Menu_Pausa.hide()
	
	combo_label_p1.text = ""
	combo_label_p2.text = ""
	status_texture.visible = false
	
	health_bar_p1.max_value = 100.0
	damage_bar_p1.max_value = 100.0
	health_bar_p2.max_value = 100.0
	damage_bar_p2.max_value = 100.0

func _on_pausa_solicitada(pausado: bool):
	get_tree().paused = pausado
	
	if pausado:
		Menu_Pausa.show()
	else:
		Menu_Pausa.hide()

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

	# 1. Extraer los datos de combate oficiales (si vienen del Núcleo 3, estarán dentro de "data")
	var combat_data: Dictionary = event_data.get("data", event_data)
	
	# 2. Identificar el tipo de evento (prioriza el "type" oficial del PDF, luego tu "event_type" simulado)
	var action_type = combat_data.get("type", event_data.get("event_type", ""))

	match action_type:
		# =========================================================
		# CASOS OFICIALES DEL BUS CENTRAL (Contrato con Núcleo 3)
		# =========================================================
		"HIT", "BLOCK":
			# El contrato oficial usa 1 o 2 para identificar al jugador
			var defender_id: String = str(combat_data.get("defender", "1"))
			var attacker_id: String = str(combat_data.get("attacker", "2"))
			
			var hp: float = float(combat_data.get("current_hp", 100.0))
			var combos: int = int(combat_data.get("combo_count", 0))
			var is_ko: bool = combat_data.get("is_ko", false)
			
			# A. Actualizar barra de salud (el HUD no calcula el daño, solo lee current_hp)
			_update_health({"player": "p" + defender_id, "current_health": hp})
			
			# B. Desplegar cartel de combos
			if combos > 1:
				_update_combo({"player": "p" + attacker_id, "hits": combos})
			
			# C. Verificar estado K.O.
			if is_ko:
				_update_match_state({"state": "ko"})
				
		"TIME_OVER":
			# El Núcleo 3 decreta el fin del tiempo
			_update_match_state({"state": "draw"}) # O el estado que decidan para tiempo agotado
			
		# =========================================================
		# CASOS DEL SIMULADOR LOCAL (Tu lógica de interfaz y pruebas)
		# =========================================================
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
		"start_round_sequence":
			_play_round_sequence(event_data.get("round", 1))
		"round_end":
			var winner = event_data.get("winner", "")
			_on_round_end(winner)

func _setup_players(data: Dictionary) -> void:
	var p1_id = data.get("player_1_fighter_id", "")
	var p2_id = data.get("player_2_fighter_id", "")
	
	_load_fighter_ui(p1_id, name_label_p1, icon_p1)
	_load_fighter_ui(p2_id, name_label_p2, icon_p2)

func _load_fighter_ui(fighter_id: String, name_label: Label, icon_rect: TextureRect) -> void:
	if fighter_id == "": return
	
	name_label.text = fighter_id.capitalize()
	var img_path = BASE_FIGHTERS_DIR + fighter_id + "/portrait.png"
	
	if FileAccess.file_exists(img_path) or ResourceLoader.exists(img_path):
		icon_rect.texture = load(img_path)
	else:
		icon_rect.texture = DEFAULT_PORTRAIT
		
func _update_health(data: Dictionary) -> void:
	var player: String = str(data.get("player", "p1")).to_lower()
	var new_health: float = clamp(float(data.get("current_health", 100.0)), 0.0, 100.0)
	
	if player == "p1" or player == "1":
		health_bar_p1.value = new_health
		
		if tween_p1 and tween_p1.is_valid(): 
			tween_p1.kill()
			
		tween_p1 = create_tween()
		tween_p1.tween_property(damage_bar_p1, "value", new_health, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	elif player == "p2" or player == "2":
		health_bar_p2.value = new_health
		
		if tween_p2 and tween_p2.is_valid(): 
			tween_p2.kill()
			
		tween_p2 = create_tween()
		tween_p2.tween_property(damage_bar_p2, "value", new_health, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
	var num: Label = num_hit_p1 if player == "p1" else num_hit_p2
	var label: Label = combo_label_p1 if player == "p1" else combo_label_p2
	
	if combo_count > 1:
		label.text = "Hits"
		num.text = str(combo_count)
		
		var t = create_tween()
		label.scale = Vector2(1.3, 1.3)
		num.scale = Vector2(1.3, 1.3) # Opcional: también escala el número
		
		# 1. Animación inicial
		t.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)
		t.parallel().tween_property(num, "scale", Vector2(1.0, 1.0), 0.15)
		
		# 2. Esperar 1 segundo en pantalla
		t.tween_interval(1.0)
		
		# 3. Limpiar los textos para que desaparezcan
		t.tween_callback(func():
			label.text = ""
			num.text = ""
		)
	else:
		label.text = ""
		num.text = ""

func _update_timer(data: Dictionary) -> void:
	var time_left: int = data.get("time_left", 99)
	timer_label.text = str(time_left)

func _play_round_sequence(round_num: int) -> void:
	var state_round = "round_" + str(round_num)
	
	if not TEXTURES_ESTADOS.has(state_round): return
	
	status_texture.texture = TEXTURES_ESTADOS[state_round]
	status_texture.visible = true
	status_texture.pivot_offset = status_texture.size / 2.0
	status_texture.scale = Vector2(2.5, 2.5)
	status_texture.modulate.a = 0.0
	
	if tween_status: 
		tween_status.kill()
		
	tween_status = create_tween()
	
	# 1. Aparece "ROUND X"
	tween_status.parallel().tween_property(status_texture, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_status.parallel().tween_property(status_texture, "modulate:a", 1.0, 0.15)
	
	# 2. Pausa para leer "ROUND X"
	tween_status.chain().tween_interval(1.2)
	
	# 3. Cambia a "READY"
	tween_status.tween_callback(func():
		status_texture.texture = TEXTURES_ESTADOS["ready"]
		status_texture.scale = Vector2(2.5, 2.5)
		status_texture.modulate.a = 0.0
	)
	tween_status.parallel().tween_property(status_texture, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_status.parallel().tween_property(status_texture, "modulate:a", 1.0, 0.15)
	
	# 4. Pausa para leer "READY"
	tween_status.chain().tween_interval(0.8)
	
	# 5. Cambia a "FIGHT"
	tween_status.tween_callback(func():
		status_texture.texture = TEXTURES_ESTADOS["fight"]
		status_texture.scale = Vector2(1.5, 1.5)
	)
	tween_status.tween_property(status_texture, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# 6. ¡AQUÍ INICIA EL COMBATE! Disparamos la señal al simulador
	tween_status.tween_callback(func(): emit_signal("fight_begins"))
	
	# 7. Pausa final y desvanece suavemente el "FIGHT"
	tween_status.tween_interval(1.0)
	tween_status.tween_property(status_texture, "modulate:a", 0.0, 0.2)
	tween_status.tween_callback(func(): status_texture.visible = false)

func _update_match_state(data: Dictionary) -> void:
	var state: String = data.get("state", "")
	
	if state == "clear":
		status_texture.visible = false
		return
		
	if TEXTURES_ESTADOS.has(state):
		status_texture.texture = TEXTURES_ESTADOS[state]
		status_texture.visible = true
		status_texture.pivot_offset = status_texture.size / 2.0
		status_texture.scale = Vector2(2.5, 2.5)
		status_texture.modulate.a = 0.0
		
		if tween_status: 
			tween_status.kill()
			
		tween_status = create_tween().set_parallel(true)
		tween_status.tween_property(status_texture, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween_status.tween_property(status_texture, "modulate:a", 1.0, 0.15)
