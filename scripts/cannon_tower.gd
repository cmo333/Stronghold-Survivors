extends Tower

var cluster_bombs = false
var burn_effect = false
var burn_damage = 5.0
var burn_duration = 3.0

# Shared static textures
static var _shared_barrel_tex: ImageTexture = null
static var _shared_rune_texes: Array[ImageTexture] = []

# Cannon tower specific visuals (note: _steam_vents and _rune_glows inherited from Tower)
var _reinforced_barrel: Sprite2D = null
var _multi_barrels: Array[Sprite2D] = []
var _smoke_trails: CPUParticles2D = null
var _barrel_rotation: float = 0.0

# Evolution: Hellfire
var hellfire_pool_damage: float = 8.0
var hellfire_pool_duration: float = 3.0

# Shared fire pool texture
static var _shared_fire_pool_tex: ImageTexture = null

# Evolution: Shockwave
var shockwave_knockback: float = 120.0
var shockwave_stun_chance: float = 0.4
var shockwave_stun_duration: float = 0.5

func _ready() -> void:
	tower_type = "cannon"
	super._ready()

func get_evolution_options() -> Array:
	return [
		{
			"id": "hellfire",
			"name": "Hellfire Mortar",
			"desc": "Larger explosions that leave fire pools. Burns enemies over time.",
			"cost": 4
		},
		{
			"id": "shockwave",
			"name": "Shockwave Cannon",
			"desc": "Knockback + stun on hit. Faster fire rate. Crowd control king.",
			"cost": 4
		}
	]

func _apply_evolution_stats() -> void:
	match evolution_id:
		"hellfire":
			explosion_radius = 200.0
			fire_rate = 0.6
			cluster_bombs = true
			burn_effect = true
		"shockwave":
			explosion_radius = 180.0
			damage = 25.0
			fire_rate = 1.0

func _apply_evolution_visuals() -> void:
	match evolution_id:
		"hellfire":
			if body_sprite != null:
				body_sprite.modulate = Color(1.3, 0.8, 0.5, 1.0)
			for rune in _rune_glows:
				if rune != null:
					rune.modulate = Color(1.0, 0.5, 0.1, 0.9)
		"shockwave":
			if body_sprite != null:
				body_sprite.modulate = Color(0.7, 0.8, 1.2, 1.0)
			for rune in _rune_glows:
				if rune != null:
					rune.modulate = Color(0.3, 0.6, 1.0, 0.9)

static func _get_barrel_tex() -> ImageTexture:
	if _shared_barrel_tex != null:
		return _shared_barrel_tex
	var img = Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(16):
		for y in range(24):
			var dx = abs(x - 8)
			if dx < 5 and y > 2 and y < 22:
				var shade = 0.3 + 0.2 * sin(y * 0.3)
				img.set_pixel(x, y, Color(shade + 0.3, shade, shade, 1.0))
			if y >= 20 and dx < 6:
				img.set_pixel(x, y, Color(0.2, 0.1, 0.1, 1.0))
	_shared_barrel_tex = ImageTexture.create_from_image(img)
	return _shared_barrel_tex

static func _get_rune_texes() -> Array[ImageTexture]:
	if not _shared_rune_texes.is_empty():
		return _shared_rune_texes
	var patterns = [
		[" XX ", "X  X", " XX ", "X  X"],
		["XXXX", "  X ", " X  ", "XXXX"],
		["X  X", "X  X", "XXXX", "X  X"],
		["XXXX", "X   ", "XXXX", "   X"],
	]
	for i in range(4):
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var pattern = patterns[i]
		for y in range(4):
			for x in range(4):
				if pattern[y][x] == "X":
					img.set_pixel(x * 3 + 1, y * 3 + 1, Color(1.0, 0.5, 0.2, 1.0))
					img.set_pixel(x * 3 + 2, y * 3 + 1, Color(1.0, 0.5, 0.2, 1.0))
					img.set_pixel(x * 3 + 1, y * 3 + 2, Color(1.0, 0.5, 0.2, 1.0))
					img.set_pixel(x * 3 + 2, y * 3 + 2, Color(1.0, 0.5, 0.2, 1.0))
		_shared_rune_texes.append(ImageTexture.create_from_image(img))
	return _shared_rune_texes

