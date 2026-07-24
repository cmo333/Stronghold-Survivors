extends TileMap

@export var tile_size: Vector2i = Vector2i(32, 32)
@export var radius: int = 80

# Biome base colors
const GRASS_COLOR = Color(0.33, 0.50, 0.27)
const MUD_COLOR = Color(0.40, 0.31, 0.21)
const STONE_COLOR = Color(0.36, 0.36, 0.39)

const VARIANTS_PER_BIOME = 6

# Zone thresholds
@export var grass_radius: int = 25
@export var transition_width: int = 15

var _detail_noise := FastNoiseLite.new()
var _edge_noise := FastNoiseLite.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.18
	_detail_noise.seed = 1337
	_edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_edge_noise.frequency = 0.09
	_edge_noise.seed = 7331
	_setup_tileset()
	_generate_terrain()

func _setup_tileset() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = tile_size

	# One atlas per biome (grass=0, mud=1, stone=2), each with several variants
	for terrain_id in range(3):
		var tex := _create_biome_texture(terrain_id)
		var atlas := TileSetAtlasSource.new()
		atlas.texture = tex
		atlas.texture_region_size = tile_size
		for i in range(VARIANTS_PER_BIOME):
			atlas.create_tile(Vector2i(i, 0))
		tileset.add_source(atlas)

	tile_set = tileset

func _create_biome_texture(terrain_id: int) -> ImageTexture:
	"""Build a horizontal strip of tile variants with layered detail."""
	var w := tile_size.x
	var h := tile_size.y
	var img := Image.create(w * VARIANTS_PER_BIOME, h, false, Image.FORMAT_RGBA8)
	var base: Color
	match terrain_id:
		0: base = GRASS_COLOR
		1: base = MUD_COLOR
		_: base = STONE_COLOR

	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + terrain_id

	for v in range(VARIANTS_PER_BIOME):
		var ox := v * w
		# Slight per-variant value shift so the field doesn't read uniform
		var variant_base := base.darkened(rng.randf_range(0.0, 0.06)) if rng.randf() < 0.5 \
			else base.lightened(rng.randf_range(0.0, 0.04))
		# Layer 1: low-frequency blotches from simplex noise
		for x in range(w):
			for y in range(h):
				var n := _detail_noise.get_noise_2d(float(x + ox + v * 71), float(y + v * 37))
				var c := variant_base
				if n > 0.25:
					c = variant_base.lightened(0.05 + 0.05 * n)
				elif n < -0.25:
					c = variant_base.darkened(0.06 + 0.06 * -n)
				# Layer 2: fine grain speckle
				var s := rng.randf()
				if s < 0.06:
					c = c.darkened(0.12)
				elif s > 0.97:
					c = c.lightened(0.08)
				img.set_pixel(ox + x, y, c)
		# Layer 3: biome-specific details
		match terrain_id:
			0: _paint_grass_details(img, ox, rng)
			1: _paint_mud_details(img, ox, rng)
			_: _paint_stone_details(img, ox, rng)

	return ImageTexture.create_from_image(img)

func _paint_grass_details(img: Image, ox: int, rng: RandomNumberGenerator) -> void:
	# Short grass blades: 1px-wide vertical strokes in a brighter green
	for i in range(rng.randi_range(8, 14)):
		var x := rng.randi_range(1, tile_size.x - 2)
		var y := rng.randi_range(3, tile_size.y - 2)
		var blade := GRASS_COLOR.lightened(rng.randf_range(0.12, 0.28))
		var len_px := rng.randi_range(2, 3)
		for k in range(len_px):
			img.set_pixel(ox + x, y - k, blade)
	# Rare tiny flower
	if rng.randf() < 0.3:
		var fx := rng.randi_range(2, tile_size.x - 3)
		var fy := rng.randi_range(2, tile_size.y - 3)
		var petal := Color(0.92, 0.88, 0.55) if rng.randf() < 0.6 else Color(0.85, 0.75, 0.9)
		img.set_pixel(ox + fx, fy, petal)

