extends Tower

# Shared static textures
static var _shared_orb_tex: ImageTexture = null
static var _shared_storm_field_tex: ImageTexture = null

var chain_count = 3
var lightning_storm = false
var stun_chance = 0.0
var storm_radius = 120.0
var _storm_timer = 0.0
var _storm_interval = 0.5

# Tesla tower specific visuals (note: _lightning_orb inherited from Tower)
var _secondary_coil: Sprite2D = null
var _arc_beams: Array[Line2D] = []
var _crackle_particles: CPUParticles2D = null
var _orb_float_angle: float = 0.0
var _line: Line2D = null

# Evolution: Storm Spire
var _storm_field_timer: float = 0.0
var _storm_field_interval: float = 0.5
var _storm_field_damage: float = 6.0
var _storm_field_radius: float = 200.0
var _storm_field_circle: Sprite2D = null

# Evolution: Arc Conduit
var _arc_bounce_damage_mult: float = 0.1  # +10% per bounce

func _ready() -> void:
	tower_type = "tesla"
	super._ready()
	_setup_lightning_line()

func get_evolution_options() -> Array:
	return [
		{
			"id": "storm_spire",
			"name": "Storm Spire",
			"desc": "Permanent lightning field damages all nearby enemies. Pure area denial.",
			"cost": 3
		},
		{
			"id": "arc_conduit",
			"name": "Arc Conduit",
			"desc": "15 chain targets, can bounce to same enemy. Each bounce +10% damage.",
			"cost": 3
		}
	]

func _apply_evolution_stats() -> void:
	match evolution_id:
		"storm_spire":
			chain_count = 4
			_storm_field_radius = 200.0
			_storm_field_damage = 6.0
		"arc_conduit":
			chain_count = 15
			damage = 16.0

func _apply_evolution_visuals() -> void:
	match evolution_id:
		"storm_spire":
			if body_sprite != null:
				body_sprite.modulate = Color(0.8, 0.9, 1.3, 1.0)
			# Create field circle visual — shared texture
			_storm_field_circle = Sprite2D.new()
			_storm_field_circle.z_index = -3
			if _shared_storm_field_tex == null:
				var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
				img.fill(Color(0, 0, 0, 0))
				var center = Vector2(32, 32)
				for x in range(64):
					for y in range(64):
						var d = Vector2(x, y).distance_to(center)
						if d < 30 and d > 24:
							img.set_pixel(x, y, Color(0.3, 0.7, 1.0, 0.25))
						elif d < 24:
							img.set_pixel(x, y, Color(0.2, 0.5, 0.9, 0.08))
				_shared_storm_field_tex = ImageTexture.create_from_image(img)
			_storm_field_circle.texture = _shared_storm_field_tex
			_storm_field_circle.scale = Vector2.ONE * (_storm_field_radius / 32.0)
			var mat = CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			_storm_field_circle.material = mat
			add_child(_storm_field_circle)
		"arc_conduit":
			if body_sprite != null:
				body_sprite.modulate = Color(0.6, 0.8, 1.4, 1.0)
			# Brighter lightning orb
			if _lightning_orb != null:
				_lightning_orb.modulate = Color(0.5, 1.0, 1.0, 1.0)

static func _get_orb_tex() -> ImageTexture:
	if _shared_orb_tex != null:
		return _shared_orb_tex
	var img = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(10, 10)
	for x in range(20):
		for y in range(20):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 9:
				var intensity = 1.0 - (dist / 9.0)
				img.set_pixel(x, y, Color(0.4, 0.8, 1.0, intensity))
	_shared_orb_tex = ImageTexture.create_from_image(img)
	return _shared_orb_tex

