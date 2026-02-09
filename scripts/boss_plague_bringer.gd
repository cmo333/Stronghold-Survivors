extends "res://scripts/boss_base.gd"

# Boss 2: Plague Bringer (Wave 10)
# A flying pestilent horror that spawns adds and creates poison clouds

@export var poison_cloud_cooldown: float = 5.0
@export var poison_cloud_duration: float = 8.0
@export var poison_cloud_radius: float = 80.0
@export var poison_damage_per_sec: float = 15.0
@export var spawn_adds_cooldown: float = 8.0
@export var max_adds: int = 6
@export var fly_height: float = 0.0  # Visual only

var _poison_timer: float = 0.0
var _spawn_timer: float = 0.0
var _active_clouds: Array = []
var _active_adds: Array = []

# Flying - ignores walls and obstacles
var is_flying: bool = true

func _ready() -> void:
	boss_name = "Plague Bringer"
	boss_title = "Winged Pestilence"
	boss_wave = 10
	boss_color = Color(0.4, 0.85, 0.3)
	
	# Plague Bringer stats
	max_health = 5000.0
	health = max_health
	speed = 75.0  # Fast flyer
	attack_damage = 20.0
	attack_rate = 1.2
	attack_range = 40.0
	
	# Flying enemies ignore terrain collisions
	collision_mask = GameLayers.PLAYER | GameLayers.ALLY  # Don't collide with buildings
	
	super._ready()

func _boss_behavior(delta: float) -> void:
	# Update timers
	_poison_timer -= delta
	_spawn_timer -= delta
	
	# Clean up dead adds from tracking
	_cleanup_adds()
	_cleanup_clouds()
	
	# Find target
	var target = _find_target()
	if target == null or not is_instance_valid(target):
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	# Spawn adds if below max
	if _spawn_timer <= 0.0 and _active_adds.size() < max_adds:
		_spawn_adds()
		_spawn_timer = spawn_adds_cooldown
	
	# Drop poison cloud
	if _poison_timer <= 0.0:
		_drop_poison_cloud()
		_poison_timer = poison_cloud_cooldown
	
	# Movement - orbit around target while staying in range
	var orbit_dir = _calculate_orbit_direction(target.global_position)
	velocity = orbit_dir * speed * _slow_multiplier
	move_and_slide()
	
	# Attack if in range
	if dist <= attack_range and _attack_cooldown <= 0.0:
		_perform_attack(target)
		_attack_cooldown = 1.0 / max(0.1, attack_rate)
	
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	
	# Apply poison to nearby targets
	_apply_poison_aura(delta)

func _calculate_orbit_direction(target_pos: Vector2) -> Vector2:
	"""Calculate orbital movement direction around target"""
	var to_target = target_pos - global_position
	var dist = to_target.length()
	
	# Desired orbit distance
	var orbit_distance = 150.0
	
	var dir: Vector2
	if dist > orbit_distance * 1.2:
		# Move closer
		dir = to_target.normalized()
	elif dist < orbit_distance * 0.8:
		# Move away
		dir = -to_target.normalized()
	else:
		# Orbit - perpendicular to target direction
		var perpendicular = Vector2(-to_target.y, to_target.x).normalized()
		# Randomize orbit direction occasionally
		if randf() < 0.01:
			perpendicular = -perpendicular
		dir = perpendicular
	
	return dir

func _perform_attack(target: Node2D) -> void:
	if target.has_method("take_damage"):
		# Plague attacks apply poison damage over time
		target.take_damage(attack_damage, global_position, true, true, "poison")
		
		# Apply poison DOT if target has the method
		if target.has_method("apply_poison"):
			target.apply_poison(poison_damage_per_sec, 3.0)
	
	# Attack FX
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("poison", global_position)
	
	AudioManager.play_sound("poison_hit", global_position, 0.7)

func _spawn_adds() -> void:
	"""Spawn plague minions"""
	var spawn_count = randi_range(1, 2)
	
	for i in range(spawn_count):
		if _active_adds.size() >= max_adds:
			break
		
		var angle = randf() * TAU
		var offset = Vector2.RIGHT.rotated(angle) * randf_range(30.0, 60.0)
		var spawn_pos = global_position + offset
		
		# Spawn a smaller plague creature
		var add = _create_plague_add(spawn_pos)
		if add != null:
			_active_adds.append(add)
	
	# Spawn FX
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("summon_shadow", global_position)
		_game.spawn_fx("poison", global_position)
	
	AudioManager.play_sound("summon", global_position, 0.6)

