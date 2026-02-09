extends "res://scripts/boss_base.gd"

# Boss 4: The Lich (Wave 20)
# An undead sorcerer that teleports, summons skeletons, and casts death nova

@export var teleport_cooldown: float = 6.0
@export var teleport_range_min: float = 150.0
@export var teleport_range_max: float = 300.0
@export var death_nova_cooldown: float = 10.0
@export var death_nova_damage: float = 80.0
@export var death_nova_radius: float = 200.0
@export var summon_cooldown: float = 5.0
@export var max_skeletons: int = 8
@export var phase_2_health_threshold: float = 0.5

var _teleport_timer: float = 0.0
var _nova_timer: float = 0.0
var _summon_timer: float = 0.0
var _active_skeletons: Array = []
var _is_teleporting: bool = false

# Phase 2 modifiers
var _phase_2_active: bool = false
var _phase_2_speed_mult: float = 1.4
var _phase_2_damage_mult: float = 1.5

func _ready() -> void:
	boss_name = "The Lich"
	boss_title = "Lord of the Dead"
	boss_wave = 20
	boss_color = Color(0.6, 0.2, 0.9)
	
	# Lich stats
	max_health = 20000.0
	health = max_health
	speed = 60.0
	attack_damage = 35.0
	attack_rate = 1.0
	attack_range = 120.0  # Ranged magic attack
	
	_max_phases = 2
	
	super._ready()

func _boss_behavior(delta: float) -> void:
	# Update timers
	_teleport_timer -= delta
	_nova_timer -= delta
	_summon_timer -= delta
	
	# Clean up dead skeletons
	_cleanup_skeletons()
	
	# Check for Phase 2 transition
	if not _phase_2_active and get_health_percent() <= phase_2_health_threshold:
		_enter_phase_2()
	
	# Don't act while teleporting
	if _is_teleporting:
		return
	
	var target = _find_target()
	if target == null or not is_instance_valid(target):
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	# Teleport if too close or cooldown ready and at comfortable range
	if _teleport_timer <= 0.0:
		if dist < 100.0 or (dist > 200.0 and randf() < 0.3):
			_teleport_away()
			return
	
	# Cast Death Nova
	if _nova_timer <= 0.0 and dist <= death_nova_radius * 0.8:
		_cast_death_nova()
		return
	
	# Summon skeletons
	if _summon_timer <= 0.0 and _active_skeletons.size() < max_skeletons:
		_summon_skeleton_army()
		return
	
	# Magic attack (ranged)
	if dist <= attack_range and _attack_cooldown <= 0.0:
		_cast_magic_missile(target)
		_attack_cooldown = 1.0 / max(0.1, attack_rate)
	elif dist > attack_range:
		# Move to optimal range
		var dir = (target.global_position - global_position).normalized()
		if dist < attack_range * 0.7:
			dir = -dir  # Back away if too close
		velocity = dir * speed * _slow_multiplier
		move_and_slide()
	
	_attack_cooldown = max(0.0, _attack_cooldown - delta)

func _enter_phase_2() -> void:
	"""Activate Phase 2 - faster, stronger, more aggressive"""
	_phase_2_active = true
	_phase = 2
	
	# Stat boosts
	speed *= _phase_2_speed_mult
	attack_damage *= _phase_2_damage_mult
	attack_rate *= 1.3
	
	# Reduce cooldowns
	teleport_cooldown *= 0.7
	death_nova_cooldown *= 0.75
	summon_cooldown *= 0.6
	
	# Visual transformation
	if body != null:
		var tween = create_tween()
		tween.tween_property(body, "modulate", Color(1.0, 0.3, 0.5), 0.5)
		tween.tween_property(body, "scale", body.scale * 1.1, 0.3)
	
	# FX
	if _game != null and _game.has_method("spawn_fx"):
		for i in range(8):
			var angle = (TAU / 8.0) * i
			var offset = Vector2.RIGHT.rotated(angle) * 60.0
			_game.spawn_fx("necrotic", global_position + offset)
		_game.spawn_fx("elite_kill", global_position)
	
	# Announcement
	if _game != null and _game.ui != null and _game.ui.has_method("show_boss_phase"):
		_game.ui.show_boss_phase(boss_name, 2)
	
	AudioManager.play_sound("boss_phase", global_position, 1.0, 0.0, true)
	boss_phase_changed.emit(2)

