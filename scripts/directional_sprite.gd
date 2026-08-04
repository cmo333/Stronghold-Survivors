extends AnimatedSprite2D

@export var base_path = "res://assets/level1/level1_player_anim"
@export var prefix = "player_hunter_32"
@export var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
@export var frames_per_dir = 4
@export var fps = 8.0
@export var loop = true
@export var sprite_scale = 1.5

var _last_dir = "S"
var _moving := false
var _speed_ratio := 0.0
var _base_fps := 8.0

func _ready() -> void:
	_base_fps = fps
	_build_frames()
	# Start standing still: the player drives playback via set_moving(). Calling
	# play() here would leave the walk loop running while idle (the moonwalk bug)
	# because set_moving(false) early-returns when already not moving.
	_hold_idle_frame()

func configure(new_base_path: String, new_prefix: String) -> void:
	if new_base_path != "":
		base_path = new_base_path
	if new_prefix != "":
		prefix = new_prefix
	_build_frames()
	# Respect current movement state after a reconfigure instead of forcing the
	# walk loop on (which would animate while standing still).
	if _moving:
		play()
	else:
		_hold_idle_frame()

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
		# Only resume the walk cycle when actually moving; otherwise hold the
		# facing frame so the character doesn't moonwalk in place.
		if _moving:
			play()
		else:
			_hold_idle_frame()

func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	if _moving:
		play()
	else:
		_hold_idle_frame()

func set_speed_ratio(r: float) -> void:
	_speed_ratio = clampf(r, 0.0, 1.4)
	if sprite_frames == null:
		return
	# Match walk cadence to travel speed (slow shuffle vs fast run).
	var anim_fps: float = _base_fps * clampf(_speed_ratio * 1.15, 0.45, 1.4)
	if sprite_frames.has_animation(_last_dir):
		sprite_frames.set_animation_speed(_last_dir, anim_fps)

func _hold_idle_frame() -> void:
	# Pause on the planted/contact frame so the silhouette reads as standing.
	if sprite_frames != null and sprite_frames.has_animation(_last_dir):
		if animation != _last_dir:
			animation = _last_dir
		frame = 0
	stop()