func _create_plague_add(spawn_pos: Vector2) -> Node:
	"""Create a plague add - use existing enemy scene with modified stats"""
	if _game == null or _game.enemies_root == null:
		return null
	
	# Use existing enemy scene as base
	var add_scene = preload("res://scenes/enemy.tscn")
	var add = add_scene.instantiate()
	add.global_position = spawn_pos
	
	if add.has_method("setup"):
		add.setup(_game, 1.0)
	
	# Modify stats for plague add
	add.max_health = 30.0
	add.health = 30.0
	add.speed = 90.0
	add.attack_damage = 8.0
	add.attack_rate = 1.5
	
	# Visual tint
	if add.has_node("Body"):
		add.get_node("Body").modulate = Color(0.4, 0.9, 0.3)
	
	_game.enemies_root.add_child(add)
	return add

func _drop_poison_cloud() -> void:
	"""Drop a lingering poison cloud at current position"""
	if _game == null:
		return
	
	var cloud = _create_poison_cloud(global_position)
	if cloud != null:
		_active_clouds.append(cloud)
	
	# FX
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("poison", global_position)
		_game.spawn_fx("necrotic", global_position)

func _create_poison_cloud(pos: Vector2) -> Node:
	"""Create poison cloud effect and damage zone"""
	var cloud = Node2D.new()
	cloud.global_position = pos
	cloud.z_index = -3
	
	# Visual - using sprite
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/fx/fx_poison_cloud_64_f001_v001.png")
	sprite.modulate = Color(0.3, 0.9, 0.2, 0.6)
	sprite.scale = Vector2.ONE * (poison_cloud_radius / 32.0)
	cloud.add_child(sprite)
	
	# Add to world
	if _game.has_node("World/FX"):
		_game.get_node("World/FX").add_child(cloud)
	else:
		_game.add_child(cloud)
	
	# Animate and destroy after duration
	var tween = create_tween()
	tween.tween_interval(poison_cloud_duration)
	tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
	tween.tween_callback(cloud.queue_free)
	
	return cloud

func _apply_poison_aura(delta: float) -> void:
	"""Apply poison damage to targets in poison clouds"""
	var damage_this_frame = poison_damage_per_sec * delta
	
	# Check all clouds
	for cloud in _active_clouds:
		if cloud == null or not is_instance_valid(cloud):
			continue
		
		var cloud_pos = cloud.global_position
		var radius_sq = poison_cloud_radius * poison_cloud_radius
		
		# Damage player
		if _game != null and _game.player != null and is_instance_valid(_game.player):
			if cloud_pos.distance_squared_to(_game.player.global_position) <= radius_sq:
				if _game.player.has_method("take_damage"):
					_game.player.take_damage(damage_this_frame, cloud_pos, false, false, "poison")
				if _game.player.has_method("apply_slow"):
					_game.player.apply_slow(hash(self), 0.7, 0.5)
		
		# Damage allies
		for ally in get_tree().get_nodes_in_group("allies"):
			if ally == null or not is_instance_valid(ally):
				continue
			if cloud_pos.distance_squared_to(ally.global_position) <= radius_sq:
				if ally.has_method("take_damage"):
					ally.take_damage(damage_this_frame, cloud_pos, false, false, "poison")

func _cleanup_adds() -> void:
	"""Remove dead adds from tracking"""
	var valid_adds: Array = []
	for add in _active_adds:
		if add != null and is_instance_valid(add):
			if "_is_dying" in add and not add._is_dying:
				valid_adds.append(add)
	_active_adds = valid_adds

func _cleanup_clouds() -> void:
	"""Remove destroyed clouds from tracking"""
	var valid_clouds: Array = []
	for cloud in _active_clouds:
		if cloud != null and is_instance_valid(cloud):
			valid_clouds.append(cloud)
	_active_clouds = valid_clouds

func _start_death_sequence() -> void:
	"""Death - clear all adds and clouds"""
	# Kill remaining adds
	for add in _active_adds:
		if add != null and is_instance_valid(add) and add.has_method("take_damage"):
			add.take_damage(9999, global_position, false, false)
	
	super._start_death_sequence()

func get_weakness_description() -> String:
	return "WEAKNESS: Sniper towers (piercing shots)"
