extends Area2D

# Lightweight projectile fired by enemies (e.g. Spitter).
# Hits the player, not other enemies.

var direction = Vector2.RIGHT
var speed = 320.0
var damage = 5.0
var max_range = 300.0
var _travelled = 0.0
var _game: Node = null

func setup(game_ref: Node, dir: Vector2, proj_speed: float, dmg: float, proj_range: float) -> void:
	_game = game_ref
	direction = dir.normalized()
	speed = proj_speed
	damage = dmg
	max_range = proj_range

func _ready() -> void:
	collision_layer = GameLayers.PROJECTILE
	collision_mask = GameLayers.PLAYER | GameLayers.ALLY
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var step = speed * delta
	global_position += direction * step
	_travelled += step
	if _travelled >= max_range:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if not (body.is_in_group("player") or body.is_in_group("allies")):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position, true)
	queue_free()
