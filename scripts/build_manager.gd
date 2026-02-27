extends Node

const BUILD_BINDINGS = {
	"build_1": "arrow_turret",
	"build_2": "cannon_tower",
	"build_3": "tesla_tower",
	"build_4": "mine_trap",
	"build_5": "ice_trap",
	"build_6": "acid_trap",
	"build_7": "resource_generator",
	"build_8": "barracks",
	"build_9": "armory",
	"build_barracks": "tech_lab",
	"build_armory": "shrine"
}

const PREVIEW_COLOR_OK = Color(0.2, 0.9, 0.8, 0.35)
const PREVIEW_COLOR_BLOCKED = Color(0.95, 0.2, 0.2, 0.35)
const PREVIEW_COLOR_UNAFFORDABLE = Color(0.95, 0.7, 0.2, 0.35)
const RANGE_PREVIEW_IDS = ["arrow_turret", "cannon_tower", "tesla_tower"]
const PREVIEW_STATUS_REFRESH_INTERVAL = 0.08

# Pathfinding constants
const PATH_CHECK_RESOLUTION = 16.0  # Match flow-field grid size for consistent path validity
const PATH_AGENT_RADIUS = 7.0
const PATH_CLEARANCE_MARGIN = 1.0
const PATH_MIN_REACHABLE_SPAWN_CELLS = 16
const PATH_MIN_REACHABLE_SPAWN_FRACTION = 0.02
const PATH_CLEARANCE_DIRS = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]
const PATH_CHECK_RADIUS_OFFSET = 0.0  # Keep accurate blocking for maze fidelity

var game: Node2D = null
var buildings_root: Node2D = null
var ui: CanvasLayer = null

var build_mode = false
var current_id = ""
var selected_building: Node = null

var grid_size = 32.0
var preview: Node2D = null
var selection_ring: Sprite2D = null
var range_ring: Sprite2D = null
var _evo_input_cooldown: float = 0.0
var _preview_status_timer: float = 0.0
var _preview_cached_pos: Vector2 = Vector2(999999.0, 999999.0)
var _preview_cached_id: String = ""
var _preview_cached_resources: int = -999999
var _preview_cached_status: Dictionary = {}
var _show_tower_range: bool = true

func setup(game_ref: Node2D, buildings_ref: Node2D, ui_ref: CanvasLayer) -> void:
	game = game_ref
	buildings_root = buildings_ref
	ui = ui_ref
	set_process_unhandled_input(true)
	_create_preview()
	_create_selection_ring()
	build_mode = true
	current_id = "arrow_turret"
	_update_preview_state()
	_set_selection_text(_describe_current_build())
	_set_controls_text()
	_refresh_palette()

func _process(delta: float) -> void:
	_preview_status_timer = max(0.0, _preview_status_timer - delta)
	if game != null and game.has_method("is_game_started") and not game.is_game_started():
		if preview != null:
			preview.visible = false
		return
	if game != null and game.has_method("is_menu_open") and game.is_menu_open():
		if preview != null:
			preview.visible = false
		if selection_ring != null:
			selection_ring.visible = false
		if range_ring != null:
			range_ring.visible = false
		return
	if game != null and game.has_method("is_tech_open") and game.is_tech_open():
		if preview != null:
			preview.visible = false
		return
	if selected_building != null and not is_instance_valid(selected_building):
		selected_building = null
		if selection_ring != null:
			selection_ring.visible = false
	# Handle evolution panel input
	if ui != null and ui.has_method("is_evolution_panel_open") and ui.is_evolution_panel_open():
		if Input.is_action_just_pressed("cancel"):
			_hide_evolution_panel()
		# Use _unhandled_key_input pattern - check for just-pressed via event
		for key_idx in range(2):
			var key = KEY_1 if key_idx == 0 else KEY_2
			if Input.is_key_pressed(key) and _evo_input_cooldown <= 0.0:
				_evo_input_cooldown = 0.3
				choose_evolution(key_idx)
				break
		_evo_input_cooldown = max(0.0, _evo_input_cooldown - delta)
		return  # Block all other input while evolution panel open

	_handle_hotkeys()
	if Input.is_action_just_pressed("upgrade"):
		_try_upgrade_selected()
	if Input.is_action_just_pressed("sell"):
		_try_sell_selected()
	if Input.is_action_just_pressed("toggle_gate"):
		_try_toggle_selected()
	if Input.is_action_just_pressed("cancel"):
		if build_mode:
			_set_build_mode(false)
		else:
			_clear_selection()
			_set_selection_text("")
	_update_preview_position()

