extends CharacterBody2D

const FeedbackConfig = preload("res://scripts/feedback_config.gd")
const ResourceGenerator = preload("res://scripts/resource_generator.gd")
const ELITE_GLOW_TEXTURE = preload("res://assets/ui/ui_selection_ring_64x64_v001.png")

var speed = 110.0
var max_health = 20.0
var health = 20.0
var attack_damage = 10.0
var attack_rate = 1.05
var attack_range = 20.0
var aggro_range = 260.0
var is_siege = false

var _attack_cooldown = 0.0
var _game: Node = null
# FFA replication. Host assigns net_id (monotonic) and remembers the scene/script
# path it spawned from so clients can instantiate a matching proxy. 0 = unreplicated.
var net_id: int = 0
var net_scene_path: String = ""
var net_script_path: String = ""
var is_net_proxy: bool = false
var _slow_sources: Dictionary = {}
var _slow_multiplier = 1.0
var _stun_timer = 0.0
var _was_stunned = false
var _was_slowed = false
var is_elite = false
var is_split_child = false
var _last_hit_fx_ms = -999999
var _last_damage_number_ms = -999999
var _is_dying = false
var _death_timer = 0.0
var _corpse_fade_timer = 0.0

# Elite modifier system: "", "aura", "regen", "splitter"
var elite_modifier = ""
var _elite_mod_timer = 0.0

# Aura: boosts nearby mob damage every few seconds
var _aura_interval = 3.0
var _aura_radius = 140.0
var _aura_damage_bonus = 1.0
var _aura_buff_duration = 2.4

# Regen: passive HP per second
var _regen_rate = 3.0

# Splitter: spawns smaller minions on death
var _split_child_count = 2
var _split_child_scale = 0.78
var _split_child_health_mult = 0.65
var _split_child_damage_mult = 0.75
var _split_child_speed_mult = 1.15

var _aura_bonus_timer = 0.0
var _aura_bonus_amount = 0.0
var _elite_glow: Sprite2D = null
var _elite_glow_tween: Tween = null
var _elite_glow_timer = 0.0
var _elite_glow_interval = 0.18

# Simple steering angles (degrees) for maze navigation
const STEER_ANGLES = [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 90.0, -90.0]

# Health bar (only for elites/siege/bosses)
var _health_bar_bg: ColorRect = null
var _health_bar_fill: ColorRect = null
const HEALTH_BAR_WIDTH = 24.0
const HEALTH_BAR_HEIGHT = 3.0
const HEALTH_BAR_OFFSET_Y = -22.0

@onready var body: CanvasItem = $Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var _base_color: Color = Color.WHITE

# Per-hit feedback: white flinch flash + decaying knockback shove
var _hit_flash_timer = 0.0
var _hit_flash_duration = 0.0
var _hit_flash_strength = 0.0
var _knockback: Vector2 = Vector2.ZERO

# --- Horde performance caches ---
# _find_target() used to run every frame for every enemy and scan the whole
# "buildings" and "allies" groups each time. With a few hundred enemies that is
# hundreds of array allocations and tens of thousands of iterations per frame.
# Targets are now re-evaluated a few times a second off shared cached lists,
# and the expensive 8-way steering probe is reused for a beat when blocked.
var _cached_target: Node2D = null
var _target_refresh_cooldown: float = 0.0
var _steer_dir: Vector2 = Vector2.ZERO
var _steer_pref_dir: Vector2 = Vector2.ZERO
var _steer_cooldown: float = 0.0

var _cached_visible: bool = true
var _visibility_check_timer: float = 0.0

