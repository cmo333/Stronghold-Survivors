extends Node2D
class_name Building

var structure_id := ""
var definition: Dictionary = {}
var tier := 0

var max_health := 40.0
var health := 40.0
var footprint_radius := 12.0
var blocks_path := true

@onready var collider_body: StaticBody2D = $Collider
@onready var collider_shape: CollisionShape2D = $Collider/CollisionShape2D

func _ready() -> void:
    add_to_group("buildings")

func configure(id: String, def: Dictionary, tier_index: int) -> void:
    structure_id = id
    definition = def
    tier = clamp(tier_index, 0, _max_tier())
    footprint_radius = float(definition.get("footprint_radius", 12))
    blocks_path = bool(definition.get("blocks_path", true))
    _apply_common()
    _apply_tier_stats(StructureDB.get_tier(definition, tier))

func _apply_common() -> void:
    if collider_body != null:
        collider_body.collision_layer = GameLayers.BUILDING if blocks_path else 0
        collider_body.collision_mask = 0
    if collider_shape != null:
        var shape := CircleShape2D.new()
        shape.radius = footprint_radius
        collider_shape.shape = shape

func _apply_tier_stats(tier_data: Dictionary) -> void:
    max_health = float(tier_data.get("health", max_health))
    health = max_health

func take_damage(amount: float) -> void:
    health -= amount
    if health <= 0.0:
        queue_free()

func heal(amount: float) -> void:
    health = min(max_health, health + amount)

func can_upgrade() -> bool:
    return tier + 1 <= _max_tier()

func get_upgrade_cost() -> int:
    if not can_upgrade():
        return 0
    var next_tier := StructureDB.get_tier(definition, tier + 1)
    return int(next_tier.get("cost", 0))

func upgrade() -> void:
    if not can_upgrade():
        return
    tier += 1
    _apply_tier_stats(StructureDB.get_tier(definition, tier))

func get_display_name() -> String:
    var name := definition.get("name", structure_id)
    return "%s (Tier %d)" % [name, tier + 1]

func get_footprint_radius() -> float:
    return footprint_radius

func _max_tier() -> int:
    var tiers := definition.get("tiers", [])
    if tiers.is_empty():
        return 0
    return tiers.size() - 1
