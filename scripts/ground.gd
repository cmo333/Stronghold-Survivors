extends TileMap

@export var tile_size: Vector2i = Vector2i(32, 32)
@export var radius: int = 80
@export var grass_folder: String = "res://assets/level1/level1_tiles"
@export var grass_variants: Array[Texture2D] = []

const GRASS_VARIANT_CANDIDATES := [
	["tile_graveyard_grass_base_32_v001.png", "tile_graveyard_grass_base_32_v002.png"],
	["tile_graveyard_grass_varA_32_v001.png", "tile_graveyard_grass_varA_32_v002.png"],
	["tile_graveyard_grass_varB_32_v001.png"],
]

func _ready() -> void:
	var variants := _resolve_grass_variants()
	if variants.is_empty():
		return

	var tileset := TileSet.new()
	tileset.tile_size = tile_size

	var source_ids: Array[int] = []
	for tex in variants:
		var source := TileSetAtlasSource.new()
		source.texture = tex
		source.texture_region_size = tile_size
		var source_id := tileset.add_source(source)
		source.create_tile(Vector2i.ZERO)
		source_ids.append(source_id)

	tile_set = tileset
	clear()

	var pattern := _build_pattern(variants.size())
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var idx := _pattern_index(x, y, pattern)
			set_cell(0, Vector2i(x, y), source_ids[idx], Vector2i.ZERO)

func _build_pattern(variant_count: int) -> Dictionary:
	if variant_count >= 3:
		return {"size": 3, "map": [0, 1, 0, 1, 2, 1, 0, 1, 0]}
	if variant_count == 2:
		return {"size": 2, "map": [0, 1, 1, 0]}
	return {"size": 1, "map": [0]}

func _pattern_index(x: int, y: int, pattern: Dictionary) -> int:
	var size: int = pattern["size"]
	var px: int = posmod(x, size)
	var py: int = posmod(y, size)
	var map: Array = pattern["map"]
	return int(map[py * size + px])

func _resolve_grass_variants() -> Array[Texture2D]:
	var variants := _compact_textures(grass_variants)
	if not variants.is_empty():
		if variants.size() > 3:
			variants.resize(3)
		return variants

	for options in GRASS_VARIANT_CANDIDATES:
		var tex := _load_first(grass_folder, options)
		if tex != null:
			variants.append(tex)
	if variants.size() > 3:
		variants.resize(3)
	return variants

func _load_first(folder: String, options: Array) -> Texture2D:
	for name in options:
		var tex := load(folder.path_join(name))
		if tex != null:
			return tex
	return null

func _compact_textures(textures: Array[Texture2D]) -> Array[Texture2D]:
	var filtered: Array[Texture2D] = []
	for tex in textures:
		if tex != null:
			filtered.append(tex)
	return filtered
