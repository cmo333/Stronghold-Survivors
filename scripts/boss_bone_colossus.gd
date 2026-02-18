extends "res://scripts/boss_base.gd"

# Boss 1: Bone Colossus (Wave 5)
# A massive skeletal warrior that slams the ground, creating AOE shockwaves

@export var slam_cooldown: float = 4.0
@export var slam_damage: float = 40.0
@export var slam_radius: float = 120.0
@export var slam_windup: float = 1.2
@export var shockwave_speed: float = 250.0
@export var shockwave_range: float = 200.0

var _slam_timer: float = 0.0
var _is_winding_up_slam: bool = false
var _slam_windup_timer: float = 0.0

# Visual refs
var _windup_indicator: Sprite2D = null

func _ready() -> void:
	boss_name = "Bone Colossus"
	boss_title = "The Ancient Guardian"
	boss_wave = 5
	boss_color = Color(0.85, 0.75, 0.55)
	
	# Bone Colossus stats
	max_health = 2000.0
	health = max_health
	speed = 55.0  # Slow but unstoppable
	attack_damage = 25.0
	attack_rate = 0.8
	attack_range = 35.0
	
	super._ready()

func _boss_behavior(delta: float) -> void:
	if _is_winding_up_slam:
		_process_slam_windup(delta)
		return
	
	# Regular movement and attack
	var target = _find_target()
	if target == null or not is_instance_valid(target):
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	# Check for slam opportunity
	_slam_timer -= delta
	if _slam_timer <= 0.0 and dist <= slam_radius * 0.7:
		_start_slam_windup()
		return
	
	# Normal attack/movement
	if dist <= attack_range:
		if _attack_cooldown <= 0.0:
			_perform_attack(target)
			_attack_cooldown = 1.0 / max(0.1, attack_rate)
		velocity = Vector2.ZERO
	else:
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * speed * _slow_multiplier
		move_and_slide()
	
	_attack_cooldown = max(0.0, _attack_cooldown - delta)

func _perform_attack(target: Node2D) -> void:
	_deal_damage(target, attack_damage, global_position, true)
	
	# Attack FX
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("hit", global_position)
	
	AudioManager.play_one_shot("heavy_hit", global_position, AudioManager.DEFAULT_PRIORITY)

func _start_slam_windup() -> void:
	"""Begin the ground slam windup"""
	_is_winding_up_slam = true
	_slam_windup_timer = slam_windup
	
	# Stop moving
	velocity = Vector2.ZERO
	
	# Create telegraph indicator
	_create_slam_indicator()
	
	# Warning sound
	AudioManager.play_one_shot("boss_warning", global_position, AudioManager.HIGH_PRIORITY)
	
	# Visual windup - raise arms (scale pulse)
	if body != null:
		if not is_inside_tree():
			return
		var tween = create_tween()
		tween.tween_property(body, "scale", body.scale * 1.15, slam_windup * 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(body, "scale", body.scale, slam_windup * 0.5).set_trans(Tween.TRANS_BACK)

func _create_slam_indicator() -> void:
	"""Create visual indicator for upcoming slam"""
	if _game == null:
		return
	
	# Spawn warning circles on ground
	for i in range(3):
		var radius = slam_radius * (0.5 + i * 0.25)
		var indicator = Sprite2D.new()
		indicator.texture = preload("res://assets/ui/ui_selection_ring_64x64_v001.png")
		indicator.modulate = Color(1.0, 0.3, 0.1, 0.4)
		indicator.scale = Vector2.ONE * (radius / 32.0)
		indicator.position = Vector2.ZERO
		indicator.z_index = -5
		add_child(indicator)
		
		# Fade out indicator
		if indicator == null or not is_instance_valid(indicator) or not indicator.is_inside_tree():
			indicator.queue_free()
			continue
		var tween = create_tween()
		tween.tween_property(indicator, "modulate:a", 0.0, slam_windup)
		tween.tween_callback(indicator.queue_free)

func _process_slam_windup(delta: float) -> void:
	_slam_windup_timer -= delta
	
	if _slam_windup_timer <= 0.0:
		_execute_slam()

func _execute_slam() -> void:
	"""Execute the ground slam attack"""
	_is_winding_up_slam = false
	_slam_timer = slam_cooldown
	
	# Screen shake
	if _game != null and _game.camera != null and _game.camera.has_method("shake"):
		_game.camera.shake(8.0, 0.6)
	
	# Slam FX
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("elite_kill", global_position)
		_game.spawn_fx("summon_fire", global_position)
	
	AudioManager.play_one_shot("explosion_large", global_position, AudioManager.HIGH_PRIORITY)
	
	# Direct damage in slam radius
	_apply_slam_damage()
	
	# Create shockwave projectile
	_create_shockwave()
	
	# Reset visual
	if body != null:
		body.scale = Vector2.ONE * 2.5

func _apply_slam_damage() -> void:
	"""Apply damage to all targets in slam radius"""
	var radius_sq = slam_radius * slam_radius
	
	# Damage player
	if _game != null and _game.player != null and is_instance_valid(_game.player):
		var dist_sq = global_position.distance_squared_to(_game.player.global_position)
		if dist_sq <= radius_sq:
			var damage_factor = 1.0 - (sqrt(dist_sq) / slam_radius) * 0.5
			var damage = slam_damage * damage_factor
			if _game.player.has_method("take_damage"):
				_game.player.take_damage(damage, global_position, true)
	
	# Damage allies
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally == null or not is_instance_valid(ally):
			continue
		var dist_sq = global_position.distance_squared_to(ally.global_position)
		if dist_sq <= radius_sq:
			var damage_factor = 1.0 - (sqrt(dist_sq) / slam_radius) * 0.5
			var damage = slam_damage * damage_factor
			if ally.has_method("take_damage"):
				ally.take_damage(damage, global_position, true)
	
	# Damage buildings
	for building in get_tree().get_nodes_in_group("buildings"):
		if building == null or not is_instance_valid(building):
			continue
		var dist_sq = global_position.distance_squared_to(building.global_position)
		if dist_sq <= radius_sq:
			var damage_factor = 1.0 - (sqrt(dist_sq) / slam_radius) * 0.5
			var damage = slam_damage * damage_factor
			if building.has_method("take_damage"):
				building.take_damage(damage)

func _create_shockwave() -> void:
	"""Create expanding shockwave projectile"""
	if _game == null:
		return
	
	# Create 8 directional shockwaves
	var shockwave_scene: PackedScene = null
	var shockwave_path = "res://scenes/boss_shockwave.tscn"
	if ResourceLoader.exists(shockwave_path):
		shockwave_scene = load(shockwave_path)
	if shockwave_scene == null:
		if _game != null and _game.has_method("spawn_fx"):
			_game.spawn_fx("shockwave", global_position)
		return
	for i in range(8):
		var angle = (TAU / 8.0) * i
		var dir = Vector2.RIGHT.rotated(angle)
		var shockwave = shockwave_scene.instantiate()
			
		shockwave.global_position = global_position + dir * 20.0
		if shockwave.has_method("setup"):
			shockwave.setup(_game, dir, shockwave_speed, slam_damage * 0.5, shockwave_range)
		
		if _game.get_node_or_null("World/Projectiles"):
			_game.get_node("World/Projectiles").add_child(shockwave)

func get_weakness_description() -> String:
	return "WEAKNESS: Fast fire rate towers (Machine Gun, Arrow Fan)"
