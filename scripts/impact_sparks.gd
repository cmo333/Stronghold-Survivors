extends GPUParticles2D
class_name ImpactSparks

# Bouncing spark particles for impact effects
# Physics-based with gravity and bounce

var _lifetime: float = 0.5
var _velocity: Vector2 = Vector2.ZERO
var _has_bounce: bool = false
var _particle_color: Color = Color.WHITE

func setup(p_color: Color, size: float, p_lifetime: float, p_velocity: Vector2, bounce: bool = true) -> void:
    _particle_color = p_color
    _lifetime = p_lifetime
    _velocity = p_velocity
    _has_bounce = bounce
    
    # Configure particle system
    modulate = p_color
    amount = 1
    lifetime = p_lifetime
    explosiveness = 1.0  # All at once
    randomness = 1.0
    
    # Use process material for physics
    if process_material != null:
        var mat = process_material as ParticleProcessMaterial
        mat.initial_velocity_min = p_velocity.length() * 0.7
        mat.initial_velocity_max = p_velocity.length() * 1.3
        mat.direction = Vector3(p_velocity.normalized().x, p_velocity.normalized().y, 0)
        mat.gravity = Vector3(0, 400, 0) if bounce else Vector3(0, 0, 0)
        mat.scale_min = size * 0.5
        mat.scale_max = size
    
    # Create spark texture
    texture = _create_spark_texture()
    
    # Emit
    emitting = true
    
    # Auto cleanup
    var timer = get_tree().create_timer(p_lifetime + 0.1)
    timer.timeout.connect(queue_free)

func _create_spark_texture() -> Texture2D:
    var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    
    # Draw a bright pixel with glow
    var center = Vector2i(4, 4)
    img.set_pixelv(center, Color.WHITE)
    img.set_pixelv(center + Vector2i(1, 0), _particle_color)
    img.set_pixelv(center - Vector2i(1, 0), _particle_color)
    img.set_pixelv(center + Vector2i(0, 1), _particle_color)
    img.set_pixelv(center - Vector2i(0, 1), _particle_color)
    
    return ImageTexture.create_from_image(img)

func _ready() -> void:
    # Fallback if not configured
    if texture == null:
        texture = _create_spark_texture()