func _unhandled_input(event: InputEvent) -> void:
	if game != null and game.has_method("is_game_started") and not game.is_game_started():
		return
	if game != null and game.has_method("is_menu_open") and game.is_menu_open():
		return
	if game != null and game.has_method("is_tech_open") and game.is_tech_open():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if build_mode:
				_set_build_mode(false)
			else:
				_clear_selection()
				_set_selection_text("")
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if build_mode and current_id != "":
				_try_place()
			else:
				_try_select()

func _handle_hotkeys() -> void:
	if Input.is_action_just_pressed("build_toggle"):
		_set_build_mode(not build_mode)
	for action in BUILD_BINDINGS.keys():
		if Input.is_action_just_pressed(action):
			var candidate = BUILD_BINDINGS[action]
			if not _is_unlocked(candidate):
				_set_selection_text("Locked: earn tech picks to unlock")
				continue
			current_id = candidate
			_set_build_mode(true)
			_set_selection_text(_describe_current_build())
			_notify_palette_active()

func _create_preview() -> void:
	var preview_scene = preload("res://scenes/build_preview.tscn")
	preview = preview_scene.instantiate()
	buildings_root.add_child(preview)
	preview.visible = false

func _create_selection_ring() -> void:
	selection_ring = Sprite2D.new()
	selection_ring.texture = preload("res://assets/ui/ui_selection_ring_64x64_v001.png")
	selection_ring.visible = false
	selection_ring.z_index = 20
	buildings_root.add_child(selection_ring)
	range_ring = Sprite2D.new()
	range_ring.texture = preload("res://assets/ui/ui_selection_ring_64x64_v001.png")
	range_ring.visible = false
	range_ring.z_index = 19
	range_ring.modulate = Color(0.4, 0.8, 1.0, 0.35)
	buildings_root.add_child(range_ring)

func _update_preview_state() -> void:
	if preview == null:
		return
	if build_mode and current_id != "" and _is_unlocked(current_id):
		preview.visible = true
	else:
		preview.visible = false
	_update_preview_visuals()
	if build_mode and current_id != "":
		_set_selection_text(_describe_current_build())
	elif selected_building != null:
		_set_selection_text(_describe_building(selected_building))
	else:
		_set_selection_text("")

func _update_preview_position() -> void:
	if preview == null or not preview.visible:
		return
	var pos = _get_mouse_world_position()
	var snapped = _snap_to_grid(pos)
	preview.global_position = snapped
	if current_id != "" and preview.has_method("set_color"):
		var def = StructureDB.get_def(current_id)
		if not def.is_empty():
			var status = _get_preview_status(snapped, def)
			if status["clear"] and status["path_clear"] and status["affordable"]:
				preview.set_color(PREVIEW_COLOR_OK)
			elif status["clear"] and status["path_clear"] and not status["affordable"]:
				preview.set_color(PREVIEW_COLOR_UNAFFORDABLE)
			else:
				preview.set_color(PREVIEW_COLOR_BLOCKED)
			if preview.has_method("set_state"):
				preview.set_state(status["clear"] and status["path_clear"] and status["affordable"])
			if preview.has_method("set_range_state"):
				preview.set_range_state(status["can_place"])