func _is_visible_to_camera() -> bool:
	"""Cheap on-screen test, re-evaluated a few times a second and staggered
	across the horde. Movement and damage always run — this only gates
	decoration, so being a frame or two stale is harmless."""
	_visibility_check_timer -= get_physics_process_delta_time()
	if _visibility_check_timer > 0.0:
		return _cached_visible
	_visibility_check_timer = randf_range(0.1, 0.2)
	if _game == null:
		return _cached_visible
	var cam = _game.get("camera")
	if cam == null or not is_instance_valid(cam):
		_cached_visible = true
		return true
	var zoom: Vector2 = cam.zoom
	if zoom.x <= 0.001 or zoom.y <= 0.001:
		_cached_visible = true
		return true
	var half: Vector2 = get_viewport_rect().size / zoom * 0.5
	var d: Vector2 = global_position - cam.global_position
	_cached_visible = absf(d.x) <= half.x + 120.0 and absf(d.y) <= half.y + 120.0
	return _cached_visible

func _allies_list() -> Array:
	if _game != null and _game.has_method("get_cached_allies"):
		return _game.get_cached_allies()
	return get_tree().get_nodes_in_group("allies")

func _buildings_list() -> Array:
	if _game != null and _game.has_method("get_cached_buildings"):
		return _game.get_cached_buildings()
	return get_tree().get_nodes_in_group("buildings")

func setup(game_ref: Node, difficulty: float) -> void:
	_game = game_ref
	var health_mult = 1.0
	if _game != null and _game.has_method("get_enemy_health_mult"):
		health_mult = float(_game.get_enemy_health_mult())
	max_health = max_health * difficulty * health_mult
	health = max_health
	speed = speed * (1.0 + difficulty * 0.03) * 0.72  # 20% slower than current baseline
	var damage_scale = 1.0 + max(0.0, difficulty - 1.35) * 0.28
	attack_damage *= damage_scale

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = GameLayers.ENEMY
	# Enemies collide with allies/buildings, but not the player body.
	collision_mask = GameLayers.ALLY | GameLayers.BUILDING
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if body != null:
		_base_color = body.modulate
		body.scale = Vector2.ONE * 1.8
	if is_elite or is_siege:
		_create_health_bar()

func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	if _game == null:
		return
	_tick_hit_flash(delta)
	_tick_aura_bonus(delta)
	_tick_elite(delta)
	# Elite glow particles are decoration; a swarm off-screen does not need them.
	if _is_visible_to_camera():
		_tick_elite_glow_particles(delta)
	# FFA clients: the host owns enemy AI/damage; we only render the replicated
	# transform + visuals. Skip targeting, attacking, and movement integration.
	if _game.has_method("is_sim_authority") and not _game.is_sim_authority():
		_update_status_visuals()
		return
	# Knockback shove is independent of AI: it plays during stun/attack/move so
	# every hit registers as a physical flinch, then decays back to zero.
	var knockback_step := _consume_knockback(delta)
	if _stun_timer > 0.0:
		_stun_timer = max(0.0, _stun_timer - delta)
		velocity = knockback_step
		if knockback_step != Vector2.ZERO:
			move_and_slide()
		else:
			velocity = Vector2.ZERO
		_update_status_visuals()
		return
	var target = _get_cached_target(delta)
	if target == null or not is_instance_valid(target):
		if knockback_step != Vector2.ZERO:
			velocity = knockback_step
			move_and_slide()
		return
	var dist = global_position.distance_to(target.global_position)
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	if dist <= _effective_attack_range(target):
		if _attack_cooldown <= 0.0 and _has_attack_los(target):
			if target.has_method("take_damage"):
				target.take_damage(attack_damage)
			_attack_cooldown = 1.0 / max(0.1, attack_rate)
		velocity = knockback_step
		if knockback_step != Vector2.ZERO:
			move_and_slide()
	else:
		var dir: Vector2 = _get_move_direction(target.global_position, delta)
		velocity = dir * speed * _slow_multiplier + knockback_step
		move_and_slide()
	_update_status_visuals()