func _setup_tower_specific_visuals() -> void:
	# Reinforced barrel overlay for T2 (initially hidden)
	_reinforced_barrel = Sprite2D.new()
	_reinforced_barrel.name = "ReinforcedBarrel"
	_reinforced_barrel.z_index = 1
	_reinforced_barrel.modulate = Color(0.8, 0.3, 0.2, 0.0)
	if body_sprite != null and body_sprite.sprite_frames != null:
		_reinforced_barrel.texture = body_sprite.sprite_frames.get_frame_texture("default", 0)
	add_child(_reinforced_barrel)

	# Steam vents for T2 — reduced to 1 vent, lower particle count
	var vent = CPUParticles2D.new()
	vent.name = "SteamVent"
	vent.z_index = 2
	vent.position = Vector2(0, -8)
	vent.amount = 4
	vent.lifetime = 0.6
	vent.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	vent.gravity = Vector2(0, -30)
	vent.initial_velocity_min = 5.0
	vent.initial_velocity_max = 15.0
	vent.scale_amount_min = 0.5
	vent.scale_amount_max = 1.0
	vent.color = Color(0.9, 0.9, 0.95, 0.0)
	vent.emitting = false
	add_child(vent)
	_steam_vents.append(vent)

	# Multi-barrel assembly for T3 — shared texture
	var barrel_tex = _get_barrel_tex()
	for i in range(3):
		var barrel = Sprite2D.new()
		barrel.name = "MultiBarrel%d" % i
		barrel.z_index = 3
		barrel.modulate = Color(0.6, 0.2, 0.2, 0.0)
		barrel.texture = barrel_tex
		add_child(barrel)
		_multi_barrels.append(barrel)

	# Glowing runes for T3 — shared textures
	var rune_texes = _get_rune_texes()
	for i in range(4):
		var rune = Sprite2D.new()
		rune.name = "RuneGlow%d" % i
		rune.z_index = 4
		rune.modulate = Color(1.0, 0.3, 0.1, 0.0)
		rune.texture = rune_texes[i]
		var rune_material = CanvasItemMaterial.new()
		rune_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		rune.material = rune_material
		var angle = (i / 4.0) * TAU
		rune.position = Vector2(cos(angle) * 12, sin(angle) * 8 + 5)
		add_child(rune)
		_rune_glows.append(rune)

	# Smoke trails for T3 — reduced amount
	_smoke_trails = CPUParticles2D.new()
	_smoke_trails.name = "SmokeTrails"
	_smoke_trails.z_index = -1
	_smoke_trails.amount = 8
	_smoke_trails.lifetime = 1.5
	_smoke_trails.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_smoke_trails.emission_sphere_radius = 8.0
	_smoke_trails.gravity = Vector2(0, -10)
	_smoke_trails.initial_velocity_min = 5.0
	_smoke_trails.initial_velocity_max = 15.0
	_smoke_trails.scale_amount_min = 0.8
	_smoke_trails.scale_amount_max = 2.0
	_smoke_trails.color = Color(0.3, 0.3, 0.3, 0.0)
	_smoke_trails.emitting = false
	add_child(_smoke_trails)

func _animate_floating_elements(delta: float) -> void:
	if upgrade_level < 3:
		return
	
	# Rotate the multi-barrel assembly
	_barrel_rotation += delta * 1.5  # Rotation speed
	
	for i in range(_multi_barrels.size()):
		var barrel = _multi_barrels[i]
		if barrel == null:
			continue
		
		# Arrange barrels in a triangle formation that rotates
		var base_angle = _barrel_rotation + (i * TAU / 3.0)
		var radius = 8.0
		barrel.position = Vector2(cos(base_angle) * radius, sin(base_angle) * radius - 5)
		barrel.rotation = base_angle + PI / 2
	
	# Pulse the runes
	for i in range(_rune_glows.size()):
		var rune = _rune_glows[i]
		if rune == null:
			continue
		var pulse = 0.7 + sin(Time.get_time_dict_from_system()["second"] * 4.0 + i) * 0.3
		rune.modulate = Color(1.0, 0.3, 0.1, 0.8 * pulse)
	
	# Enable smoke trails
	if _smoke_trails != null:
		_smoke_trails.emitting = true
		_smoke_trails.modulate = Color(0.3, 0.3, 0.3, 0.4)

