extends Area2D

const GOLD_TEX = preload("res://assets/ui/ui_icon_gold_32_v001.png")
const HEAL_TEX = preload("res://assets/ui/ui_icon_crystal_32_v001.png")

# Once a pickup is inside the magnet it accelerates rather than sliding in at a
# fixed rate, and it never lets go. A constant 240px/s crawl reads as the loot
# following you home; the whole appeal of the genre's pickup is the snap.
const MAGNET_ACCEL = 1500.0
const MAGNET_MAX_SPEED = 1250.0
# Collected by distance as well as by body overlap. At the top speed above, a
# pickup covers ~21px in a 60Hz frame and more on a long one, which is wider than
# the player's 10px collider - the overlap can simply be stepped over.
const COLLECT_RADIUS = 14.0
# The target lookup walks every player in FFA. Pickups are the most numerous
# node in a late run, so it runs on a cadence instead of every frame per pickup.
const TARGET_REFRESH_INTERVAL = 0.2

var value = 1
var kind = "gold"
var _game: Node = null
var magnet_radius = 120.0
var magnet_speed = 240.0
var _player: Node2D = null
# Idle shimmer is driven by maths in _process rather than a looping Tween per
# pickup: a Tween is a node with four interpolators, and hundreds of them are
# live at once late in a run.
var _bob_phase: float = 0.0
var _bob_rate: float = 2.0
var _bob_scale: float = 1.0
var _bob_amount: float = 0.0
var _bob_alpha: float = 0.0
var _base_color: Color = Color.WHITE
var _locked: bool = false
var _collected: bool = false
var _speed: float = 0.0
var _target: Node2D = null
var _target_timer: float = 0.0
@onready var sprite: Sprite2D = $Body

func setup(game_ref: Node, amount: int, kind_name: String = "gold") -> void:
    _game = game_ref
    value = amount
    kind = kind_name
    _apply_visual()
    _apply_magnet_settings()

func _ready() -> void:
    add_to_group("pickups")
    collision_layer = GameLayers.PICKUP
    collision_mask = GameLayers.PLAYER
    body_entered.connect(_on_body_entered)
    _player = get_tree().get_first_node_in_group("player")
    _apply_visual()
    _apply_magnet_settings()

func _process(delta: float) -> void:
    _animate_idle(delta)
    # Magnet toward the NEAREST player (FFA). In solo this is just the one player.
    var target := _magnet_target(delta)
    if target == null:
        return
    var to_target: Vector2 = target.global_position - global_position
    var dist := to_target.length()
    if not _locked:
        if dist > magnet_radius:
            return
        # Latched. From here it is coming home even if the player runs away -
        # loot that gives up halfway is loot the player has to walk back for.
        _locked = true
        _speed = magnet_speed
    _speed = minf(_speed + MAGNET_ACCEL * delta, MAGNET_MAX_SPEED)
    if dist <= COLLECT_RADIUS or dist <= _speed * delta:
        # Collection used to require a physics overlap, which a corpse cannot
        # produce. Paying out by distance has to keep that property or loot
        # banks itself onto a player in the middle of dying.
        if _can_collect(target):
            _collect(target)
            return
    # Step is clamped to the remaining distance, so a pickup that is not allowed
    # to pay out yet parks on the target instead of oscillating across it.
    global_position += (to_target / dist) * minf(_speed * delta, dist)

func _can_collect(target: Node) -> bool:
    if target == null or not is_instance_valid(target):
        return false
    if "_is_dying" in target and bool(target._is_dying):
        return false
    return true

func _animate_idle(delta: float) -> void:
    if sprite == null or not is_instance_valid(sprite):
        return
    _bob_phase += delta * _bob_rate
    var wave: float = sin(_bob_phase)
    # Locked pickups swell slightly so a stream of them reads as "on the way in"
    # rather than as scenery that happens to be sliding.
    var lock_bonus: float = 0.18 if _locked else 0.0
    sprite.scale = Vector2.ONE * (_bob_scale + lock_bonus + wave * _bob_amount)
    if _bob_alpha > 0.0:
        var a: float = clampf(_base_color.a - _bob_alpha * (0.5 + 0.5 * wave), 0.0, 1.0)
        sprite.modulate = Color(_base_color.r, _base_color.g, _base_color.b, a)

