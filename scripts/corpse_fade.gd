extends Sprite2D
class_name CorpseFade

# Fading corpse sprite that stays for a short time after enemy death
# Scales down to 0.2x and fades alpha over lifetime

var _lifetime: float = 1.0
var _elapsed: float = 0.0
var _start_scale: Vector2 = Vector2.ONE
var _target_scale: Vector2 = Vector2.ONE * 0.2
var _base_color: Color = Color.WHITE

func setup(p_texture: Texture2D, p_color: Color, p_start_scale: Vector2, p_lifetime: float = 1.0) -> void:
    self.texture = p_texture
    _base_color = p_color
    _start_scale = p_start_scale
    _target_scale = p_start_scale * 0.2
    _lifetime = p_lifetime
    
    modulate = p_color
    scale = p_start_scale
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = -1  # Below living entities
    
    # Center the sprite
    if p_texture != null:
        offset = Vector2(-p_texture.get_width() / 2.0, -p_texture.get_height() / 2.0)
    
    # Flash white initially
    _flash_white()

func _flash_white() -> void:
    modulate = Color.WHITE
    
    # Tween to base color
    var tween = create_tween()
    tween.tween_property(self, "modulate", _base_color, 0.1)
    tween.tween_callback(_start_fade_sequence)

func _start_fade_sequence() -> void:
    # Main fade sequence: scale down and fade out
    var tween = create_tween()
    
    # Scale to 0.2x over lifetime
    tween.parallel().tween_property(self, "scale", _target_scale, _lifetime).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    
    # Fade alpha to 0
    var fade_color = _base_color
    fade_color.a = 0.0
    tween.parallel().tween_property(self, "modulate", fade_color, _lifetime * 0.8).set_delay(_lifetime * 0.2)
    
    # Cleanup
    tween.tween_callback(queue_free)

func _process(delta: float) -> void:
    _elapsed += delta
    
    # Safety cleanup
    if _elapsed >= _lifetime + 0.5:
        queue_free()