func _update_preview_visuals() -> void:
	if preview == null or current_id == "":
		return
	if not _is_unlocked(current_id):
		return
	_invalidate_preview_cache()
	var def = StructureDB.get_def(current_id)
	if def.is_empty():
		return
	var radius = _get_effective_footprint_radius(def)
	if preview.has_method("set_radius"):
		preview.set_radius(radius)
	if preview.has_method("set_color"):
		preview.set_color(PREVIEW_COLOR_OK)
	if preview.has_method("set_ghost_texture"):
		var path = str(def.get("preview", ""))
		preview.set_ghost_texture(path)
	if preview.has_method("set_range_radius"):
		if _show_tower_range and RANGE_PREVIEW_IDS.has(current_id):
			preview.set_range_radius(float(def.get("range", 0.0)))
		else:
			preview.set_range_radius(0.0)

func _try_place() -> void:
	var def = StructureDB.get_def(current_id)
	if def.is_empty():
		return
	if not _is_unlocked(current_id):
		_set_selection_text("Locked: earn tech picks to unlock")
		return
	var tier = 0
	var pos = _snap_to_grid(_get_mouse_world_position())
	var status = _evaluate_placement(pos, def)
	if not status["can_place"]:
		_set_selection_text(status["reason"])
		return
	var cost = int(status["cost"])
	var scene_path: String = str(def.get("scene", ""))
	if scene_path == "":
		return
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return
	var building: Node2D = scene.instantiate()
	building.global_position = pos
	buildings_root.add_child(building)
	if building.has_method("configure"):
		building.configure(current_id, def, tier)
	if game != null:
		if game.has_method("mark_flow_field_dirty"):
			game.mark_flow_field_dirty()
		game.spend(cost)
		if game.has_method("spawn_fx"):
			game.spawn_fx("build", pos)
		# Track tower built
		if game.has_method("track_tower_built"):
			game.track_tower_built()
	_invalidate_preview_cache()
	_set_selection_text("Built %s" % def.get("name", current_id))

func _try_select() -> void:
	selected_building = null
	var pos = _get_mouse_world_position()
	var best_dist = INF
	var buildings_found = get_tree().get_nodes_in_group("buildings")
	for raw_building in buildings_found:
		if raw_building == null or not is_instance_valid(raw_building):
			continue
		if not (raw_building is Node2D):
			continue
		var building := raw_building as Node2D
		var radius = 12.0
		if building.has_method("get_footprint_radius"):
			radius = building.get_footprint_radius()
		# Increase selection radius significantly for easier clicking (3x footprint, min 40px)
		var select_radius = max(radius * 3.0, 40.0)
		var dist = pos.distance_to(building.global_position)
		if dist <= select_radius and dist < best_dist:
			best_dist = dist
			selected_building = building
	if selected_building != null:
		_set_selection_text(_describe_building(selected_building))
		_update_selection_ring()
		_show_upgrade_panel()
	else:
		_set_selection_text("")
		if selection_ring != null:
			selection_ring.visible = false
		if range_ring != null:
			range_ring.visible = false
		_hide_upgrade_panel()

func _try_upgrade_selected() -> void:
	if selected_building == null:
		return

	# Check for evolution first (T3 tower, not yet evolved)
	if selected_building.has_method("can_evolve") and selected_building.can_evolve():
		_show_evolution_choice(selected_building)
		return

	if not selected_building.has_method("can_upgrade"):
		return
	var can_up = selected_building.can_upgrade()
	if not can_up:
		_set_selection_text("No upgrade available")
		return
	var upgrade_cost = _apply_cost_mult(int(selected_building.get_upgrade_cost()))
	var can_afford = game != null and game.can_afford(upgrade_cost)
	if not can_afford:
		_set_selection_text("Not enough resources")
		return

	# Store position before upgrade (in case building dies)
	var building_pos = selected_building.global_position

	if selected_building.has_method("upgrade"):
		var prev_tier = -1
		if "tier" in selected_building:
			prev_tier = selected_building.tier

		# Apply the upgrade first (so can_upgrade() isn't blocked by upgrade FX cooldown)
		selected_building.upgrade()

		var upgraded = true
		if prev_tier >= 0 and "tier" in selected_building:
			upgraded = selected_building.tier != prev_tier

		if not upgraded:
			_set_selection_text("No upgrade available")
			return

		# Play upgrade juice effects after upgrade is applied
		if selected_building.has_method("play_upgrade_juice"):
			var juice_level = -1
			if "upgrade_level" in selected_building:
				juice_level = selected_building.upgrade_level
			elif "tier" in selected_building:
				juice_level = selected_building.tier + 1
			selected_building.play_upgrade_juice(juice_level)

		if game != null:
			game.spend(upgrade_cost)
			# Premium upgrade FX
			if game.has_method("spawn_fx"):
				game.spawn_fx("upgrade_burst", building_pos)
			# Stronger screenshake for higher tiers
			if game.has_method("shake_camera"):
				var tier = 1
				if "tier" in selected_building:
					tier = selected_building.tier
				var shake = 4.0 + tier * 2.0
				game.shake_camera(shake, 0.3)

		_set_selection_text(_describe_building(selected_building))
		_update_selection_ring()
		_show_upgrade_panel()

