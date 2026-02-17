extends Tower

var pierce_count = 1

# Shared static textures (created once, reused by all arrow turrets)
static var _shared_metal_bands_tex: ImageTexture = null
static var _shared_crystal_tex: ImageTexture = null
static var _shared_arrow_tex: ImageTexture = null

# Arrow tower specific visuals (note: _crystal_core is inherited from Tower)
var _floating_arrows: Array[Sprite2D] = []
var _arrow_orbit_angle: float = 0.0
var _metal_bands: Sprite2D = null

# Evolution: Gatling
var _gatling_spin_time: float = 0.0
var _gatling_max_spin: float = 2.0  # Time to reach max fire rate
var _gatling_base_rate: float = 1.0
var _gatling_max_rate: float = 4.0
var _gatling_firing: bool = false
var _gatling_idle_timer: float = 0.0
var _gatling_barrel_angle: float = 0.0

# Evolution: Sniper
var _sniper_laser_line: Line2D = null
var _sniper_charge_timer: float = 0.0
var _sniper_charging: bool = false
var _sniper_target: Node = null

func _ready() -> void:
	tower_type = "arrow"
	super._ready()

func get_evolution_options() -> Array:
	return [
		{
			"id": "gatling",
			"name": "Gatling Turret",
			"desc": "Rapid fire that spins up over 2s. Lower damage, overwhelming volume.",
			"cost": 3
		},
		{
			"id": "sniper",
			"name": "Sniper Turret",
			"desc": "Massive single-target damage. Infinite pierce hitscan. Extended range.",
			"cost": 3
		}
	]

func _apply_evolution_stats() -> void:
	match evolution_id:
		"gatling":
			_gatling_base_rate = fire_rate
			fire_rate = 4.0
			damage = 8.0
			pierce_count = 1
			projectile_speed = 1200.0
		"sniper":
			fire_rate = 0.3
			damage = 85.0
			range = 600.0
			projectile_range = 700.0
			pierce_count = 999  # Infinite pierce

func _apply_evolution_visuals() -> void:
	match evolution_id:
		"gatling":
			# Yellow/orange tint
			if body_sprite != null:
				body_sprite.modulate = Color(1.2, 1.0, 0.7, 1.0)
			# Hide crystal and arrows, they don't fit gatling
			if _crystal_core != null:
				_crystal_core.visible = false
			for arrow in _floating_arrows:
				if arrow != null:
					arrow.visible = false
		"sniper":
			# Dark red tint
			if body_sprite != null:
				body_sprite.modulate = Color(1.0, 0.7, 0.7, 1.0)
			# Create laser sight line
			_sniper_laser_line = Line2D.new()
			_sniper_laser_line.width = 1.0
			_sniper_laser_line.default_color = Color(1.0, 0.15, 0.1, 0.35)
			_sniper_laser_line.z_index = 15
			add_child(_sniper_laser_line)
			# Hide crystal and arrows
			if _crystal_core != null:
				_crystal_core.visible = false
			for arrow in _floating_arrows:
				if arrow != null:
					arrow.visible = false

static func _get_metal_bands_tex() -> ImageTexture:
	if _shared_metal_bands_tex != null:
		return _shared_metal_bands_tex
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(48):
		for y in range(48):
			if y >= 8 and y <= 12:
				var shade = 0.5 + 0.3 * sin(x * 0.3)
				img.set_pixel(x, y, Color(shade, shade, shade + 0.1, 0.9))
			if y >= 36 and y <= 40:
				var shade = 0.5 + 0.3 * sin(x * 0.3 + 1.0)
				img.set_pixel(x, y, Color(shade, shade, shade + 0.1, 0.9))
	_shared_metal_bands_tex = ImageTexture.create_from_image(img)
	return _shared_metal_bands_tex

static func _get_crystal_tex() -> ImageTexture:
	if _shared_crystal_tex != null:
		return _shared_crystal_tex
	var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(12, 12)
	for x in range(24):
		for y in range(24):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 10:
				var intensity = 1.0 - (dist / 10.0)
				img.set_pixel(x, y, Color(0.2, 0.95, 0.3, intensity * 0.9))
	_shared_crystal_tex = ImageTexture.create_from_image(img)
	return _shared_crystal_tex