func _get_move_direction(target_pos: Vector2, delta: float) -> Vector2:
	"""Steer around obstacles by probing a few angles toward the target."""
	var base_dir = (target_pos - global_position).normalized()
	if base_dir == Vector2.ZERO:
		return Vector2.ZERO

	var preferred_dir = base_dir
	if _game != null and _game.has_method("get_flow_direction"):
		var flow_dir = _game.get_flow_direction(global_position)
		if flow_dir != Vector2.ZERO:
			preferred_dir = flow_dir

	var step = preferred_dir * speed * _slow_multiplier * max(delta, 0.016)
	if not test_move(global_transform, step):
		_steer_cooldown = 0.0
		return preferred_dir

	# Blocked. Probing 8 alternate headings costs 8 more physics queries, so with
	# a few hundred enemies in a maze this dominates the frame. The chosen
	# detour stays valid for a beat, so reuse it briefly instead of recomputing
	# every frame; re-probe early if the goal direction swings sharply.
	_steer_cooldown -= delta
	if _steer_cooldown > 0.0 and _steer_dir != Vector2.ZERO \
			and preferred_dir.dot(_steer_pref_dir) > 0.86:
		return _steer_dir

	var best_dir = preferred_dir
	var best_dist = INF
	for angle in STEER_ANGLES:
		if angle == 0.0:
			continue
		var candidate = preferred_dir.rotated(deg_to_rad(angle))
		var candidate_step = candidate * speed * _slow_multiplier * max(delta, 0.016)
		if test_move(global_transform, candidate_step):
			continue
		var probe_pos = global_position + candidate * 24.0
		var dist = probe_pos.distance_squared_to(target_pos)
		if dist < best_dist:
			best_dist = dist
			best_dir = candidate
	_steer_dir = best_dir
	_steer_pref_dir = preferred_dir
	# Staggered so the horde doesn't all re-probe on the same frame.
	_steer_cooldown = randf_range(0.10, 0.18)
	return best_dir

func _get_cached_target(delta: float) -> Node2D:
	"""Target selection is expensive and does not need to run every frame.

	Re-evaluating ~4x/second is imperceptible in play but cuts the cost by an
	order of magnitude with a large horde. The cache is dropped immediately if
	the current target dies so enemies never stall on a corpse."""
	_target_refresh_cooldown -= delta
	if _cached_target != null and not is_instance_valid(_cached_target):
		_cached_target = null
		_target_refresh_cooldown = 0.0
	if _cached_target == null or _target_refresh_cooldown <= 0.0:
		_cached_target = _find_target()
		# Stagger refreshes across the horde so they don't all recompute on the
		# same frame and cause a periodic hitch.
		_target_refresh_cooldown = randf_range(0.18, 0.32)
	return _cached_target

func _find_target() -> Node2D:
	if _game == null:
		return null

	# FFA: chase the NEAREST living player. Solo: this is just the one player.
	var player: Node2D = null
	if _game.has_method("get_nearest_player"):
		player = _game.get_nearest_player(global_position) as Node2D
	if player == null:
		player = _game.player as Node2D
	var best: Node2D = null
	var best_dist = INF
	var is_generator = false

	# Extraction mode: the extractor is the objective, so it outranks everything.
	# Enemies only peel off to swing at the player or allies that are close
	# enough to be in the way — otherwise they beeline for the objective.
	if _game.has_method("has_extractor") and _game.has_extractor():
		var ext := _game.extractor as Node2D
		if ext != null and is_instance_valid(ext):
			var ext_dist = global_position.distance_squared_to(ext.global_position)
			var interrupt_range = attack_range * 1.6
			# Something is close enough to be blocking the path — deal with it.
			if player != null and is_instance_valid(player) \
					and global_position.distance_squared_to(player.global_position) <= interrupt_range * interrupt_range:
				return player
			for ally in _allies_list():
				if ally == null or not is_instance_valid(ally):
					continue
				if global_position.distance_squared_to(ally.global_position) <= interrupt_range * interrupt_range:
					return ally
			var _unused = ext_dist
			return ext

	# First check: player
	if player != null and is_instance_valid(player):
		best = player
		best_dist = global_position.distance_squared_to(player.global_position)
		is_generator = false
	
	# Check allies (higher priority than generators, lower than player)
	for ally in _allies_list():
		if ally == null or not is_instance_valid(ally):
			continue
		var dist = global_position.distance_squared_to(ally.global_position)
		if dist < best_dist and dist <= aggro_range * aggro_range:
			best = ally
			best_dist = dist
			is_generator = false
	
	# Check generators (target if within aggro range)
	# Generators have lower priority than player/allies but will be attacked if closest
	for building in _buildings_list():
		if building == null or not is_instance_valid(building):
			continue
		# Only target resource generators
		if not building is ResourceGenerator:
			continue
		if building.has_method("is_destroyed") and building.is_destroyed():
			continue
		
		var dist = global_position.distance_squared_to(building.global_position)
		# Generators must be within aggro range to be targeted
		if dist <= aggro_range * aggro_range and dist < best_dist:
			best = building
			best_dist = dist
			is_generator = true
	
	if best == null:
		return player
	
	# For generators, they must be within aggro range
	# For player/allies, they can be targeted at any distance (player is always valid)
	if is_generator:
		if best_dist <= aggro_range * aggro_range:
			return best
		return player
	
	if best_dist <= aggro_range * aggro_range:
		return best
	return player

