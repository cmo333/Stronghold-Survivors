extends Area2D
class_name PowerUp

# Power-Up Types
enum Type {
	ANCIENT_RELIC,    # Gold glow - Maxes out one random tower to T3
	TIME_CRYSTAL,     # Cyan glow - Freezes all enemies for 5 seconds
	RESOURCE_CACHE,   # Green glow - +500 gold instantly
	BERSERK_ORB       # Red glow - Player damage ×3 for 15 seconds
}

# Configuration for each power-up type
const TYPE_CONFIG = {
	Type.ANCIENT_RELIC: {
		"name": "Ancient Relic",
		"color": Color(1.0, 0.84, 0.0),      # Gold
		"glow_color": Color(1.0, 0.9, 0.3),
		"spawn_min": 600.0,
		"spawn_max": 800.0,
		"duration": 30.0,
		"icon": "res://assets/ui/ui_icon_gold_32_v001.png"
	},
	Type.TIME_CRYSTAL: {
		"name": "Time Crystal",
		"color": Color(0.0, 0.9, 1.0),       # Cyan
		"glow_color": Color(0.3, 0.95, 1.0),
		"spawn_min": 500.0,
		"spawn_max": 700.0,
		"duration": 20.0,
		"icon": "res://assets/ui/ui_icon_crystal_32_v001.png"
	},
	Type.RESOURCE_CACHE: {
		"name": "Resource Cache",
		"color": Color(0.2, 0.9, 0.3),       # Green
		"glow_color": Color(0.4, 1.0, 0.4),
		"spawn_min": 400.0,
		"spawn_max": 600.0,
		"duration": 45.0,
		"icon": "res://assets/ui/ui_icon_gold_32_v001.png"
	},
	Type.BERSERK_ORB: {
		"name": "Berserk Orb",
		"color": Color(1.0, 0.2, 0.2),       # Red
		"glow_color": Color(1.0, 0.4, 0.3),
		"spawn_min": 700.0,
		"spawn_max": 900.0,
		"duration": 25.0,
		"icon": "res://assets/ui/ui_icon_fire_32_v001.png"
	}
}

# Node references
@onready var body: Sprite2D = $Body
@onready var glow: Sprite2D = $Glow
@onready var beacon: Sprite2D = $Beacon
@onready var collision: CollisionShape2D = $CollisionShape2D

# State
var power_up_type: Type = Type.RESOURCE_CACHE
var _game: Node = null
var _player: Node2D = null
var _lifetime: float = 30.0
var _time_alive: float = 0.0
var _collected: bool = false
var _bob_offset: float = 0.0
var _bob_speed: float = 2.5
var _bob_height: float = 8.0
var _base_y: float = 0.0
var _beacon_rotation_speed: float = 30.0
var _particle_timer: float = 0.0
var _particle_interval: float = 0.15

func _ready() -> void:
	add_to_group("powerups")
	collision_layer = GameLayers.PICKUP
	collision_mask = GameLayers.PLAYER
	body_entered.connect(_on_body_entered)
	
	_player = get_tree().get_first_node_in_group("player")
	_game = get_tree().get_first_node_in_group("game")
	
	_base_y = global_position.y
	_bob_offset = randf() * TAU  # Random starting phase
	
	_apply_visuals()
	_start_glow_pulse()

func setup(game_ref: Node, type: Type, position: Vector2) -> void:
	_game = game_ref
	power_up_type = type
	global_position = position
	_base_y = position.y
	
	var config = TYPE_CONFIG.get(type, TYPE_CONFIG[Type.RESOURCE_CACHE])
	_lifetime = config.duration

func _process(delta: float) -> void:
	if _collected:
		return
	
	# Update lifetime
	_time_alive += delta
	if _time_alive >= _lifetime:
		_despawn()
		return
	
	# Floating animation (bob up/down)
	var bob = sin(_time_alive * _bob_speed + _bob_offset) * _bob_height
	global_position.y = _base_y + bob
	
	# Rotate beacon
	if beacon != null:
		beacon.rotation_degrees += _beacon_rotation_speed * delta
	
	# Spawn trail particles going to sky
	_particle_timer += delta
	if _particle_timer >= _particle_interval:
		_particle_timer = 0.0
		_spawn_trail_particle()
	
	# Visual warning when about to expire (last 5 seconds)
	var time_remaining = _lifetime - _time_alive
	if time_remaining <= 5.0:
		_blink_warning(time_remaining, delta)

