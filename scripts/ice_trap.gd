extends Trap

@onready var field_area: Area2D = $Field
@onready var field_shape: CollisionShape2D = $Field/CollisionShape2D
@onready var sprite: AnimatedSprite2D = $Sprite

var field_radius := 70.0
var slow_factor := 0.55
var _source_id := 0

func _ready() -> void:
    _source_id = get_instance_id()
    field_area.collision_layer = 0
    field_area.collision_mask = GameLayers.ENEMY
    field_area.body_entered.connect(_on_body_entered)
    field_area.body_exited.connect(_on_body_exited)
    if sprite != null:
        sprite.play()

func _apply_tier_stats(tier_data: Dictionary) -> void:
    super._apply_tier_stats(tier_data)
    field_radius = float(tier_data.get("field_radius", field_radius))
    slow_factor = float(tier_data.get("slow_factor", slow_factor))
    var shape := CircleShape2D.new()
    shape.radius = field_radius
    field_shape.shape = shape

func _on_body_entered(body: Node) -> void:
    if body == null:
        return
    if body.has_method("apply_slow"):
        body.apply_slow(_source_id, slow_factor)
    if sprite != null:
        sprite.frame = 0
        sprite.play()
    if get_tree().get_first_node_in_group("game") != null:
        var game := get_tree().get_first_node_in_group("game")
        if game.has_method("spawn_fx"):
            game.spawn_fx("ice", global_position)

func _on_body_exited(body: Node) -> void:
    if body == null:
        return
    if body.has_method("remove_slow"):
        body.remove_slow(_source_id)
