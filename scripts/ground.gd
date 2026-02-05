extends TileMap

@export var tile_texture: Texture2D
@export var tile_textures: Array[Texture2D] = []
@export var tile_size: Vector2i = Vector2i(32, 32)
@export var radius: int = 80
@export var base_weight: float = 0.7

func _ready() -> void:
	var textures: Array[Texture2D] = []
	for tex in tile_textures:
		if tex != null:
			textures.append(tex)
	if textures.is_empty() and tile_texture != null:
		textures.append(tile_texture)
	if textures.is_empty():
		return
	var tileset = TileSet.new()
	tileset.tile_size = tile_size
	var sources: Array = []
	for tex in textures:
		var source = TileSetAtlasSource.new()
		source.texture = tex
		source.texture_region_size = tile_size
		var source_id = tileset.add_source(source)
		source.create_tile(Vector2i(0, 0))
		sources.append(source_id)
	tile_set = tileset
	clear()
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var source_id = _pick_source(sources)
			set_cell(0, Vector2i(x, y), source_id, Vector2i(0, 0))

func _pick_source(sources: Array) -> int:
	if sources.is_empty():
		return -1
	if sources.size() == 1:
		return sources[0]
	if randf() <= base_weight:
		return sources[0]
	return sources[randi_range(1, sources.size() - 1)]