# --- Evolution System ---
var _evolution_target: Node = null
var _evolution_options: Array = []

func _show_evolution_choice(building: Node) -> void:
	if not building.has_method("get_evolution_options"):
		return
	_evolution_options = building.get_evolution_options()
	if _evolution_options.is_empty():
		_set_selection_text("No evolutions available")
		return
	_evolution_target = building
	# Flash to draw attention to evolution panel
	if game != null and game.has_method("flash_screen"):
		game.flash_screen(Color(0.7, 0.3, 1.0, 0.3), 0.3)
	# Show evolution UI panel
	if ui != null and ui.has_method("show_evolution_panel"):
		ui.show_evolution_panel(_evolution_options, game.essence if game != null else 0)

func choose_evolution(index: int) -> void:
	if _evolution_target == null or not is_instance_valid(_evolution_target):
		_hide_evolution_panel()
		return
	if index < 0 or index >= _evolution_options.size():
		_hide_evolution_panel()
		return
	var option = _evolution_options[index]
	var cost = int(option.get("cost", 3))
	if game == null or game.essence < cost:
		_set_selection_text("Not enough Essence (%d needed)" % cost)
		return
	# Spend essence and evolve
	game.essence -= cost
	_evolution_target.evolve(option.get("id", ""))
	_hide_evolution_panel()
	_set_selection_text(_describe_building(_evolution_target))
	_update_selection_ring()
	_show_upgrade_panel()

func _hide_evolution_panel() -> void:
	_evolution_target = null
	_evolution_options = []
	if ui != null and ui.has_method("hide_evolution_panel"):
		ui.hide_evolution_panel()

func _show_upgrade_panel() -> void:
	if ui == null:
		return
	if ui.has_method("show_upgrade_panel"):
		ui.show_upgrade_panel(selected_building)

func _hide_upgrade_panel() -> void:
	if ui == null:
		return
	if ui.has_method("hide_upgrade_panel"):
		ui.hide_upgrade_panel()

func _try_toggle_selected() -> void:
	if selected_building == null:
		return
	if selected_building.has_method("toggle"):
		var was_blocks_path = bool(selected_building.blocks_path) if "blocks_path" in selected_building else false
		selected_building.toggle()
		# Prevent closing gates (or other toggles) from sealing enemy routes.
		var now_blocks_path = bool(selected_building.blocks_path) if "blocks_path" in selected_building else false
		if not was_blocks_path and now_blocks_path:
			var radius = 12.0
			if selected_building.has_method("get_footprint_radius"):
				radius = float(selected_building.get_footprint_radius())
			if not _check_path_validity(selected_building.global_position, radius):
				selected_building.toggle()
				_set_selection_text("Must leave path open!")
				_invalidate_preview_cache()
				return
		if game != null and game.has_method("mark_flow_field_dirty"):
			game.mark_flow_field_dirty()
		_invalidate_preview_cache()
		_set_selection_text(_describe_building(selected_building))
		_update_selection_ring()

func _try_sell_selected() -> void:
	if selected_building == null or not is_instance_valid(selected_building):
		return
	if not selected_building.has_method("sell"):
		return
	var refund = 0
	if selected_building.has_method("get_sell_value"):
		refund = selected_building.get_sell_value()
	var bld = selected_building
	selected_building = null
	_clear_selection()
	_hide_upgrade_panel()
	bld.sell()
	_invalidate_preview_cache()
	_set_selection_text("Sold for %d resources" % refund)

