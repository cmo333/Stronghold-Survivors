extends TileMap

const TERRAIN_GRASS := 0
const TERRAIN_MUD := 1
const TERRAIN_STONE := 2

const EDGE_DIRS := ["N", "E", "S", "W"]
const CORNER_DIRS := ["NE", "NW", "SE", "SW"]
const DIR_OFFSETS := {
	"N": Vector2i(0, -1),
	"E": Vector2i(1, 0),
	"S": Vector2i(0, 1),
	"W": Vector2i(-1, 0),
	"NE": Vector2i(1, -1),
	"NW": Vector2i(-1, -1),
	"SE": Vector2i(1, 1),
	"SW": Vector2i(-1, 1),
}

@export var tile_texture: Texture2D
@export var tile_textures: Array[Texture2D] = []
@export var tile_size: Vector2i = Vector2i(32, 32)
@export var radius: int = 80
@export var base_weight: float = 0.7

@export var use_auto_tiles: bool = true
@export var terrain_folder: String = "res://assets/level1/level1_terrain_macro"

@export var grass_tiles: Array[Texture2D] = []
@export var mud_tiles: Array[Texture2D] = []
@export var stone_tiles: Array[Texture2D] = []
@export var dark_grass_tiles: Array[Texture2D] = []
@export var blood_tiles: Array[Texture2D] = []

# Order: N, E, S, W
@export var grass_to_mud_edges: Array[Texture2D] = []
@export var grass_to_stone_edges: Array[Texture2D] = []

# Order: NE, NW, SE, SW
@export var grass_to_mud_corners: Array[Texture2D] = []
@export var grass_to_stone_corners: Array[Texture2D] = []

@export var seed: int = 1337
@export var noise_frequency: float = 0.035
@export var mud_threshold: float = -0.28
@export var stone_threshold: float = 0.32
@export var smooth_passes: int = 1
@export var accent_frequency: float = 0.08
@export var dark_grass_threshold: float = 0.55
@export var blood_threshold: float = 0.6

func _ready() -> void:
	var tiles: Dictionary = _resolve_tiles()
	if tiles["grass"].is_empty():
		return

	var tileset: TileSet = TileSet.new()
	tileset.tile_size = tile_size
	var source_ids: Dictionary = {}

	# Register all textures up front for stable IDs.
	for tex in tiles["all"]:
		_register_texture(tex, tileset, source_ids)

	tile_set = tileset
	clear()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed

	var terrain_map: Dictionary = _generate_terrain_map()
	var accent_noise: FastNoiseLite = _build_noise(seed + 1337, accent_frequency)

	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var pos: Vector2i = Vector2i(x, y)
			var terrain: int = int(terrain_map.get(pos, TERRAIN_GRASS))
			var tex: Texture2D = null

			if terrain == TERRAIN_GRASS:
				tex = _select_transition_tile(pos, terrain_map, tiles)
				if tex == null:
					if _use_accent(accent_noise, pos, dark_grass_threshold) and not tiles["dark_grass"].is_empty():
						tex = _pick_variant(tiles["dark_grass"], rng)
					else:
						tex = _pick_variant(tiles["grass"], rng)
			elif terrain == TERRAIN_MUD:
				if _use_accent(accent_noise, pos, blood_threshold) and not tiles["blood"].is_empty():
					tex = _pick_variant(tiles["blood"], rng)
				else:
					tex = _pick_variant(tiles["mud"], rng)
			else:
				tex = _pick_variant(tiles["stone"], rng)

			var source_id := _register_texture(tex, tileset, source_ids)
			set_cell(0, pos, source_id, Vector2i(0, 0))

func _register_texture(tex: Texture2D, tileset: TileSet, source_ids: Dictionary) -> int:
	if tex == null:
		return -1
	var key := tex.resource_path
	if key == "":
		key = str(tex.get_instance_id())
	if source_ids.has(key):
		return source_ids[key]
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = tile_size
	var source_id := tileset.add_source(source)
	source.create_tile(Vector2i(0, 0))
	source_ids[key] = source_id
	return source_id

func _build_noise(noise_seed: int, frequency: float) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = 2
	noise.fractal_gain = 0.5
	return noise

func _generate_terrain_map() -> Dictionary:
	var noise: FastNoiseLite = _build_noise(seed, noise_frequency)
	var terrain: Dictionary = {}
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var n: float = noise.get_noise_2d(x, y)
			var t: int = TERRAIN_GRASS
			if n < mud_threshold:
				t = TERRAIN_MUD
			elif n > stone_threshold:
				t = TERRAIN_STONE
			terrain[Vector2i(x, y)] = t

	for _i in range(smooth_passes):
		terrain = _smooth_terrain(terrain)

	return terrain

