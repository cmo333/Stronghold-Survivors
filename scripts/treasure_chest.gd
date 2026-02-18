extends Area2D

# Upgrade definitions (same as before)
const UPGRADES = {
	"gun_damage": {"name": "Firepower", "rarity": "common", "value": 1.15, "desc": "+15% gun damage"},
	"tower_range": {"name": "Reach", "rarity": "common", "value": 1.12, "desc": "+12% tower range"},
	"speed": {"name": "Swiftness", "rarity": "common", "value": 1.10, "desc": "+10% move speed"},
	"max_hp": {"name": "Vitality", "rarity": "common", "value": 1.20, "desc": "+20% max HP"},
	"build_cost": {"name": "Efficiency", "rarity": "common", "value": 0.85, "desc": "-15% build cost"},
	"reload_speed": {"name": "Quickload", "rarity": "common", "value": 0.90, "desc": "-10% reload time"},
	"crit_chance": {"name": "Precision", "rarity": "rare", "value": 0.08, "desc": "+8% crit chance"},
	"crit_damage": {"name": "Devastation", "rarity": "rare", "value": 1.25, "desc": "+25% crit damage"},
	"pierce": {"name": "Penetration", "rarity": "rare", "value": 1, "desc": "+1 pierce"},
	"cooldown": {"name": "Haste", "rarity": "rare", "value": 0.88, "desc": "-12% cooldowns"},
	"pickup_range": {"name": "Magnetism", "rarity": "rare", "value": 1.30, "desc": "+30% pickup range"},
	"multishot": {"name": "Double Tap", "rarity": "epic", "value": 1, "desc": "Fire 2 projectiles"},
	"explosive": {"name": "Combustion", "rarity": "epic", "value": 1, "desc": "Projectiles explode on hit"},
	"chain": {"name": "Arc", "rarity": "epic", "value": 3, "desc": "Lightning chains to 3 targets"},
	"vampiric": {"name": "Life Drain", "rarity": "epic", "value": 0.08, "desc": "Heal 8% of damage dealt"},
}

const DIAMOND_UPGRADES = {
	"multishot_split": {"name": "📌 Multishot", "rarity": "diamond", "desc": "Projectiles split into 2 on hit"},
	"vampiric_heart": {"name": "💎 Vampiric", "rarity": "diamond", "desc": "Lifesteal 15% of damage dealt"},
	"chain_master": {"name": "⚡ Chain Lord", "rarity": "diamond", "desc": "Tesla bounces to 5 extra targets"},
	"time_dilation": {"name": "⏱️ Chronos", "rarity": "diamond", "desc": "Tech pick slow-mo lasts 2x longer"},
	"phoenix": {"name": "🔥 Phoenix", "rarity": "diamond", "desc": "Once per wave, survive at 1 HP"},
	"fortress": {"name": "🏰 Fortress", "rarity": "diamond", "desc": "Towers gain +50% HP and self-repair"},
}

const RARITY_COLORS = {
	"common": Color(0.4, 0.9, 0.4),
	"rare": Color(0.3, 0.6, 1.0),
	"epic": Color(0.8, 0.3, 1.0),
	"diamond": Color(0.2, 1.0, 1.0),
}

const UPGRADE_COUNTS = [
	{"count": 1, "weight": 20},
	{"count": 2, "weight": 35},
	{"count": 3, "weight": 30},
	{"count": 4, "weight": 12},
	{"count": 5, "weight": 3},
]

@export var auto_open_delay = 0.25

# Static: only one chest can run the slow-mo animation at a time
static var _chest_opening: bool = false
static var _saved_time_scale: float = 1.0

var _game: Node = null
var _player_in_range = false
var _opened = false
var _opening = false
var _owns_time_scale = false  # True if THIS chest set Engine.time_scale
var _proximity_timer = 0.0
var _upgrades_to_grant: Array = []

@onready var body: Sprite2D = $Body
@onready var glow: Sprite2D = $Glow

func setup(game_ref: Node) -> void:
	_game = game_ref

