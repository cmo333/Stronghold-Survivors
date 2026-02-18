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

# Pathfinding constants
const PATH_CHECK_RESOLUTION = 16.0  # Grid size for pathfinding check (smaller = more accurate)
const PATH_CHECK_RADIUS_OFFSET = 4.0  # How much to shrink building radius for path checks

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
	if game != null and game.has_method("is_game_started") and not game.is_game_started():
		if preview != null:
			preview.visible = false
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
			var status = _evaluate_placement(snapped, def)
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
	var def = StructureDB.get_def(current_id)
	if def.is_empty():
		return
	var radius = float(def.get("footprint_radius", 12))
	if preview.has_method("set_radius"):
		preview.set_radius(radius)
	if preview.has_method("set_color"):
		preview.set_color(PREVIEW_COLOR_OK)
	if preview.has_method("set_ghost_texture"):
		var path = str(def.get("preview", ""))
		preview.set_ghost_texture(path)
	if preview.has_method("set_range_radius"):
		if RANGE_PREVIEW_IDS.has(current_id):
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
	_set_selection_text("Built %s" % def.get("name", current_id))

func _try_select() -> void:
	selected_building = null
	var pos = _get_mouse_world_position()
	var best_dist = INF
	var buildings_found = get_tree().get_nodes_in_group("buildings")
	for building: Node2D in buildings_found:
		if building == null:
			continue
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
		selected_building.toggle()
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
	if not selected_building.has_method("get_range"):
		range_ring.visible = false
		return
	var range_value = float(selected_building.get_range())
	var diameter = range_value * 2.0
	var scale = diameter / 64.0
	range_ring.scale = Vector2.ONE * scale
	range_ring.global_position = selected_building.global_position
	range_ring.visible = true

func _is_clear(position: Vector2, radius: float) -> bool:
	if game == null:
		return true
	var space: PhysicsDirectSpaceState2D = game.get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = radius
	var params = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, position)
	params.collision_mask = GameLayers.BUILDING
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var hits: Array = space.intersect_shape(params, 1)
	if not hits.is_empty():
		return false
	for building: Node2D in get_tree().get_nodes_in_group("buildings"):
		if building == null or not is_instance_valid(building):
			continue
		var other_radius = 12.0
		if building.has_method("get_footprint_radius"):
			other_radius = building.get_footprint_radius()
		var min_dist = radius + other_radius
		if position.distance_squared_to(building.global_position) < min_dist * min_dist:
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
	_update_preview_state()

func _clear_selection() -> void:
	selected_building = null
	if selection_ring != null:
		selection_ring.visible = false
	if range_ring != null:
		range_ring.visible = false
	_hide_upgrade_panel()

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
	result["footprint"] = float(def.get("footprint_radius", 12))
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

func _check_path_validity(proposed_pos: Vector2, proposed_radius: float) -> bool:
	"""Check if placing a building would block paths. Disabled for now."""
	return true

func _apply_cost_mult(cost: int) -> int:
	var final_cost = cost
	if game != null and game.has_method("get_build_cost_mult"):
		final_cost = int(round(final_cost * game.get_build_cost_mult()))
	return max(0, final_cost)

func _controls_text() -> String:
	return "LMB: place/select | RMB/Esc: cancel | U: upgrade | X: sell | B: build"
