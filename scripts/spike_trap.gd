extends Trap

@onready var trigger_area: Area2D = $Trigger
@onready var trigger_shape: CollisionShape2D = $Trigger/CollisionShape2D
@onready var sprite: AnimatedSprite2D = $Sprite

var damage = 20.0
var pulse_radius = 56.0
var trigger_radius = 24.0
var stun_duration = 0.25
var _armed = true
var _game: Node = null

func _ready() -> void:
	_game = get_tree().get_first_node_in_group("game")
	trigger_area.collision_layer = 0
	trigger_area.collision_mask = GameLayers.ENEMY
	trigger_area.body_entered.connect(_on_body_entered)
	if sprite != null:
		sprite.stop()

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	trigger_radius = float(tier_data.get("trigger_radius", trigger_radius))
	damage = float(tier_data.get("damage", damage))
	pulse_radius = float(tier_data.get("pulse_radius", pulse_radius))
	stun_duration = float(tier_data.get("stun_duration", stun_duration))
	var shape = CircleShape2D.new()
	shape.radius = trigger_radius
	trigger_shape.shape = shape

func _on_body_entered(body: Node) -> void:
	if not _armed:
		return
	if body == null or not body.is_in_group("enemies"):
		return
	_armed = false
	if sprite != null:
		sprite.frame = 0
		sprite.play()
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.08).timeout
	if not is_inside_tree():
		return
	if _game != null:
		var radius_sq = pulse_radius * pulse_radius
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.global_position.distance_squared_to(global_position) > radius_sq:
				continue
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, enemy.global_position, false, true, "bleed")
			if enemy.has_method("stun") and stun_duration > 0.0:
				enemy.stun(stun_duration)
		if _game.has_method("spawn_fx"):
			_game.spawn_fx("chain_hit", global_position)
			_game.spawn_fx("blood", global_position)
		if _game.has_method("shake_camera"):
			_game.shake_camera(FeedbackConfig.SCREEN_SHAKE_EXPLOSION * 0.75, 0.12)
	queue_free()
