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
	"tower_core_damage": {"name": "Warheads", "rarity": "rare", "value": 3, "desc": "+3 tower damage"},
	"tower_targeting": {"name": "Targeting Uplink", "rarity": "rare", "value": 1.10, "desc": "+10% tower fire rate"},
	"multishot": {"name": "Double Tap", "rarity": "epic", "value": 1, "desc": "Fire 2 projectiles"},
	"explosive": {"name": "Combustion", "rarity": "epic", "value": 1, "desc": "Projectiles explode on hit"},
	"chain": {"name": "Arc", "rarity": "epic", "value": 3, "desc": "Lightning chains to 3 targets"},
	"vampiric": {"name": "Life Drain", "rarity": "epic", "value": 0.08, "desc": "Heal 8% of damage dealt"},
	"tower_barrage": {"name": "Orbital Barrage", "rarity": "epic", "value": 1.18, "desc": "+18% tower fire rate and +2 damage"},
}

const DIAMOND_UPGRADES = {
	"multishot_split": {"name": "📌 Multishot", "rarity": "diamond", "desc": "Projectiles split into 2 on hit"},
	"vampiric_heart": {"name": "💎 Vampiric", "rarity": "diamond", "desc": "Lifesteal 15% of damage dealt"},
	"chain_master": {"name": "⚡ Chain Lord", "rarity": "diamond", "desc": "Tesla bounces to 5 extra targets"},
	"time_dilation": {"name": "⏱️ Chronos", "rarity": "diamond", "desc": "Tech pick slow-mo lasts 2x longer"},
	"phoenix": {"name": "🔥 Phoenix", "rarity": "diamond", "desc": "Once per wave, survive at 1 HP"},
	"fortress": {"name": "🏰 Fortress", "rarity": "diamond", "desc": "Towers gain +50% HP and self-repair"},
	"orbital_matrix": {"name": "🛰️ Orbital Matrix", "rarity": "diamond", "desc": "Towers gain +35% fire rate, +10 damage, +20% range"},
}

const RARITY_COLORS = {
	"common": Color(0.4, 0.9, 0.4),
	"rare": Color(0.3, 0.6, 1.0),
	"epic": Color(0.8, 0.3, 1.0),
	"diamond": Color(0.2, 1.0, 1.0),
}

const UPGRADE_COUNTS = [
	{"count": 2, "weight": 25},
	{"count": 3, "weight": 40},
	{"count": 4, "weight": 25},
	{"count": 5, "weight": 10},
]

@export var auto_open_delay = 0.25

var _game: Node = null
var _player_in_range = false
var _opener_id: int = 0  # peer_id of the player opening (FFA score credit; 0 = local)
var _opened = false
var _opening = false
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
	_start_glow_pulse()

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
		# FFA: chests/pickups only exist on the host's sim, so EVERY player body
		# (the local player, remote proxies, and bots) physically overlaps this
		# chest here. Only the LOCAL player may open it — otherwise a bot or a
		# remote player walking past would auto-open the chest and flash the
		# modal/screen FX on THIS machine's screen (the reported bug). Remote/bot
		# players open their own chests on their own machines.
		if not _is_local_player_body(body_node):
			return
		_player_in_range = true
		_proximity_timer = 0.0
		# Remember who is opening so FFA credits the right player's score.
		if "peer_id" in body_node:
			_opener_id = int(body_node.peer_id)

func _on_body_exited(body_node: Node) -> void:
	if body_node.is_in_group("player"):
		if not _is_local_player_body(body_node):
			return
		_player_in_range = false
		_proximity_timer = 0.0

# True only for the player this machine controls. In solo there is a single
# player and it always qualifies. In FFA we compare against _game.local_player
# (falling back to a peer_id match) so bots/remote proxies are ignored.
func _is_local_player_body(body_node: Node) -> bool:
	if _game == null and is_inside_tree():
		_game = get_tree().get_first_node_in_group("game")
	if _game == null or not is_instance_valid(_game):
		return true
	# Solo: the only player is local.
	if _game.has_method("is_solo") and _game.is_solo():
		return true
	# Never let host-driven bots trip the chest.
	if "is_bot" in body_node and bool(body_node.is_bot):
		return false
	var lp = _game.local_player if "local_player" in _game else null
	if lp != null and is_instance_valid(lp):
		return body_node == lp
	# Fallback: compare peer ids if local_player isn't bound yet.
	if "peer_id" in body_node and _game.has_method("local_player_id"):
		return int(body_node.peer_id) == int(_game.local_player_id())
	return true

