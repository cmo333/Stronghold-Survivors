extends TileMap

@export var tile_size: Vector2i = Vector2i(32, 32)
@export var radius: int = 80
@export var grass_radius: int = 25
@export var transition_width: int = 15
@export var use_asset_tiles: bool = true
# 1 = a tile variant per cell. At 2 the variants came in 2x2 blocks (64px), which
# read as a coarse checkerboard across open ground rather than as ground texture.
# Per-cell variation plus the calm-tile weighting below gives texture, not noise.
@export var variant_patch_cells: int = 1
@export var fill_margin_cells: int = 20
# The terrain fills nearly the whole screen, and at full brightness it competes
# with the units and towers standing on it - the eye reads the field as the
# subject and the action as clutter on top of it. Dimming the ground layer
# alone (sprites, FX and UI keep their own values) seats it behind the action.
# One knob: 1.0 is the raw tile art, lower is a calmer field.
@export var terrain_brightness: float = 0.88

# Per-level terrain palettes. Each level maps the three distance biomes
# (inner/grass, mid/mud, outer/stone) to its own art set. "blight" is a shared
# overlay category painted on top of bonus (resource) zones, not a biome.
#
# Biome entries may be a plain path String OR a {"path", "weight"} Dictionary.
# "calm" base tiles carry high weight; sparse "detail" tiles (moss, dead grass,
# blood, gravel) carry low weight so they read as rare accents instead of busy
# static. This weighting is the main lever that removes the noisy look.
const LEVEL_TERRAIN := {
	# SIMPLE + CLEAN: the v001 macro tiles are SEAMLESS (no baked-in dark borders),
	# unlike the v002 set whose grass tiles have black edges that create an ugly
	# grid when tiled. Use a couple of near-identical seamless tiles per biome for
	# gentle variation without any visible grid.
	"graveyard": {
		"grass": [
			{"path": "res://assets/level1/level1_terrain_macro/tile_graveyard_grass_base_a_32_v001.png", "weight": 1},
			{"path": "res://assets/level1/level1_terrain_macro/tile_graveyard_grass_base_d_32_v001.png", "weight": 1}
		],
		"mud": [
			{"path": "res://assets/level1/level1_terrain_macro/tile_graveyard_mud_base_a_32_v001.png", "weight": 1},
			{"path": "res://assets/level1/level1_terrain_macro/tile_graveyard_mud_base_b_32_v001.png", "weight": 1}
		],
		"stone": [
			{"path": "res://assets/level1/level1_terrain_macro/tile_graveyard_stone_cracked_a_32_v001.png", "weight": 1},
			{"path": "res://assets/level1/level1_terrain_macro/tile_graveyard_stone_cracked_d_32_v001.png", "weight": 1}
		]
	},
	"space": {
		# Inner = clean lit deck plating, mid/outer = worn armored hull.
		"grass": [
			"res://assets/level1/level1_terrain_space/tile_space_deck_a_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_deck_b_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_deck_c_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_deck_d_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_deck_e_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_deck_f_32_v001.png"
		],
		"mud": [
			"res://assets/level1/level1_terrain_space/tile_space_hull_a_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_hull_b_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_hull_c_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_hull_d_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_hull_e_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_hull_f_32_v001.png"
		],
		"stone": [
			"res://assets/level1/level1_terrain_space/tile_space_hull_a_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_hull_b_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_hull_c_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_hull_d_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_hull_e_32_v001.png",
			"res://assets/level1/level1_terrain_space/tile_space_hull_f_32_v001.png"
		]
	}
}

# Edge/corner transition tiles, keyed "<from>_to_<to>_<edge|corner><dir>".
# DISABLED for graveyard: the shipped transition art has dark baked-in borders
# that reintroduce the ugly grid. With no entries the generator falls back to a
# clean base-tile seam, which looks simpler and better. (Kept here so a future
# borderless transition set can be dropped in without code changes.)
const TRANSITION_TILES := {}

# Sparse alpha decals scattered above the base tiles. DISABLED for now: the user
# wants a clean, simple ground with no scattered clutter. Empty list => no decals.
const DECAL_TILES := {}

