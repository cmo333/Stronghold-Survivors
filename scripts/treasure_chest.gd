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

# The rarest thing in the table, and the only pull that is a *creature* rather
# than a stat. Deliberately one entry: a mythic is a story, not a category.
const MYTHIC_UPGRADES = {
	"golden_coco": {
		"name": "\u2728 GOLDEN COCO",
		"rarity": "mythic",
		"desc": "She hunts chests, gathers loot, and burns what she passes",
	},
	"rainbow_coco": {
		"name": "\U0001F308 RAINBOW COCO",
		"rarity": "mythic",
		"desc": "Everything the golden does, and every tower you own hits harder and faster",
	},
}
# Rolled before anything else and independently of the diamond slot, so a
# mythic run can also carry a diamond -- the jackpot should be able to stack.
const MYTHIC_CHANCE := 0.02


# Which mythic this chest may offer, given what the player already has.
#
# THE BUG THIS EXISTS TO FIX. The roll used to pick blindly from
# MYTHIC_UPGRADES, which held only the golden coco, while spawn_golden_coco()
# returns early if a companion is already out. So a second mythic pull printed
# the rarest card in the game, played the jackpot fanfare, consumed a slot from
# the chest's own budget (`count -= 1`) and then did NOTHING. A duplicate mythic
# was strictly worse than a common.
#
# It was not a rare edge case either: at 2% a chest, a run that opens 83 chests
# expects 1.66 mythics, so a second pull is the normal outcome of a long run and
# was reported from the first serious one.
#
# Order is fixed rather than random: golden first, rainbow second. The rainbow
# is an escalation of the golden and reads as one only if it arrives after her.
# Once both are out there is no third mythic, and returning "" makes the roll
# skip the mythic slot entirely so the chest spends it on a normal upgrade
# instead of burning it.
func _pick_mythic() -> String:
	var g = _game
	if g == null and is_inside_tree():
		g = get_tree().get_first_node_in_group("game")
	# No game reference is not the same as "nothing spawned yet". Falling back to
	# the golden would hand out a second inert one, which is the bug; falling
	# back to "" costs at most one mythic slot in a state that should not happen.
	if g == null or not is_instance_valid(g):
		return ""
	if not g.has_method("has_golden_coco") or not g.has_method("has_rainbow_coco"):
		return ""
	if not bool(g.has_golden_coco()):
		return "golden_coco"
	if not bool(g.has_rainbow_coco()):
		return "rainbow_coco"
	return ""

const RARITY_COLORS = {
	"common": Color(0.4, 0.9, 0.4),
	"rare": Color(0.3, 0.6, 1.0),
	"epic": Color(0.8, 0.3, 1.0),
	"diamond": Color(0.2, 1.0, 1.0),
	"mythic": Color(1.0, 0.82, 0.25),
}

const UPGRADE_COUNTS = [
	{"count": 2, "weight": 25},
	{"count": 3, "weight": 40},
	{"count": 4, "weight": 25},
	{"count": 5, "weight": 10},
]

@export var auto_open_delay = 0.25

# Static: only one chest can run modal resolution at a time.
static var _chest_modal_in_progress: bool = false

var _game: Node = null
var _player_in_range = false
var _opener_id: int = 0  # peer_id of the player opening (FFA score credit; 0 = local)
var _opened = false
var _opening = false
var _owns_modal = false
var _proximity_timer = 0.0
var _upgrades_to_grant: Array = []
var _charge_tweens: Array = []

@onready var body: Sprite2D = $Body
@onready var glow: Sprite2D = $Glow

# Lid states in the sprite strip, in order.
const FRAME_SHUT := 0
const FRAME_STRAIN := 1
const FRAME_CRACK := 2
const FRAME_OPEN := 3

func _set_body_frame(index: int) -> void:
	var spr := get_node_or_null("Body") as Sprite2D
	if spr != null and spr.hframes > index:
		spr.frame = index

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

# Safety net: if this chest is freed for any reason while it owns modal state, release it.
func _on_tree_exiting() -> void:
	_release_modal()

func _release_modal() -> void:
	if not _owns_modal:
		return
	_owns_modal = false
	_chest_modal_in_progress = false
	if _game != null and is_instance_valid(_game) and _game.has_method("end_chest_modal"):
		_game.call_deferred("end_chest_modal")

# Backward-compatible alias for older helper flow paths.
func _restore_time_scale() -> void:
	_release_modal()

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

	if _chest_modal_in_progress:
		_grant_all_upgrades_instant()
		_opened = true
		queue_free()
		return

	_chest_modal_in_progress = true
	_owns_modal = true
	if _game.has_method("begin_chest_modal"):
		_game.begin_chest_modal()
	if _game.has_method("add_resources"):
		_game.add_resources(bonus_gold, _opener_id)
	if _game.has_method("show_chest_summary"):
		_game.show_chest_summary(bonus_gold, _upgrades_to_grant.size())
	# Visual takeover and audio run together; await the visual since it is the
	# longer of the two and owns the screen.
	var ui_node = _game.get("ui")
	if ui_node != null and ui_node.has_method("play_chest_reveal"):
		_play_jackpot_sequence()
		await ui_node.play_chest_reveal(_upgrades_to_grant, _best_rarity())
	else:
		await _play_jackpot_sequence()
	_grant_all_upgrades_instant()
	_opened = true
	if is_inside_tree():
		await get_tree().create_timer(0.35, true, false, true).timeout
	_release_modal()
	queue_free()

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
	"mythic": "reveal_diamond",
}
const RARITY_RANK := {"common": 0, "rare": 1, "epic": 2, "diamond": 3, "mythic": 4}
# Per-rarity punch: screen flash alpha, camera shake, and how long the beat holds.
const RARITY_PUNCH := {
	"common": {"flash": 0.10, "shake": 2.0, "hold": 0.28},
	"rare": {"flash": 0.16, "shake": 4.5, "hold": 0.34},
	"epic": {"flash": 0.24, "shake": 7.5, "hold": 0.44},
	"diamond": {"flash": 0.40, "shake": 13.0, "hold": 0.75},
	"mythic": {"flash": 0.55, "shake": 18.0, "hold": 1.20},
}