func _setup_tower_specific_visuals() -> void:
	# Secondary coil for T2 (initially hidden)
	_secondary_coil = Sprite2D.new()
	_secondary_coil.name = "SecondaryCoil"
	_secondary_coil.z_index = -1
	_secondary_coil.modulate = Color(0.5, 0.7, 1.0, 0.0)
	_secondary_coil.position = Vector2(8, 0)
	if body_sprite != null and body_sprite.sprite_frames != null:
		_secondary_coil.texture = body_sprite.sprite_frames.get_frame_texture("default", 0)
	var coil_material = CanvasItemMaterial.new()
	coil_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_secondary_coil.material = coil_material
	add_child(_secondary_coil)

	# Lightning orb for T3 (initially hidden) — shared texture
	_lightning_orb = Sprite2D.new()
	_lightning_orb.name = "LightningOrb"
	_lightning_orb.z_index = 5
	_lightning_orb.position = Vector2(0, -25)
	_lightning_orb.modulate = Color(0.2, 0.8, 1.0, 0.0)
	_lightning_orb.texture = _get_orb_tex()
	var orb_material = CanvasItemMaterial.new()
	orb_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lightning_orb.material = orb_material
	add_child(_lightning_orb)

	# Arc beams for T3 — reduced from 3 to 2
	for i in range(2):
		var beam = Line2D.new()
		beam.name = "ArcBeam%d" % i
		beam.width = 2.0
		beam.default_color = Color(0.3, 0.9, 1.0, 0.0)
		beam.z_index = 4
		add_child(beam)
		_arc_beams.append(beam)

	# Crackle particles for T3 — reduced amount
	_crackle_particles = CPUParticles2D.new()
	_crackle_particles.name = "CrackleParticles"
	_crackle_particles.amount = 6
	_crackle_particles.lifetime = 0.5
	_crackle_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_crackle_particles.emission_sphere_radius = 20.0
	_crackle_particles.gravity = Vector2(0, -20)
	_crackle_particles.initial_velocity_min = 10.0
	_crackle_particles.initial_velocity_max = 30.0
	_crackle_particles.scale_amount_min = 0.3
	_crackle_particles.scale_amount_max = 0.8
	_crackle_particles.color = Color(0.4, 0.9, 1.0, 0.0)
	_crackle_particles.emitting = false
	add_child(_crackle_particles)

func _setup_lightning_line() -> void:
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = Color(0.3, 0.8, 1.0, 0.9)
	_line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_line.z_index = 10
	add_child(_line)

func _animate_floating_elements(delta: float) -> void:
	if upgrade_level < 3 or _lightning_orb == null:
		return
	
	# Float the orb up and down
	_orb_float_angle += delta * 3.0
	_lightning_orb.position.y = -25 + sin(_orb_float_angle) * 4.0
	
	# Pulse the orb
	var pulse = 0.9 + sin(_orb_float_angle * 2.0) * 0.15
	_lightning_orb.scale = Vector2.ONE * pulse
	
	# Animate arc beams
	_update_arc_beams()
	
	# Enable crackle particles
	if _crackle_particles != null:
		_crackle_particles.emitting = true
		_crackle_particles.modulate = Color(0.4, 0.9, 1.0, 0.7)

func _update_arc_beams() -> void:
	if _lightning_orb == null:
		return
	
	var orb_pos = _lightning_orb.position
	var tower_points = [
		Vector2(-8, -5),
		Vector2(8, -5),
	]
	
	for i in range(_arc_beams.size()):
		var beam = _arc_beams[i]
		if beam == null:
			continue
		
		# Generate jagged arc points
		var start = orb_pos
		var end = tower_points[i]
		var points = _generate_arc_points(start, end, 4)
		beam.points = points
		
		# Random flicker
		beam.default_color.a = 0.4 + randf() * 0.4

