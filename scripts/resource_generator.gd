extends "res://scripts/building.gd"

const MAX_HP = 100.0
const LOW_HP_THRESHOLD = 0.3  # 30% health = low HP (pulse red)
const HEALTH_BAR_WIDTH = 32.0
const HEALTH_BAR_HEIGHT = 4.0
const HEALTH_BAR_OFFSET = -28.0  # Above the building

var income = 2
var interval = 2.0
var _timer = 0.0
var _game: Node = null
var _health_bar: ProgressBar = null
var _health_bar_container: Node2D = null
var _is_destroyed = false
var _pulse_tween: Tween = null
var _low_hp_pulse_active = false
var _was_damaged = false
var _under_attack_warning_shown = false

# Visual components
@onready var body: CanvasItem = get_node_or_null("Body")
@onready var base_modulate: Color = Color.WHITE

func _ready() -> void:
    super._ready()
    _game = get_tree().get_first_node_in_group("game")
    max_health = MAX_HP
    health = MAX_HP
    
    # Store base modulate color
    if body != null:
        base_modulate = body.modulate
    
    # Create health bar
    _create_health_bar()
    
    # Register with game
    if _game != null and _game.has_method("register_generator"):
        _game.register_generator(self)

func _apply_tier_stats(tier_data: Dictionary) -> void:
    super._apply_tier_stats(tier_data)
    income = int(tier_data.get("income", income))
    interval = float(tier_data.get("interval", interval))
    # Generators have fixed HP regardless of tier for balance
    max_health = MAX_HP
    health = MAX_HP

func _process(delta: float) -> void:
    if _is_destroyed or _game == null:
        return
    
    _timer += delta
    if _timer >= interval:
        _timer -= interval
        _game.add_resources(income)

func take_damage(amount: float) -> void:
    if _is_destroyed:
        return
    
    health -= amount
    _was_damaged = true
    
    # Audio: Building hit sound
    AudioManager.play_one_shot("building_hit", global_position, AudioManager.DEFAULT_PRIORITY)
    
    # Show health bar when damaged
    _update_health_bar()
    _health_bar_container.visible = true
    
    # Show "under attack" warning on first damage
    if not _under_attack_warning_shown and _game != null:
        _under_attack_warning_shown = true
        if _game.has_method("show_floating_text"):
            _game.show_floating_text("GENERATOR UNDER ATTACK!", global_position + Vector2(0, -50), Color(1.0, 0.5, 0.0, 1.0))
    
    # Check for low HP pulse effect
    var hp_ratio = health / max_health
    if hp_ratio <= LOW_HP_THRESHOLD and not _low_hp_pulse_active:
        _start_low_hp_pulse()
    
    # Flash red on hit
    _flash_damage()
    
    if health <= 0.0:
        _destroy()

func heal(amount: float) -> void:
    if _is_destroyed:
        return
    health = min(max_health, health + amount)
    _update_health_bar()
    
    # Stop low HP pulse if healed above threshold
    var hp_ratio = health / max_health
    if hp_ratio > LOW_HP_THRESHOLD and _low_hp_pulse_active:
        _stop_low_hp_pulse()

func _destroy() -> void:
    _is_destroyed = true
    
    # Audio: Generator destroyed sound
    AudioManager.play_one_shot("generator_destroyed", global_position, AudioManager.CRITICAL_PRIORITY)
    
    # Screen shake
    if _game != null and _game.has_method("shake_camera"):
        _game.shake_camera(FeedbackConfig.SCREEN_SHAKE_BUILDING_DESTROY)
    
    # Spawn explosion FX
    if _game != null and _game.has_method("spawn_fx"):
        _game.spawn_fx("explosion", global_position)
        _spawn_glow_burst()
    
    # Show death message
    if _game != null and _game.has_method("show_floating_text"):
        _game.show_floating_text("GENERATOR DESTROYED!", global_position + Vector2(0, -40), Color(1.0, 0.0, 0.0, 1.0))
    
    # Notify game
    if _game != null and _game.has_method("on_generator_destroyed"):
        _game.on_generator_destroyed(self)
    
    # Track generator lost
    if _game != null and _game.has_method("track_generator_lost"):
        _game.track_generator_lost()
    
    queue_free()