func _ready() -> void:
	add_to_group("treasure_chests")
	collision_layer = 0
	collision_mask = GameLayers.PLAYER
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	tree_exiting.connect(_on_tree_exiting)
	_start_glow_pulse()

# Safety net: if this chest is freed for ANY reason while it owns time_scale, restore it
func _on_tree_exiting() -> void:
	if _owns_time_scale:
		_restore_time_scale()

func _restore_time_scale() -> void:
	if _owns_time_scale:
		_owns_time_scale = false
		_chest_opening = false
		Engine.time_scale = _saved_time_scale

func _process(delta: float) -> void:
	if _opened or _opening:
		return
	if _player_in_range:
		_proximity_timer += delta
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			_start_open()
			return
		if _proximity_timer >= auto_open_delay:
			_start_open()

func _on_body_entered(body_node: Node) -> void:
	if body_node.is_in_group("player"):
		_player_in_range = true
		_proximity_timer = 0.0

func _on_body_exited(body_node: Node) -> void:
	if body_node.is_in_group("player"):
		_player_in_range = false
		_proximity_timer = 0.0

func _start_open() -> void:
	if _opened or _opening:
		return
	_opening = true
	_upgrades_to_grant = _roll_upgrades()

	# If another chest is already animating, skip the slow-mo sequence entirely
	# Just grant upgrades instantly to avoid time_scale corruption
	if _chest_opening:
		_grant_all_upgrades_instant()
		_opened = true
		queue_free()
		return

	# This chest owns the slow-mo animation
	_chest_opening = true
	_owns_time_scale = true
	_saved_time_scale = Engine.time_scale
	Engine.time_scale = 0.15  # Super slow mo during opening

	_play_vs_opening_sequence()

# Fast path: grant all upgrades without animation (used when another chest is mid-animation)
func _grant_all_upgrades_instant() -> void:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	if _game == null or not is_instance_valid(_game) or not _game.is_inside_tree():
		return
	for upgrade in _upgrades_to_grant:
		var id = upgrade.get("id", "")
		if _game.has_method("apply_chest_upgrade"):
			_game.call_deferred("apply_chest_upgrade", id, upgrade)
		if _game.has_method("show_floating_text"):
			var rarity = upgrade.get("rarity", "common")
			var color = RARITY_COLORS.get(rarity, Color.WHITE)
			_game.call_deferred("show_floating_text", upgrade.get("name", ""), global_position + Vector2(0, -40), color)

