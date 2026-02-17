extends "res://scripts/boss_base.gd"

# Boss 3: Siegebreaker (Wave 15)
# A heavily armored siege unit that targets generators and fires mortar shots

@export var mortar_cooldown: float = 4.0
@export var mortar_damage: float = 60.0
@export var mortar_radius: float = 60.0
@export var mortar_range: float = 400.0
@export var shield_health: float = 3000.0
@export var shield_regen_delay: float = 8.0
@export var shield_regen_rate: float = 150.0

var _mortar_timer: float = 0.0
var _current_shield: float = 0.0
var _max_shield: float = 0.0
var _shield_broken: bool = false
var _shield_regen_timer: float = 0.0
var _target_generator: Node = null

# Visual nodes
var _shield_visual: Sprite2D = null

func _ready() -> void:
	boss_name = "Siegebreaker"
	boss_title = "The Wall Crusher"
	boss_wave = 15
	boss_color = Color(0.9, 0.3, 0.2)
	
	# Siegebreaker stats
	max_health = 10000.0
	health = max_health
	speed = 45.0  # Very slow
	attack_damage = 40.0
	attack_rate = 0.6
	attack_range = 50.0
	
	# Shield setup
	_max_shield = shield_health
	_current_shield = _max_shield
	
	super._ready()

func setup(game_ref: Node, difficulty: float) -> void:
	# Shield scales with difficulty more than health
	var shield_mult = 1.0 + (difficulty - 1.0) * 0.8
	_max_shield = shield_health * shield_mult
	_current_shield = _max_shield
	
	super.setup(game_ref, difficulty)
	
	# Create shield visual
	_create_shield_visual()

func _create_shield_visual() -> void:
	"""Create the energy shield visual"""
	_shield_visual = Sprite2D.new()
	_shield_visual.name = "ShieldVisual"
	_shield_visual.texture = preload("res://assets/ui/ui_selection_ring_64x64_v001.png")
	_shield_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shield_visual.z_index = 1
	
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_shield_visual.material = mat
	
	# Scale to cover the boss
	_shield_visual.scale = Vector2.ONE * 4.0
	_shield_visual.modulate = Color(0.3, 0.6, 1.0, 0.5)
	
	add_child(_shield_visual)
	
	# Pulse animation
	_start_shield_pulse()

func _start_shield_pulse() -> void:
	if _shield_visual == null or not is_instance_valid(_shield_visual):
		return
	if not is_inside_tree() or not _shield_visual.is_inside_tree():
		return
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(_shield_visual, "scale", Vector2.ONE * 4.2, 1.0).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_shield_visual, "modulate:a", 0.7, 1.0)
	tween.tween_property(_shield_visual, "scale", Vector2.ONE * 3.8, 1.0).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_shield_visual, "modulate:a", 0.4, 1.0)

func _boss_behavior(delta: float) -> void:
	# Update timers
	_mortar_timer -= delta
	
	# Shield regen logic
	_update_shield(delta)
	
	# Find target - prioritize generators
	var target = _find_siege_target()
	if target == null or not is_instance_valid(target):
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	# Mortar attack on generators/player from range
	if _mortar_timer <= 0.0 and dist <= mortar_range:
		_fire_mortar(target.global_position)
		_mortar_timer = mortar_cooldown
	
	# Move toward target
	var dir = (target.global_position - global_position).normalized()
	velocity = dir * speed * _slow_multiplier
	move_and_slide()
	
	# Melee attack if close
	if dist <= attack_range and _attack_cooldown <= 0.0:
		_perform_attack(target)
		_attack_cooldown = 1.0 / max(0.1, attack_rate)
	
	_attack_cooldown = max(0.0, _attack_cooldown - delta)

func _find_siege_target() -> Node2D:
	"""Find target - generators highest priority, then player"""
	if _game == null:
		return null
	
	# Look for active generators first
	var generators = get_tree().get_nodes_in_group("buildings")
	var best_generator = null
	var best_dist = INF
	
	for building in generators:
		if building == null or not is_instance_valid(building):
			continue
		if not building is preload("res://scripts/resource_generator.gd"):
			continue
		if building.has_method("is_destroyed") and building.is_destroyed():
			continue
		
		var dist = global_position.distance_squared_to(building.global_position)
		if dist < best_dist:
			best_dist = dist
			best_generator = building
	
	if best_generator != null:
		return best_generator
	
	# Fall back to player
	if _game.player != null and is_instance_valid(_game.player):
		return _game.player
	
	return null

func _fire_mortar(target_pos: Vector2) -> void:
	"""Fire a mortar projectile at target position"""
	if _game == null:
		return
	
	# Create mortar projectile
	var mortar = _create_mortar_projectile(target_pos)
	if mortar != null:
		if _game.has_node("World/Projectiles"):
			_game.get_node("World/Projectiles").add_child(mortar)
	
	# FX
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("fire", global_position)
	
	AudioManager.play_sound("mortar_fire", global_position, 1.0, 0.0, true)