func _describe_building(building: Node) -> String:
	if building == null:
		return ""

	var base_name = ""
	if building.has_method("get_display_name"):
		base_name = building.get_display_name()
	else:
		base_name = building.name

	# Add evolution or upgrade info
	if building.has_method("can_evolve") and building.can_evolve():
		base_name += " [U: EVOLVE]"
	elif building.has_method("can_upgrade") and building.can_upgrade():
		var cost = _apply_cost_mult(building.get_upgrade_cost())
		base_name += " [U:%d]" % cost

	# Add sell value
	if building.has_method("get_sell_value"):
		base_name += " [X: Sell +%d]" % building.get_sell_value()

	return base_name

func _describe_current_build() -> String:
	if current_id == "":
		return ""
	var def = StructureDB.get_def(current_id)
	if def.is_empty():
		return "Build: %s" % current_id
	var tier_data = StructureDB.get_tier(def, 0)
	var cost = _apply_cost_mult(int(tier_data.get("cost", 0)))
	return "Build: %s (Cost %d)" % [def.get("name", current_id), cost]

func _set_controls_text() -> void:
	if ui == null:
		return
	if ui.has_method("set_controls"):
		ui.set_controls(_controls_text())

func refresh_controls() -> void:
	_set_controls_text()
	_refresh_palette()

func _refresh_palette() -> void:
	if ui == null or game == null:
		return
	if ui.has_method("update_palette"):
		ui.update_palette(game.unlocked_builds, current_id)

func _notify_palette_active() -> void:
	if ui == null:
		return
	if ui.has_method("set_palette_active"):
		ui.set_palette_active(current_id)

func _set_selection_text(text: String) -> void:
	if ui == null:
		return
	if ui.has_method("set_selection"):
		ui.set_selection(text)

func _update_selection_ring() -> void:
	if selection_ring == null:
		return
	if selected_building == null:
		selection_ring.visible = false
		if range_ring != null:
			range_ring.visible = false
		return
	var radius = 12.0
	if selected_building.has_method("get_footprint_radius"):
		radius = selected_building.get_footprint_radius()
	var diameter = radius * 2.2
	var scale = diameter / 64.0
	selection_ring.scale = Vector2.ONE * scale
	selection_ring.global_position = selected_building.global_position
	selection_ring.visible = true
	_update_range_ring()

func _update_range_ring() -> void:
	if range_ring == null or selected_building == null:
		return
	if not _show_tower_range:
		range_ring.visible = false
		return
	if not selected_building.has_method("get_range"):
		range_ring.visible = false
		return
	var range_value = float(selected_building.get_range())
	var diameter = range_value * 2.0
	var scale = diameter / 64.0
	range_ring.scale = Vector2.ONE * scale
	range_ring.global_position = selected_building.global_position
	range_ring.visible = true

func set_show_tower_range(enabled: bool) -> void:
	_show_tower_range = enabled
	if not enabled and range_ring != null:
		range_ring.visible = false
	if preview != null and preview.has_method("set_range_radius"):
		if not enabled:
			preview.set_range_radius(0.0)
		else:
			_update_preview_visuals()

func _is_clear(position: Vector2, radius: float) -> bool:
	if game == null:
		return true
	var space: PhysicsDirectSpaceState2D = game.get_world_2d().direct_space_state
	var shape = RectangleShape2D.new()
	# Slight inset so edge-touching grid-aligned towers are allowed (flush placement for maze building).
	var query_size = max(1.0, radius * 2.0 - 0.2)
	shape.size = Vector2(query_size, query_size)
	var params = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, position)
	params.collision_mask = GameLayers.BUILDING
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var hits: Array = space.intersect_shape(params, 1)
	if not hits.is_empty():
		return false
	for raw_building in get_tree().get_nodes_in_group("buildings"):
		if raw_building == null or not is_instance_valid(raw_building):
			continue
		if not (raw_building is Node2D):
			continue
		var building := raw_building as Node2D
		var other_radius = 12.0
		if building.has_method("get_footprint_radius"):
			other_radius = building.get_footprint_radius()
		var min_dist = radius + other_radius
		if abs(position.x - building.global_position.x) < min_dist and abs(position.y - building.global_position.y) < min_dist:
			return false
	return true