func _on_body_entered(body_node: Node) -> void:
	if body_node.is_in_group("player") and not _collected:
		_collect(body_node)

func _collect(player: Node2D) -> void:
	_collected = true
	
	# Audio: Powerup pickup sound
	AudioManager.play_one_shot("powerup_pickup", global_position, AudioManager.HIGH_PRIORITY)
	
	# Spawn collection burst effect
	_spawn_collection_burst()
	
	# Apply effect based on type
	_apply_effect(player)
	
	# Show floating text
	if _game != null and _game.has_method("show_floating_text"):
		var config = TYPE_CONFIG.get(power_up_type, TYPE_CONFIG[Type.RESOURCE_CACHE])
		_game.show_floating_text(config.name, global_position + Vector2(0, -40), config.color)
	
	queue_free()

func _apply_effect(player: Node2D) -> void:
	if _game == null:
		return
	
	match power_up_type:
		Type.ANCIENT_RELIC:
			_apply_ancient_relic()
		Type.TIME_CRYSTAL:
			_apply_time_crystal()
		Type.RESOURCE_CACHE:
			_apply_resource_cache()
		Type.BERSERK_ORB:
			_apply_berserk_orb(player)

func _apply_ancient_relic() -> void:
	# Find all towers and upgrade one random tower to T3
	var towers: Array = []
	for building in get_tree().get_nodes_in_group("buildings"):
		if building is Tower:
			towers.append(building)
	
	if towers.is_empty():
		# No towers - give gold instead
		if _game.has_method("add_resources"):
			_game.add_resources(200)
		return
	
	# Pick random tower
	var target_tower = towers[randi_range(0, towers.size() - 1)]
	
	# Upgrade to T3 (tier 2, since tiers are 0-indexed)
	if target_tower.has_method("can_upgrade"):
		while target_tower.can_upgrade() and target_tower.tier < 2:
			target_tower.upgrade()
	
	# Visual effect at tower location
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("build", target_tower.global_position)
		_game.spawn_fx("holy_burst", target_tower.global_position)
	
	# Screen shake and flash
	if _game.has_method("shake_camera"):
		_game.shake_camera(5.0)
	if _game.has_method("flash_screen"):
		_game.flash_screen(Color(1.0, 0.9, 0.3, 0.3), 0.3)

func _apply_time_crystal() -> void:
	# Freeze all enemies for 5 seconds
	var frozen_count = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("stun"):
			enemy.stun(5.0)
			frozen_count += 1
	
	# Visual effects
	if _game.has_method("spawn_fx"):
		for i in range(3):
			var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
			_game.spawn_fx("ice", global_position + offset)
	
	# Screen effect - time dilation visual
	if _game.has_method("flash_screen"):
		_game.flash_screen(Color(0.3, 0.95, 1.0, 0.4), 0.5)
	
	# Show frozen count
	if frozen_count > 0 and _game.has_method("show_floating_text"):
		_game.show_floating_text("Frozen %d!" % frozen_count, global_position + Vector2(0, -60), Color(0.3, 0.95, 1.0))

func _apply_resource_cache() -> void:
	# +500 gold instantly
	if _game.has_method("add_resources"):
		_game.add_resources(500)
	
	# Visual effects
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("elite_kill", global_position)
	
	# Gold burst particles
	if _game.has_method("spawn_glow_particle"):
		for i in range(20):
			var angle = (TAU / 20.0) * i
			var dir = Vector2.RIGHT.rotated(angle)
			var vel = dir * randf_range(80.0, 200.0)
			_game.spawn_glow_particle(global_position, Color(1.0, 0.9, 0.3), randf_range(10.0, 18.0), 0.8, vel, 2.5, 0.7, 1.0, 5)