func _create_mortar_projectile(target_pos: Vector2) -> Node:
	"""Create mortar projectile that arcs to target"""
	# Use existing projectile as base or create new
	var mortar = preload("res://scenes/enemy_projectile.tscn").instantiate()
	mortar.global_position = global_position
	
	# Calculate direction and setup
	var dir = (target_pos - global_position).normalized()
	var dist = global_position.distance_to(target_pos)
	
	if mortar.has_method("setup"):
		# Slower speed for arcing mortar
		mortar.setup(_game, dir, 180.0, mortar_damage, dist * 1.2)
	
	# Connect to explode on impact
	mortar.body_entered.connect(_on_mortar_impact.bind(mortar, target_pos))
	
	return mortar

func _on_mortar_impact(body: Node, mortar: Node, impact_pos: Vector2) -> void:
	"""Handle mortar impact explosion"""
	# Explosion at mortar position
	var explosion_pos = mortar.global_position
	
	# Visual FX
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("crit", explosion_pos)
		_game.spawn_fx("fire", explosion_pos)
	
	AudioManager.play_sound("explosion", explosion_pos, 0.9)
	
	# AOE damage
	_apply_mortar_damage(explosion_pos)
	
	# Destroy mortar
	if is_instance_valid(mortar):
		mortar.queue_free()

func _apply_mortar_damage(center: Vector2) -> void:
	"""Apply AOE damage from mortar explosion"""
	var radius_sq = mortar_radius * mortar_radius
	
	# Damage player
	if _game != null and _game.player != null and is_instance_valid(_game.player):
		var dist_sq = center.distance_squared_to(_game.player.global_position)
		if dist_sq <= radius_sq:
			var damage_mult = 1.0 - (sqrt(dist_sq) / mortar_radius) * 0.6
			if _game.player.has_method("take_damage"):
				_game.player.take_damage(mortar_damage * damage_mult, center, true)
	
	# Damage buildings
	for building in get_tree().get_nodes_in_group("buildings"):
		if building == null or not is_instance_valid(building):
			continue
		var dist_sq = center.distance_squared_to(building.global_position)
		if dist_sq <= radius_sq:
			var damage_mult = 1.0 - (sqrt(dist_sq) / mortar_radius) * 0.6
			if building.has_method("take_damage"):
				building.take_damage(mortar_damage * damage_mult * 1.5)  # Extra damage to buildings

func _update_shield(delta: float) -> void:
	"""Update shield state and regen"""
	if _shield_broken:
		_shield_regen_timer -= delta
		if _shield_regen_timer <= 0.0:
			# Restore shield
			_shield_broken = false
			_current_shield = _max_shield * 0.25  # Start at 25%
			if _shield_visual != null:
				_shield_visual.visible = true
			AudioManager.play_sound("shield_restore", global_position, 0.8)
	else:
		# Regenerate shield if not at max
		if _current_shield < _max_shield:
			_current_shield = min(_max_shield, _current_shield + shield_regen_rate * delta)
	
	# Update visual
	if _shield_visual != null:
		var shield_percent = _current_shield / _max_shield
		_shield_visual.modulate.a = 0.3 + shield_percent * 0.4

func take_damage(amount: float, hit_position: Vector2 = Vector2.ZERO, show_hit_fx: bool = true, show_damage_number: bool = true, damage_type: String = "normal") -> void:
	"""Override damage to handle shield"""
	if not is_boss_active or _is_dying:
		return
	
	# Tesla/lightning bypasses shield
	if damage_type == "lightning" or damage_type == "tesla":
		# Full damage bypasses shield
		super.take_damage(amount, hit_position, show_hit_fx, show_damage_number, damage_type)
		return
	
	# Shield absorbs damage
	if _current_shield > 0 and not _shield_broken:
		var shield_absorb = min(_current_shield, amount)
		_current_shield -= shield_absorb
		amount -= shield_absorb
		
		# Shield hit FX
		if _game != null and _game.has_method("spawn_fx"):
			_game.spawn_fx("tesla", hit_position)
		
		# Shield break check
		if _current_shield <= 0:
			_shield_broken = true
			_shield_regen_timer = shield_regen_delay
			if _shield_visual != null:
				_shield_visual.visible = false
			AudioManager.play_sound("shield_break", global_position, 1.0, 0.0, true)
			
			# Shield break FX
			if _game != null and _game.camera != null and _game.camera.has_method("shake"):
				_game.camera.shake(5.0, 0.3)
		
		# Show absorbed damage number
		if show_damage_number and _game != null and _game.has_method("spawn_damage_number"):
			_game.spawn_damage_number(shield_absorb, hit_position, _max_shield, false, false, false, "shield")
	
	# Remaining damage goes to health
	if amount > 0:
		super.take_damage(amount, hit_position, show_hit_fx, show_damage_number, damage_type)

func _perform_attack(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, global_position, true, true, "normal")
	
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("hit", global_position)
	
	AudioManager.play_sound("heavy_hit", global_position, 0.9)

func get_shield_percent() -> float:
	return _current_shield / _max_shield if _max_shield > 0 else 0.0

func get_weakness_description() -> String:
	return "WEAKNESS: Tesla towers (lightning bypasses shield)"