func _update_tower_specific_visuals() -> void:
	if not is_inside_tree():
		return
	# T2: Show reinforced barrel and steam vents
	if _reinforced_barrel != null:
		var tween = create_tween()
		if upgrade_level >= 2:
			_reinforced_barrel.scale = Vector2.ONE * 1.15
			tween.tween_property(_reinforced_barrel, "modulate", Color(0.95, 0.35, 0.25, 1.0), 0.3)
		else:
			tween.tween_property(_reinforced_barrel, "modulate", Color(0.8, 0.3, 0.2, 0.0), 0.3)
	
	for vent in _steam_vents:
		if vent != null:
			if upgrade_level >= 2:
				vent.emitting = true
				vent.modulate = Color(0.95, 0.95, 1.0, 0.8)
			else:
				vent.emitting = false
				vent.modulate = Color(0.9, 0.9, 0.95, 0.0)
	
	# T3: Show multi-barrels, runes, and smoke
	if upgrade_level >= 3:
		for barrel in _multi_barrels:
			if barrel != null:
				var barrel_tween = create_tween()
				barrel.scale = Vector2.ONE * 1.2
				barrel_tween.tween_property(barrel, "modulate", Color(0.7, 0.25, 0.2, 1.0), 0.4)
		
		for rune in _rune_glows:
			if rune != null:
				var rune_tween = create_tween()
				rune.scale = Vector2.ONE * 1.15
				rune_tween.tween_property(rune, "modulate", Color(1.2, 0.4, 0.15, 1.0), 0.5)
		
		if _smoke_trails != null:
			_smoke_trails.emitting = true
			_smoke_trails.modulate = Color(0.35, 0.35, 0.35, 0.6)
	else:
		for barrel in _multi_barrels:
			if barrel != null:
				barrel.modulate = Color(0.6, 0.2, 0.2, 0.0)
		for rune in _rune_glows:
			if rune != null:
				rune.modulate = Color(1.0, 0.3, 0.1, 0.0)
		if _smoke_trails != null:
			_smoke_trails.emitting = false
			_smoke_trails.modulate = Color(0.3, 0.3, 0.3, 0.0)

func _play_tower_specific_upgrade_effects() -> void:
	if not is_inside_tree():
		return
	if upgrade_level == 2:
		# Reinforced barrel clangs in
		if _reinforced_barrel != null:
			_reinforced_barrel.modulate = Color(2.0, 1.0, 0.5, 0.0)
			var tween = create_tween()
			tween.tween_property(_reinforced_barrel, "modulate", Color(0.8, 0.3, 0.2, 0.85), 0.4)
		
		# Steam vents puff
		for vent in _steam_vents:
			if vent != null:
				vent.modulate = Color(1.0, 1.0, 1.0, 1.0)
				var vent_tween = create_tween()
				vent_tween.tween_property(vent, "modulate", Color(0.9, 0.9, 0.95, 0.6), 0.5)
	
	elif upgrade_level == 3:
		# Multi-barrels spin in
		for i in range(_multi_barrels.size()):
			var barrel = _multi_barrels[i]
			if barrel != null:
				barrel.modulate = Color(2.0, 0.5, 0.3, 0.0)
				var tween = create_tween()
				tween.tween_property(barrel, "modulate", Color(0.6, 0.2, 0.2, 0.9), 0.5)
		
		# Runes ignite
		for rune in _rune_glows:
			if rune != null:
				rune.modulate = Color(3.0, 1.0, 0.2, 0.0)
				var rune_tween = create_tween()
				rune_tween.tween_property(rune, "modulate", Color(1.0, 0.3, 0.1, 0.8), 0.6)

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	cluster_bombs = bool(tier_data.get("cluster_bombs", false))
	burn_effect = bool(tier_data.get("burn_effect", false))

