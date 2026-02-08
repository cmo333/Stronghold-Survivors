extends Area2D

# Lightweight projectile fired by enemies (e.g. Spitter).
# Hits the player, not other enemies.

var direction = Vector2.RIGHT
var speed = 320.0
var damage = 5.0
var max_range = 300.0
var _travelled = 0.0
var _game: Node = null
var _last_position = Vector2.ZERO
var _trail_distance = 0.0
var _trail_step = 12.0

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
	_last_position = global_position

func _physics_process(delta: float) -> void:
	var step = speed * delta
	global_position += direction * step
	_travelled += step
	_spawn_trail()
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

func _spawn_trail() -> void:
	if _game == null or not _game.has_method("spawn_glow_particle"):
		return
	var moved = global_position.distance_to(_last_position)
	_trail_distance += moved
	if _trail_distance < _trail_step:
		_last_position = global_position
		return
	_trail_distance = 0.0
	var trail_color = Color(1.0, 0.35, 0.25).lerp(Color.WHITE, 0.15)
	var trail_velocity = -direction * speed * 0.08
	_game.spawn_glow_particle(global_position, trail_color, 5.0, 0.3, trail_velocity, 1.6, 0.75, 1.0, 2)
	_last_position = global_position
