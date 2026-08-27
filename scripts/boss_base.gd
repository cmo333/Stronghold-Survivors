extends "res://scripts/enemy.gd"

const Building = preload("res://scripts/building.gd")

signal boss_spawned(boss)
signal boss_died(boss)
signal boss_phase_changed(phase: int)

@export var intro_duration: float = 0.6
# Regular enemies render at 1.8. 3.9 puts a boss half again as large as the
# previous 2.6, so it reads as a boss at a glance in a packed field.
@export var boss_scale: float = 3.9

const PLAYER_COLLISION_RADIUS = 7.0

var boss_name: String = "Boss"
var boss_title: String = ""
var boss_wave: int = 0
var boss_color: Color = Color(1.0, 0.3, 0.3)
var is_boss_active: bool = false
var _max_phases: int = 1
var _intro_timer: float = 0.0

# Bosses died off-screen to massed tower fire before they ever became a fight
# worth noticing. Tripling the pool buys them enough time on the field to
# actually reach the base and be dealt with deliberately.
#
# 2.5, not 3.0, because this is not the only factor in _scale_health_mult. It
# multiplies main.gd's get_enemy_health_mult(), which is 1.2 at the reference
# below (ENEMY_HEALTH_BASE_MULT 2.0 x the 0.60 early-game grace), and that
# scaling was dead when the x3 was asked for -- setup() computed it and the
# subclass _ready() threw it away. Repairing that made the two compound: a flat
# 3.0 here measured x3.60 at difficulty 1.0, x5.22 at difficulty 2.0 and x8.61
# at the 90% extraction milestone, against an authored colossus base of 2000.
#
# THE REFERENCE IS: difficulty 1.0, run start, no extraction milestone -- the
# least-scaled state the game ever occupies. At that point a boss is now exactly
# x3 its authored base (colossus 2000 -> 6000), measured in a running engine by
# tools/boss_test.sh, not computed. x3 is therefore the FLOOR; difficulty, run
# length and the milestone steps all still stack on top, which is the whole
# point of having repaired the scaling. Anchoring x3 at some mid-run difficulty
# instead would put a boss BELOW the requested x3 in the easy half of the run.
const BOSS_HEALTH_MULT := 2.5

# Boss AoE against structures, applied on top of each attack's own falloff.
#
# The colossus slam does 40 in a 120px radius every 4s and a basic arrow turret
# has 40 health, so every slam deleted every turret it touched -- a measured
# 12/12 destroyed in 12 seconds, with the boss simply stood next to the player
# inside their own base. No walling, no breach, no warning: the base just went
# away. Tripling boss health made that far worse by letting the boss land ~5x
# as many slams before dying.
#
# Bosses should threaten a base, not delete it. At 0.35 a slam takes ~3 hits to
# kill a basic turret, so the player has ~12s of the boss parked in the base to
# react -- and the damage still scales with everything else, so a late boss is
# still the thing that ends a run.
const BOSS_AOE_BUILDING_MULT := 0.35

# Scaling computed in setup() but applied in _ready(). See _apply_boss_scaling.
var _scale_health_mult: float = 1.0
var _scale_damage_mult: float = 1.0
var _scale_speed_mult: float = 1.0

func setup(game_ref: Node, difficulty: float) -> void:
	_game = game_ref
	# WITHOUT the run-length ramp -- see get_enemy_health_mult() in main.gd for
	# why bosses opt out of it. They still scale with run length through
	# `difficulty` below; the ramp would be the third count of the same axis.
	var global_health_mult = 1.0
	if _game != null and _game.has_method("get_enemy_health_mult"):
		global_health_mult = float(_game.get_enemy_health_mult(false))
	var milestone_speed_mult = 1.0
	if _game != null and _game.has_method("get_enemy_speed_mult"):
		milestone_speed_mult = float(_game.get_enemy_speed_mult())
	var diff = max(1.0, difficulty)
	# Deliberately only recorded here -- see _apply_boss_scaling for why.
	_scale_health_mult = global_health_mult * (1.0 + (diff - 1.0) * 0.45) * BOSS_HEALTH_MULT
	_scale_damage_mult = 1.0 + (diff - 1.0) * 0.2
	_scale_speed_mult = (1.0 + (diff - 1.0) * 0.1) * milestone_speed_mult