# Vampire Survivors style dramatic opening sequence
func _play_vs_opening_sequence() -> void:
	if _game == null:
		if is_inside_tree():
			_game = get_tree().get_first_node_in_group("game")

	# PHASE 1: Build anticipation - chest glows brighter
	if glow != null and is_inside_tree():
		var bright_tween = create_tween()
		bright_tween.set_speed_scale(1.0 / max(Engine.time_scale, 0.01))
		bright_tween.tween_property(glow, "modulate", Color(1.0, 0.9, 0.4, 0.9), 0.3)
		bright_tween.parallel().tween_property(glow, "scale", Vector2.ONE * 1.4, 0.3)

	# Big particle burst
	if _game != null and _game.has_method("spawn_glow_particle"):
		for i in range(20):
			var angle = (TAU / 20.0) * i
			var dir = Vector2.RIGHT.rotated(angle)
			var vel = dir * randf_range(150.0, 300.0)
			var color = Color(1.0, 0.85, 0.3).lerp(Color.WHITE, randf_range(0.2, 0.5))
			_game.spawn_glow_particle(global_position, color, randf_range(12.0, 20.0), 1.2, vel, 3.0, 0.8, 1.3, 5)

	# Wait for anticipation
	if not is_inside_tree():
		_grant_all_upgrades_instant()
		_restore_time_scale()
		return
	await get_tree().create_timer(0.4 * max(Engine.time_scale, 0.01)).timeout
	if not is_inside_tree():
		# tree_exiting signal handles time_scale restore
		return

	# PHASE 2: Chest bursts open with screen shake
	AudioManager.play_one_shot("chest_open", global_position, AudioManager.HIGH_PRIORITY)

	if body != null and is_inside_tree():
		var open_tween = create_tween()
		open_tween.set_speed_scale(1.0 / max(Engine.time_scale, 0.01))
		open_tween.tween_property(body, "rotation", -0.6, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		open_tween.parallel().tween_property(body, "scale", Vector2(1.1, 0.9), 0.1).set_trans(Tween.TRANS_ELASTIC)

	if _game != null and _game.has_method("shake_camera"):
		_game.shake_camera(8.0)
	if _game != null and _game.has_method("flash_screen"):
		_game.flash_screen(Color(1.0, 0.9, 0.4, 0.4), 0.2)

	# Wait for open animation
	if not is_inside_tree():
		_grant_all_upgrades_instant()
		_restore_time_scale()
		return
	await get_tree().create_timer(0.3 * max(Engine.time_scale, 0.01)).timeout
	if not is_inside_tree():
		return

	# PHASE 3: Items fly out one by one (VS style)
	await _reveal_items_vs_style()

	# Always restore time scale and clean up
	_restore_time_scale()
	_opened = true
	queue_free()

func _reveal_items_vs_style() -> void:
	if _game == null:
		return

	var item_count = _upgrades_to_grant.size()
	var spread_angle = min(PI * 0.6, item_count * 0.3)
	var start_angle = -spread_angle / 2.0

	for i in range(item_count):
		var upgrade = _upgrades_to_grant[i]
		var rarity = upgrade.get("rarity", "common")
		var color = RARITY_COLORS.get(rarity, Color.WHITE)

		var angle = start_angle + (spread_angle / (item_count - 1 if item_count > 1 else 1)) * i
		var fly_direction = Vector2.RIGHT.rotated(angle - PI/2)
		var target_pos = global_position + fly_direction * 120.0

		_spawn_floating_item(upgrade, target_pos, color, i)

		# Pause between items for drama
		if not is_inside_tree():
			# Grant any remaining upgrades we haven't shown yet
			for j in range(i + 1, item_count):
				var remaining = _upgrades_to_grant[j]
				var rid = remaining.get("id", "")
				if _game != null and is_instance_valid(_game) and _game.is_inside_tree() and _game.has_method("apply_chest_upgrade"):
					_game.call_deferred("apply_chest_upgrade", rid, remaining)
			return
		await get_tree().create_timer(0.5 * max(Engine.time_scale, 0.01)).timeout
		if not is_inside_tree():
			for j in range(i + 1, item_count):
				var remaining = _upgrades_to_grant[j]
				var rid = remaining.get("id", "")
				if _game != null and is_instance_valid(_game) and _game.is_inside_tree() and _game.has_method("apply_chest_upgrade"):
					_game.call_deferred("apply_chest_upgrade", rid, remaining)
			return

	# Final burst after all items
	if _game != null and _game.has_method("spawn_glow_particle"):
		for i in range(30):
			var dir = Vector2.RIGHT.rotated(randf() * TAU)
			var vel = dir * randf_range(50.0, 200.0)
			var color = Color(1.0, 1.0, 0.5)
			_game.spawn_glow_particle(global_position, color, randf_range(8.0, 16.0), 1.0, vel, 2.5, 0.7, 1.2, 5)

func _spawn_floating_item(upgrade: Dictionary, target_pos: Vector2, color: Color, index: int) -> void:
	var rarity = upgrade.get("rarity", "common")
	var display_name = upgrade.get("name", "")
	
	# Create floating label (VS style item name)
	if _game != null and is_instance_valid(_game) and _game.is_inside_tree() and _game.has_method("show_floating_text"):
		# Main item text
		var prefix = ""
		if rarity == "diamond":
			prefix = "💎 "
		elif rarity == "epic":
			prefix = "✦ "
		
		_game.call_deferred("show_floating_text", prefix + display_name, target_pos, color)
		
		# Apply the upgrade immediately (VS auto-collects)
		var id = upgrade.get("id", "")
		_game.call_deferred("apply_chest_upgrade", id, upgrade)
	
	# Rarity-specific effects
	match rarity:
		"diamond":
			if _game != null and _game.has_method("shake_camera"):
				_game.shake_camera(10.0)
			if _game != null and _game.has_method("flash_screen"):
				_game.flash_screen(Color(0.2, 1.0, 1.0, 0.5), 0.4)
			# Diamond particle ring
			if _game != null and _game.has_method("spawn_glow_particle"):
				for j in range(16):
					var angle = (TAU / 16.0) * j
					var dir = Vector2.RIGHT.rotated(angle)
					var vel = dir * 100.0
					_game.spawn_glow_particle(target_pos, color, 15.0, 1.0, vel, 3.0, 0.8, 1.2, 5)
		"epic":
			if _game != null and _game.has_method("spawn_glow_particle"):
				for j in range(10):
					var dir = Vector2.RIGHT.rotated(randf() * TAU)
					var vel = dir * randf_range(40.0, 100.0)
					_game.spawn_glow_particle(target_pos, color, 10.0, 0.8, vel, 2.5, 0.7, 1.0, 5)
		"rare":
			if _game != null and _game.has_method("spawn_glow_particle"):
				for j in range(6):
					var dir = Vector2.RIGHT.rotated(randf() * TAU)
					var vel = dir * randf_range(30.0, 70.0)
					_game.spawn_glow_particle(target_pos, color, 7.0, 0.6, vel, 2.0, 0.6, 0.9, 5)
		_:
			if _game != null and _game.has_method("spawn_glow_particle"):
				for j in range(4):
					var dir = Vector2.RIGHT.rotated(randf() * TAU)
					var vel = dir * randf_range(20.0, 50.0)
					_game.spawn_glow_particle(target_pos, color, 5.0, 0.5, vel, 1.5, 0.5, 0.8, 5)

func _roll_upgrades() -> Array:
	var result = []
	
	var total_weight = 0
	for entry in UPGRADE_COUNTS:
		total_weight += entry.weight
	
	var roll = randi_range(1, total_weight)
	var count = 1
	var cumulative = 0
	for entry in UPGRADE_COUNTS:
		cumulative += entry.weight
		if roll <= cumulative:
			count = entry.count
			break
	
	var has_diamond = randf() < 0.05
	if has_diamond:
		var diamond_keys = DIAMOND_UPGRADES.keys()
		var diamond_key = diamond_keys[randi_range(0, diamond_keys.size() - 1)]
		var diamond_upgrade = DIAMOND_UPGRADES[diamond_key].duplicate()
		diamond_upgrade["id"] = diamond_key
		result.append(diamond_upgrade)
		count -= 1
	
	for i in range(count):
		result.append(_roll_regular_upgrade())
	
	return result

func _roll_regular_upgrade() -> Dictionary:
	var rarity_roll = randf()
	var target_rarity = "common"
	if rarity_roll < 0.10:
		target_rarity = "epic"
	elif rarity_roll < 0.40:
		target_rarity = "rare"
	
	var candidates = []
	for key in UPGRADES.keys():
		if UPGRADES[key].rarity == target_rarity:
			var upgrade = UPGRADES[key].duplicate()
			upgrade["id"] = key
			candidates.append(upgrade)
	
	if candidates.is_empty():
		for key in UPGRADES.keys():
			if UPGRADES[key].rarity == "common":
				var upgrade = UPGRADES[key].duplicate()
				upgrade["id"] = key
				candidates.append(upgrade)
	
	return candidates[randi_range(0, candidates.size() - 1)]

func _start_glow_pulse() -> void:
	if glow == null:
		return
	if not is_inside_tree():
		return
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	var base_scale = glow.scale
	var bright = glow.modulate
	bright.a = 0.7
	var dim = glow.modulate
	dim.a = 0.35
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(glow, "scale", base_scale * 1.15, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(glow, "modulate", bright, 0.6)
	tween.tween_property(glow, "scale", base_scale, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(glow, "modulate", dim, 0.6)
