extends Area2D

@export var dueno_id: int = 1
@export var direccion: float = 1.0
@export var velocidad: float = 900.0
@export var dano: int = 15
@export var empuje: Vector2 = Vector2(320.0, -140.0)
@export var distancia_maxima: float = 960.0

var _distancia_recorrida: float = 0.0

func _ready() -> void:
	if direccion < 0.0:
		$Hadoken.flip_h = true
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var avance := velocidad * delta
	global_position.x += direccion * avance
	_distancia_recorrida += avance
	if _distancia_recorrida >= distancia_maxima:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.name not in ["Hurtbox-Estandar", "Hurtbox-Baja", "Hurtbox"]:
		return

	var objetivo = area.get_parent()
	if objetivo == null or not objetivo.has_method("recibir_ataque"):
		return
	var id_objetivo = objetivo.get("player_id")
	if id_objetivo != null and int(id_objetivo) == dueno_id:
		return

	objetivo.recibir_ataque(dano, Vector2(empuje.x * direccion, empuje.y), dueno_id, "MEDIO", false)
	queue_free()
