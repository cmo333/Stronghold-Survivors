extends TileMap

@export var tile_size: Vector2i = Vector2i(32, 32)
@export var radius: int = 80

# Biome colors
const GRASS_COLOR = Color(0.35, 0.52, 0.28)
const MUD_COLOR = Color(0.42, 0.32, 0.22)  
const STONE_COLOR = Color(0.38, 0.38, 0.40)

# Zone thresholds
@export var grass_radius: int = 25
@export var transition_width: int = 15

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_tileset()
	_generate_terrain()

func _setup_tileset() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = tile_size
	
	# Create 3 atlas sources (grass=0, mud=1, stone=2)
	for terrain_id in range(3):
		var color: Color
		match terrain_id:
			0: color = GRASS_COLOR
			1: color = MUD_COLOR
			2: color = STONE_COLOR
		
		var tex := _create_color_texture(color)
		var atlas := TileSetAtlasSource.new()
		atlas.texture = tex
		atlas.texture_region_size = tile_size
		atlas.create_tile(Vector2i.ZERO)
		tileset.add_source(atlas)
	
	tile_set = tileset

func _create_color_texture(color: Color) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(color)
	
	# Add subtle noise
	for x in range(32):
		for y in range(32):
			if randf() < 0.1:
				var c := color.darkened(0.1)
				img.set_pixel(x, y, c)
	
	return ImageTexture.create_from_image(img)

func _generate_terrain() -> void:
	clear()
	
	# Generate radial zones with simple set_cell
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var pos := Vector2i(x, y)
			var dist := int(Vector2(x, y).length())
			
			if dist > radius:
				continue
			
			var terrain_id := _get_terrain_for_distance(dist, x, y)
			set_cell(0, pos, terrain_id, Vector2i.ZERO)

func _get_terrain_for_distance(dist: int, x: int, y: int) -> int:
	if dist < grass_radius:
		return 0  # Grass
	elif dist < grass_radius + transition_width:
		# Transition zone - blend with noise
		var t := float(dist - grass_radius) / float(transition_width)
		var noise := _pseudo_noise(x, y)
		var blend := t + (noise - 0.5) * 0.5
		return 1 if blend > 0.5 else 0
	elif dist < grass_radius + transition_width * 2:
		var t := float(dist - grass_radius - transition_width) / float(transition_width)
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