func _teleport_away() -> void:
	"""Teleport to a new location"""
	if _game == null or _game.player == null:
		return
	
	_is_teleporting = true
	
	# Find valid teleport location
	var target = _game.player.global_position
	var new_pos = _find_teleport_location(target)
	
	if new_pos == Vector2.ZERO:
		_is_teleporting = false
		return
	
	# Teleport out FX
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("summon_shadow", global_position)
		_game.spawn_fx("ghost", global_position)
	
	AudioManager.play_sound("teleport", global_position, 0.8)
	
	# Fade out
	var tween = create_tween()
	if body != null:
		tween.tween_property(body, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): 
			global_position = new_pos
			if body != null:
				body.modulate.a = 0.0
		)
		tween.tween_property(body, "modulate:a", 1.0, 0.2)
	else:
		global_position = new_pos
	
	tween.tween_callback(func():
		_is_teleporting = false
		_teleport_timer = teleport_cooldown
		
		# Teleport in FX
		if _game.has_method("spawn_fx"):
			_game.spawn_fx("summon_shadow", global_position)
			_game.spawn_fx("ghost", global_position)
		
		AudioManager.play_sound("teleport_arrive", global_position, 0.8)
	)

func _find_teleport_location(target_pos: Vector2) -> Vector2:
	"""Find a valid teleport location away from target"""
	for attempt in range(10):
		var angle = randf() * TAU
		var distance = randf_range(teleport_range_min, teleport_range_max)
		var new_pos = target_pos + Vector2.RIGHT.rotated(angle) * distance
		
		# Check if position is valid (not inside walls, etc.)
		# For now, just return the position
		return new_pos
	
	return Vector2.ZERO

func _cast_death_nova() -> void:
	"""Cast the devastating Death Nova attack"""
	_nova_timer = death_nova_cooldown
	
	# Warning indicator
	_create_nova_indicator()
	
	# Windup animation
	if body != null:
		var tween = create_tween()
		tween.tween_property(body, "scale", body.scale * 1.2, 0.5)
		tween.tween_interval(0.5)
		tween.tween_property(body, "scale", Vector2.ONE * 2.5 * (1.1 if _phase_2_active else 1.0), 0.3)
		tween.tween_callback(_execute_nova)
	else:
		_execute_nova()

func _create_nova_indicator() -> void:
	"""Create warning indicator for Death Nova"""
	if _game == null:
		return
	
	# Expanding ring indicator
	var indicator = Sprite2D.new()
	indicator.texture = preload("res://assets/ui/ui_selection_ring_64x64_v001.png")
	indicator.modulate = Color(0.8, 0.1, 0.9, 0.6)
	indicator.scale = Vector2.ZERO
	indicator.z_index = -5
	add_child(indicator)
	
	var tween = create_tween()
	tween.tween_property(indicator, "scale", Vector2.ONE * (death_nova_radius / 32.0), 1.0)
	tween.parallel().tween_property(indicator, "modulate:a", 0.0, 1.0)
	tween.tween_callback(indicator.queue_free)
	
	AudioManager.play_sound("nova_charge", global_position, 0.9)

func _execute_nova() -> void:
	"""Execute the Death Nova explosion"""
	# Screen shake
	if _game != null and _game.camera != null and _game.camera.has_method("shake"):
		_game.camera.shake(12.0, 0.8)
	
	# Visual FX
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("elite_kill", global_position)
		_game.spawn_fx("necrotic", global_position)
		
		# Multiple expanding rings
		for i in range(3):
			var ring = Sprite2D.new()
			ring.texture = preload("res://assets/ui/ui_selection_ring_64x64_v001.png")
			ring.modulate = Color(0.6, 0.0, 0.8, 0.5)
			ring.scale = Vector2.ONE * 0.5
			ring.z_index = -4
			_game.get_node_or_null("World/FX").add_child(ring) if _game.has_node("World/FX") else _game.add_child(ring)
			ring.global_position = global_position
			
			var tween = create_tween()
			tween.tween_property(ring, "scale", Vector2.ONE * (death_nova_radius / 32.0) * (1.0 + i * 0.3), 0.5)
			tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
			tween.tween_callback(ring.queue_free)
	
	AudioManager.play_sound("nova_explosion", global_position, 1.2, 0.0, true)
	
	# Apply damage
	_apply_nova_damage()

