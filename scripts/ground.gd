extends TileMap

@export var tile_size: Vector2i = Vector2i(32, 32)
@export var radius: int = 80

const GRASS_TILE := "res://assets/level1/level1_tiles/tile_graveyard_grass_base_32_v002.png"

func _ready() -> void:
	var tex = load(GRASS_TILE)
	if tex == null:
		push_error("Failed to load grass tile: " + GRASS_TILE)
		return

	var tileset := TileSet.new()
	tileset.tile_size = tile_size

	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = tile_size
	var source_id := tileset.add_source(source)
	source.create_tile(Vector2i.ZERO)

	tile_set = tileset
	clear()

	# Simple repeating pattern - just one tile
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			set_cell(0, Vector2i(x, y), source_id, Vector2i.ZERO)