func _snap_to_grid(position: Vector2) -> Vector2:
	if grid_size <= 0.0:
		return position
	return Vector2(
		round(position.x / grid_size) * grid_size,
		round(position.y / grid_size) * grid_size
	)

func _get_mouse_world_position() -> Vector2:
	var viewport = get_viewport()
	return viewport.get_camera_2d().get_global_mouse_position()

func _is_unlocked(id: String) -> bool:
	if game != null and game.has_method("is_build_unlocked"):
		return game.is_build_unlocked(id)
	return true

func _set_build_mode(active: bool) -> void:
	build_mode = active
	_invalidate_preview_cache()
	_update_preview_state()

func _clear_selection() -> void:
	selected_building = null
	if selection_ring != null:
		selection_ring.visible = false
	if range_ring != null:
		range_ring.visible = false
	_hide_upgrade_panel()

func _invalidate_preview_cache() -> void:
	_preview_status_timer = 0.0
	_preview_cached_id = ""
	_preview_cached_resources = -999999
	_preview_cached_pos = Vector2(999999.0, 999999.0)
	_preview_cached_status = {}

func _get_resource_snapshot() -> int:
	if game == null:
		return -1
	if "resources" in game:
		return int(game.resources)
	return -1

func _get_preview_status(snapped: Vector2, def: Dictionary) -> Dictionary:
	var resources_now = _get_resource_snapshot()
	var needs_refresh = _preview_cached_status.is_empty()
	if current_id != _preview_cached_id:
		needs_refresh = true
	elif snapped != _preview_cached_pos:
		needs_refresh = true
	elif resources_now != _preview_cached_resources:
		needs_refresh = true
	elif _preview_status_timer <= 0.0:
		needs_refresh = true
	if needs_refresh:
		_preview_cached_status = _evaluate_placement(snapped, def)
		_preview_cached_pos = snapped
		_preview_cached_id = current_id
		_preview_cached_resources = resources_now
		_preview_status_timer = PREVIEW_STATUS_REFRESH_INTERVAL
	return _preview_cached_status

func _evaluate_placement(pos: Vector2, def: Dictionary) -> Dictionary:
	var result = {
		"can_place": false,
		"reason": "",
		"affordable": true,
		"clear": true,
		"path_clear": true,
		"cost": 0,
		"footprint": 12.0
	}
	if def.is_empty():
		result["reason"] = "Invalid build"
		return result
	var tier_data = StructureDB.get_tier(def, 0)
	var cost = _apply_cost_mult(int(tier_data.get("cost", 0)))
	result["cost"] = cost
	result["footprint"] = _get_effective_footprint_radius(def)
	if game != null and not game.can_afford(cost):
		result["affordable"] = false
		result["reason"] = "Not enough resources"
	result["clear"] = _is_clear(pos, result["footprint"])
	if not result["clear"] and result["reason"] == "":
		result["reason"] = "Blocked placement"
	
	# Check path blocking - only for buildings that block path
	var blocks_path = bool(def.get("blocks_path", true))
	if blocks_path and result["clear"]:
		result["path_clear"] = _check_path_validity(pos, result["footprint"])
		if not result["path_clear"]:
			result["reason"] = "Must leave path open!"
	
	result["can_place"] = result["affordable"] and result["clear"] and result["path_clear"]
	return result

func _get_effective_footprint_radius(def: Dictionary) -> float:
	var radius = float(def.get("footprint_radius", 12))
	var blocks_path = bool(def.get("blocks_path", true))
	# Keep preview/placement checks aligned with Building.configure() collider sizing.
	if blocks_path:
		radius = max(radius, 16.0)
	return radius

