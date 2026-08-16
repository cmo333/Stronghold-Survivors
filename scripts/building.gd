extends Node2D
class_name Building

var structure_id = ""
var definition: Dictionary = {}
var tier = 0

# Multiplayer ownership. Solo: stays 1 (no effect). FFA: the builder's peer_id.
# When that player dies or leaves, the host sets `inert = true` so this building
# stops firing / generating income (see tower.gd / resource_generator.gd).
var owner_id: int = 1
var inert: bool = false

var max_health = 40.0
var health = 40.0
var footprint_radius = 12.0
var blocks_path = true
const MIN_FOOTPRINT_RADIUS = 16.0

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
	if blocks_path:
		footprint_radius = max(footprint_radius, MIN_FOOTPRINT_RADIUS)
	_apply_common()
	_apply_tier_stats(StructureDB.get_tier(definition, tier))

func _apply_common() -> void:
	if collider_body != null:
		collider_body.collision_layer = GameLayers.BUILDING if blocks_path else 0
		collider_body.collision_mask = 0
	if collider_shape != null:
		var shape = RectangleShape2D.new()
		shape.size = Vector2(footprint_radius * 2.0, footprint_radius * 2.0)
		collider_shape.shape = shape
	# Wider than the footprint and dropped to the base of the art, otherwise the
	# building covers its own shadow completely and nothing reads as grounded.
	ContactShadow.attach(self, footprint_radius * 3.8, 0.42, footprint_radius * 0.85)

func _apply_tier_stats(tier_data: Dictionary) -> void:
	max_health = float(tier_data.get("health", max_health))
	health = max_health

func take_damage(amount: float) -> void:
	var game_node = get_tree().get_first_node_in_group("game")
	if game_node != null and game_node.has_method("is_damage_blocked") and game_node.is_damage_blocked():
		return
	health -= amount
	if health <= 0.0:
		if game_node != null and game_node.has_method("shake_camera"):
			game_node.shake_camera(FeedbackConfig.SCREEN_SHAKE_BUILDING_DESTROY)
		queue_free()

func heal(amount: float) -> void:
	health = min(max_health, health + amount)

func can_upgrade() -> bool:
	return tier + 1 <= _max_tier()

func get_upgrade_cost() -> int:
	if not can_upgrade():
		return 0
	var next_tier = StructureDB.get_tier(definition, tier + 1)
	return int(next_tier.get("cost", 0))

# Essence price of the NEXT tier, if that tier declares one.
#
# build_manager and ui already look for this method on any selected building and
# already gate the purchase on it (build_manager.gd:501, ui.gd:527) -- until now
# only tower.gd answered, so essence was effectively tower-only. Reading it off
# the tier data means any structure can charge essence by adding one key, and
# every structure that does not declare one is unchanged at 0.
func get_upgrade_essence_cost() -> int:
	if not can_upgrade():
		return 0
	var next_tier = StructureDB.get_tier(definition, tier + 1)
	return int(next_tier.get("essence_cost", 0))


# What the player HAS and what they WOULD GET, as the building will actually
# have them.
#
# The upgrade panel used to read tier_data["damage"] straight out of
# structures.json and print it. For every structure but a tower that is correct.
# For a tower it is not: _apply_tier_stats multiplies damage, range and fire
# rate by ESSENCE_INFUSION_*_MULT afterwards, so the panel advertised a T3
# upgrade at 1/1.65 of the damage it delivers and a 500-gold purchase read as a
# worse deal than it was.
#
# The fix is this method rather than the same multiply repeated in ui.gd. A UI
# that re-derives a transformation the model owns is a second copy of it, and
# the two drift the moment one changes -- which is precisely how the panel got
# out of step to begin with. The UI asks; the building answers.
func get_upgrade_preview() -> Dictionary:
	var out := {"current": {}, "next": {}}
	out["current"] = _preview_stats(StructureDB.get_tier(definition, tier), tier)
	if can_upgrade():
		out["next"] = _preview_stats(StructureDB.get_tier(definition, tier + 1), tier + 1)
	return out


# Base implementation is the tier data verbatim, which is right for every
# structure that does not transform it. tower.gd overrides.
func _preview_stats(tier_data: Dictionary, _tier_index: int) -> Dictionary:
	return {
		"damage": float(tier_data.get("damage", 0.0)),
		"range": float(tier_data.get("range", 0.0)),
		"fire_rate": float(tier_data.get("fire_rate", 0.0)),
	}

func upgrade() -> void:
	if not can_upgrade():
		return
	tier += 1
	_apply_tier_stats(StructureDB.get_tier(definition, tier))
	# Notify subclasses that upgrade occurred (for visual updates)
	_on_upgraded()

func get_display_name() -> String:
	var name = definition.get("name", structure_id)
	return "%s (Tier %d)" % [name, tier + 1]

func get_footprint_radius() -> float:
	return footprint_radius

func _max_tier() -> int:
	var tiers = definition.get("tiers", [])
	if tiers.is_empty():
		return 0
	return tiers.size() - 1

# Called after upgrade is applied - override in subclasses for visual effects
func _on_upgraded() -> void:
	pass

func get_sell_value() -> int:
	var total_cost = 0
	var tiers = definition.get("tiers", [])
	for i in range(tier + 1):
		if i < tiers.size():
			total_cost += int(tiers[i].get("cost", 0))
	return int(total_cost * 0.75)

func sell() -> void:
	var game_node = get_tree().get_first_node_in_group("game")
	if game_node != null:
		var refund = get_sell_value()
		game_node.add_resources(refund)
		if game_node.has_method("show_floating_text"):
			game_node.show_floating_text("+%d" % refund, global_position + Vector2(0, -30), Color(1.0, 0.9, 0.3))
	queue_free()

func _exit_tree() -> void:
	var game_node = get_tree().get_first_node_in_group("game")
	if game_node != null and game_node.has_method("mark_flow_field_dirty"):
		game_node.mark_flow_field_dirty()