static func _get_arrow_tex() -> ImageTexture:
	if _shared_arrow_tex != null:
		return _shared_arrow_tex
	var img = Image.create(12, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(12):
		for y in range(16):
			if y < 6 and abs(x - 6) < (6 - y) * 0.8:
				img.set_pixel(x, y, Color(0.9, 0.95, 0.9, 1.0))
			if y >= 6 and y < 14 and abs(x - 6) < 2:
				img.set_pixel(x, y, Color(0.8, 0.9, 0.8, 1.0))
			if y >= 14 and abs(x - 6) < 4:
				img.set_pixel(x, y, Color(0.6, 0.8, 0.6, 0.9))
	_shared_arrow_tex = ImageTexture.create_from_image(img)
	return _shared_arrow_tex

func _setup_tower_specific_visuals() -> void:
	# Metal bands for T2 (initially hidden) — shared texture
	_metal_bands = Sprite2D.new()
	_metal_bands.name = "MetalBands"
	_metal_bands.z_index = 1
	_metal_bands.modulate = Color(0.6, 0.6, 0.7, 0.0)
	_metal_bands.texture = _get_metal_bands_tex()
	add_child(_metal_bands)

	# Crystal core for T3 (initially hidden) — shared texture
	_crystal_core = Sprite2D.new()
	_crystal_core.name = "CrystalCore"
	_crystal_core.z_index = 2
	_crystal_core.modulate = Color(0.2, 0.9, 0.3, 0.0)
	_crystal_core.texture = _get_crystal_tex()
	var crystal_material = CanvasItemMaterial.new()
	crystal_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_crystal_core.material = crystal_material
	add_child(_crystal_core)

	# Floating arrows for T3 (initially hidden) — shared texture
	var arrow_tex = _get_arrow_tex()
	for i in range(3):
		var arrow = Sprite2D.new()
		arrow.name = "FloatingArrow%d" % i
		arrow.z_index = 3
		arrow.modulate = Color(0.3, 0.9, 0.4, 0.0)
		arrow.texture = arrow_tex
		var arrow_material = CanvasItemMaterial.new()
		arrow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		arrow.material = arrow_material
		add_child(arrow)
		_floating_arrows.append(arrow)

func _animate_floating_elements(delta: float) -> void:
	if upgrade_level < 3:
		return
	
	# Orbit the floating arrows around the tower
	_arrow_orbit_angle += delta * 2.0  # Rotation speed
	
	for i in range(_floating_arrows.size()):
		var arrow = _floating_arrows[i]
		if arrow == null:
			continue
		
		# Each arrow at different height and radius
		var angle = _arrow_orbit_angle + (i * TAU / 3.0)  # 120 degrees apart
		var radius = 22.0 + i * 3.0
		var height_offset = sin(_arrow_orbit_angle * 1.5 + i) * 3.0
		
		arrow.position = Vector2(cos(angle) * radius, sin(angle) * radius * 0.3 + height_offset - 10)
		arrow.rotation = angle + PI / 2  # Point in direction of orbit
	
	# Pulse the crystal core
	if _crystal_core != null:
		var pulse = 0.8 + sin(Time.get_time_dict_from_system()["second"] * 5.0) * 0.2
		_crystal_core.scale = Vector2.ONE * (0.9 + pulse * 0.2)
		_crystal_core.modulate = Color(0.2, 0.9, 0.3, 0.8 * pulse)

func _update_tower_specific_visuals() -> void:
	# T2: Show metal bands
	if _metal_bands != null:
		var tween = create_tween()
		if upgrade_level >= 2:
			tween.tween_property(_metal_bands, "modulate", Color(0.7, 0.7, 0.8, 0.9), 0.3)
		else:
			tween.tween_property(_metal_bands, "modulate", Color(0.6, 0.6, 0.7, 0.0), 0.3)
	
	# T3: Show crystal core and floating arrows
	if upgrade_level >= 3:
		if _crystal_core != null:
			var crystal_tween = create_tween()
			crystal_tween.tween_property(_crystal_core, "modulate", Color(0.2, 0.9, 0.3, 0.9), 0.5)
		
		for arrow in _floating_arrows:
			if arrow != null:
				var arrow_tween = create_tween()
				arrow_tween.tween_property(arrow, "modulate", Color(0.3, 0.9, 0.4, 0.85), 0.5)
	else:
		if _crystal_core != null:
			_crystal_core.modulate = Color(0.2, 0.9, 0.3, 0.0)
		for arrow in _floating_arrows:
			if arrow != null:
				arrow.modulate = Color(0.3, 0.9, 0.4, 0.0)

func _play_tower_specific_upgrade_effects() -> void:
	if upgrade_level == 2:
		# Metal bands shimmer in
		if _metal_bands != null:
			_metal_bands.modulate = Color(1.5, 1.5, 1.6, 0.0)
			var tween = create_tween()
			tween.tween_property(_metal_bands, "modulate", Color(0.7, 0.7, 0.8, 0.9), 0.4)
	
	elif upgrade_level == 3:
		# Crystal and arrows appear with flash
		if _crystal_core != null:
			_crystal_core.modulate = Color(2.0, 3.0, 2.0, 1.0)
			var tween = create_tween()
			tween.tween_property(_crystal_core, "modulate", Color(0.2, 0.9, 0.3, 0.9), 0.5)
		
		# Arrows spiral in
		for i in range(_floating_arrows.size()):
			var arrow = _floating_arrows[i]
			if arrow != null:
				arrow.modulate = Color(1.0, 1.0, 1.0, 0.0)
				var tween = create_tween()
				tween.tween_property(arrow, "modulate", Color(0.3, 0.9, 0.4, 0.85), 0.6)

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	pierce_count = int(tier_data.get("pierce_count", 1))

func _process(delta: float) -> void:
	super._process(delta)

	# Gatling spin-up mechanic
	if is_evolved and evolution_id == "gatling":
		if _gatling_firing:
			_gatling_spin_time = min(_gatling_spin_time + delta, _gatling_max_spin)
			_gatling_idle_timer = 0.0
		else:
			_gatling_idle_timer += delta
			if _gatling_idle_timer > 0.5:
				_gatling_spin_time = max(0.0, _gatling_spin_time - delta * 2.0)
		_gatling_firing = false
		# Animate barrel rotation based on spin
		var spin_pct = _gatling_spin_time / _gatling_max_spin
		_gatling_barrel_angle += delta * (1.0 + spin_pct * 8.0)
		if body_sprite != null:
			body_sprite.rotation = sin(_gatling_barrel_angle * 3.0) * 0.05 * spin_pct
		# Adjust effective fire rate based on spin
		fire_rate = lerpf(_gatling_base_rate, _gatling_max_rate, spin_pct)

	# Sniper laser sight
	if is_evolved and evolution_id == "sniper" and _sniper_laser_line != null:
		var enemies = _get_enemies()
		var closest: Node2D = null
		var closest_dist = range * range
		for enemy in enemies:
			if enemy == null or not is_instance_valid(enemy):
				continue
			var d = global_position.distance_squared_to(enemy.global_position)
			if d < closest_dist:
				closest_dist = d
				closest = enemy
		if closest != null:
			var dir = (closest.global_position - global_position).normalized()
			_sniper_laser_line.points = [Vector2.ZERO, dir * range]
			_sniper_laser_line.default_color.a = 0.2 + sin(Time.get_ticks_msec() * 0.005) * 0.1
		else:
			_sniper_laser_line.points = [Vector2.ZERO, Vector2.ZERO]

func _fire_at(target: Node2D) -> void:
	if _game == null:
		return

	# Sniper evolution: hitscan line
	if is_evolved and evolution_id == "sniper":
		_fire_sniper(target)
		return

	# Gatling evolution: mark as firing for spin-up
	if is_evolved and evolution_id == "gatling":
		_gatling_firing = true

	var dir = (target.global_position - global_position).normalized()
	var dmg_bonus = 0.0
	if _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()

	# Get multishot level and angles
	var level = 0
	if _game.has_method("get_tech_level"):
		level = _game.get_tech_level("arrow_fan")
	var extra_angles: Array[float] = []
	if not is_evolved:  # Fan only for non-evolved
		if level == 1:
			extra_angles = [-0.2, 0.2]
		elif level == 2:
			extra_angles = [-0.35, -0.15, 0.15, 0.35]
		elif level >= 3:
			extra_angles = [-0.5, -0.3, -0.1, 0.1, 0.3, 0.5]

	# Spawn multishot indicator if we have spread shots
	if extra_angles.size() > 0 and _game != null and _game.fx_manager != null:
		_game.fx_manager.spawn_multishot_indicator(global_position, dir, extra_angles)

	# Spawn main projectile with pierce capability
	_game.spawn_projectile(global_position, dir, projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius, pierce_count)

	# Spawn extra projectiles
	for angle in extra_angles:
		_game.spawn_projectile(global_position, dir.rotated(angle), projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius, pierce_count)

	# Gatling muzzle flash
	if is_evolved and evolution_id == "gatling" and _game.has_method("spawn_fx"):
		_game.spawn_fx("hit", global_position + dir * 12.0)

func _fire_sniper(target: Node2D) -> void:
	var dir = (target.global_position - global_position).normalized()
	var dmg_bonus = 0.0
	if _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()

	# Hitscan: damage ALL enemies in a line
	var total_dmg = damage + dmg_bonus
	var enemies = _get_enemies()
	var hit_count = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		# Check if enemy is roughly on the line (within 20px perpendicular distance)
		var to_enemy = enemy.global_position - global_position
		var proj = to_enemy.dot(dir)
		if proj < 0 or proj > range:
			continue
		var perp_dist = abs(to_enemy.cross(dir))
		if perp_dist < 20.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(total_dmg, enemy.global_position, false, false)
			hit_count += 1

	# Visual: bright line flash
	if _sniper_laser_line != null:
		_sniper_laser_line.default_color = Color(1.0, 0.3, 0.2, 0.9)
		_sniper_laser_line.width = 3.0
		_sniper_laser_line.points = [Vector2.ZERO, dir * range]
		var tween = create_tween()
		tween.tween_property(_sniper_laser_line, "default_color:a", 0.2, 0.15)
		tween.parallel().tween_property(_sniper_laser_line, "width", 1.0, 0.15)

	# Screen shake for sniper
	if _game.has_method("shake_camera"):
		_game.shake_camera(3.0, 0.1)
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("crit", global_position + dir * 16.0)
