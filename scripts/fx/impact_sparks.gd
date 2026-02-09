extends GPUParticles2D

# Bouncing spark particles for impact effects
# Physics-based with gravity and bounce

var _lifetime: float = 0.5
var _velocity: Vector2 = Vector2.ZERO
var _has_bounce: bool = false
var _color: Color = Color.WHITE

func setup(color: Color, size: float, lifetime: float, velocity: Vector2, bounce: bool = true) -> void:
    _color = color
    _lifetime = lifetime
    _velocity = velocity
    _has_bounce = bounce
    
    # Configure particle system
    modulate = color
    amount = 1
    self.lifetime = lifetime
    explosiveness = 1.0  # All at once
    randomness = 1.0
    
    # Use process material for physics
    if process_material != null:
        var mat = process_material as ParticleProcessMaterial
        mat.initial_velocity_min = velocity.length() * 0.7
        mat.initial_velocity_max = velocity.length() * 1.3
        mat.direction = Vector3(velocity.normalized().x, velocity.normalized().y, 0)
        mat.gravity = Vector3(0, 400, 0) if bounce else Vector3(0, 0, 0)
        mat.scale_min = size * 0.5
        mat.scale_max = size
    
    # Create spark texture
    texture = _create_spark_texture()
    
    # Emit
    emitting = true
    
    # Auto cleanup
    var timer = get_tree().create_timer(lifetime + 0.1)
    timer.timeout.connect(queue_free)

func _create_spark_texture() -> Texture2D:
    var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    
    # Draw a bright pixel with glow
    var center = Vector2i(4, 4)
    img.set_pixelv(center, Color.WHITE)
    img.set_pixelv(center + Vector2i(1, 0), _color)
    img.set_pixelv(center - Vector2i(1, 0), _color)
    img.set_pixelv(center + Vector2i(0, 1), _color)
    img.set_pixelv(center - Vector2i(0, 1), _color)
    
    return ImageTexture.create_from_image(img)

func _ready() -> void:
    # Fallback if not configured
    if texture == null:
        texture = _create_spark_texture()