func _effective_attack_range(target: Node2D) -> float:
	"""Attack range measured to a target's *surface*, not its origin.

	Buildings are solid colliders, so an enemy pathing into a 2x2 structure
	physically stops ~footprint_radius away from its centre. Comparing raw
	distance-to-centre against attack_range meant large buildings could never be
	reached: enemies would crowd the extractor forever without ever swinging."""
	if target == null or not is_instance_valid(target):
		return attack_range
	if target.is_in_group("buildings") and target.has_method("get_footprint_radius"):
		return attack_range + float(target.get_footprint_radius())
	return attack_range

func _has_attack_los(target: Node2D) -> bool:
	"""True if no blocking building sits between this enemy and the target.

	Prevents melee enemies from damaging the player/allies *through* maze walls
	when they happen to be within attack_range on opposite sides of a structure.
	Building targets (the enemy is attacking the wall itself) always have LOS.
	"""
	if target == null or not is_instance_valid(target):
		return false
	if target.is_in_group("buildings"):
		return true
	var world = get_world_2d()
	if world == null:
		return true
	var params = PhysicsRayQueryParameters2D.create(global_position, target.global_position, GameLayers.BUILDING)
	params.exclude = [self]
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var hit = world.direct_space_state.intersect_ray(params)
	# A building between us and the target blocks the melee swing.
	return hit.is_empty()

func _create_health_bar() -> void:
	if _health_bar_bg != null:
		return
	_health_bar_bg = ColorRect.new()
	_health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	_health_bar_bg.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, HEALTH_BAR_OFFSET_Y)
	_health_bar_bg.color = Color(0.15, 0.15, 0.15, 0.7)
	_health_bar_bg.z_index = 15
	add_child(_health_bar_bg)

	_health_bar_fill = ColorRect.new()
	_health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	_health_bar_fill.position = Vector2.ZERO
	if is_elite:
		_health_bar_fill.color = Color(1.0, 0.85, 0.2, 0.9)  # Gold for elites
	elif is_siege:
		_health_bar_fill.color = Color(1.0, 0.3, 0.2, 0.9)  # Red for siege
	else:
		_health_bar_fill.color = Color(0.2, 0.9, 0.2, 0.9)  # Green default
	_health_bar_bg.add_child(_health_bar_fill)

func _update_health_bar() -> void:
	if _health_bar_fill == null:
		return
	var ratio = clampf(health / max_health, 0.0, 1.0)
	_health_bar_fill.size.x = HEALTH_BAR_WIDTH * ratio
	# Color shift: green → yellow → red as health drops
	if not is_elite:
		if ratio > 0.5:
			_health_bar_fill.color = Color(0.2, 0.9, 0.2, 0.9).lerp(Color(1.0, 0.9, 0.2, 0.9), 1.0 - ratio * 2.0)
		else:
			_health_bar_fill.color = Color(1.0, 0.9, 0.2, 0.9).lerp(Color(1.0, 0.2, 0.2, 0.9), 1.0 - ratio * 2.0)

