extends Node2D

# The golden coco: a mythic chest pull that runs the map for you.
#
# Three jobs, in priority order:
#   1. hunt down treasure chests and open them
#   2. hoover up currency and pickups wherever they fell
#   3. burn whatever she runs past, via a flame aura
#
# She is untargetable rather than literally invisible. She has no physics body
# and is in no group any enemy scans, so nothing can path to her, hit her, or
# be blocked by her -- she just runs through the fight. Making her a real body
# would mean giving her health, a death, and a reason for the player to babysit
# her, none of which is what a reward is for.
#
# Permanent for the rest of the run. She is the rarest thing in the chest table.

const SPEED := 190.0
const ARRIVE_RADIUS := 22.0

# Everything she can see. Deliberately most of the screen and then some -- the
# point of the pull is that loot stops being something you walk back for.
const HUNT_RADIUS := 1400.0
# Pickups inside this get dragged to her, then collected on contact.
const VACUUM_RADIUS := 170.0
const VACUUM_SPEED := 420.0

const AURA_RADIUS := 96.0
const AURA_DPS := 55.0
const AURA_TICK := 0.25

# Idle wandering, when there is nothing worth fetching.
const ROAM_RADIUS := 320.0
const ROAM_REPICK := 2.5

const FRAME_COUNT := 4
const FRAME_TIME := 0.09

var _game: Node = null
var _target: Node2D = null
var _roam_point: Vector2 = Vector2.ZERO
var _roam_timer: float = 0.0
var _aura_timer: float = 0.0
var _anim_timer: float = 0.0
var _frame: int = 0
var _retarget_timer: float = 0.0

@onready var body: Sprite2D = $Body
@onready var aura: Node2D = $Aura


func setup(game_ref: Node) -> void:
	_game = game_ref


func _ready() -> void:
	add_to_group("companions")
	z_index = 6
	_roam_point = global_position
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")


func _process(delta: float) -> void:
	if _game == null or not is_instance_valid(_game):
		return
	if "game_over" in _game and _game.game_over:
		return
	_tick_target(delta)
	_tick_move(delta)
	_tick_vacuum(delta)
	_tick_aura(delta)
	_tick_anim(delta)
	queue_redraw()


# --- what to chase -----------------------------------------------------------

func _tick_target(delta: float) -> void:
	# Re-picking every frame across every chest and pickup on the map is the
	# kind of thing that quietly costs a millisecond once the field is busy.
	_retarget_timer -= delta
	if _target != null and is_instance_valid(_target) and _retarget_timer > 0.0:
		return
	_retarget_timer = 0.25
	_target = _find_chest()
	if _target == null:
		_target = _find_pickup()


