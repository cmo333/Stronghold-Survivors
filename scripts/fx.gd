extends Node2D

@onready var sprite: AnimatedSprite2D = $Sprite

func setup(frame_paths: Array, fps: float = 10.0, lifetime: float = 0.35, loop: bool = false) -> void:
    if frame_paths.is_empty():
        queue_free()
        return
    var frames := SpriteFrames.new()
    frames.add_animation("default")
    frames.set_animation_speed("default", fps)
    frames.set_animation_loop("default", loop)
    var has_frame := false
    for path in frame_paths:
        if not ResourceLoader.exists(path):
            continue
        var texture := load(path)
        if texture != null:
            frames.add_frame("default", texture)
            has_frame = true
    if not has_frame:
        queue_free()
        return
    sprite.sprite_frames = frames
    sprite.animation = "default"
    sprite.play()
    if lifetime > 0.0:
        var timer := get_tree().create_timer(lifetime)
        timer.timeout.connect(queue_free)