func _check_path_validity(proposed_pos: Vector2, proposed_radius: float) -> bool:
	"""Check if placing a building would block paths to the player."""
	if game == null or game.player == null:
		return true

	var player_pos: Vector2 = game.player.global_position
	var cell_size = PATH_CHECK_RESOLUTION
	var spawn_min = 500.0
	var spawn_max = 750.0
	var play_radius = 0.0
	var spawn_min_prop = game.get("spawn_radius_min")
	var spawn_max_prop = game.get("spawn_radius_max")
	if typeof(spawn_min_prop) in [TYPE_FLOAT, TYPE_INT]:
		spawn_min = float(spawn_min_prop)
	if typeof(spawn_max_prop) in [TYPE_FLOAT, TYPE_INT]:
		spawn_max = float(spawn_max_prop)
	var play_radius_prop = game.get("play_radius")
	if typeof(play_radius_prop) in [TYPE_FLOAT, TYPE_INT]:
		play_radius = float(play_radius_prop)

	if spawn_max <= 0.0:
		return true

	var max_radius = spawn_max + cell_size * 2.0
	var grid_radius = int(ceil(max_radius / cell_size))
	var grid_size = grid_radius * 2 + 1
	# Snap the validation grid to world cells so preview validity doesn't flicker
	# when the player moves sub-pixel amounts between frames.
	var player_cell_center = Vector2i(
		int(floor(player_pos.x / cell_size)),
		int(floor(player_pos.y / cell_size))
	)
	var origin = Vector2(
		float(player_cell_center.x - grid_radius) * cell_size,
		float(player_cell_center.y - grid_radius) * cell_size
	)

	var total = grid_size * grid_size
	var blocked = PackedByteArray()
	blocked.resize(total)
	for i in range(total):
		blocked[i] = 0

	# Mark blocked cells from existing buildings
	for building in get_tree().get_nodes_in_group("buildings"):
		if building == null or not is_instance_valid(building):
			continue
		var blocks_path = true
		if "blocks_path" in building:
			blocks_path = bool(building.blocks_path)
		if not blocks_path:
			continue
		var radius = 12.0
		if building.has_method("get_footprint_radius"):
			radius = float(building.get_footprint_radius())
		_mark_blocked_circle(blocked, origin, grid_size, cell_size, building.global_position, radius + PATH_AGENT_RADIUS + PATH_CHECK_RADIUS_OFFSET, play_radius)

	# Mark blocked cells for proposed building
	_mark_blocked_circle(blocked, origin, grid_size, cell_size, proposed_pos, proposed_radius + PATH_AGENT_RADIUS + PATH_CHECK_RADIUS_OFFSET, play_radius)

	# Clearance field (distance from nearest obstacle cell)
	var clearance = _compute_clearance_field(blocked, grid_size)
	var required_cells = _get_required_clearance_cells(cell_size)

	# BFS from player
	var dist = PackedInt32Array()
	dist.resize(total)
	for i in range(total):
		dist[i] = -1
	var start_cell = _world_to_path_cell(player_pos, origin, cell_size)
	if start_cell.x < 0 or start_cell.y < 0 or start_cell.x >= grid_size or start_cell.y >= grid_size:
		return true
	var start_idx = start_cell.y * grid_size + start_cell.x
	if blocked[start_idx] == 1 or clearance[start_idx] < required_cells:
		return false
	dist[start_idx] = 0
	var queue: Array = [start_idx]
	var head = 0
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var idx = queue[head]
		head += 1
		var x = idx % grid_size
		var y = int(idx / grid_size)
		for dir in dirs:
			var nx = x + dir.x
			var ny = y + dir.y
			if nx < 0 or ny < 0 or nx >= grid_size or ny >= grid_size:
				continue
			var nidx = ny * grid_size + nx
			if blocked[nidx] == 1 or clearance[nidx] < required_cells:
				continue
			if dist[nidx] >= 0:
				continue
			if play_radius > 0.0:
				var world = _path_cell_center(Vector2i(nx, ny), origin, cell_size)
				if world.length() > play_radius:
					continue
			dist[nidx] = dist[idx] + 1
			queue.append(nidx)

	# Validate enough reachable spawn ring cells to keep spawning reliable.
	var min_dist_sq = spawn_min * spawn_min
	var max_dist_sq = spawn_max * spawn_max
	var total_spawn_cells = 0
	var reachable_spawn_cells = 0
	for y in range(grid_size):
		for x in range(grid_size):
			var world = _path_cell_center(Vector2i(x, y), origin, cell_size)
			if play_radius > 0.0 and world.length() > play_radius:
				continue
			var d2 = world.distance_squared_to(player_pos)
			if d2 < min_dist_sq or d2 > max_dist_sq:
				continue
			total_spawn_cells += 1
			var idx = y * grid_size + x
			if dist[idx] < 0:
				continue
			reachable_spawn_cells += 1

	if total_spawn_cells <= 0:
		return false
	var min_reachable_cells = max(PATH_MIN_REACHABLE_SPAWN_CELLS, int(ceil(float(total_spawn_cells) * PATH_MIN_REACHABLE_SPAWN_FRACTION)))
	return reachable_spawn_cells >= min_reachable_cells