func _start_open() -> void:
	if _opened or _opening:
		return
	_opening = true
	_upgrades_to_grant = _roll_upgrades()
	# Bonus gold on every chest open (50-150).
	var bonus_gold = randi_range(50, 150)
	if _game == null and is_inside_tree():
		_game = get_tree().get_first_node_in_group("game")
	if _game == null or not is_instance_valid(_game) or not _game.is_inside_tree():
		queue_free()
		return

	# Count this chest toward the run scorecard exactly once, before either the
	# fast-path or the modal branch below.
	if _game.has_method("on_treasure_opened"):
		_game.on_treasure_opened(_opener_id)

	# Rewards land immediately and the run never stops. The chest used to freeze
	# the game and hand the screen to a full-screen card reveal; it interrupted
	# the fight for several seconds to restate what the banner already says, so
	# it is gone. The world-space payoff stays - it plays over live combat.
	if _game.has_method("add_resources"):
		_game.add_resources(bonus_gold, _opener_id)
	if _game.has_method("show_chest_summary"):
		_game.show_chest_summary(bonus_gold, _upgrades_to_grant.size())
	_grant_all_upgrades_instant()
	_opened = true
	# Burst, coins and the per-item beats run unawaited: the chest node has to
	# survive them, so it frees itself when the sequence finishes rather than
	# here.
	_play_jackpot_sequence()

# ============================================
# JACKPOT PRESENTATION
# A chest is the biggest dopamine beat in the run, so it gets the slot-machine
# treatment: tension that builds, one escalating reveal per item, and a payoff
# scaled to the best thing that dropped.
# ============================================

const REVEAL_SOUNDS := {
	"common": "reveal_common",
	"rare": "reveal_rare",
	"epic": "reveal_epic",
	"diamond": "reveal_diamond",
}
const RARITY_RANK := {"common": 0, "rare": 1, "epic": 2, "diamond": 3}
# Per-rarity punch: screen flash alpha, camera shake, and how long the beat holds.
const RARITY_PUNCH := {
	"common": {"flash": 0.10, "shake": 2.0, "hold": 0.28},
	"rare": {"flash": 0.16, "shake": 4.5, "hold": 0.34},
	"epic": {"flash": 0.24, "shake": 7.5, "hold": 0.44},
	"diamond": {"flash": 0.40, "shake": 13.0, "hold": 0.75},
}

func _best_rarity() -> String:
	var best := "common"
	for u in _upgrades_to_grant:
		var r := str(u.get("rarity", "common"))
		if int(RARITY_RANK.get(r, 0)) > int(RARITY_RANK.get(best, 0)):
			best = r
	return best