func _smooth_terrain(terrain: Dictionary) -> Dictionary:
	var smoothed: Dictionary = {}
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var pos: Vector2i = Vector2i(x, y)
			var counts: Array[int] = [0, 0, 0]
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if ox == 0 and oy == 0:
						continue
					var npos: Vector2i = Vector2i(x + ox, y + oy)
					var t: int = int(terrain.get(npos, terrain[pos]))
					counts[t] += 1
			var best: int = TERRAIN_GRASS
			var best_count: int = counts[best]
			for i in range(3):
				if counts[i] > best_count:
					best = i
					best_count = counts[i]
			if best_count >= 5:
				smoothed[pos] = best
			else:
				smoothed[pos] = terrain[pos]
	return smoothed

func _select_transition_tile(pos: Vector2i, terrain_map: Dictionary, tiles: Dictionary) -> Texture2D:
	var neighbors: Dictionary = {
		"N": terrain_map.get(pos + DIR_OFFSETS["N"], TERRAIN_GRASS),
		"E": terrain_map.get(pos + DIR_OFFSETS["E"], TERRAIN_GRASS),
		"S": terrain_map.get(pos + DIR_OFFSETS["S"], TERRAIN_GRASS),
		"W": terrain_map.get(pos + DIR_OFFSETS["W"], TERRAIN_GRASS),
	}

	var mud_count: int = 0
	var stone_count: int = 0
	for dir in EDGE_DIRS:
		var t: int = int(neighbors[dir])
		if t == TERRAIN_MUD:
			mud_count += 1
		elif t == TERRAIN_STONE:
			stone_count += 1

	if mud_count == 0 and stone_count == 0:
		return null

	var use_mud: bool = mud_count >= stone_count
	var edges: Dictionary = tiles["gm_edges"] if use_mud else tiles["gs_edges"]
	var corners: Dictionary = tiles["gm_corners"] if use_mud else tiles["gs_corners"]
	var target: int = TERRAIN_MUD if use_mud else TERRAIN_STONE

	var n: bool = neighbors["N"] == target
	var e: bool = neighbors["E"] == target
	var s: bool = neighbors["S"] == target
	var w: bool = neighbors["W"] == target

	if n and e and corners.has("NE"):
		return corners["NE"]
	if n and w and corners.has("NW"):
		return corners["NW"]
	if s and e and corners.has("SE"):
		return corners["SE"]
	if s and w and corners.has("SW"):
		return corners["SW"]
	if n and edges.has("N"):
		return edges["N"]
	if e and edges.has("E"):
		return edges["E"]
	if s and edges.has("S"):
		return edges["S"]
	if w and edges.has("W"):
		return edges["W"]
	return null

func _use_accent(noise: FastNoiseLite, pos: Vector2i, threshold: float) -> bool:
	return noise.get_noise_2d(pos.x, pos.y) > threshold

func _pick_variant(textures: Array[Texture2D], rng: RandomNumberGenerator) -> Texture2D:
	if textures.is_empty():
		return null
	if textures.size() == 1:
		return textures[0]
	return textures[rng.randi_range(0, textures.size() - 1)]

func _resolve_tiles() -> Dictionary:
	var tiles: Dictionary = {
		"grass": [],
		"mud": [],
		"stone": [],
		"dark_grass": [],
		"blood": [],
		"gm_edges": {},
		"gm_corners": {},
		"gs_edges": {},
		"gs_corners": {},
		"all": [],
	}

	if use_auto_tiles:
		tiles = _load_tiles_from_folder(terrain_folder, tiles)

	if tiles["grass"].is_empty():
		tiles["grass"] = _compact_textures(grass_tiles)
	if tiles["mud"].is_empty():
		tiles["mud"] = _compact_textures(mud_tiles)
	if tiles["stone"].is_empty():
		tiles["stone"] = _compact_textures(stone_tiles)
	if tiles["dark_grass"].is_empty():
		tiles["dark_grass"] = _compact_textures(dark_grass_tiles)
	if tiles["blood"].is_empty():
		tiles["blood"] = _compact_textures(blood_tiles)

	_assign_edges_and_corners(tiles, grass_to_mud_edges, grass_to_mud_corners, "gm_edges", "gm_corners")
	_assign_edges_and_corners(tiles, grass_to_stone_edges, grass_to_stone_corners, "gs_edges", "gs_corners")

	if tiles["grass"].is_empty():
		tiles["grass"] = _compact_textures(tile_textures)
	if tiles["grass"].is_empty() and tile_texture != null:
		tiles["grass"] = [tile_texture]

	tiles["all"] = _gather_all_textures(tiles)
	return tiles