func _find_chest() -> Node2D:
	"""Chests first, always. They are worth more than anything else lying about
	and they are the thing a player has to physically walk to."""
	var best: Node2D = null
	var best_d := HUNT_RADIUS * HUNT_RADIUS
	for c in get_tree().get_nodes_in_group("treasure_chests"):
		if c == null or not is_instance_valid(c) or not (c is Node2D):
			continue
		# Never chase a chest that is already opening -- she would stand on it
		# for the rest of the run.
		if ("_opened" in c and c._opened) or ("_opening" in c and c._opening):
			continue
		var d: float = global_position.distance_squared_to((c as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


func _find_pickup() -> Node2D:
	var best: Node2D = null
	var best_d := HUNT_RADIUS * HUNT_RADIUS
	for p in get_tree().get_nodes_in_group("pickups"):
		if p == null or not is_instance_valid(p) or not (p is Node2D):
			continue
		var d: float = global_position.distance_squared_to((p as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


# --- movement ----------------------------------------------------------------

func _tick_move(delta: float) -> void:
	var goal: Vector2
	if _target != null and is_instance_valid(_target):
		goal = (_target as Node2D).global_position
	else:
		_roam_timer -= delta
		var reached := global_position.distance_to(_roam_point) <= ARRIVE_RADIUS
		if _roam_timer <= 0.0 or reached:
			_roam_timer = ROAM_REPICK
			_roam_point = _roam_anchor() + Vector2(
				randf_range(-ROAM_RADIUS, ROAM_RADIUS),
				randf_range(-ROAM_RADIUS, ROAM_RADIUS))
		goal = _roam_point

	var to_goal := goal - global_position
	var dist := to_goal.length()
	if dist > ARRIVE_RADIUS:
		var step := to_goal / dist * SPEED * delta
		global_position += step
		if absf(step.x) > 0.01:
			# Art faces east; mirror for westward travel.
			body.flip_h = step.x < 0.0
	elif _target != null and is_instance_valid(_target):
		_arrive_at(_target)


func _roam_anchor() -> Vector2:
	if _game != null and "player" in _game and _game.player != null \
			and is_instance_valid(_game.player):
		return (_game.player as Node2D).global_position
	return global_position


func _arrive_at(t: Node2D) -> void:
	if t.is_in_group("treasure_chests"):
		# Straight down the normal open path, so the loot roll, the reveal and
		# the gold credit are the same code the player triggers by hand.
		if t.has_method("_start_open"):
			t._start_open()
		_target = null
		_retarget_timer = 0.0


# --- pickups -----------------------------------------------------------------

func _tick_vacuum(_delta: float) -> void:
	"""Pull loose loot to her, then let it collect itself.

	Pickups magnet toward the nearest player and are collected by a body_entered
	against the player body. She has no body, so she cannot trip that -- instead
	she drags pickups into her radius and hands them to the collector directly.
	"""
	for p in get_tree().get_nodes_in_group("pickups"):
		if p == null or not is_instance_valid(p) or not (p is Node2D):
			continue
		var pk := p as Node2D
		var d := global_position.distance_to(pk.global_position)
		if d > VACUUM_RADIUS:
			continue
		if d <= 14.0:
			_collect(pk)
			continue
		# maxf, not max: the untyped builtin returns Variant, which makes the
		# division untyped and the inference fail to parse.
		var dir: Vector2 = (global_position - pk.global_position) / maxf(d, 0.001)
		pk.global_position += dir * VACUUM_SPEED * get_process_delta_time()


func _collect(pk: Node2D) -> void:
	# Hand the pickup the player's body and let its own collection run. Value,
	# kind, essence-vs-heal, FFA ownership and the floating text all then behave
	# exactly as if the player had walked over it -- none of that is duplicated
	# here, so none of it can drift.
	var player = _game.player if (_game != null and "player" in _game) else null
	if player != null and is_instance_valid(player) and pk.has_method("_on_body_entered"):
		pk._on_body_entered(player)


# --- flame aura --------------------------------------------------------------

func _tick_aura(delta: float) -> void:
	_aura_timer -= delta
	if _aura_timer > 0.0:
		return
	_aura_timer = AURA_TICK
	var dmg := AURA_DPS * AURA_TICK
	# Straight off the group, not through `get_enemies_near()`. That query reads
	# a spatial grid rebuilt from a cache on an interval, so a freshly spawned
	# enemy standing right on top of her is invisible to it for a beat -- an
	# aura that misses whatever just walked in is not an aura. At four ticks a
	# second even a 300-body horde is ~1200 distance checks per second, which is
	# nothing next to what the horde already costs.
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var r2 := AURA_RADIUS * AURA_RADIUS
	for e in enemies:
		if e == null or not is_instance_valid(e) or not (e is Node2D):
			continue
		if global_position.distance_squared_to((e as Node2D).global_position) > r2:
			continue
		if e.has_method("take_damage"):
			# Damage numbers off: the aura ticks four times a second across
			# everything in radius and would bury the screen in text.
			e.take_damage(dmg, global_position, true, false, "fire")


# --- presentation ------------------------------------------------------------

func _tick_anim(delta: float) -> void:
	_anim_timer -= delta
	if _anim_timer > 0.0:
		return
	_anim_timer = FRAME_TIME
	_frame = (_frame + 1) % FRAME_COUNT
	body.frame = _frame


func _draw() -> void:
	# Aura drawn here rather than as a sprite: it is a ring of heat that has to
	# sit under her and over the ground, and one draw call beats a pooled node.
	var t := float(Time.get_ticks_msec()) * 0.004
	var pulse := 1.0 + sin(t) * 0.06
	for i in range(3):
		var f := 1.0 - float(i) * 0.3
		var col := Color(1.0, 0.55 + 0.15 * f, 0.12, 0.10 * f)
		draw_circle(Vector2.ZERO, AURA_RADIUS * pulse * f, col)
	draw_arc(Vector2.ZERO, AURA_RADIUS * pulse, 0.0, TAU, 40,
			Color(1.0, 0.72, 0.25, 0.35), 2.0, true)