# Blight overlay tiles painted over bonus/resource zones (the user's space-level
# idea). Shared across levels; kept opaque so the TileMap accepts them.
const BLIGHT_TILE_PATHS := [
	"res://assets/level1/level1_terrain_space/tile_blight_base_a_32_v001.png",
	"res://assets/level1/level1_terrain_space/tile_blight_base_b_32_v001.png",
	"res://assets/level1/level1_terrain_space/tile_blight_base_c_32_v001.png",
	"res://assets/level1/level1_terrain_space/tile_blight_base_d_32_v001.png",
	"res://assets/level1/level1_terrain_space/tile_blight_base_e_32_v001.png",
	"res://assets/level1/level1_terrain_space/tile_blight_base_f_32_v001.png"
]

const FALLBACK_COLORS := {
	"grass": Color(0.35, 0.52, 0.28),
	"mud": Color(0.42, 0.32, 0.22),
	"stone": Color(0.38, 0.38, 0.40),
	"blight": Color(0.28, 0.22, 0.12)
}

# Source ids for biome base tiles, parallel weights, and transition tiles.
var _tile_sources := {
	"grass": [],
	"mud": [],
	"stone": [],
	"blight": []
}
var _tile_weights := {
	"grass": [],
	"mud": [],
	"stone": [],
	"blight": []
}
# _transition_sources["grass_mud"]["edgeN"] -> source_id
var _transition_sources := {}
var _seed_offset: int = 0
var active_level: String = "graveyard"
var _decals_root: Node2D = null

# Biome order index used for transition direction (lower = more central).
const BIOME_RANK := {"grass": 0, "mud": 1, "stone": 2}

# Set the active level before terrain generation so the right tile palette loads.
# Safe to call after _ready: it rebuilds the tileset and regenerates the map.
func set_active_level(level_id: String) -> void:
	var key := str(level_id)
	if not LEVEL_TERRAIN.has(key):
		key = "graveyard"
	if key == active_level and not _tile_sources["grass"].is_empty():
		return
	active_level = key
	_setup_tileset()
	_generate_terrain()

func _terrain_palette() -> Dictionary:
	return LEVEL_TERRAIN.get(active_level, LEVEL_TERRAIN["graveyard"])

func _resolved_tile_size() -> Vector2i:
	# Terrain source art is 32x32. Lock to this so scene overrides don't create gaps.
	if tile_size.x != 32 or tile_size.y != 32:
		return Vector2i(32, 32)
	return tile_size

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var b := clampf(terrain_brightness, 0.5, 1.0)
	modulate = Color(b, b, b, 1.0)
	_seed_offset = randi()
	_setup_tileset()
	_generate_terrain()

func _setup_tileset() -> void:
	var tileset := TileSet.new()
	var ts: Vector2i = _resolved_tile_size()
	tileset.tile_size = ts
	_tile_sources = {"grass": [], "mud": [], "stone": [], "blight": []}
	_tile_weights = {"grass": [], "mud": [], "stone": [], "blight": []}
	_transition_sources = {}

	if use_asset_tiles:
		_populate_tileset_from_assets(tileset)
		_populate_transition_sources(tileset)
	_ensure_fallback_sources(tileset)
	tile_set = tileset

# Normalize a palette entry (String or {"path","weight"}) into [path, weight].
func _entry_path_weight(entry) -> Array:
	if entry is Dictionary:
		return [str(entry.get("path", "")), int(entry.get("weight", 1))]
	return [str(entry), 1]

func _populate_tileset_from_assets(tileset: TileSet) -> void:
	var added: Dictionary = {}
	var palette: Dictionary = _terrain_palette()
	# Biome tiles for the active level, plus the shared blight overlay set.
	var categories := {
		"grass": palette.get("grass", []),
		"mud": palette.get("mud", []),
		"stone": palette.get("stone", []),
		"blight": BLIGHT_TILE_PATHS
	}
	for category in categories.keys():
		var path_list: Array = categories[category]
		for raw_entry in path_list:
			var pw: Array = _entry_path_weight(raw_entry)
			var path: String = pw[0]
			var weight: int = max(1, int(pw[1]))
			if path == "" or added.has(path):
				continue
			var sid := _add_tile_source(tileset, path)
			if sid < 0:
				continue
			_tile_sources[str(category)].append(sid)
			_tile_weights[str(category)].append(weight)
			added[path] = true

