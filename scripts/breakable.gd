extends Area2D

const TEX_SMALL = preload("res://assets/level1/level1_props/prop_graveyard_tombstone_small_32_v002.png")
const TEX_LARGE = preload("res://assets/level1/level1_props/prop_graveyard_tombstone_large_48_v002.png")
const TEX_SKULL = preload("res://assets/level1/level1_props/prop_graveyard_skull_pile_32_v002.png")
const TEX_PILLAR = preload("res://assets/level1/level1_props/prop_graveyard_broken_pillar_48_v002.png")
const TEX_FENCE = preload("res://assets/level1/level1_props/prop_graveyard_broken_fence_32_v002.png")
const TEX_CART = preload("res://assets/level1/level1_props/prop_graveyard_broken_cart_48_v001.png")

var value = 6
var xp = 2
var style = "small"
var is_chest = false
var _game: Node = null
var _chest_glow_timer = 0.0
var _chest_glow_interval = 0.24
@onready var sprite: Sprite2D = $Body
var _shadow: Sprite2D = null
static var _shadow_tex: Texture2D = null

func setup(game_ref: Node, amount: int, xp_amount: int, style_name: String = "small", chest: bool = false) -> void:
	_game = game_ref
	value = amount
	xp = xp_amount
	style = style_name
	is_chest = chest
	_apply_style()

func _ready() -> void:
	collision_layer = 0
	collision_mask = GameLayers.PLAYER
	body_entered.connect(_on_body_entered)
	_ensure_shadow()
	_apply_style()

# Soft contact shadow so breakables sit on the ground instead of floating. The
# radial texture is built once and shared across all breakables.
func _ensure_shadow() -> void:
	if _shadow != null and is_instance_valid(_shadow):
		return
	if _shadow_tex == null:
		var size := 48
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := float(size) * 0.5
		for y in range(size):
			for x in range(size):
				var d: float = Vector2(x - c, y - c).length() / c
				var a: float = clamp(1.0 - d, 0.0, 1.0)
				a = a * a
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_shadow_tex = ImageTexture.create_from_image(img)
	_shadow = Sprite2D.new()
	_shadow.texture = _shadow_tex
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shadow.modulate = Color(0, 0, 0, 0.32)
	_shadow.z_index = -1
	add_child(_shadow)
	move_child(_shadow, 0)

func _process(delta: float) -> void:
	if not is_chest or _game == null or not _game.has_method("spawn_glow_particle"):
		return
	_chest_glow_timer += delta
	if _chest_glow_timer < _chest_glow_interval:
		return
	_chest_glow_timer = 0.0
	var glow_color = Color(1.0, 0.85, 0.35).lerp(Color.WHITE, randf_range(0.05, 0.25))
	var offset = Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
	var vel = Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0))
	_game.spawn_glow_particle(global_position + offset, glow_color, randf_range(5.0, 7.5), 0.55, vel, 1.9, 0.55, 1.0, -1)

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player"):
		if _game != null:
			_game.add_resources(value)
			_game.add_xp(xp)
			if _game.has_method("spawn_pickup") and _game.has_method("should_spawn_heal_drop"):
				if _game.should_spawn_heal_drop(false, false, "breakable", is_chest):
					var heal_amount = 14 if is_chest else 12
					if _game.has_method("get_heal_drop_amount"):
						heal_amount = int(_game.get_heal_drop_amount(false, false, "breakable", is_chest))
					_game.spawn_pickup(global_position, heal_amount, "heal")
		queue_free()

func _apply_style() -> void:
	if sprite == null:
		return
	var tex: Texture2D = TEX_SMALL
	match style:
		"large":
			tex = TEX_LARGE
		"skull":
			tex = TEX_SKULL
		"pillar":
			tex = TEX_PILLAR
		"fence":
			tex = TEX_FENCE
		_:
			tex = TEX_SMALL
	if is_chest:
		tex = TEX_CART
	sprite.texture = tex
	# Seat the sprite so its base meets the node origin (the y-sort anchor) and
	# size the contact shadow to the art footprint.
	var h := 32.0
	if tex != null:
		h = float(tex.get_height())
	sprite.offset = Vector2(0, -h * 0.5)
	if _shadow != null and is_instance_valid(_shadow):
		var base_w: float = 48.0
		if _shadow_tex != null:
			base_w = float(_shadow_tex.get_width())
		var sx: float = (h * 0.6) / max(1.0, base_w)
		_shadow.scale = Vector2(sx, sx * 0.42)
		_shadow.position = Vector2(0, -2)
