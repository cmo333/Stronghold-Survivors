extends Node2D

@export var sprite_path: NodePath = NodePath("Sprite")
@onready var sprite: AnimatedSprite2D = get_node_or_null(sprite_path) as AnimatedSprite2D

func setup(frame_paths: Array, fps: float = 10.0, lifetime: float = 0.35, loop: bool = false, scale: float = 1.0, alpha: float = 1.0, z: int = 0, tint: Color = Color.WHITE) -> void:
	if sprite == null:
		push_warning("FX missing AnimatedSprite2D at path: %s" % [str(sprite_path)])
		queue_free()
		return
	if frame_paths.is_empty():
		queue_free()
		return
	var frames = SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", loop)
	var has_frame = false
	for path in frame_paths:
		if not ResourceLoader.exists(path):
			continue
		var texture = load(path)
		if texture != null:
			frames.add_frame("default", texture)
			has_frame = true
	if not has_frame:
		queue_free()
		return
	sprite.sprite_frames = frames
	sprite.animation = "default"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = z
	sprite.scale = Vector2.ONE * max(0.1, scale)
	sprite.modulate = Color(tint.r, tint.g, tint.b, clamp(alpha, 0.0, 1.0) * tint.a)
	sprite.play()
	if lifetime > 0.0:
		var timer = get_tree().create_timer(lifetime)
		timer.timeout.connect(queue_free)
