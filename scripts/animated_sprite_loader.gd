extends AnimatedSprite2D

@export var frame_paths: Array[String] = []
@export var fps: float = 6.0
@export var animation_name: String = "default"
@export var autoplay: bool = true
@export var loop: bool = true

func _ready() -> void:
    if frame_paths.is_empty():
        return
    var frames := SpriteFrames.new()
    frames.add_animation(animation_name)
    frames.set_animation_speed(animation_name, fps)
    frames.set_animation_loop(animation_name, loop)
    for path in frame_paths:
        var texture := load(path)
        if texture != null:
            frames.add_frame(animation_name, texture)
    sprite_frames = frames
    animation = animation_name
    if autoplay:
        play()