func take_damage(amount: float, hit_position: Vector2 = Vector2.ZERO, show_hit_fx: bool = true, show_damage_number: bool = true, damage_type: String = "normal", hit_dir: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0.0:
		return
	var hit_pos = hit_position
	if hit_pos == Vector2.ZERO:
		hit_pos = global_position
	var now_ms = Time.get_ticks_msec()
	var will_die = health - amount <= 0.0
	var is_crit = _is_crit_hit(amount)

	# Per-hit flinch: white flash + a shove away from the impact. Skip if already
	# dying so the death sequence owns the visuals.
	if not _is_dying:
		_trigger_hit_flash(is_crit)
		var push_dir = hit_dir
		if push_dir == Vector2.ZERO and hit_position != Vector2.ZERO:
			push_dir = global_position - hit_position
		if push_dir != Vector2.ZERO:
			var kb = FeedbackConfig.HIT_KNOCKBACK_BASE
			if is_crit:
				kb *= FeedbackConfig.HIT_KNOCKBACK_CRIT_MULT
			if will_die:
				kb *= FeedbackConfig.HIT_KNOCKBACK_KILL_MULT
			apply_knockback(push_dir, kb)

	if will_die:
		# Play death sound
		AudioManager.play_impact_sound(is_crit, true, hit_pos)
	else:
		# Play hit sound
		AudioManager.play_impact_sound(is_crit, false, hit_pos)
	
	if show_hit_fx and FeedbackConfig.ENABLE_HIT_SPARKS and amount >= FeedbackConfig.HIT_SPARK_MIN_DAMAGE:
		var elapsed = float(now_ms - _last_hit_fx_ms) / 1000.0
		if elapsed >= FeedbackConfig.HIT_SPARK_COOLDOWN or is_crit or will_die:
			if _game != null and _game.has_method("spawn_fx"):
				var hit_kind = "hit"
				if is_crit:
					hit_kind = "crit"
				else:
					match damage_type:
						"fire":
							hit_kind = "fire_burst"
						"ice":
							hit_kind = "ice"
						"lightning":
							hit_kind = "chain_hit"
						"acid", "poison":
							hit_kind = "poison"
						"bleed":
							hit_kind = "blood"
				_game.spawn_fx(hit_kind, hit_pos)
			_last_hit_fx_ms = now_ms

	if show_damage_number and FeedbackConfig.ENABLE_DAMAGE_NUMBERS:
		var elapsed_num = float(now_ms - _last_damage_number_ms) / 1000.0
		if elapsed_num >= FeedbackConfig.DAMAGE_NUMBER_COOLDOWN or is_crit or will_die:
			if _game != null and _game.has_method("spawn_damage_number"):
				_game.spawn_damage_number(amount, hit_pos, max_health, is_crit, will_die, is_elite, damage_type)
			_last_damage_number_ms = now_ms

	health -= amount
	_update_health_bar()

	# Trigger hitstop on crit
	if is_crit and _game != null and _game.has_method("trigger_hitstop"):
		_game.trigger_hitstop()
	
	if health <= 0.0 and not _is_dying:
		_start_death_sequence()

func _start_death_sequence() -> void:
	_is_dying = true
	health = 0.0
	
	# Disable collision and AI
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# White flash
	if body != null:
		body.modulate = Color.WHITE
		
	# Particle burst on death
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("blood", global_position)
		if FeedbackConfig.ENABLE_DEATH_FEEDBACK:
			if is_elite or is_siege:
				if _game.has_method("spawn_setpiece_fx"):
					_game.spawn_setpiece_fx("elite_death", global_position, 1.15 if is_siege else 1.0)
				else:
					_game.spawn_fx("elite_kill", global_position)
			else:
				_game.spawn_fx("kill_pop", global_position)
			# Extra particle burst for satisfying death
			_game.spawn_glow_burst_death(global_position, _base_color)
	
	# Use FX Manager for enhanced death effects if available
	if _game != null and _game.fx_manager != null:
		var corpse_texture = null
		if body != null and body is Sprite2D:
			corpse_texture = (body as Sprite2D).texture
		_game.fx_manager.spawn_death_effect(self, _base_color, corpse_texture)
		# Gore spray on every kill for visceral, dopamine-rich feedback.
		if _game.fx_manager.has_method("spawn_gore_particles"):
			_game.fx_manager.spawn_gore_particles(global_position, _base_color)
		# Heavies erupt in a bigger burst.
		if (is_elite or is_siege) and _game.fx_manager.has_method("spawn_death_burst"):
			_game.fx_manager.spawn_death_burst(global_position, _base_color, 16)

	# Hide health bar on death
	if _health_bar_bg != null:
		_health_bar_bg.visible = false

	# Death animation sequence using tween (safety check)
	if not is_inside_tree():
		queue_free()
		return
	var tween = create_tween()

	if body != null:
		var orig_scale = body.scale
		# Pop UP briefly (satisfying squash & stretch)
		tween.tween_property(body, "scale", orig_scale * 1.3, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Then SLAM down to nothing
		tween.tween_property(body, "scale", orig_scale * 0.15, FeedbackConfig.DEATH_SCALE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		# Fade out overlapping with scale
		tween.parallel().tween_property(body, "modulate:a", 0.0, FeedbackConfig.DEATH_FADE_DURATION)

	# Elite/siege screen flash
	if (is_elite or is_siege) and _game != null and _game.has_method("flash_screen"):
		_game.flash_screen(Color(1.0, 0.9, 0.3, 0.15), 0.15)

	# Corpse fade delay then cleanup
	tween.tween_interval(FeedbackConfig.DEATH_CORPSE_FADE_DELAY)
	tween.tween_callback(_finish_death)
	
	# Spawn drops immediately (don't wait for animation)
	if _game != null:
		if is_elite and elite_modifier == "splitter" and not is_split_child:
			_spawn_split_minions()
		if _game.has_method("spawn_pickup"):
			var gold_amount = 2
			if is_siege:
				gold_amount = 4
			if is_elite:
				gold_amount = 6
			_game.spawn_pickup(global_position, gold_amount, "gold")
			if _game.has_method("should_spawn_heal_drop") and _game.should_spawn_heal_drop(is_elite, is_siege, "enemy", false):
				var heal_amount = 5
				if _game.has_method("get_heal_drop_amount"):
					heal_amount = int(_game.get_heal_drop_amount(is_elite, is_siege, "enemy", false))
				_game.spawn_pickup(global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8)), heal_amount, "heal")
		if is_elite and _game.has_method("spawn_treasure_chest"):
			_game.spawn_treasure_chest(global_position)
		# Essence drops from elite/siege kills (throttled to reduce clutter)
		if is_elite and randf() < 0.6 and _game.has_method("spawn_pickup"):
			_game.spawn_pickup(global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 1, "essence")
		if is_siege and not is_elite and randf() < 0.35 and _game.has_method("spawn_pickup"):
			_game.spawn_pickup(global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 1, "essence")
		var xp_reward = 1
		if is_siege:
			xp_reward = 3
		if is_elite:
			xp_reward = 5
		_game.add_xp(xp_reward)
		if _game.has_method("on_enemy_killed"):
			_game.on_enemy_killed(is_elite, is_siege)

func _finish_death() -> void:
	queue_free()

func _is_crit_hit(amount: float) -> bool:
	if not FeedbackConfig.ENABLE_CRIT_POP:
		return false
	var pct = FeedbackConfig.CRIT_PCT_MAX_HEALTH
	if is_elite:
		pct = FeedbackConfig.CRIT_PCT_ELITE
	var threshold = max(FeedbackConfig.CRIT_MIN_DAMAGE, max_health * pct)
	return amount >= threshold

func apply_slow(source_id: int, factor: float, duration: float = 0.0) -> void:
	_slow_sources[source_id] = clamp(factor, 0.1, 1.0)
	_recalc_slow()
	_update_status_visuals()
	if duration > 0.0:
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(func():
			remove_slow(source_id)
		)

func remove_slow(source_id: int) -> void:
	_slow_sources.erase(source_id)
	_recalc_slow()
	_update_status_visuals()

func _recalc_slow() -> void:
	_slow_multiplier = 1.0
	for factor in _slow_sources.values():
		_slow_multiplier = min(_slow_multiplier, float(factor))

func stun(duration: float) -> void:
	_stun_timer = max(_stun_timer, duration)
	_update_status_visuals()

func is_siege_unit() -> bool:
	return is_siege

func set_elite(multiplier: float) -> void:
	is_elite = true
	max_health *= multiplier
	health = max_health
	speed *= 1.1
	attack_damage *= 1.4
	if body != null:
		body.scale = body.scale * 1.35
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var shape: CircleShape2D = collision_shape.shape
		shape.radius *= 1.15
	var glow_color = Color(1.0, 0.8, 0.3)
	# Assign a random elite modifier
	var roll = randf()
	if roll < 0.34:
		elite_modifier = "aura"
		_base_color = _base_color.lerp(Color(1.0, 0.45, 0.25), 0.5)
		glow_color = Color(1.0, 0.5, 0.25)
	elif roll < 0.67:
		elite_modifier = "regen"
		_base_color = _base_color.lerp(Color(0.3, 1.0, 0.4), 0.5)
		glow_color = Color(0.3, 1.0, 0.5)
	else:
		elite_modifier = "splitter"
		_base_color = _base_color.lerp(Color(0.65, 0.55, 1.0), 0.5)
		glow_color = Color(0.7, 0.6, 1.0)
	if body != null:
		body.modulate = _base_color
	_create_elite_glow(glow_color)

func _tick_elite(delta: float) -> void:
	if not is_elite or elite_modifier == "" or _stun_timer > 0.0:
		return
	match elite_modifier:
		"regen":
			_process_regen(delta)
		"aura":
			_process_aura(delta)

func _process_regen(delta: float) -> void:
	if health < max_health:
		health = min(max_health, health + _regen_rate * delta)
		_update_health_bar()

func _process_aura(delta: float) -> void:
	_elite_mod_timer += delta
	if _elite_mod_timer < _aura_interval:
		return
	_elite_mod_timer = 0.0
	var radius_sq = _aura_radius * _aura_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_squared_to(enemy.global_position) > radius_sq:
			continue
		if "attack_damage" in enemy:
			if enemy.has_method("apply_aura_bonus"):
				enemy.apply_aura_bonus(_aura_damage_bonus, _aura_buff_duration)
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("summon_fire", global_position)

func _update_status_visuals() -> void:
	if body == null:
		return
	var stunned_now = _stun_timer > 0.0
	var slowed_now = not _slow_sources.is_empty()
	if stunned_now and not _was_stunned:
		if _game != null and _game.has_method("spawn_fx"):
			_game.spawn_fx("stun", global_position)
	if stunned_now == _was_stunned and slowed_now == _was_slowed:
		return
	_was_stunned = stunned_now
	_was_slowed = slowed_now
	if stunned_now:
		body.modulate = _base_color.lerp(Color(1.0, 0.9, 0.4), 0.6)
	elif slowed_now:
		body.modulate = _base_color.lerp(Color(0.5, 0.8, 1.0), 0.5)
	else:
		body.modulate = _base_color

func _trigger_hit_flash(is_crit: bool) -> void:
	if not FeedbackConfig.ENABLE_HIT_FLASH or body == null:
		return
	if is_crit:
		_hit_flash_duration = FeedbackConfig.HIT_FLASH_CRIT_DURATION
		_hit_flash_strength = FeedbackConfig.HIT_FLASH_CRIT_STRENGTH
	else:
		_hit_flash_duration = FeedbackConfig.HIT_FLASH_DURATION
		_hit_flash_strength = FeedbackConfig.HIT_FLASH_STRENGTH
	_hit_flash_timer = _hit_flash_duration

func _tick_hit_flash(delta: float) -> void:
	if _hit_flash_timer <= 0.0 or body == null:
		return
	_hit_flash_timer = max(0.0, _hit_flash_timer - delta)
	if _hit_flash_timer <= 0.0:
		# Flash done: hand modulate back to the status-visual state machine.
		_was_stunned = false
		_was_slowed = false
		_update_status_visuals()
		return
	# Owns body.modulate while active; fades the white tint out over its lifetime.
	var t = _hit_flash_timer / max(0.001, _hit_flash_duration)
	body.modulate = _base_color.lerp(Color.WHITE, _hit_flash_strength * t)

func apply_knockback(dir: Vector2, strength: float) -> void:
	if not FeedbackConfig.ENABLE_HIT_KNOCKBACK or dir == Vector2.ZERO or strength <= 0.0:
		return
	if is_siege:
		strength *= FeedbackConfig.HIT_KNOCKBACK_SIEGE_RESIST
	_knockback += dir.normalized() * strength
	if _knockback.length() > FeedbackConfig.HIT_KNOCKBACK_MAX:
		_knockback = _knockback.normalized() * FeedbackConfig.HIT_KNOCKBACK_MAX

func _consume_knockback(delta: float) -> Vector2:
	if _knockback == Vector2.ZERO:
		return Vector2.ZERO
	var step := _knockback
	# Exponential decay so the shove settles smoothly rather than snapping.
	_knockback = _knockback.lerp(Vector2.ZERO, clampf(FeedbackConfig.HIT_KNOCKBACK_DECAY * delta, 0.0, 1.0))
	if _knockback.length() < 4.0:
		_knockback = Vector2.ZERO
	return step

func apply_aura_bonus(amount: float, duration: float) -> void:
	if amount <= 0.0 or duration <= 0.0:
		return
	if _aura_bonus_amount < amount:
		attack_damage += amount - _aura_bonus_amount
		_aura_bonus_amount = amount
	_aura_bonus_timer = max(_aura_bonus_timer, duration)

func _tick_aura_bonus(delta: float) -> void:
	if _aura_bonus_timer <= 0.0:
		return
	_aura_bonus_timer = max(0.0, _aura_bonus_timer - delta)
	if _aura_bonus_timer == 0.0 and _aura_bonus_amount > 0.0:
		attack_damage = max(0.0, attack_damage - _aura_bonus_amount)
		_aura_bonus_amount = 0.0

func apply_split_child() -> void:
	is_split_child = true
	is_elite = false
	elite_modifier = ""
	max_health *= _split_child_health_mult
	health = max_health
	speed *= _split_child_speed_mult
	attack_damage *= _split_child_damage_mult
	if body != null:
		body.scale = body.scale * _split_child_scale
		body.modulate = _base_color.lerp(Color(0.9, 0.9, 1.0), 0.2)
		_base_color = body.modulate
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var shape: CircleShape2D = collision_shape.shape
		shape.radius *= _split_child_scale
	if _elite_glow != null:
		_elite_glow.queue_free()
		_elite_glow = null
	if _elite_glow_tween != null:
		_elite_glow_tween.kill()
		_elite_glow_tween = null

func _spawn_split_minions() -> void:
	if _game == null or not _game.has_method("spawn_split_minions"):
		return
	_game.spawn_split_minions(global_position, _split_child_count)

func create_siege_threat_ring() -> void:
	# Siege units get a steady red threat ring so the player can pick them
	# out of the horde at a glance (they hit buildings hard and move slow).
	if _elite_glow != null:
		return
	_create_elite_glow(Color(1.0, 0.25, 0.2))

func _create_elite_glow(_color: Color) -> void:
	# Aura/threat rings removed: in dense swarms the stacked ground rings buried the
	# action and destroyed readability. Elites/siege stay identifiable via their
	# tinted body. Gameplay aura buff logic (_process_aura) is unaffected.
	return

func _tick_elite_glow_particles(_delta: float) -> void:
	# Aura/threat glow particles removed alongside the rings for swarm readability.
	return