func _apply_boss_scaling() -> void:
	"""Apply the multipliers setup() worked out, once base stats are final.

	setup() is called on the instance BEFORE it is added to the tree, so it runs
	before _ready() -- and every boss subclass assigns its own `max_health`,
	`speed` and `attack_damage` inside its `_ready()`. Scaling in setup() was
	therefore overwritten a moment later, in every case: bosses have always
	fought at their flat authored health (2000 / 5000 / 10000 / 20000) with no
	difficulty, run-length or milestone scaling at all, which is a large part of
	why they evaporate against a built-up base.

	Subclasses call `super._ready()` after setting their stats, so this is the
	first point where the base values are real. It runs before Enemy._ready() so
	the boss health bar is built against the final number.
	"""
	max_health *= _scale_health_mult
	health = max_health
	attack_damage *= _scale_damage_mult
	speed *= _scale_speed_mult

func _ready() -> void:
	is_siege = true
	is_elite = false
	is_boss_active = true
	add_to_group("bosses")
	_apply_boss_scaling()
	super._ready()
	_style_boss()
	_intro_timer = intro_duration
	if _game != null and _game.ui != null and _game.ui.has_method("show_announcement"):
		_game.ui.show_announcement(boss_name.to_upper(), boss_color, 48, 2.6)
	boss_spawned.emit(self)

func _physics_process(delta: float) -> void:
	if _is_dying or not is_boss_active:
		return
	if _game == null:
		return
	if _stun_timer > 0.0:
		_stun_timer = max(0.0, _stun_timer - delta)
		velocity = Vector2.ZERO
		_update_status_visuals()
		return
	_boss_behavior(delta)
	_update_status_visuals()

func _boss_behavior(delta: float) -> void:
	super._physics_process(delta)

func take_damage(amount: float, hit_position: Vector2 = Vector2.ZERO, show_hit_fx: bool = true, show_damage_number: bool = true, damage_type: String = "normal", hit_dir: Vector2 = Vector2.ZERO) -> void:
	if not is_boss_active or _is_dying:
		return
	super.take_damage(amount, hit_position, show_hit_fx, show_damage_number, damage_type, hit_dir)

func _start_death_sequence() -> void:
	if not is_boss_active:
		return
	is_boss_active = false
	boss_died.emit(self)
	super._start_death_sequence()

func get_health_percent() -> float:
	if max_health <= 0.0:
		return 0.0
	return clamp(health / max_health, 0.0, 1.0)

func _deal_damage(target: Node, amount: float, hit_pos: Vector2, show_hit_fx: bool = true) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target is Building:
		if target.has_method("take_damage"):
			target.take_damage(amount)
		return
	if target.has_method("take_damage"):
		target.take_damage(amount, hit_pos, show_hit_fx)

func _style_boss() -> void:
	if body != null:
		body.scale = Vector2.ONE * boss_scale
		# Strong enough to read as a distinct variant rather than a tint. At 0.35
		# a boss was near-indistinguishable from the ordinary enemy it shares art
		# with; 0.75 plus a brightness lift makes it a coloured elite.
		body.modulate = body.modulate.lerp(boss_color, 0.75) * 1.15
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var shape: CircleShape2D = collision_shape.shape
		shape.radius = PLAYER_COLLISION_RADIUS
	if _health_bar_bg != null:
		_health_bar_bg.position.y -= 6.0
		_health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH * 2.0, HEALTH_BAR_HEIGHT * 1.4)
		if _health_bar_fill != null:
			_health_bar_fill.size = _health_bar_bg.size
			_health_bar_fill.color = boss_color
