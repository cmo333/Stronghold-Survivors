extends GPUParticles2D

# Ambient environmental particles (dust motes, fireflies, embers)
# Uses GPU particles for performance with many particles

const DUST_COLOR = Color(0.9, 0.85, 0.75, 0.3)
const FIREFLY_COLOR = Color(0.6, 1.0, 0.4, 0.7)
const EMBER_COLOR = Color(1.0, 0.5, 0.2, 0.6)

func setup_dust() -> void:
    # Dust motes floating in light
    amount = 30
    lifetime = 8.0
    
    modulate = DUST_COLOR
    
    if process_material != null:
        var mat = process_material as ParticleProcessMaterial
        mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
        mat.emission_box_extents = Vector3(400, 300, 1)
        mat.initial_velocity_min = 5.0
        mat.initial_velocity_max = 15.0
        mat.damping_min = 0.5
        mat.damping_max = 2.0
    
    _create_dust_texture()

func setup_fireflies() -> void:
    # Fireflies in grass zones
    amount = 15
    lifetime = 6.0
    
    modulate = FIREFLY_COLOR
    
    if process_material != null:
        var mat = process_material as ParticleProcessMaterial
        mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
        mat.emission_box_extents = Vector3(300, 200, 1)
        mat.initial_velocity_min = 8.0
        mat.initial_velocity_max = 20.0
        mat.damping_min = 0.2
        mat.damping_max = 0.8
    
    _create_firefly_texture()

func setup_embers() -> void:
    # Embers in wasteland zones
    amount = 40
    lifetime = 4.0
    
    modulate = EMBER_COLOR
    
    if process_material != null:
        var mat = process_material as ParticleProcessMaterial
        mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
        mat.emission_box_extents = Vector3(350, 250, 1)
        mat.initial_velocity_min = 10.0
        mat.initial_velocity_max = 30.0
        # Embers float upward
        mat.direction = Vector3(0, -1, 0)
        mat.spread = 45.0
        mat.damping_min = 0.1
        mat.damping_max = 0.5
    
    _create_ember_texture()

func _create_dust_texture() -> void:
    var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    
    # Soft pixel
    var center = Color(1.0, 1.0, 1.0, 0.6)
    img.set_pixel(1, 1, center)
    img.set_pixel(2, 1, center)
    img.set_pixel(1, 2, center)
    img.set_pixel(2, 2, center)
    
    texture = ImageTexture.create_from_image(img)

func _create_firefly_texture() -> void:
    var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    
    # Glowing center
    var bright = Color(1.0, 1.0, 1.0, 1.0)
    var glow = Color(1.0, 1.0, 1.0, 0.5)
    
    img.set_pixel(2, 2, bright)
    img.set_pixel(3, 2, bright)
    img.set_pixel(2, 3, bright)
    img.set_pixel(3, 3, bright)
    img.set_pixel(1, 2, glow)
    img.set_pixel(4, 2, glow)
    img.set_pixel(2, 1, glow)
    img.set_pixel(2, 4, glow)
    
    texture = ImageTexture.create_from_image(img)

func _create_ember_texture() -> void:
    var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    
    # Small bright ember
    var center = Color(1.0, 0.9, 0.7, 1.0)
    img.set_pixel(1, 1, center)
    img.set_pixel(2, 1, center)
    img.set_pixel(1, 2, center)
    img.set_pixel(2, 2, center)
    
    texture = ImageTexture.create_from_image(img)

func _ready() -> void:
    # Default to dust if not configured
    if texture == null:
        setup_dust()
