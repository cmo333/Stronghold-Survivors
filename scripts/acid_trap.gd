extends Trap

@onready var trigger_area: Area2D = $Trigger
@onready var trigger_shape: CollisionShape2D = $Trigger/CollisionShape2D
@onready var sprite: AnimatedSprite2D = $Sprite

var damage := 22.0
var explosion_radius := 80.0
var trigger_radius := 24.0
var siege_bonus := 2.0
var _armed := true
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
    explosion_radius = float(tier_data.get("explosion_radius", explosion_radius))
    siege_bonus = float(tier_data.get("siege_bonus", siege_bonus))
    var shape := CircleShape2D.new()
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
    await get_tree().create_timer(0.12).timeout
    if _game != null:
        _game.damage_enemies_in_radius(global_position, explosion_radius, damage, siege_bonus)
        if _game.has_method("spawn_fx"):
            _game.spawn_fx("acid", global_position)
    queue_free()