func _magnet_target(delta: float) -> Node2D:
    _target_timer -= delta
    if _target != null and is_instance_valid(_target) and _target_timer > 0.0:
        return _target
    _target_timer = TARGET_REFRESH_INTERVAL
    if _game != null and _game.has_method("get_nearest_player"):
        var n = _game.get_nearest_player(global_position)
        if n != null:
            _target = n
            return _target
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player")
    _target = _player
    return _target

func _collect(body: Node) -> void:
    """Distance-based collection. Shares the crediting path with the overlap
    signal so a vacuumed pickup and a walked-over one cannot pay out differently."""
    if body == null or not is_instance_valid(body):
        return
    _award(body)

func _on_body_entered(body: Node) -> void:
    if body == null:
        return
    if body.is_in_group("player"):
        _award(body)

func _award(body: Node) -> void:
    # Both collection paths land here, and both can fire in the same frame - the
    # overlap signal and the distance check - so the first one out takes it.
    if _collected:
        return
    _collected = true
    # Credit the collecting player's pool (FFA). owner_id == 0 => local/solo.
    var owner_id := 0
    if "peer_id" in body:
        owner_id = int(body.peer_id)
    # Only the local player's pickups show floating feedback on this screen;
    # a bot/remote player grabbing loot is still credited to THEIR ledger but
    # doesn't spam this machine's HUD with text/heals it doesn't own.
    var is_local := _is_local_player_body(body)
    if _game != null:
        if kind == "heal":
            if _game.has_method("heal_player"):
                _game.heal_player(value, owner_id)
            if is_local and _game.has_method("show_floating_text"):
                _game.show_floating_text("+%d HP" % value, global_position + Vector2(0.0, -10.0), Color(0.45, 1.0, 0.55, 1.0))
        elif kind == "essence":
            if _game.has_method("add_essence"):
                _game.add_essence(value, owner_id)
        else:
            _game.add_resources(value, owner_id)
    queue_free()

# True only for the player this machine controls (so HUD feedback stays local).
func _is_local_player_body(body: Node) -> bool:
    if _game == null or not is_instance_valid(_game):
        return true
    if _game.has_method("is_solo") and _game.is_solo():
        return true
    if "is_bot" in body and bool(body.is_bot):
        return false
    var lp = _game.local_player if "local_player" in _game else null
    if lp != null and is_instance_valid(lp):
        return body == lp
    if "peer_id" in body and _game.has_method("local_player_id"):
        return int(body.peer_id) == int(_game.local_player_id())
    return true

func _apply_visual() -> void:
    if sprite == null:
        return
    # The shimmer used to be a looping Tween per pickup, four interpolators each.
    # Hundreds are alive at once in a late run, so the same motion is driven from
    # _process maths instead and the per-kind numbers just become parameters.
    if kind == "heal":
        sprite.texture = HEAL_TEX
        _base_color = Color(0.45, 1.0, 0.58, 0.98)
        _bob_scale = 1.22
        _bob_amount = 0.06
        _bob_alpha = 0.22
        _bob_rate = TAU / 0.64
    elif kind == "essence":
        sprite.texture = HEAL_TEX
        _base_color = Color(0.7, 0.3, 1.0, 1.0)
        _bob_scale = 1.13
        _bob_amount = 0.05
        _bob_alpha = 0.38
        _bob_rate = TAU / 0.8
    else:
        sprite.texture = GOLD_TEX
        _base_color = Color(1.0, 0.95, 0.7, 1.0)
        _bob_scale = 1.225
        _bob_amount = 0.075
        _bob_alpha = 0.2
        _bob_rate = TAU / 1.0
    # Desynchronised so a pile of drops does not breathe in lockstep.
    _bob_phase = randf() * TAU
    sprite.modulate = _base_color
    sprite.scale = Vector2.ONE * _bob_scale

func _apply_magnet_settings() -> void:
    var base_radius = 120.0
    var base_speed = 240.0
    if kind == "gold":
        base_radius = 150.0
        base_speed = 260.0
    elif kind == "essence":
        base_radius = 135.0
        base_speed = 250.0
    if _game != null and _game.has_method("get_pickup_range_mult"):
        base_radius *= float(_game.get_pickup_range_mult())
    magnet_radius = base_radius
    magnet_speed = base_speed
