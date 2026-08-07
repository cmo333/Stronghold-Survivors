extends AnimatedSprite2D

@export var base_path = "res://assets/level1/level1_player_anim"
@export var prefix = "player_hunter_32"
@export var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
@export var frames_per_dir = 4
@export var fps = 8.0
@export var loop = true
@export var sprite_scale = 1.5

# Build the west headings by mirroring their eastern twin, and take the
# up-diagonals from the north (back) pose.
#
# The hero art is generated one heading at a time, and two headings came back
# wrong in ways that read as the character walking backwards:
#   - the NE/NW frames face the camera, so walking away from the screen showed
#     the character's face instead of their back;
#   - in the older sets every heading faces east, so walking west moonwalked.
# Deriving the west half by mirroring makes left/right disagree-with-travel
# impossible for any art set, present or future.
@export var derive_headings := true

# Re-anchor each frame of a walk cycle on the cycle's own centre of mass.
#
# The frames inside one strip drift sideways - up to 10px of a 40px cell on the
# hunter set - so the character skates across the sprite and snaps back every
# loop, on top of whatever the player's actual movement is doing. The drift is
# a pure translation (the strips were sliced on a shared crop rectangle rather
# than per-frame), so subtracting it restores a planted walk.
@export var align_frames := true

# heading -> [source heading, mirrored]
const DERIVED_HEADINGS := {
	"N": ["N", false],
	"NE": ["N", false],
	"NW": ["N", true],
	"E": ["E", false],
	"W": ["E", true],
	"SE": ["SE", false],
	"SW": ["SE", true],
	"S": ["S", false],
}

# Fraction of the silhouette used to anchor a frame. The legs alternate through
# a walk cycle, so anchoring on the whole body would fight the animation; the
# head and torso are what should stay put.
const ANCHOR_BODY_FRACTION := 0.55
const ANCHOR_ALPHA_CUTOFF := 0.3

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
	# One animation per *source* heading; mirrored headings share it and flip at
	# draw time, so N/NE/NW are one set of textures rather than three.
	for src in _source_headings():
		var textures := _load_heading(src)
		if textures.is_empty():
			# A hero set missing this heading would otherwise leave an empty
			# animation that renders nothing at all when faced.
			continue
		frames.add_animation(src)
		frames.set_animation_speed(src, fps)
		frames.set_animation_loop(src, loop)
		for tex in textures:
			frames.add_frame(src, tex)
	sprite_frames = frames
	_apply_heading(_last_dir)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * sprite_scale

# The distinct headings that own art, in the order they should be built.
func _source_headings() -> Array:
	if not derive_headings:
		return directions.duplicate()
	var seen: Array = []
	for dir in directions:
		var src: String = _source_for(dir)[0]
		if not seen.has(src):
			seen.append(src)
	return seen

func _source_for(dir: String) -> Array:
	if derive_headings and DERIVED_HEADINGS.has(dir):
		return DERIVED_HEADINGS[dir]
	return [dir, false]

func _frame_path(dir: String, index: int) -> String:
	return "%s/%s_%s_move_f%03d_v001.png" % [base_path, prefix, dir, index]

func _load_heading(dir: String) -> Array:
	var images: Array = []
	for i in range(1, frames_per_dir + 1):
		var path := _frame_path(dir, i)
		if not ResourceLoader.exists(path):
			continue
		var tex = load(path)
		if tex == null:
			continue
		if not align_frames:
			images.append(tex)
			continue
		var img: Image = tex.get_image()
		if img == null:
			images.append(tex)
			continue
		# Imported textures can come back VRAM-compressed, which has no
		# per-pixel access and cannot be blitted into.
		if img.is_compressed():
			if img.decompress() != OK:
				images.append(tex)
				continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		images.append(img)
	if not align_frames:
		return images
	return _align(images)

