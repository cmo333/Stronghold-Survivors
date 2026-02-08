# Terrain Generator Documentation

## Overview

The terrain generator creates a circular game world with three distinct biome zones:
- **Center (Grass)**: Safe zone around the stronghold
- **Mid (Mud/Transition)**: Dangerous transition area  
- **Outer (Stone/Wasteland)**: Hostile wasteland at the edges

## Implementation Details

### File: `scripts/ground.gd`

The terrain generator is a TileMap node that uses Godot 4's terrain painting system.

### Key Features

1. **FastNoiseLite Integration**
   - OpenSimplex noise for coherent biome patterns
   - Configurable frequency (default: 0.01) and octaves (default: 3)
   - Seed support for reproducible maps

2. **Distance-Based Zones**
   - Circular world with configurable radius (default: 80 tiles = 2560px)
   - Smooth falloff from center to edge using smoothstep interpolation
   - Coherent transitions between biomes

3. **Terrain Painting**
   - Uses `set_cells_terrain_connect()` for proper biome transitions
   - Three terrain types: Grass (0), Mud (1), Stone (2)
   - Automatic tile blending at biome boundaries

4. **Procedural Fallback**
   - Generates procedural textures if asset textures aren't found
   - Matches approximate colors of intended art style

## Configuration

### Export Variables

```gdscript
@export var tile_size: Vector2i = Vector2i(32, 32)    # Tile dimensions
@export var radius: int = 80                          # World radius in tiles
@export var noise_seed: int = 0                       # 0 = random seed
@export var noise_frequency: float = 0.01             # Noise scale
@export var noise_octaves: int = 3                    # Noise detail
@export var grass_threshold: float = 0.33             # Grass < 0.33
@export var transition_threshold: float = 0.66        # Mud 0.33-0.66
```

### Biome Thresholds

- **Grass Zone**: `biome_value < 0.33`
- **Mud Zone**: `0.33 <= biome_value < 0.66`
- **Stone/Wasteland**: `biome_value >= 0.66`

## Public API

### Methods

```gdscript
# Regenerate terrain with current settings
regenerate()

# Set new noise seed and regenerate
set_noise_seed(new_seed: int)

# Get biome type at world position (returns TERRAIN_GRASS, TERRAIN_MUD, or TERRAIN_STONE)
get_biome_at(world_pos: Vector2) -> int

# Check if position is within valid build area
is_valid_build_position(world_pos: Vector2) -> bool
```

### Constants

```gdscript
TERRAIN_GRASS = 0
TERRAIN_MUD = 1
TERRAIN_STONE = 2
```

## How It Works

1. **Noise Generation**: Creates coherent noise pattern using FastNoiseLite
2. **Distance Calculation**: Each tile's distance from center is normalized [0, 1]
3. **Biome Blending**: Noise value is blended with distance factor (outer = more wasteland)
4. **Terrain Painting**: Cells are collected by biome type and painted using terrain connect
5. **Transitions**: Godot's terrain system automatically handles tile transitions

## Testing

To test the terrain generator:

1. Open the project in Godot 4
2. Run the main scene (`scenes/main.tscn`)
3. You should see:
   - Green center area (grass)
   - Brown middle ring (mud/transition)
   - Grey outer ring (stone/wasteland)
   - Smooth transitions between zones
   - No visible grid lines at biome boundaries

## Future Enhancements

1. **Asset Integration**: Load actual terrain tile textures from `assets/level1/level1_terrain_v002/`
2. **Transition Tiles**: Configure TileSet with proper transition tile atlases
3. **Biome Variations**: Add sub-biomes within each zone
4. **Height Variance**: Add elevation data for gameplay variation
5. **Decoration**: Place environmental props based on biome type
