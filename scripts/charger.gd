extends "res://scripts/enemy_variant.gd"

# Charger: locks direction toward player, bursts forward, overshoots.
# Distinct from Hellhound — Charger commits to a straight line and slides past.

var charge_cooldown = 3.5
var charge_windup = 0.4
var charge_duration = 0.6
var charge_speed_mult = 2.8
var _charge_cd = 0.0
var _charge_timer = 0.0
var _windup_timer = 0.0
var _charge_dir = Vector2.ZERO
var _base_speed = 0.0
var _is_winding_up = false
var _is_charging = false

func _ready() -> void:
	super._ready()
	_base_speed = speed

func _physics_process(delta: float) -> void:
	if _game == null:
		return
	_tick_elite(delta)
	if _stun_timer > 0.0:
		_stun_timer = max(0.0, _stun_timer - delta)
		velocity = Vector2.ZERO
		_is_charging = false
		_is_winding_up = false
		_update_status_visuals()
		return

	_charge_cd = max(0.0, _charge_cd - delta)

	# Windup: pause before charging, lock direction
	if _is_winding_up:
		_windup_timer -= delta
		velocity = Vector2.ZERO
		if _windup_timer <= 0.0:
			_is_winding_up = false
			_is_charging = true
			_charge_timer = charge_duration
		_update_status_visuals()
		return

	# Charging: locked direction, high speed, overshoot
	if _is_charging:
		_charge_timer -= delta
		speed = _base_speed * charge_speed_mult
		velocity = _charge_dir * speed * _slow_multiplier
		move_and_slide()
		if _charge_timer <= 0.0:
			_is_charging = false
			speed = _base_speed
			_charge_cd = charge_cooldown
		_update_status_visuals()
		return

	# Normal movement — try to initiate charge when close enough
	speed = _base_speed
	var target = _find_target()
	if target == null or not is_instance_valid(target):
		return

	var dist = global_position.distance_to(target.global_position)
	_attack_cooldown = max(0.0, _attack_cooldown - delta)

	if dist <= attack_range:
		if _attack_cooldown <= 0.0:
			if target.has_method("take_damage"):
				target.take_damage(attack_damage)
			_attack_cooldown = 1.0 / max(0.1, attack_rate)
		velocity = Vector2.ZERO
	else:
		var dir = (target.global_position - global_position).normalized()
		# Trigger charge when in range and off cooldown
		if dist < 300.0 and _charge_cd <= 0.0:
			_charge_dir = dir
			_is_winding_up = true
			_windup_timer = charge_windup
			velocity = Vector2.ZERO
		else:
			velocity = dir * speed * _slow_multiplier
			move_and_slide()
	_update_status_visuals()