# Shift every frame so its upper body sits on the cycle's mean position, and pad
# the canvas so no shift pushes art off the edge. Padding is symmetric, so the
# character keeps its offset from the sprite's origin and nothing moves on
# screen except the drift being removed.
func _align(images: Array) -> Array:
	var anchors: Array = []
	for img in images:
		if not (img is Image):
			return _to_textures(images)
		anchors.append(_anchor_x(img))
	if anchors.is_empty():
		return []
	var mean := 0.0
	for a in anchors:
		mean += a
	mean /= float(anchors.size())

	var shifts: Array = []
	var pad := 0
	for a in anchors:
		var s := int(round(mean - a))
		shifts.append(s)
		pad = max(pad, abs(s))

	var out: Array = []
	for i in range(images.size()):
		var src: Image = images[i]
		var padded := Image.create(src.get_width() + pad * 2, src.get_height() + pad * 2, false, Image.FORMAT_RGBA8)
		padded.fill(Color(0, 0, 0, 0))
		padded.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(pad + int(shifts[i]), pad))
		out.append(ImageTexture.create_from_image(padded))
	return out

# Alpha-weighted horizontal centre of the head and torso. Reads the raw RGBA8
# buffer rather than calling get_pixel() per texel, since this walks every frame
# of every heading each time a hero is built.
func _anchor_x(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var cutoff := int(ANCHOR_ALPHA_CUTOFF * 255.0)
	var top := -1
	var bottom := -1
	for y in range(h):
		var row := y * w * 4
		for x in range(w):
			if data[row + x * 4 + 3] > cutoff:
				if top < 0:
					top = y
				bottom = y
				break
	if top < 0:
		return w * 0.5
	var cut: int = top + int(float(bottom - top) * ANCHOR_BODY_FRACTION)
	var sum_x := 0.0
	var sum_a := 0.0
	for y in range(top, min(cut + 1, h)):
		var row := y * w * 4
		for x in range(w):
			var a: int = data[row + x * 4 + 3]
			if a == 0:
				continue
			sum_x += x * a
			sum_a += a
	if sum_a <= 0.0:
		return w * 0.5
	return sum_x / sum_a

func _to_textures(images: Array) -> Array:
	var out: Array = []
	for img in images:
		if img is Image:
			out.append(ImageTexture.create_from_image(img))
		else:
			out.append(img)
	return out

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
	if dir == _last_dir:
		return
	_last_dir = dir
	_apply_heading(dir)

# Point the sprite at a heading without restarting the walk. Turning used to
# reset `frame` to 0, so strafing around a corner replayed the contact frame
# over and over and the legs never got through a full step.
func _apply_heading(dir: String) -> void:
	var mapping := _source_for(dir)
	var src: String = mapping[0]
	flip_h = bool(mapping[1])
	if sprite_frames == null:
		return
	if not sprite_frames.has_animation(src):
		src = _fallback_animation()
		if src == "":
			return
	if animation == src:
		return
	var keep_frame := frame
	var keep_progress := frame_progress
	animation = src
	var count := sprite_frames.get_frame_count(src)
	if count > 0:
		frame = keep_frame % count
		frame_progress = keep_progress
	if _moving:
		play()
	else:
		stop()

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
	# Match walk cadence to travel speed (slow shuffle vs fast run). speed_scale
	# applies to whichever animation is playing; setting it on the SpriteFrames
	# resource only ever reached the heading that happened to be current.
	speed_scale = clampf(_speed_ratio * 1.15, 0.45, 1.4)

# Any heading that actually has art, for hero sets missing one.
func _fallback_animation() -> String:
	if sprite_frames == null:
		return ""
	for name in sprite_frames.get_animation_names():
		if sprite_frames.get_frame_count(name) > 0:
			return name
	return ""

func _hold_idle_frame() -> void:
	# Pause on the planted/contact frame so the silhouette reads as standing.
	var src: String = _source_for(_last_dir)[0]
	if sprite_frames != null and not sprite_frames.has_animation(src):
		src = _fallback_animation()
	if sprite_frames != null and sprite_frames.has_animation(src):
		if animation != src:
			animation = src
		frame = 0
	stop()
