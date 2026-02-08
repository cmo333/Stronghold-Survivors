extends CharacterBody2D
class_name Ally

var speed: float = 120.0
var max_health: float = 120.0
var health: float = 120.0
var attack_damage: float = 16.0
var attack_rate: float = 1.0
var attack_range: float = 22.0
var aggro_range: float = 260.0
var leash_radius: float = 280.0
var orbit_radius: float = 140.0
var orbit_speed: float = 2.2
var aoe_radius: float = 0.0
var aoe_damage: float = 0.0
var attack_fx: String = "ally_slash"
var aoe_fx: String = "summon_fire"
var spawn_fx: String = "summon_shadow"
var death_fx: String = "kill_pop"
var damage_type: String = "ally"

var _cooldown: float = 0.0
var _game: Node = null
var _orbit_angle: float = 0.0
var _orbit_dir: float = 1.0

@onready var body: AnimatedSprite2D = $Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func setup(game_ref: Node, config: Dictionary) -> void:
	_game = game_ref
	speed = float(config.get("speed", speed))
	max_health = float(config.get("max_health", max_health))
	health = max_health
	attack_damage = float(config.get("attack_damage", attack_damage))
	attack_rate = float(config.get("attack_rate", attack_rate))
	attack_range = float(config.get("attack_range", attack_range))
	aggro_range = float(config.get("aggro_range", aggro_range))
	leash_radius = float(config.get("leash_radius", leash_radius))
	orbit_radius = float(config.get("orbit_radius", orbit_radius))
	orbit_speed = float(config.get("orbit_speed", orbit_speed))
	aoe_radius = float(config.get("aoe_radius", aoe_radius))
	if config.has("aoe_damage"):
		aoe_damage = float(config.get("aoe_damage", aoe_damage))
	else:
		aoe_damage = attack_damage * 1.3
	attack_fx = str(config.get("attack_fx", attack_fx))
	aoe_fx = str(config.get("aoe_fx", aoe_fx))
	spawn_fx = str(config.get("spawn_fx", spawn_fx))
	death_fx = str(config.get("death_fx", death_fx))
	damage_type = str(config.get("damage_type", damage_type))
	if body != null:
		var scale = float(config.get("scale", 1.0))
		body.scale = Vector2.ONE * scale
		body.z_index = int(config.get("z", 1))
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var shape: CircleShape2D = collision_shape.shape
		shape.radius = max(6.0, float(config.get("hit_radius", shape.radius)))

func _ready() -> void:
	add_to_group("allies")
	collision_layer = GameLayers.ALLY
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_orbit_angle = randf() * TAU
	_orbit_dir = -1.0 if randf() < 0.5 else 1.0

func _physics_process(delta: float) -> void:
	if _game == null:
		return
	_cooldown = max(0.0, _cooldown - delta)
	var player: Node2D = _game.player as Node2D
	var target = _find_target()
	if target != null and _within_leash(player, target):
		var dist = global_position.distance_to(target.global_position)
		if dist <= attack_range:
			velocity = Vector2.ZERO
			_attack(target)
		else:
			_move_towards(target, delta)
	else:
		_orbit_player(player, delta)

func _find_target() -> Node2D:
	var best: Node2D = null
	var best_dist = aggro_range * aggro_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_squared_to(enemy.global_position)
		if dist <= best_dist:
			best = enemy
			best_dist = dist
	return best

func _within_leash(player: Node2D, target: Node2D) -> bool:
	if player == null:
		return true
	var dist = player.global_position.distance_to(target.global_position)
	return dist <= leash_radius

func _move_towards(target: Node2D, delta: float) -> void:
	var dir = (target.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()

func _orbit_player(player: Node2D, delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		return
	_orbit_angle += orbit_speed * delta * _orbit_dir
	var desired = player.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_radius
	var to_target = desired - global_position
	if to_target.length() < 6.0:
		velocity = Vector2.ZERO
	else:
		velocity = to_target.normalized() * speed
	move_and_slide()

func _attack(target: Node2D) -> void:
	if _cooldown > 0.0:
		return
	if aoe_radius > 0.0 and _game != null:
		_game.damage_enemies_in_radius(global_position, aoe_radius, aoe_damage, 1.0, damage_type)
		if _game.has_method("spawn_fx") and aoe_fx != "":
			_game.spawn_fx(aoe_fx, global_position)
	else:
		if target != null and target.has_method("take_damage"):
			target.take_damage(attack_damage, global_position, true, true, damage_type)
		if _game != null and _game.has_method("spawn_fx") and attack_fx != "":
			_game.spawn_fx(attack_fx, global_position)
	_cooldown = 1.0 / max(0.1, attack_rate)

func take_damage(amount: float, hit_position: Vector2 = Vector2.ZERO, show_hit_fx: bool = true) -> void:
	if amount <= 0.0:
		return
	health -= amount
	if show_hit_fx and _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("hit", hit_position if hit_position != Vector2.ZERO else global_position)
	if health <= 0.0:
		if _game != null and _game.has_method("spawn_fx") and death_fx != "":
			_game.spawn_fx(death_fx, global_position)
		queue_free()