func _play_jackpot_sequence() -> void:
	"""Audio + world FX for an opened chest, played over live combat.

	This used to be timed against a full-screen reveal that froze the run. With
	that gone the beats have to earn their place while the player is still being
	shot at, so the anticipation is short and every beat is world-space: sound,
	particles at the chest, and camera shake.

	Frees the chest when it finishes - the node has to outlive its own effects.
	"""
	if not is_inside_tree():
		queue_free()
		return
	var best := _best_rarity()

	# 1. Anticipation. Brief now: there is no modal holding the player still, so
	#    a long riser is just a delay between opening the chest and the payoff.
	AudioManager.play_one_shot("chest_charge", global_position, AudioManager.HIGH_PRIORITY)
	_animate_charge_up()
	await get_tree().create_timer(0.25, true, false, true).timeout
	if not is_inside_tree():
		return

	# 2. Burst open + coin payout.
	AudioManager.play_one_shot("chest_open", global_position, AudioManager.HIGH_PRIORITY)
	AudioManager.play_one_shot("coin_cascade", global_position, AudioManager.DEFAULT_PRIORITY)
	_burst(Color(1.0, 0.9, 0.5), 26, 1.0)
	if _game != null and _game.has_method("shake_camera"):
		_game.shake_camera(5.0, 0.25)
	await get_tree().create_timer(0.28, true, false, true).timeout
	if not is_inside_tree():
		return

	# 3. One beat per item, escalating. Rarity drives sound, colour, flash,
	#    shake and hold time together so a great drop is unmistakable.
	for i in range(_upgrades_to_grant.size()):
		if not is_inside_tree():
			return
		var upgrade: Dictionary = _upgrades_to_grant[i]
		var rarity := str(upgrade.get("rarity", "common"))
		var rank := int(RARITY_RANK.get(rarity, 0))
		var punch: Dictionary = RARITY_PUNCH.get(rarity, RARITY_PUNCH["common"])
		var color: Color = RARITY_COLORS.get(rarity, Color.WHITE)

		AudioManager.play_one_shot(str(REVEAL_SOUNDS.get(rarity, "reveal_common")),
			global_position, AudioManager.HIGH_PRIORITY)
		_burst(color, 10 + rank * 10, 0.7 + float(rank) * 0.35)
		if _game != null and _game.has_method("shake_camera"):
			_game.shake_camera(float(punch["shake"]), 0.28)
		await get_tree().create_timer(0.24 + rank * 0.1, true, false, true).timeout

	# 4. Payoff. Only a genuinely rare drop earns the fanfare — firing it on
	#    every chest would make it wallpaper.
	if not is_inside_tree():
		return
	if int(RARITY_RANK.get(best, 0)) >= int(RARITY_RANK["epic"]):
		AudioManager.play_one_shot("jackpot_fanfare", global_position, AudioManager.CRITICAL_PRIORITY)
		var jc: Color = RARITY_COLORS.get(best, Color(1.0, 0.9, 0.4))
		_burst(jc, 60, 2.0)
		if _game != null and _game.has_method("shake_camera"):
			_game.shake_camera(11.0, 0.5)
		await get_tree().create_timer(0.75, true, false, true).timeout

	if is_inside_tree():
		queue_free()

func _animate_charge_up() -> void:
	"""Chest rattles and swells while the riser builds."""
	if not is_inside_tree():
		return
	var spr := get_node_or_null("Body")
	if spr == null:
		return
	var base_scale: Vector2 = spr.scale
	var tw := create_tween()
	tw.set_parallel(false)
	# Accelerating shake: five shorter, bigger wobbles.
	for i in range(5):
		var amp := 2.0 + float(i) * 1.6
		var dur := 0.16 - float(i) * 0.02
		tw.tween_property(spr, "position:x", amp, dur * 0.5).as_relative().set_trans(Tween.TRANS_SINE)
		tw.tween_property(spr, "position:x", -amp * 2.0, dur).as_relative().set_trans(Tween.TRANS_SINE)
		tw.tween_property(spr, "position:x", amp, dur * 0.5).as_relative().set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween()
	tw2.tween_property(spr, "scale", base_scale * 1.35, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.parallel().tween_property(spr, "modulate", Color(2.2, 2.0, 1.4), 0.8)

func _burst(color: Color, count: int, scale_mult: float) -> void:
	if _game == null or not _game.has_method("spawn_glow_particle"):
		return
	for i in range(count):
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var vel := dir * randf_range(70.0, 260.0) * scale_mult
		_game.spawn_glow_particle(global_position, color,
			randf_range(7.0, 15.0) * scale_mult, randf_range(0.7, 1.3),
			vel, 2.5, 0.7, 1.2, 5)

# Fast path: grant all upgrades without animation (used when another chest is mid-animation)
func _grant_all_upgrades_instant() -> void:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	if _game == null or not is_instance_valid(_game) or not _game.is_inside_tree():
		return
	for upgrade in _upgrades_to_grant:
		var id = upgrade.get("id", "")
		if _game.has_method("apply_chest_upgrade"):
			_game.apply_chest_upgrade(id, upgrade)

# Vampire Survivors style dramatic opening sequence
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
	
	var has_diamond = randf() < 0.10
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
	if rarity_roll < 0.18:
		target_rarity = "epic"
	elif rarity_roll < 0.55:
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
