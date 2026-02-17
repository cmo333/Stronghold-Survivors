extends Node2D
class_name GlowParticle

@export var color: Color = Color(0.5, 0.95, 1.0, 1.0)
@export var size: float = 8.0
@export var lifetime: float = 0.45
@export_range(0.0, 3.0, 0.05) var bloom_intensity: float = 1.6
@export var velocity: Vector2 = Vector2.ZERO
@export var drag: float = 0.0
@export var spin_speed: float = 3.2
@export var tilt_speed: Vector2 = Vector2(1.1, 0.9)
@export var trail_strength: float = 0.7
@export var trail_length: float = 0.9
@export var z: int = 0

var _age := 0.0
var _core: MeshInstance2D
var _trail: MeshInstance2D
var _core_material: ShaderMaterial
var _trail_material: ShaderMaterial
var _rot_3d := Vector3.ZERO
var _rot_speed := Vector3.ZERO
var _last_position := Vector2.ZERO

const GLOW_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float bloom = 1.6;
uniform float alpha = 1.0;
uniform float softness = 1.6;
uniform vec3 rot = vec3(0.0, 0.0, 0.0);
uniform float perspective = 0.35;

void vertex() {
	vec3 p = vec3(VERTEX, 0.0);
	float sx = sin(rot.x);
	float cx = cos(rot.x);
	float sy = sin(rot.y);
	float cy = cos(rot.y);
	float sz = sin(rot.z);
	float cz = cos(rot.z);
	p = vec3(p.x, p.y * cx - p.z * sx, p.y * sx + p.z * cx);
	p = vec3(p.x * cy + p.z * sy, p.y, -p.x * sy + p.z * cy);
	p = vec3(p.x * cz - p.y * sz, p.x * sz + p.y * cz, p.z);
	float persp = 1.0 / (1.0 + p.z * perspective);
	VERTEX = p.xy * persp;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	float falloff = pow(clamp(1.0 - d, 0.0, 1.0), softness);
	vec4 c = glow_color * bloom;
	COLOR = vec4(c.rgb * falloff, c.a * falloff * alpha);
}
"""

static var _shared_shader: Shader = null
static var _shared_quad: QuadMesh = null

func setup(p_color: Color, p_size: float, p_lifetime: float, p_velocity: Vector2 = Vector2.ZERO, p_bloom: float = 1.6, p_trail_strength: float = 0.7, p_trail_length: float = 0.9, p_z: int = 0) -> void:
	color = p_color
	size = p_size
	lifetime = p_lifetime
	velocity = p_velocity
	bloom_intensity = p_bloom
	trail_strength = p_trail_strength
	trail_length = p_trail_length
	z = p_z
	if is_inside_tree():
		_apply_settings()

func set_bloom_intensity(value: float) -> void:
	bloom_intensity = max(0.0, value)
	_update_materials(1.0)

func _ready() -> void:
	_build_nodes()
	_apply_settings()
	_last_position = global_position

func _process(delta: float) -> void:
	_age += delta
	if lifetime > 0.0 and _age >= lifetime:
		queue_free()
		return
	if velocity != Vector2.ZERO:
		global_position += velocity * delta
		if drag > 0.0:
			velocity = velocity.lerp(Vector2.ZERO, clamp(drag * delta, 0.0, 1.0))
	_update_motion(delta)

func _build_nodes() -> void:
	_core = MeshInstance2D.new()
	_core.name = "Core"
	_core.mesh = _make_quad()
	_core_material = _make_material(1.6)
	_core.material = _core_material
	_core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_core.z_index = z
	add_child(_core)

	_trail = MeshInstance2D.new()
	_trail.name = "Trail"
	_trail.mesh = _make_quad()
	_trail_material = _make_material(1.2)
	_trail.material = _trail_material
	_trail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_trail.z_index = z - 1
	add_child(_trail)

func _apply_settings() -> void:
	z_index = z
	if _core != null:
		_core.scale = Vector2.ONE * max(0.1, size)
	if _trail != null:
		_trail.scale = Vector2.ONE * max(0.1, size)
	_update_materials(1.0)
	_rot_3d = Vector3(
		randf_range(-0.4, 0.4),
		randf_range(-0.4, 0.4),
		randf_range(-PI, PI)
	)
	_rot_speed = Vector3(
		randf_range(-tilt_speed.x, tilt_speed.x),
		randf_range(-tilt_speed.y, tilt_speed.y),
		randf_range(-spin_speed, spin_speed)
	)

func _update_motion(delta: float) -> void:
	var life_t = 1.0
	if lifetime > 0.0:
		life_t = clamp(1.0 - (_age / lifetime), 0.0, 1.0)
	_rot_3d += _rot_speed * delta
	_update_materials(life_t)
	_update_trail(life_t, delta)
	_last_position = global_position

func _update_trail(life_t: float, delta: float) -> void:
	if _trail == null:
		return
	if trail_strength <= 0.01:
		_trail.visible = false
		return
	var motion = global_position - _last_position
	var speed = 0.0
	if delta > 0.0:
		speed = motion.length() / delta
	if speed <= 1.0:
		_trail.visible = false
		return
	_trail.visible = true
	var dir = motion.normalized()
	var stretch = clamp(1.0 + speed * 0.015 * trail_length, 1.0, 6.0)
	_trail.rotation = dir.angle()
	_trail.scale = Vector2(max(0.1, size) * stretch, max(0.1, size) * 0.45)
	_trail.position = -dir * (size * 0.45 * stretch)
	if _trail_material != null:
		_trail_material.set_shader_parameter("alpha", life_t * trail_strength)

func _update_materials(alpha: float) -> void:
	if _core_material != null:
		_core_material.set_shader_parameter("glow_color", color)
		_core_material.set_shader_parameter("bloom", bloom_intensity)
		_core_material.set_shader_parameter("alpha", alpha)
		_core_material.set_shader_parameter("rot", _rot_3d)
	if _trail_material != null:
		_trail_material.set_shader_parameter("glow_color", color)
		_trail_material.set_shader_parameter("bloom", bloom_intensity)
		_trail_material.set_shader_parameter("alpha", alpha * trail_strength)
		_trail_material.set_shader_parameter("rot", _rot_3d)

func _make_material(softness: float) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = _get_shader()
	material.set_shader_parameter("softness", softness)
	material.set_shader_parameter("bloom", bloom_intensity)
	material.set_shader_parameter("alpha", 1.0)
	material.set_shader_parameter("glow_color", color)
	material.set_shader_parameter("rot", _rot_3d)
	return material

func _make_quad() -> QuadMesh:
	if _shared_quad == null:
		_shared_quad = QuadMesh.new()
		_shared_quad.size = Vector2.ONE
	return _shared_quad

func _get_shader() -> Shader:
	if _shared_shader == null:
		_shared_shader = Shader.new()
		_shared_shader.code = GLOW_SHADER_CODE
	return _shared_shader