func _spawn_glow_burst() -> void:
    if _game == null:
        return
    # Spawn orange/red glow particles for explosion
    for i in range(15):
        var dir = Vector2.RIGHT.rotated(randf() * TAU)
        var vel = dir * randf_range(80.0, 180.0)
        var color = Color(1.0, 0.4 + randf() * 0.3, 0.1, 1.0)
        if _game.has_method("spawn_glow_particle"):
            _game.spawn_glow_particle(
                global_position + dir * randf_range(0.0, 12.0),
                color,
                randf_range(8.0, 16.0),
                randf_range(0.4, 0.8),
                vel,
                2.0,
                0.7,
                1.0,
                2
            )

func _create_health_bar() -> void:
    _health_bar_container = Node2D.new()
    _health_bar_container.name = "HealthBarContainer"
    _health_bar_container.visible = false  # Hidden until damaged
    add_child(_health_bar_container)
    
    # Create background
    var bg = ColorRect.new()
    bg.name = "HealthBarBG"
    bg.color = Color(0.2, 0.2, 0.2, 0.9)
    bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
    bg.position = Vector2(-HEALTH_BAR_WIDTH / 2, HEALTH_BAR_OFFSET)
    _health_bar_container.add_child(bg)
    
    # Create progress bar
    _health_bar = ProgressBar.new()
    _health_bar.name = "HealthBar"
    _health_bar.min_value = 0
    _health_bar.max_value = max_health
    _health_bar.value = health
    _health_bar.show_percentage = false
    _health_bar.size = Vector2(HEALTH_BAR_WIDTH - 2, HEALTH_BAR_HEIGHT - 2)
    _health_bar.position = Vector2(-(HEALTH_BAR_WIDTH - 2) / 2, HEALTH_BAR_OFFSET + 1)
    
    # Style the progress bar
    var fg_style = StyleBoxFlat.new()
    fg_style.bg_color = Color(0.2, 0.85, 0.3, 1.0)  # Green
    _health_bar.add_theme_stylebox_override("fill", fg_style)
    
    var bg_style = StyleBoxFlat.new()
    bg_style.bg_color = Color(0.1, 0.1, 0.1, 1.0)
    _health_bar.add_theme_stylebox_override("background", bg_style)
    
    _health_bar_container.add_child(_health_bar)

func _update_health_bar() -> void:
    if _health_bar == null:
        return
    _health_bar.value = health
    
    # Change color based on health
    var fg_style = StyleBoxFlat.new()
    var hp_ratio = health / max_health
    if hp_ratio > 0.6:
        fg_style.bg_color = Color(0.2, 0.85, 0.3, 1.0)  # Green
    elif hp_ratio > 0.3:
        fg_style.bg_color = Color(0.95, 0.75, 0.2, 1.0)  # Yellow
    else:
        fg_style.bg_color = Color(0.95, 0.2, 0.2, 1.0)  # Red
    _health_bar.add_theme_stylebox_override("fill", fg_style)

func _flash_damage() -> void:
    if body == null:
        return
    body.modulate = Color(1.0, 0.3, 0.3, 1.0)  # Flash red
    var tween = create_tween()
    tween.tween_property(body, "modulate", base_modulate, 0.15).set_trans(Tween.TRANS_SINE)

func _start_low_hp_pulse() -> void:
    _low_hp_pulse_active = true
    if body == null:
        return
    
    if _pulse_tween != null:
        _pulse_tween.kill()
    
    _pulse_tween = create_tween()
    _pulse_tween.set_loops()
    # Pulse between normal and bright red
    var dim_color = base_modulate.lerp(Color(1.0, 0.2, 0.2), 0.3)
    var bright_color = base_modulate.lerp(Color(1.0, 0.1, 0.1), 0.6)
    _pulse_tween.tween_property(body, "modulate", bright_color, 0.4).set_trans(Tween.TRANS_SINE)
    _pulse_tween.tween_property(body, "modulate", dim_color, 0.4).set_trans(Tween.TRANS_SINE)

func _stop_low_hp_pulse() -> void:
    _low_hp_pulse_active = false
    if _pulse_tween != null:
        _pulse_tween.kill()
        _pulse_tween = null
    if body != null:
        var tween = create_tween()
        tween.tween_property(body, "modulate", base_modulate, 0.3).set_trans(Tween.TRANS_SINE)

func is_destroyed() -> bool:
    return _is_destroyed

func get_health_ratio() -> float:
    return health / max_health

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        if _pulse_tween != null:
            _pulse_tween.kill()