func _paint_mud_details(img: Image, ox: int, rng: RandomNumberGenerator) -> void:
	# Dark horizontal streaks (dried ruts)
	for i in range(rng.randi_range(3, 6)):
		var x := rng.randi_range(1, tile_size.x - 7)
		var y := rng.randi_range(1, tile_size.y - 2)
		var streak := MUD_COLOR.darkened(rng.randf_range(0.15, 0.3))
		var len_px := rng.randi_range(3, 6)
		for k in range(len_px):
			img.set_pixel(ox + x + k, y, streak)
	# Occasional pebble
	for i in range(rng.randi_range(0, 2)):
		var px := rng.randi_range(2, tile_size.x - 4)
		var py := rng.randi_range(2, tile_size.y - 4)
		var pebble := Color(0.5, 0.47, 0.45).darkened(rng.randf_range(0.0, 0.15))
		img.set_pixel(ox + px, py, pebble)
		img.set_pixel(ox + px + 1, py, pebble)
		img.set_pixel(ox + px, py + 1, pebble.darkened(0.1))

func _paint_stone_details(img: Image, ox: int, rng: RandomNumberGenerator) -> void:
	# Cracks: short dark diagonal runs
	for i in range(rng.randi_range(1, 3)):
		var x := rng.randi_range(3, tile_size.x - 8)
		var y := rng.randi_range(3, tile_size.y - 8)
		var crack := STONE_COLOR.darkened(rng.randf_range(0.25, 0.4))
		var len_px := rng.randi_range(3, 7)
		for k in range(len_px):
			img.set_pixel(ox + x + k, y + k, crack)
			if rng.randf() < 0.4 and x + k + 1 < tile_size.x:
				img.set_pixel(ox + x + k + 1, y + k, crack.lightened(0.06))
	# Light chips
	for i in range(rng.randi_range(2, 5)):
		var cx := rng.randi_range(1, tile_size.x - 2)
		var cy := rng.randi_range(1, tile_size.y - 2)
		img.set_pixel(ox + cx, cy, STONE_COLOR.lightened(rng.randf_range(0.1, 0.2)))

func _generate_terrain() -> void:
	clear()

	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var pos := Vector2i(x, y)
			var dist := int(Vector2(x, y).length())

			if dist > radius:
				continue

			var terrain_id := _get_terrain_for_distance(dist, x, y)
			var variant := _variant_for_cell(x, y)
			set_cell(0, pos, terrain_id, Vector2i(variant, 0))

func _variant_for_cell(x: int, y: int) -> int:
	# Deterministic per-cell variant pick so regeneration is stable
	var n := int(_pseudo_noise(x * 3 + 11, y * 5 + 7) * 1000.0)
	return n % VARIANTS_PER_BIOME

func _get_terrain_for_distance(dist: int, x: int, y: int) -> int:
	# Organic wobble on the ring boundaries so biomes interlock like real terrain
	var wobble := _edge_noise.get_noise_2d(float(x), float(y)) * float(transition_width) * 0.8
	var d := float(dist) + wobble
	if d < float(grass_radius):
		return 0  # Grass
	elif d < float(grass_radius + transition_width):
		var t := (d - float(grass_radius)) / float(transition_width)
		var noise := _pseudo_noise(x, y)
		var blend := t + (noise - 0.5) * 0.5
		return 1 if blend > 0.5 else 0
	elif d < float(grass_radius + transition_width * 2):
		var t := (d - float(grass_radius + transition_width)) / float(transition_width)
		var noise := _pseudo_noise(x, y)
		var blend := t + (noise - 0.5) * 0.5
		return 2 if blend > 0.5 else 1
	else:
		# Outer wasteland
		var noise := _pseudo_noise(x, y)
		return 2 if noise > 0.3 else 1

func _pseudo_noise(x: int, y: int) -> float:
	var n := int(sin(float(x * 12.9898 + y * 78.233)) * 43758.5453)
	return float(abs(n) % 1000) / 1000.0

func get_biome_at(world_pos: Vector2) -> String:
	var tile_pos := local_to_map(world_pos)
	var dist := int(Vector2(tile_pos).length())

	if dist > radius:
		return "stone"
	elif dist < grass_radius:
		return "grass"
	elif dist < grass_radius + transition_width:
		return "transition"
	else:
		return "wasteland"