# Load + validate an opaque tile and add it as a TileSet atlas source.
# Returns the source id, or -1 if the asset is missing/transparent/invalid.
func _add_tile_source(tileset: TileSet, path: String) -> int:
	if not ResourceLoader.exists(path):
		return -1
	var tex = load(path)
	if not (tex is Texture2D):
		return -1
	if not _is_full_coverage_texture(tex as Texture2D):
		return -1
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = _resolved_tile_size()
	atlas.create_tile(Vector2i.ZERO)
	var source_id: int = tileset.get_next_source_id()
	tileset.add_source(atlas, source_id)
	return source_id

func _populate_transition_sources(tileset: TileSet) -> void:
	var sets: Dictionary = TRANSITION_TILES.get(active_level, {})
	for pair_key in sets.keys():
		var dirs: Dictionary = sets[pair_key]
		var resolved := {}
		for dir_key in dirs.keys():
			var sid := _add_tile_source(tileset, str(dirs[dir_key]))
			if sid >= 0:
				resolved[dir_key] = sid
		if not resolved.is_empty():
			_transition_sources[pair_key] = resolved

func _is_full_coverage_texture(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var img = tex.get_image()
	if img == null:
		return false
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a < 0.995:
				return false
	return true

func _ensure_fallback_sources(tileset: TileSet) -> void:
	for category in ["grass", "mud", "stone", "blight"]:
		if not _tile_sources[category].is_empty():
			continue
		var color: Color = FALLBACK_COLORS.get(category, Color(1.0, 0.0, 1.0))
		var atlas := TileSetAtlasSource.new()
		atlas.texture = _create_color_texture(color)
		atlas.texture_region_size = _resolved_tile_size()
		atlas.create_tile(Vector2i.ZERO)
		var source_id = tileset.get_next_source_id()
		tileset.add_source(atlas, source_id)
		_tile_sources[category].append(source_id)
		_tile_weights[category].append(1)

func _create_color_texture(color: Color) -> ImageTexture:
	var resolved = _resolved_tile_size()
	var w = max(1, resolved.x)
	var h = max(1, resolved.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	for x in range(w):
		for y in range(h):
			if randf() < 0.10:
				img.set_pixel(x, y, color.darkened(0.1))
	return ImageTexture.create_from_image(img)

func _generate_terrain() -> void:
	clear()
	var fill_radius: int = radius + maxi(0, fill_margin_cells)
	# Pass 1: classify every cell into a biome (grass/mud/stone) once. Using a
	# stable per-cell classification (not per-tile coin flips) gives coherent
	# regions whose borders we can then blend with edge/corner tiles.
	var biome_map: Dictionary = {}
	for x in range(-fill_radius, fill_radius + 1):
		for y in range(-fill_radius, fill_radius + 1):
			biome_map[Vector2i(x, y)] = _classify_biome(x, y)
	# Pass 2: paint. Interior cells use a weighted base pick; boundary cells use
	# the matching transition tile so biomes blend smoothly instead of snapping.
	for cell in biome_map.keys():
		var biome: String = biome_map[cell]
		var sid: int = _resolve_cell_source(cell, biome, biome_map)
		set_cell(0, cell, sid, Vector2i.ZERO)
	_rebuild_decals(fill_radius, biome_map)

# Smooth radial classification with low-frequency noise jitter on the seams so
# the boundary wanders organically rather than forming a perfect ring.
func _classify_biome(x: int, y: int) -> String:
	var dist := Vector2(x, y).length()
	var jitter := (_pseudo_noise(x, y) - 0.5) * float(transition_width) * 0.9
	var d := dist + jitter
	if d < float(grass_radius):
		return "grass"
	if d < float(grass_radius + transition_width):
		return "mud"
	return "stone"

func _resolve_cell_source(cell: Vector2i, biome: String, biome_map: Dictionary) -> int:
	var trans := _transition_source_for(cell, biome, biome_map)
	if trans >= 0:
		return trans
	return _pick_from(biome, cell.x, cell.y)

# If this cell sits on the inner edge of a biome boundary, return a transition
# tile id oriented toward the neighbouring (more central) biome. Returns -1 for
# interior cells or when no transition art is available.
func _transition_source_for(cell: Vector2i, biome: String, biome_map: Dictionary) -> int:
	var my_rank: int = BIOME_RANK.get(biome, 0)
	# We blend on the OUTER biome's tiles facing the inner biome (e.g. mud cells
	# bordering grass get a grass->mud edge). Only act if a neighbour is more
	# central than us.
	var inner_biome := ""
	var nN: bool = _neighbor_is_inner(cell + Vector2i(0, -1), my_rank, biome_map)
	var nS: bool = _neighbor_is_inner(cell + Vector2i(0, 1), my_rank, biome_map)
	var nE: bool = _neighbor_is_inner(cell + Vector2i(1, 0), my_rank, biome_map)
	var nW: bool = _neighbor_is_inner(cell + Vector2i(-1, 0), my_rank, biome_map)
	if not (nN or nS or nE or nW):
		return -1
	# Determine which inner biome we border (pick the first found).
	inner_biome = _inner_neighbor_biome(cell, my_rank, biome_map)
	if inner_biome == "":
		return -1
	var pair_key := _pair_key(inner_biome, biome)
	var dirs: Dictionary = _transition_sources.get(pair_key, {})
	if dirs.is_empty():
		return -1
	var dir_key := _direction_key(nN, nS, nE, nW)
	if dirs.has(dir_key):
		return int(dirs[dir_key])
	# Fall back to any available edge if the exact corner/edge is missing.
	for k in ["edgeN", "edgeS", "edgeE", "edgeW"]:
		if dirs.has(k):
			return int(dirs[k])
	return -1

func _neighbor_is_inner(ncell: Vector2i, my_rank: int, biome_map: Dictionary) -> bool:
	if not biome_map.has(ncell):
		return false
	var nb: String = biome_map[ncell]
	return BIOME_RANK.get(nb, 0) < my_rank

func _inner_neighbor_biome(cell: Vector2i, my_rank: int, biome_map: Dictionary) -> String:
	for off in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var ncell: Vector2i = cell + off
		if not biome_map.has(ncell):
			continue
		var nb: String = biome_map[ncell]
		if BIOME_RANK.get(nb, 0) < my_rank:
			return nb
	return ""

func _pair_key(inner: String, outer: String) -> String:
	return "%s_%s" % [inner, outer]

# Convert which sides border the inner biome into an edge/corner key. Corner
# tiles point their "inner" quadrant toward the inner biome; e.g. inner to the
# N and E -> the inner region sits to the upper-right -> cornerNE.
func _direction_key(nN: bool, nS: bool, nE: bool, nW: bool) -> String:
	if nN and nE:
		return "cornerNE"
	if nN and nW:
		return "cornerNW"
	if nS and nE:
		return "cornerSE"
	if nS and nW:
		return "cornerSW"
	if nN:
		return "edgeN"
	if nS:
		return "edgeS"
	if nE:
		return "edgeE"
	return "edgeW"

# Build the sparse alpha decal overlay. Walks the disc on a coarse grid and
# drops a single muted decal per cell-block with seeded jitter, keeping density
# low so decals never compete with combat readability.
func _rebuild_decals(fill_radius: int, biome_map: Dictionary) -> void:
	if _decals_root != null and is_instance_valid(_decals_root):
		_decals_root.queue_free()
		_decals_root = null
	var decal_defs: Array = DECAL_TILES.get(active_level, [])
	if decal_defs.is_empty():
		return
	var textures: Array = []
	var scales: Array = []
	for d in decal_defs:
		var p := str(d.get("path", ""))
		if p != "" and ResourceLoader.exists(p):
			textures.append(load(p))
			scales.append(float(d.get("scale", 1.0)))
	if textures.is_empty():
		return
	_decals_root = Node2D.new()
	_decals_root.name = "GroundDecals"
	_decals_root.z_index = -9
	_decals_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_decals_root)
	var ts: Vector2i = _resolved_tile_size()
	var block := 12  # ~1 candidate decal per 12x12 cell block
	var bx := -fill_radius
	while bx <= fill_radius:
		var by := -fill_radius
		while by <= fill_radius:
			# Seeded chance + jitter so the layout is stable per generation.
			if _cell_hash(bx * 7 + 3, by * 13 - 5) < 0.55:
				by += block
				continue
			var jx := int((_cell_hash(bx, by) - 0.5) * float(block))
			var jy := int((_cell_hash(by, bx) - 0.5) * float(block))
			var cx := bx + jx
			var cy := by + jy
			var cell := Vector2i(cx, cy)
			if Vector2(cx, cy).length() > float(fill_radius):
				by += block
				continue
			# Skip decals right on the spawn pocket so the start area stays clean.
			if Vector2(cx, cy).length() < float(grass_radius) * 0.4:
				by += block
				continue
			var idx := int(floor(_cell_hash(cx * 5 + 1, cy * 9 - 2) * float(textures.size()))) % textures.size()
			var spr := Sprite2D.new()
			spr.texture = textures[idx]
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.modulate = Color(1, 1, 1, randf_range(0.45, 0.7))
			spr.scale = Vector2.ONE * float(scales[idx])
			spr.rotation = randf_range(-0.25, 0.25)
			spr.position = Vector2((cx + 0.5) * float(ts.x), (cy + 0.5) * float(ts.y))
			_decals_root.add_child(spr)
			by += block
		bx += block

# Paint blight-corruption tiles in circular patches over the given world-space
# zone centers (used for bonus/resource zones). Radius is in world units.
func paint_blight_zones(centers: Array, world_radius: float) -> void:
	if _tile_sources.get("blight", []).is_empty():
		return
	var cell_radius: int = maxi(1, int(ceil(world_radius / 32.0)))
	for c in centers:
		var center_world: Vector2 = c
		var center_cell: Vector2i = local_to_map(to_local(center_world))
		for dx in range(-cell_radius, cell_radius + 1):
			for dy in range(-cell_radius, cell_radius + 1):
				# Soft circular edge so patches read organic, not square.
				var d := Vector2(dx, dy).length()
				if d > cell_radius:
					continue
				if d > cell_radius - 1.5 and _cell_hash(center_cell.x + dx, center_cell.y + dy) > 0.55:
					continue
				var cell := Vector2i(center_cell.x + dx, center_cell.y + dy)
				set_cell(0, cell, _pick_from("blight", cell.x, cell.y), Vector2i.ZERO)

# Weighted, seeded tile pick within a biome. Variant patches keep small clusters
# of the same tile together (less salt-and-pepper); weight biases toward calm
# base tiles so detail tiles stay sparse.
func _pick_from(category: String, x: int, y: int) -> int:
	var source_list: Array = _tile_sources.get(category, [])
	var weight_list: Array = _tile_weights.get(category, [])
	if source_list.is_empty():
		source_list = _tile_sources.get("stone", [])
		weight_list = _tile_weights.get("stone", [])
	if source_list.is_empty():
		return 0
	var patch: int = maxi(1, variant_patch_cells)
	var px: int = int(floor(float(x) / float(patch)))
	var py: int = int(floor(float(y) / float(patch)))
	var roll := _cell_hash(px, py)
	if weight_list.size() != source_list.size():
		var idx := int(floor(roll * float(source_list.size()))) % source_list.size()
		return int(source_list[idx])
	var total := 0
	for w in weight_list:
		total += int(w)
	if total <= 0:
		return int(source_list[0])
	var target := roll * float(total)
	var acc := 0.0
	for i in range(source_list.size()):
		acc += float(weight_list[i])
		if target <= acc:
			return int(source_list[i])
	return int(source_list[source_list.size() - 1])

func _cell_hash(x: int, y: int) -> float:
	var value = sin(float(x * 127 + y * 311 + _seed_offset) * 0.01573) * 43758.5453
	return absf(value - floor(value))

func _pseudo_noise(x: int, y: int) -> float:
	var coarse_x := int(floor(float(x) / 8.0))
	var coarse_y := int(floor(float(y) / 8.0))
	return _cell_hash(coarse_x * 3 + 17, coarse_y * 5 - 11)

func get_biome_at(world_pos: Vector2) -> String:
	var tile_pos := local_to_map(world_pos)
	var dist := int(Vector2(tile_pos).length())
	if dist > radius:
		return "stone"
	if dist < grass_radius:
		return "grass"
	if dist < grass_radius + transition_width:
		return "transition"
	return "wasteland"