func _apply_nova_damage() -> void:
	"""Apply Death Nova damage to all targets in radius"""
	var radius_sq = death_nova_radius * death_nova_radius
	
	# Damage player
	if _game != null and _game.player != null and is_instance_valid(_game.player):
		var dist_sq = global_position.distance_squared_to(_game.player.global_position)
		if dist_sq <= radius_sq:
			# Full damage if close, falling off with distance
			var dist = sqrt(dist_sq)
			var damage_mult = 1.0 - (dist / death_nova_radius) * 0.5
			if _game.player.has_method("take_damage"):
				_game.player.take_damage(death_nova_damage * damage_mult, global_position, true, true, "magic")
	
	# Damage allies
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally == null or not is_instance_valid(ally):
			continue
		var dist_sq = global_position.distance_squared_to(ally.global_position)
		if dist_sq <= radius_sq:
			var dist = sqrt(dist_sq)
			var damage_mult = 1.0 - (dist / death_nova_radius) * 0.5
			if ally.has_method("take_damage"):
				ally.take_damage(death_nova_damage * damage_mult, global_position, true, true, "magic")

func _summon_skeleton_army() -> void:
	"""Summon skeleton minions"""
	_summon_timer = summon_cooldown
	
	var summon_count = randi_range(2, 3)
	if _phase_2_active:
		summon_count += 1
	
	for i in range(summon_count):
		if _active_skeletons.size() >= max_skeletons:
			break
		
		var angle = (TAU / summon_count) * i + randf_range(-0.3, 0.3)
		var offset = Vector2.RIGHT.rotated(angle) * randf_range(40.0, 70.0)
		var spawn_pos = global_position + offset
		
		var skeleton = _create_skeleton(spawn_pos)
		if skeleton != null:
			_active_skeletons.append(skeleton)
	
	# FX
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("summon_shadow", global_position)
		for i in range(3):
			var angle = randf() * TAU
			var offset = Vector2.RIGHT.rotated(angle) * randf_range(20.0, 50.0)
			_game.spawn_fx("ghost", global_position + offset)
	
	AudioManager.play_sound("summon_army", global_position, 0.8)

func _create_skeleton(spawn_pos: Vector2) -> Node:
	"""Create a skeleton minion"""
	if _game == null or _game.enemies_root == null:
		return null
	
	var skeleton = preload("res://scenes/enemy.tscn").instantiate()
	skeleton.global_position = spawn_pos
	
	if skeleton.has_method("setup"):
		skeleton.setup(_game, 1.0)
	
	# Skeleton stats
	skeleton.max_health = 40.0 if _phase_2_active else 25.0
	skeleton.health = skeleton.max_health
	skeleton.speed = 85.0
	skeleton.attack_damage = 12.0 if _phase_2_active else 8.0
	skeleton.attack_rate = 1.2
	
	# Visual - bone color
	if skeleton.has_node("Body"):
		skeleton.get_node("Body").modulate = Color(0.85, 0.9, 0.8)
	
	_game.enemies_root.add_child(skeleton)
	return skeleton

func _cast_magic_missile(target: Node2D) -> void:
	"""Cast a magic missile at target"""
	if _game == null:
		return
	
	# Create projectile
	var missile = preload("res://scenes/enemy_projectile.tscn").instantiate()
	missile.global_position = global_position
	
	var dir = (target.global_position - global_position).normalized()
	if missile.has_method("setup"):
		var damage = attack_damage * (_phase_2_damage_mult if _phase_2_active else 1.0)
		missile.setup(_game, dir, 280.0, damage, 300.0)
	
	# Visual tint
	if missile.has_node("Sprite2D"):
		missile.get_node("Sprite2D").modulate = Color(0.8, 0.2, 1.0)
	
	if _game.has_node("World/Projectiles"):
		_game.get_node("World/Projectiles").add_child(missile)
	
	# FX
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("necrotic", global_position)

func _cleanup_skeletons() -> void:
	"""Remove dead skeletons from tracking"""
	var valid: Array = []
	for skel in _active_skeletons:
		if skel != null and is_instance_valid(skel):
			if "_is_dying" in skel and not skel._is_dying:
				valid.append(skel)
	_active_skeletons = valid

func _start_death_sequence() -> void:
	"""Death - all skeletons die with the Lich"""
	# Kill all skeletons
	for skeleton in _active_skeletons:
		if skeleton != null and is_instance_valid(skeleton) and skeleton.has_method("take_damage"):
			skeleton.take_damage(9999, global_position, false, false)
	
	super._start_death_sequence()

func get_weakness_description() -> String:
	return "WEAKNESS: High burst damage (take down quickly)"