func _best_rarity() -> String:
	var best := "common"
	for u in _upgrades_to_grant:
		var r := str(u.get("rarity", "common"))
		if int(RARITY_RANK.get(r, 0)) > int(RARITY_RANK.get(best, 0)):
			best = r
	return best

func _play_jackpot_sequence() -> void:
	"""Audio + world FX, timed to the full-screen reveal in ui.gd.

	The visual takeover runs in parallel (started by the caller) — this drives
	the sound and camera so every audio beat lands on its matching visual beat.
	"""
	if not is_inside_tree():
		return
	var best := _best_rarity()

	# 1. Anticipation. The riser's tremolo accelerates, so the pause before the
	#    first reveal is doing real work — never cut this short.
	AudioManager.play_one_shot("chest_charge", global_position, AudioManager.HIGH_PRIORITY)
	_animate_charge_up()
	await get_tree().create_timer(0.85, true, false, true).timeout
	if not is_inside_tree():
		return

	# 2. Burst open + coin payout.
	_kill_charge_tweens()
	_set_body_frame(FRAME_OPEN)
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
		# Matches the card slam timing in ui.play_chest_reveal().
		await get_tree().create_timer(0.3 + rank * 0.12, true, false, true).timeout

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

func _animate_charge_up() -> void:
	"""Chest rattles, strains and swells while the riser builds.

	Both tweens ignore time scale. `begin_chest_modal()` sets
	`Engine.time_scale` to 0 for the duration of the reveal, so a plain tween
	here never advances a single step -- the world chest sat perfectly still
	through its own charge-up while the audio built around it.
	"""
	if not is_inside_tree():
		return
	var spr := get_node_or_null("Body")
	if spr == null:
		return
	var base_scale: Vector2 = spr.scale
	_kill_charge_tweens()
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(false)
	# Accelerating shake: five shorter, bigger wobbles, with the lid giving way
	# partway through so the chest escalates rather than just vibrating. The
	# wobbles shorten as they go, so the frame changes hang off indices 1 and 2
	# (~0.32s and ~0.60s) -- the whole charge phase is only 0.85s, and anything
	# later fires after the burst has already opened the lid.
	for i in range(5):
		var amp := 2.0 + float(i) * 1.6
		var dur := 0.16 - float(i) * 0.02
		if i == 1:
			tw.tween_callback(_set_body_frame.bind(FRAME_STRAIN))
		elif i == 2:
			tw.tween_callback(_set_body_frame.bind(FRAME_CRACK))
		tw.tween_property(spr, "position:x", amp, dur * 0.5).as_relative().set_trans(Tween.TRANS_SINE)
		tw.tween_property(spr, "position:x", -amp * 2.0, dur).as_relative().set_trans(Tween.TRANS_SINE)
		tw.tween_property(spr, "position:x", amp, dur * 0.5).as_relative().set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween()
	tw2.set_ignore_time_scale(true)
	tw2.tween_property(spr, "scale", base_scale * 1.35, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.parallel().tween_property(spr, "modulate", Color(2.2, 2.0, 1.4), 0.8)
	_charge_tweens = [tw, tw2]

func _kill_charge_tweens() -> void:
	"""Stop the charge-up before the burst.

	The shake tween runs 1.20s but the charge phase is 0.85s, so left alive it
	keeps swelling the chest after it has opened and its trailing frame
	callback stamps the cracked lid back over the open one.
	"""
	for t in _charge_tweens:
		if t != null and is_instance_valid(t) and t.is_valid():
			t.kill()
	_charge_tweens.clear()

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
		# Squash relative to the body's authored base scale so the pop scales with
		# the chest size instead of snapping it back to ~1x.
		open_tween.parallel().tween_property(body, "scale", body.scale * Vector2(1.1, 0.9), 0.1).set_trans(Tween.TRANS_ELASTIC)

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
	
	# Mythic first: it takes a slot from the same budget, so a mythic pull is
	# genuinely rarer loot rather than a free extra on top.
	#
	# Which mythic depends on what is already on the field, and that is the whole
	# point -- see _pick_mythic.
	if randf() < MYTHIC_CHANCE:
		var mythic_key := _pick_mythic()
		if mythic_key != "":
			var mythic_upgrade = MYTHIC_UPGRADES[mythic_key].duplicate()
			mythic_upgrade["id"] = mythic_key
			result.append(mythic_upgrade)
			count -= 1

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