func _assign_edges_and_corners(
		tiles: Dictionary,
		edges: Array[Texture2D],
		corners: Array[Texture2D],
		edges_key: String,
		corners_key: String
	) -> void:
	var edge_dict: Dictionary = tiles[edges_key]
	if edge_dict.is_empty() and edges.size() >= 4:
		for i in range(4):
			if edges[i] != null:
				edge_dict[EDGE_DIRS[i]] = edges[i]
		tiles[edges_key] = edge_dict
	var corner_dict: Dictionary = tiles[corners_key]
	if corner_dict.is_empty() and corners.size() >= 4:
		for i in range(4):
			if corners[i] != null:
				corner_dict[CORNER_DIRS[i]] = corners[i]
		tiles[corners_key] = corner_dict

func _load_tiles_from_folder(folder: String, tiles: Dictionary) -> Dictionary:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return tiles

	var grass_files: Array[String] = []
	var mud_files: Array[String] = []
	var stone_files: Array[String] = []
	var dark_grass_files: Array[String] = []
	var blood_files: Array[String] = []

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".png"):
			if file_name.begins_with("tile_graveyard_grass_base_"):
				grass_files.append(file_name)
			elif file_name.begins_with("tile_graveyard_mud_base_"):
				mud_files.append(file_name)
			elif file_name.begins_with("tile_graveyard_stone_cracked_"):
				stone_files.append(file_name)
			elif file_name.begins_with("tile_graveyard_grass_dark_clump_"):
				dark_grass_files.append(file_name)
			elif file_name.begins_with("tile_graveyard_dirt_blood_"):
				blood_files.append(file_name)
			elif file_name.begins_with("tile_graveyard_grass_to_mud_edge"):
				_assign_edge_file(tiles["gm_edges"], folder, file_name, "edge", 1)
			elif file_name.begins_with("tile_graveyard_grass_to_mud_corner"):
				_assign_edge_file(tiles["gm_corners"], folder, file_name, "corner", 2)
			elif file_name.begins_with("tile_graveyard_grass_to_stone_edge"):
				_assign_edge_file(tiles["gs_edges"], folder, file_name, "edge", 1)
			elif file_name.begins_with("tile_graveyard_grass_to_stone_corner"):
				_assign_edge_file(tiles["gs_corners"], folder, file_name, "corner", 2)
		file_name = dir.get_next()
	dir.list_dir_end()

	grass_files.sort()
	mud_files.sort()
	stone_files.sort()
	dark_grass_files.sort()
	blood_files.sort()

	tiles["grass"] = _load_sorted(folder, grass_files)
	tiles["mud"] = _load_sorted(folder, mud_files)
	tiles["stone"] = _load_sorted(folder, stone_files)
	tiles["dark_grass"] = _load_sorted(folder, dark_grass_files)
	tiles["blood"] = _load_sorted(folder, blood_files)

	return tiles

func _assign_edge_file(target: Dictionary, folder: String, file_name: String, token: String, length: int) -> void:
	var idx: int = file_name.find(token)
	if idx == -1:
		return
	var key: String = file_name.substr(idx + token.length(), length)
	var tex := load(folder.path_join(file_name))
	if tex != null and key != "":
		target[key] = tex

func _load_sorted(folder: String, files: Array[String]) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for file_name in files:
		var tex := load(folder.path_join(file_name))
		if tex != null:
			textures.append(tex)
	return textures

func _compact_textures(textures: Array[Texture2D]) -> Array[Texture2D]:
	var filtered: Array[Texture2D] = []
	for tex in textures:
		if tex != null:
			filtered.append(tex)
	return filtered

func _gather_all_textures(tiles: Dictionary) -> Array[Texture2D]:
	var all_textures: Array[Texture2D] = []
	var groups: Array[String] = ["grass", "mud", "stone", "dark_grass", "blood"]
	for group in groups:
		for tex in tiles[group]:
			if tex != null:
				all_textures.append(tex)
	for dir in EDGE_DIRS:
		if tiles["gm_edges"].has(dir):
			all_textures.append(tiles["gm_edges"][dir])
		if tiles["gs_edges"].has(dir):
			all_textures.append(tiles["gs_edges"][dir])
	for dir in CORNER_DIRS:
		if tiles["gm_corners"].has(dir):
			all_textures.append(tiles["gm_corners"][dir])
		if tiles["gs_corners"].has(dir):
			all_textures.append(tiles["gs_corners"][dir])
	return all_textures