func _apply_berserk_orb(player: Node2D) -> void:
	# Player damage ×3 for 15 seconds
	if player.has_method("apply_berserk_buff"):
		player.apply_berserk_buff(3.0, 15.0)
	
	# Visual effects
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("fire", global_position)
		_game.spawn_fx("summon_fire", global_position)
	
	# Screen flash red
	if _game.has_method("flash_screen"):
		_game.flash_screen(Color(1.0, 0.3, 0.2, 0.4), 0.4)
	
	# Screen shake
	if _game.has_method("shake_camera"):
		_game.shake_camera(8.0)

func _spawn_trail_particle() -> void:
	if _game == null or not _game.has_method("spawn_glow_particle"):
		return
	
	var config = TYPE_CONFIG.get(power_up_type, TYPE_CONFIG[Type.RESOURCE_CACHE])
	var color = config.glow_color
	
	# Spawn particle that floats upward
	var start_pos = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	var vel = Vector2(0, -randf_range(30.0, 60.0))  # Upward velocity
	
	_game.spawn_glow_particle(start_pos, color, randf_range(4.0, 8.0), 0.6, vel, 1.5, 0.6, 0.8, 2)

func _spawn_collection_burst() -> void:
	if _game == null:
		return
	
	var config = TYPE_CONFIG.get(power_up_type, TYPE_CONFIG[Type.RESOURCE_CACHE])
	var color = config.glow_color
	
	# Glow burst
	if _game.has_method("_spawn_glow_burst"):
		_game._spawn_glow_burst(global_position, color, 16, 12.0, 0.6, 180.0, 2.0)
	
	# Additional particles
	if _game.has_method("spawn_glow_particle"):
		for i in range(24):
			var angle = (TAU / 24.0) * i
			var dir = Vector2.RIGHT.rotated(angle)
			var vel = dir * randf_range(100.0, 250.0)
			_game.spawn_glow_particle(global_position, color, randf_range(10.0, 20.0), 1.0, vel, 3.0, 0.8, 1.2, 5)
	
	# Shockwave ring
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("shockwave", global_position)

func _blink_warning(time_remaining: float, delta: float) -> void:
	# Blink faster as time runs out
	var blink_rate = 0.3 if time_remaining > 2.0 else 0.15
	var blink = fmod(time_remaining, blink_rate * 2) < blink_rate
	
	if body != null:
		body.modulate.a = 1.0 if blink else 0.4
	if glow != null:
		glow.modulate.a = (0.8 if blink else 0.2)

func _despawn() -> void:
	# Fade out and despawn
	if not is_inside_tree():
		return
	var tween = create_tween()
	if body != null:
		tween.tween_property(body, "modulate:a", 0.0, 0.5)
	if glow != null:
		tween.parallel().tween_property(glow, "modulate:a", 0.0, 0.5)
	if beacon != null:
		tween.parallel().tween_property(beacon, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _apply_visuals() -> void:
	var config = TYPE_CONFIG.get(power_up_type, TYPE_CONFIG[Type.RESOURCE_CACHE])
	
	# Load and set icon texture
	if body != null:
		var texture_path = config.icon
		if ResourceLoader.exists(texture_path):
			body.texture = load(texture_path)
		body.modulate = config.color
		body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Set glow color
	if glow != null:
		glow.modulate = config.glow_color
		glow.modulate.a = 0.5

func _start_glow_pulse() -> void:
	if glow == null:
		return
	if not is_inside_tree():
		return
	if not glow.is_inside_tree():
		return
	
	# Add additive blend mode for glow effect
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	
	# Pulse animation
	var base_scale = glow.scale
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(glow, "scale", base_scale * 1.3, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(glow, "modulate:a", 0.8, 0.8)
	tween.tween_property(glow, "scale", base_scale, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(glow, "modulate:a", 0.4, 0.8)

# Static helper functions
static func get_spawn_distance(type: Type) -> Dictionary:
	var config = TYPE_CONFIG.get(type, TYPE_CONFIG[Type.RESOURCE_CACHE])
	return {
		"min": config.spawn_min,
		"max": config.spawn_max
	}

static func get_random_type() -> Type:
	var roll = randf()
	if roll < 0.35:
		return Type.RESOURCE_CACHE    # 35% - most common
	elif roll < 0.60:
		return Type.TIME_CRYSTAL      # 25%
	elif roll < 0.80:
		return Type.ANCIENT_RELIC     # 20%
	else:
		return Type.BERSERK_ORB       # 20% - rarest
