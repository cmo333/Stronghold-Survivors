extends AnimatedSprite2D

@export var frame_paths: Array[String] = []
@export var fps: float = 6.0
@export var animation_name: String = "default"
@export var loop: bool = true
@export var auto_play: bool = true

func _ready() -> void:
	if frame_paths.is_empty():
		return
	var frames = SpriteFrames.new()
	# SpriteFrames already has "default" animation, remove it first
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)
	for path in frame_paths:
		var texture = load(path)
		if texture != null:
			frames.add_frame(animation_name, texture)
	sprite_frames = frames
	animation = animation_name
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE
	if auto_play:
		play()
