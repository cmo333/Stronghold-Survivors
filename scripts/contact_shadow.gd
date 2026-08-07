extends RefCounted
class_name ContactShadow

## Soft elliptical contact shadows.
##
## Everything in the world was drawn floating on flat grass: a packed base read as
## a sticker sheet rather than a place. A single dark ellipse under each object
## does more for depth than any amount of extra sprite detail, and costs one
## Sprite2D sharing one texture.
##
## The texture is a squashed radial falloff generated once and reused, so adding
## shadows to hundreds of entities does not add hundreds of images.

const TEX_SIZE := 64
const SQUASH := 0.46          # height as a fraction of width - a ground plane read

static var _tex: ImageTexture = null

static func get_texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(TEX_SIZE) * 0.5
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var dx := (float(x) + 0.5 - c) / c
			# Squash vertically so the ellipse reads as a shape lying on the
			# ground rather than a ball floating behind the object.
			var dy := (float(y) + 0.5 - c) / (c * SQUASH)
			var d := sqrt(dx * dx + dy * dy)
			if d >= 1.0:
				continue
			# Squared falloff keeps the core solid and the edge soft, which reads
			# as a contact shadow instead of a blurry smudge.
			var a := (1.0 - d) * (1.0 - d)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_tex = ImageTexture.create_from_image(img)
	return _tex

## Attach a shadow to `host`. `width` is the shadow's full width in world pixels.
static func attach(host: Node2D, width: float, alpha: float = 0.34, y_offset: float = 0.0) -> Sprite2D:
	if host == null:
		return null
	var existing = host.get_node_or_null("ContactShadow")
	if existing != null:
		return existing as Sprite2D
	var shadow := Sprite2D.new()
	shadow.name = "ContactShadow"
	shadow.texture = get_texture()
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shadow.modulate = Color(0.0, 0.0, 0.02, alpha)
	# z_index stays 0. A negative index would drop the shadow below the ground
	# tilemap and make it invisible; being first in the child list already puts
	# it under its own object's art, which is all that is wanted.
	shadow.z_index = 0
	var s := width / float(TEX_SIZE)
	shadow.scale = Vector2.ONE * s
	# The visual drop comes from the sprite's texture offset rather than its
	# node position, so a Y-sorted parent still treats the shadow as sitting at
	# the object's own origin instead of sorting it in front.
	shadow.position = Vector2.ZERO
	shadow.offset = Vector2(0.0, y_offset / max(0.0001, s))
	host.add_child(shadow)
	host.move_child(shadow, 0)
	return shadow