func _fire_at(target: Node2D) -> void:
	if _game == null:
		return
	var target_pos = target.global_position
	var target_vel = Vector2.ZERO
	if "velocity" in target:
		target_vel = target.velocity
	var to_target = target_pos - global_position
	var distance = to_target.length()
	var lead_time = distance / max(1.0, projectile_speed)
	if target_vel.length() > 0.1:
		target_pos += target_vel * lead_time
	var dir = (target_pos - global_position).normalized()
	var dmg_bonus = 0.0
	if _game != null and _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()
	
	# Spawn main cannonball with cluster and burn capability
	var projectile = _game.spawn_cannonball(global_position, dir, projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius, cluster_bombs, burn_effect)

	# Spawn shockwave effect at cannon position
	if _game != null and _game.fx_manager != null:
		_game.fx_manager.spawn_cannon_shockwave(global_position, explosion_radius * 0.5, "fire" if burn_effect else "normal")

	# Shockwave evolution: knockback + stun on impact
	if is_evolved and evolution_id == "shockwave":
		_apply_shockwave_at(target_pos)

	# Hellfire evolution: spawn fire pool at target position
	if is_evolved and evolution_id == "hellfire":
		_spawn_fire_pool(target_pos)

	# Puff steam when firing (if T2+)
	if upgrade_level >= 2 and is_inside_tree():
		for vent in _steam_vents:
			if vent != null and vent.emitting:
				vent.amount = 12  # Burst of steam
				var t = get_tree().create_timer(0.1)
				t.timeout.connect(func():
					if is_instance_valid(vent):
						vent.amount = 8  # Back to normal
				)

func _apply_shockwave_at(pos: Vector2) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.3).timeout  # Delay for projectile travel
	if not is_inside_tree():
		return
	var enemies = _get_enemies()
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist = pos.distance_to(enemy.global_position)
		if dist <= explosion_radius:
			# Knockback
			var push_dir = (enemy.global_position - pos).normalized()
			if push_dir.length() < 0.1:
				push_dir = Vector2.RIGHT.rotated(randf() * TAU)
			enemy.global_position += push_dir * shockwave_knockback * (1.0 - dist / explosion_radius)
			# Stun chance
			if randf() < shockwave_stun_chance and enemy.has_method("stun"):
				enemy.stun(shockwave_stun_duration)
	# Visual: expanding blue ring
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("shockwave", pos)

func _spawn_fire_pool(pos: Vector2) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.3).timeout  # Delay for projectile travel
	if not is_inside_tree() or _game == null:
		return
	# Create a fire pool that damages enemies over time
	var pool = Node2D.new()
	pool.global_position = pos
	pool.z_index = -2
	var fx_parent = _game.get_node_or_null("World/FX")
	if fx_parent != null:
		fx_parent.add_child(pool)
	else:
		_game.add_child(pool)

	# Visual: orange circle — shared texture
	var sprite = Sprite2D.new()
	if _shared_fire_pool_tex == null:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var center = Vector2(32, 32)
		for x in range(64):
			for y in range(64):
				var d = Vector2(x, y).distance_to(center)
				if d < 28:
					var a = (1.0 - d / 28.0) * 0.5
					img.set_pixel(x, y, Color(1.0, 0.4, 0.1, a))
		_shared_fire_pool_tex = ImageTexture.create_from_image(img)
	sprite.texture = _shared_fire_pool_tex
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = mat
	sprite.scale = Vector2.ONE * (explosion_radius / 32.0)
	pool.add_child(sprite)

	# Damage tick timer — use pool's tree since pool outlives the tower
	var tick_count = 0
	var tick_interval = 0.5
	var max_ticks = int(hellfire_pool_duration / tick_interval)
	var fade_start_tick = int(max_ticks * 0.6)
	var game_ref = _game  # Capture reference since tower may be freed
	while tick_count < max_ticks and is_instance_valid(pool) and pool.is_inside_tree():
		await pool.get_tree().create_timer(tick_interval).timeout
		tick_count += 1
		if not is_instance_valid(pool) or not pool.is_inside_tree():
			break
		var enemies: Array = []
		if game_ref != null and is_instance_valid(game_ref) and "cached_enemies" in game_ref:
			enemies = game_ref.cached_enemies
		elif pool.is_inside_tree():
			enemies = pool.get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if enemy == null or not is_instance_valid(enemy):
				continue
			if pool.global_position.distance_to(enemy.global_position) <= explosion_radius * 0.8:
				if enemy.has_method("take_damage"):
					enemy.take_damage(hellfire_pool_damage, enemy.global_position, false, false)
		# Fade out near end
		if tick_count > fade_start_tick and is_instance_valid(sprite):
			sprite.modulate.a = lerpf(sprite.modulate.a, 0.0, 0.3)
	if is_instance_valid(pool):
		pool.queue_free()
