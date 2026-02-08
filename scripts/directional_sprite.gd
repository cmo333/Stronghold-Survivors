extends AnimatedSprite2D

@export var base_path = "res://assets/level1/level1_player_anim"
@export var prefix = "player_hunter_32"
@export var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
@export var frames_per_dir = 4
@export var fps = 8.0
@export var loop = true
@export var sprite_scale = 2.2

var _last_dir = "S"

func _ready() -> void:
	_build_frames()
	play()

func configure(new_base_path: String, new_prefix: String) -> void:
	if new_base_path != "":
		base_path = new_base_path
	if new_prefix != "":
		prefix = new_prefix
	_build_frames()
	play()

func _build_frames() -> void:
	_ensure_defaults()
	var frames = SpriteFrames.new()
	for dir in directions:
		frames.add_animation(dir)
		frames.set_animation_speed(dir, fps)
		frames.set_animation_loop(dir, loop)
		for i in range(1, frames_per_dir + 1):
			var path = "%s/%s_%s_move_f%03d_v001.png" % [base_path, prefix, dir, i]
			if ResourceLoader.exists(path):
				frames.add_frame(dir, load(path))
	sprite_frames = frames
	animation = _last_dir
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * sprite_scale

func _ensure_defaults() -> void:
	if base_path == null or base_path == "":
		base_path = "res://assets/level1/level1_player_anim"
	if prefix == null or prefix == "":
		prefix = "player_hunter_32"
	if directions == null or typeof(directions) != TYPE_ARRAY or directions.is_empty():
		directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	if frames_per_dir == null or int(frames_per_dir) <= 0:
		frames_per_dir = 4
	if fps == null or float(fps) <= 0.0:
		fps = 8.0
	if loop == null:
		loop = true
	if sprite_scale == null or float(sprite_scale) <= 0.0:
		sprite_scale = 1.0

func set_direction(dir: String) -> void:
	if dir == "":
		return
	_last_dir = dir
	if animation != dir:
		animation = dir
		play()
