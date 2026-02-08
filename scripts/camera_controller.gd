extends Camera2D
class_name DynamicCamera

const FeedbackConfig = preload("res://scripts/feedback_config.gd")

# Screen effects nodes
var _vignette: ColorRect = null
var _chromatic_aberration: ColorRect = null

# Camera state
var _target_position: Vector2 = Vector2.ZERO
var _mouse_offset: Vector2 = Vector2.ZERO
var _current_zoom: Vector2 = Vector2.ONE
var _base_zoom: Vector2 = Vector2.ONE
var _zoom_target: Vector2 = Vector2.ONE
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_strength: float = 0.0
var _shake_timer: float = 0.0

# Chromatic aberration state
var _chromatic_timer: float = 0.0
var _chromatic_intensity: float = 0.0

# Vignette state
var _target_vignette_alpha: float = 0.0
var _current_vignette_alpha: float = 0.0

var _player: Node2D = null
var _game: Node = null

func _ready() -> void:
	_setup_screen_effects()
	_base_zoom = zoom
	_current_zoom = zoom
	_zoom_target = zoom

func setup(player: Node2D, game: Node) -> void:
	_player = player
	_game = game

func _setup_screen_effects() -> void:
	# Create vignette overlay for low HP
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.color = Color(0.0, 0.0, 0.0, 0.0)
	_vignette.anchors_preset = Control.PRESET_FULL_RECT
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = 100
	
	# Add radial gradient texture for vignette effect
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform float intensity : hint_range(0.0, 1.0) = 0.0;
	uniform float inner_radius : hint_range(0.0, 1.0) = 0.4;
	uniform float outer_radius : hint_range(0.0, 1.0) = 1.0;
	uniform vec3 vignette_color : source_color = vec3(0.0, 0.0, 0.0);
	
	void fragment() {
		vec2 center = vec2(0.5, 0.5);
		float dist = distance(UV, center) * 2.0;
		float vignette = smoothstep(inner_radius, outer_radius, dist);
		COLOR = vec4(vignette_color, vignette * intensity);
	}
	"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.0)
	mat.set_shader_parameter("inner_radius", 0.5)
	mat.set_shader_parameter("outer_radius", 1.2)
	mat.set_shader_parameter("vignette_color", Color(0.1, 0.0, 0.0))
	_vignette.material = mat
	
	# Create chromatic aberration overlay for damage
	_chromatic_aberration = ColorRect.new()
	_chromatic_aberration.name = "ChromaticAberration"
	_chromatic_aberration.color = Color(1.0, 0.0, 0.0, 0.0)
	_chromatic_aberration.anchors_preset = Control.PRESET_FULL_RECT
	_chromatic_aberration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chromatic_aberration.z_index = 99
	
	var ca_shader = Shader.new()
	ca_shader.code = """
	shader_type canvas_item;
	uniform float intensity : hint_range(0.0, 1.0) = 0.0;
	uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
	
	void fragment() {
		vec2 uv = SCREEN_UV;
		vec2 center = vec2(0.5, 0.5);
		vec2 dir = uv - center;
		float dist = length(dir);
		
		float r = texture(screen_texture, uv + dir * intensity * 0.02).r;
		float g = texture(screen_texture, uv + dir * intensity * 0.01).g;
		float b = texture(screen_texture, uv).b;
		
		COLOR = vec4(r, g, b, intensity * 0.5);
	}
	"""
	var ca_mat = ShaderMaterial.new()
	ca_mat.shader = ca_shader
	ca_mat.set_shader_parameter("intensity", 0.0)
	_chromatic_aberration.material = ca_mat
	
	# Add to scene (as siblings so they render on top)
	if get_parent() != null:
		get_parent().add_child(_vignette)
		get_parent().add_child(_chromatic_aberration)

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_shake(delta)
	_update_screen_effects(delta)

func _update_camera(delta: float) -> void:
	if _player == null:
		return
	
	# Get mouse position for camera lean
	var viewport = get_viewport()
	if viewport == null:
		return
	
	var mouse_pos = viewport.get_mouse_position()
	var viewport_size = viewport.get_visible_rect().size
	var mouse_normalized = (mouse_pos - viewport_size * 0.5) / (viewport_size * 0.5)
	
	# Camera lean toward mouse cursor
	_mouse_offset = mouse_normalized * FeedbackConfig.CAMERA_MOUSE_LEAN_AMOUNT
	
	# Dynamic zoom based on enemy count
	var enemy_count = get_tree().get_nodes_in_group("enemies").size()
	if enemy_count > FeedbackConfig.CAMERA_ENEMY_COUNT_THRESHOLD:
		_zoom_target = _base_zoom * FeedbackConfig.CAMERA_ZOOM_OUT_AMOUNT
	else:
		_zoom_target = _base_zoom
	
	# Smooth zoom
	_current_zoom = _current_zoom.lerp(_zoom_target, delta * FeedbackConfig.CAMERA_SMOOTH_SPEED)
	zoom = _current_zoom
	
	# Smooth follow with slight lag
	var target_pos = _player.global_position + _mouse_offset + _shake_offset
	position = position.lerp(target_pos, delta * FeedbackConfig.CAMERA_SMOOTH_SPEED)

func _update_shake(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var t = _shake_timer / FeedbackConfig.SCREEN_SHAKE_DURATION if FeedbackConfig.SCREEN_SHAKE_DURATION > 0 else 0.0
		var intensity = _shake_strength * t
		_shake_offset = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * intensity
	else:
		_shake_offset = Vector2.ZERO
		_shake_strength = 0.0

func _update_screen_effects(delta: float) -> void:
	# Update chromatic aberration
	if _chromatic_timer > 0.0:
		_chromatic_timer -= delta
		var t = _chromatic_timer / FeedbackConfig.CHROMATIC_ABERRATION_DURATION
		_chromatic_intensity = t * 0.5
	else:
		_chromatic_intensity = 0.0
	
	if _chromatic_aberration != null and _chromatic_aberration.material != null:
		_chromatic_aberration.material.set_shader_parameter("intensity", _chromatic_intensity)
	
	# Update vignette based on player health
	if _player != null and "health" in _player and "max_health" in _player:
		var health_ratio = _player.health / _player.max_health
		if health_ratio < FeedbackConfig.VIGNETTE_LOW_HP_THRESHOLD:
			var vignette_intensity = 1.0 - (health_ratio / FeedbackConfig.VIGNETTE_LOW_HP_THRESHOLD)
			_target_vignette_alpha = vignette_intensity * 0.7
		else:
			_target_vignette_alpha = 0.0
	
	_current_vignette_alpha = lerp(_current_vignette_alpha, _target_vignette_alpha, delta * 3.0)
	
	if _vignette != null and _vignette.material != null:
		_vignette.material.set_shader_parameter("intensity", _current_vignette_alpha)

func shake(strength: float, duration: float = FeedbackConfig.SCREEN_SHAKE_DURATION) -> void:
	_shake_strength = max(_shake_strength, strength)
	_shake_timer = max(_shake_timer, duration)

func trigger_damage_flash() -> void:
	_chromatic_timer = FeedbackConfig.CHROMATIC_ABERRATION_DURATION

func trigger_hitstop() -> void:
	# This will be called from main.gd which has access to Engine.time_scale
	pass