func _generate_arc_points(from: Vector2, to: Vector2, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = [from]
	var mid = (from + to) / 2.0
	var jitter = (to - from).length() * 0.2
	mid += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	
	for i in range(1, segments):
		var t = float(i) / segments
		var pos = from.lerp(to, t)
		# Add curve offset
		var curve = sin(t * PI) * jitter * 0.5
		pos += Vector2(randf_range(-curve, curve), randf_range(-curve, curve))
		points.append(pos)
	
	points.append(to)
	return points

func _update_tower_specific_visuals() -> void:
	if not is_inside_tree():
		return
	# T2: Show secondary coil with arcing
	if _secondary_coil != null:
		var tween = create_tween()
		if upgrade_level >= 2:
			tween.tween_property(_secondary_coil, "modulate", Color(0.6, 0.8, 1.0, 0.7), 0.3)
		else:
			tween.tween_property(_secondary_coil, "modulate", Color(0.5, 0.7, 1.0, 0.0), 0.3)
	
	# T3: Show lightning orb and arc beams
	if upgrade_level >= 3:
		if _lightning_orb != null:
			var orb_tween = create_tween()
			orb_tween.tween_property(_lightning_orb, "modulate", Color(0.4, 0.9, 1.0, 0.9), 0.5)
		
		for beam in _arc_beams:
			if beam != null:
				var beam_tween = create_tween()
				beam_tween.tween_property(beam, "default_color:a", 0.6, 0.4)
		
		if _crackle_particles != null:
			_crackle_particles.emitting = true
			_crackle_particles.modulate = Color(0.4, 0.9, 1.0, 0.7)
	else:
		if _lightning_orb != null:
			_lightning_orb.modulate = Color(0.2, 0.8, 1.0, 0.0)
		for beam in _arc_beams:
			if beam != null:
				beam.default_color.a = 0.0
		if _crackle_particles != null:
			_crackle_particles.emitting = false
			_crackle_particles.modulate = Color(0.4, 0.9, 1.0, 0.0)

func _play_tower_specific_upgrade_effects() -> void:
	if not is_inside_tree():
		return
	if upgrade_level == 2:
		# Secondary coil fades in with electric flash
		if _secondary_coil != null:
			_secondary_coil.modulate = Color(2.0, 2.5, 3.0, 0.0)
			var tween = create_tween()
			tween.tween_property(_secondary_coil, "modulate", Color(0.6, 0.8, 1.0, 0.7), 0.4)
	
	elif upgrade_level == 3:
		# Orb appears with lightning flash
		if _lightning_orb != null:
			_lightning_orb.modulate = Color(3.0, 3.0, 4.0, 1.0)
			var tween = create_tween()
			tween.tween_property(_lightning_orb, "modulate", Color(0.4, 0.9, 1.0, 0.9), 0.3)
		
		# Arc beams zap in
		for beam in _arc_beams:
			if beam != null:
				beam.default_color = Color(2.0, 2.5, 3.0, 1.0)
				var beam_tween = create_tween()
				beam_tween.tween_property(beam, "default_color", Color(0.3, 0.9, 1.0, 0.6), 0.5)

func _process(delta: float) -> void:
	super._process(delta)
	# Handle lightning storm AOE for T3
	if lightning_storm and upgrade_level >= 3:
		_storm_timer -= delta
		if _storm_timer <= 0:
			_storm_timer = _storm_interval
			_trigger_lightning_storm()

	# Storm Spire evolution: permanent aura damage
	if is_evolved and evolution_id == "storm_spire":
		_storm_field_timer -= delta
		if _storm_field_timer <= 0:
			_storm_field_timer = _storm_field_interval
			_tick_storm_field()
		# Pulse visual
		if _storm_field_circle != null:
			var pulse = 0.8 + sin(Time.get_ticks_msec() * 0.003) * 0.2
			_storm_field_circle.modulate.a = pulse

func _tick_storm_field() -> void:
	if _game == null:
		return
	var field_dmg = _storm_field_damage
	# Double damage during lightning storm
	if lightning_storm:
		field_dmg *= 2.0
	var dmg_bonus = 0.0
	if _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()
	var enemies = _get_enemies()
	var hits = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= _storm_field_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(field_dmg + dmg_bonus, enemy.global_position, false, true)
			hits += 1
			if hits >= 8:  # Cap per tick
				break
	# Occasional visual spark
	if hits > 0 and _game.has_method("spawn_fx") and randf() < 0.3:
		var random_enemy = enemies[randi() % enemies.size()] if enemies.size() > 0 else null
		if random_enemy != null and is_instance_valid(random_enemy):
			_game.spawn_fx("tesla", random_enemy.global_position)

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	chain_count = int(tier_data.get("chain_count", chain_count))
	lightning_storm = bool(tier_data.get("lightning_storm", false))
	stun_chance = float(tier_data.get("stun_chance", 0.0))
	storm_radius = range * 0.5  # Storm radius is half of tower range

func _trigger_lightning_storm() -> void:
	if _game == null:
		return
	# Find enemies in storm radius around tower
	var enemies = _get_enemies()
	var storm_hits = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= storm_radius:
			# Random AOE lightning strike
			var dmg_bonus = 0.0
			if _game.has_method("get_tower_damage_bonus"):
				dmg_bonus = _game.get_tower_damage_bonus()
			
			if enemy.has_method("take_damage"):
				enemy.take_damage((damage + dmg_bonus) * 0.5, enemy.global_position, false, true)
			
			# Stun chance
			if stun_chance > 0 and randf() < stun_chance and enemy.has_method("stun"):
				enemy.stun(0.5)
			
			if _game.has_method("spawn_fx"):
				_game.spawn_fx("tesla", enemy.global_position)
			
			storm_hits += 1
			if storm_hits >= 3:  # Max 3 storm strikes per interval
				break

func _fire_at(target: Node2D) -> void:
	# Arc Conduit: special chain logic that allows re-hitting
	if is_evolved and evolution_id == "arc_conduit":
		_fire_arc_conduit(target)
		return

	var enemies = _get_enemies().duplicate()  # Copy before sorting — don't mutate shared cache
	enemies.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	var dmg_bonus = 0.0
	if _game != null and _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()
	var emp_level = 0
	if _game != null and _game.has_method("get_tech_level"):
		emp_level = _game.get_tech_level("tesla_emp")

	var hits = 0
	var last_pos = global_position
	var line_points: PackedVector2Array = [Vector2.ZERO]  # Start at tower center
	var hit_positions: Array[Vector2] = []

	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_squared_to(enemy.global_position) > range * range:
			continue

		# Visual lightning arc to this enemy
		var arc_points = _generate_arc(last_pos, enemy.global_position, 3)
		for pt in arc_points:
			line_points.append(pt - global_position)

		if enemy.has_method("take_damage"):
			enemy.take_damage(damage + dmg_bonus, enemy.global_position, false, true)

		# Stun chance for T3
		if stun_chance > 0 and randf() < stun_chance and enemy.has_method("stun"):
			enemy.stun(0.3)

		if _game != null and _game.has_method("spawn_fx"):
			_game.spawn_fx("tesla", enemy.global_position)
			if hits > 0:
				_game.spawn_fx("chain_hit", enemy.global_position)

		if emp_level > 0 and enemy.has_method("apply_slow"):
			var slow_factor = max(0.45, 0.8 - emp_level * 0.12)
			var slow_duration = 0.6 + 0.2 * emp_level
			enemy.apply_slow(get_instance_id(), slow_factor, slow_duration)

		if emp_level > 0 and enemy.has_method("stun"):
			enemy.stun(0.08 * emp_level)

		last_pos = enemy.global_position
		hit_positions.append(enemy.global_position)
		hits += 1
		if hits >= chain_count:
			break

func _fire_arc_conduit(target: Node2D) -> void:
	var enemies = _get_enemies()
	var in_range: Array = []
	for e in enemies:
		if e != null and is_instance_valid(e) and global_position.distance_squared_to(e.global_position) <= range * range:
			in_range.append(e)
	if in_range.is_empty():
		return

	var dmg_bonus = 0.0
	if _game != null and _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()
	var emp_level = 0
	if _game != null and _game.has_method("get_tech_level"):
		emp_level = _game.get_tech_level("tesla_emp")

	var hits = 0
	var current_dmg = damage + dmg_bonus
	var last_pos = global_position
	var line_points: PackedVector2Array = [Vector2.ZERO]
	var hit_positions: Array[Vector2] = []
	var current_target = target

	while hits < chain_count:
		if current_target == null or not is_instance_valid(current_target):
			break

		# Arc visual
		var arc_points = _generate_arc(last_pos, current_target.global_position, 3)
		for pt in arc_points:
			line_points.append(pt - global_position)

		# Deal escalating damage
		if current_target.has_method("take_damage"):
			current_target.take_damage(current_dmg, current_target.global_position, false, true)

		if stun_chance > 0 and randf() < stun_chance and current_target.has_method("stun"):
			current_target.stun(0.3)

		if _game != null and _game.has_method("spawn_fx"):
			_game.spawn_fx("tesla", current_target.global_position)
			if hits > 0:
				_game.spawn_fx("chain_hit", current_target.global_position)

		if emp_level > 0 and current_target.has_method("apply_slow"):
			current_target.apply_slow(get_instance_id(), max(0.45, 0.8 - emp_level * 0.12), 0.6 + 0.2 * emp_level)

		last_pos = current_target.global_position
		hit_positions.append(current_target.global_position)
		hits += 1
		current_dmg *= (1.0 + _arc_bounce_damage_mult)  # Escalate!

		# Find next target (can bounce to any in-range enemy, including already-hit)
		var best: Node2D = null
		var best_dist = 999999.0
		for e in in_range:
			if e == null or not is_instance_valid(e) or e == current_target:
				continue
			var d = last_pos.distance_to(e.global_position)
			if d < best_dist and d < range * 0.7:
				best_dist = d
				best = e
		# If no other target, bounce back to any random one
		if best == null and in_range.size() > 1:
			var candidates = in_range.filter(func(e): return e != null and is_instance_valid(e) and e != current_target)
			if not candidates.is_empty():
				best = candidates[randi() % candidates.size()]
		# If still no target but original is alive, bounce back to it
		if best == null and current_target != null and is_instance_valid(current_target):
			best = current_target
		current_target = best

	# Show arc conduit lightning lines
	_line.points = line_points
	_line.visible = true
	_line.default_color = Color(0.4, 0.9, 1.0, 0.9)
	_line.modulate.a = 1.0
	if _game != null and _game.fx_manager != null and hit_positions.size() > 0:
		_game.fx_manager.spawn_tesla_lightning(global_position, hit_positions)
	if not is_inside_tree():
		return
	var arc_tween = create_tween()
	arc_tween.tween_property(_line, "modulate:a", 0.0, 0.12)
	arc_tween.tween_callback(func(): _line.visible = false)
	arc_tween.tween_property(_line, "modulate:a", 0.9, 0.0)

func _generate_arc(from: Vector2, to: Vector2, segments: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var mid = (from + to) / 2.0
	var jitter = (to - from).length() * 0.15
	mid += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	
	for i in range(1, segments + 1):
		var t = float(i) / (segments + 1)
		# Quadratic bezier-ish with jitter
		var pos = from.lerp(to, t)
		var curve = sin(t * PI) * jitter * 0.5
		pos += Vector2(randf_range(-curve, curve), randf_range(-curve, curve))
		points.append(pos)
	
	points.append(to)
	return points