func _world_to_path_cell(world_pos: Vector2, origin: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(
		int(floor((world_pos.x - origin.x) / cell_size)),
		int(floor((world_pos.y - origin.y) / cell_size))
	)

func _path_cell_center(cell: Vector2i, origin: Vector2, cell_size: float) -> Vector2:
	return origin + Vector2((float(cell.x) + 0.5) * cell_size, (float(cell.y) + 0.5) * cell_size)

func _mark_blocked_circle(blocked: PackedByteArray, origin: Vector2, grid_size: int, cell_size: float, center: Vector2, radius: float, play_radius: float) -> void:
	if radius <= 0.0:
		return
	var min_cell = _world_to_path_cell(center - Vector2(radius, radius), origin, cell_size)
	var max_cell = _world_to_path_cell(center + Vector2(radius, radius), origin, cell_size)
	for x in range(min_cell.x, max_cell.x + 1):
		if x < 0 or x >= grid_size:
			continue
		for y in range(min_cell.y, max_cell.y + 1):
			if y < 0 or y >= grid_size:
				continue
			var idx = y * grid_size + x
			var world = _path_cell_center(Vector2i(x, y), origin, cell_size)
			if play_radius > 0.0 and world.length() > play_radius:
				continue
			if abs(world.x - center.x) <= radius and abs(world.y - center.y) <= radius:
				blocked[idx] = 1

func _compute_clearance_field(blocked: PackedByteArray, grid_size: int) -> PackedInt32Array:
	var total = grid_size * grid_size
	var clearance = PackedInt32Array()
	clearance.resize(total)
	for i in range(total):
		clearance[i] = -1
	var queue: Array = []
	for i in range(total):
		if blocked[i] == 1:
			clearance[i] = 0
			queue.append(i)
	if queue.is_empty():
		for i in range(total):
			clearance[i] = grid_size
		return clearance
	var head = 0
	while head < queue.size():
		var idx = queue[head]
		head += 1
		var x = idx % grid_size
		var y = int(idx / grid_size)
		for dir in PATH_CLEARANCE_DIRS:
			var nx = x + dir.x
			var ny = y + dir.y
			if nx < 0 or ny < 0 or nx >= grid_size or ny >= grid_size:
				continue
			var nidx = ny * grid_size + nx
			if clearance[nidx] >= 0:
				continue
			clearance[nidx] = clearance[idx] + 1
			queue.append(nidx)
	return clearance

func _get_required_clearance_cells(cell_size: float) -> int:
	var required = (PATH_AGENT_RADIUS + PATH_CLEARANCE_MARGIN + cell_size * 0.5) / cell_size
	return int(ceil(required))

func _apply_cost_mult(cost: int) -> int:
	var final_cost = cost
	if game != null and game.has_method("get_build_cost_mult"):
		final_cost = int(round(final_cost * game.get_build_cost_mult()))
	return max(0, final_cost)

func _controls_text() -> String:
	return "LMB: place/select | RMB/Esc: cancel | U: upgrade | X: sell | B: build | P: pause"
