extends "res://scripts/enemy.gd"

const Building = preload("res://scripts/building.gd")

signal boss_spawned(boss)
signal boss_died(boss)
signal boss_phase_changed(phase: int)

@export var intro_duration: float = 0.6
@export var boss_scale: float = 2.6

var boss_name: String = "Boss"
var boss_title: String = ""
var boss_wave: int = 0
var boss_color: Color = Color(1.0, 0.3, 0.3)
var is_boss_active: bool = false
var _max_phases: int = 1
var _intro_timer: float = 0.0

func setup(game_ref: Node, difficulty: float) -> void:
	_game = game_ref
	var diff = max(1.0, difficulty)
	var health_mult = 1.0 + (diff - 1.0) * 0.45
	var damage_mult = 1.0 + (diff - 1.0) * 0.2
	var speed_mult = 1.0 + (diff - 1.0) * 0.1
	max_health *= health_mult
	health = max_health
	attack_damage *= damage_mult
	speed *= speed_mult

func _ready() -> void:
	is_siege = true
	is_elite = false
	is_boss_active = true
	add_to_group("bosses")
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

func take_damage(amount: float, hit_position: Vector2 = Vector2.ZERO, show_hit_fx: bool = true, show_damage_number: bool = true, damage_type: String = "normal") -> void:
	if not is_boss_active or _is_dying:
		return
	super.take_damage(amount, hit_position, show_hit_fx, show_damage_number, damage_type)

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
		body.modulate = body.modulate.lerp(boss_color, 0.35)
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var shape: CircleShape2D = collision_shape.shape
		shape.radius = max(shape.radius, 18.0)
	if _health_bar_bg != null:
		_health_bar_bg.position.y -= 6.0
		_health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH * 2.0, HEALTH_BAR_HEIGHT * 1.4)
		if _health_bar_fill != null:
			_health_bar_fill.size = _health_bar_bg.size
			_health_bar_fill.color = boss_color
