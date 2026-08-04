extends Node

const BUILD_BINDINGS = {
	"build_1": "arrow_turret",
	"build_2": "cannon_tower",
	"build_3": "tesla_tower",
	"build_4": "resource_generator",
	"build_5": "shrine",
	"build_shrine": "shrine"
}
# NOTE: traps + extra towers/utility buildings were removed from the buildable
# set; their hotkey bindings were dropped here. See docs/REMOVED_BUILDINGS.md.

const PREVIEW_COLOR_OK = Color(0.24, 1.0, 0.92, 0.62)
const PREVIEW_COLOR_BLOCKED = Color(1.0, 0.22, 0.22, 0.6)
const PREVIEW_COLOR_UNAFFORDABLE = Color(1.0, 0.76, 0.24, 0.6)
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
var _selection_pulse: float = 0.0
var _selection_ring_base_scale: float = 1.18

# --- Gamepad / virtual build cursor ---
# When the player's last input came from a controller, build placement uses a
# code-driven cursor (right stick / d-pad) instead of the mouse. Both input
# methods coexist; switching device flips _using_gamepad automatically.
const VIRTUAL_CURSOR_SPEED := 520.0
# Build ids the prev/next shoulder buttons cycle through (matches BUILD_BINDINGS order).
const BUILD_CYCLE_ORDER := ["arrow_turret", "cannon_tower", "tesla_tower", "resource_generator", "shrine"]
var _using_gamepad: bool = false
var _virtual_cursor: Vector2 = Vector2.ZERO
var _virtual_cursor_seeded: bool = false
var _virtual_cursor_sprite: Sprite2D = null
var _evo_pad_cooldown: float = 0.0

func setup(game_ref: Node2D, buildings_ref: Node2D, ui_ref: CanvasLayer) -> void:
	game = game_ref
	buildings_root = buildings_ref
	ui = ui_ref
	# Mouse/touch selection of evolution choices routes through this signal so
	# clicking a card behaves identically to the keyboard/controller picks.
	if ui != null and ui.has_signal("evolution_card_clicked"):
		if not ui.evolution_card_clicked.is_connected(_on_evolution_card_clicked):
			ui.evolution_card_clicked.connect(_on_evolution_card_clicked)
	set_process_unhandled_input(true)
	_create_preview()
	_create_selection_ring()
	# Start OUT of build mode: the player opts in via a build hotkey (1-5) or the
	# build toggle. current_id is pre-seeded so the first toggle has a sensible
	# default, but no preview/placement is shown until the player asks for it.
	build_mode = false
	current_id = "arrow_turret"
	_update_preview_state()
	_set_selection_text(_describe_current_build())
	_set_controls_text()
	_refresh_palette()
	_sync_build_focus()

func _process(delta: float) -> void:
	_preview_status_timer = max(0.0, _preview_status_timer - delta)
	_animate_selection_ring(delta)
	if game != null and game.has_method("is_game_started") and not game.is_game_started():
		if preview != null:
			preview.visible = false
		_set_virtual_cursor_visible(false)
		return
	if game != null and game.has_method("is_menu_open") and game.is_menu_open():
		if preview != null:
			preview.visible = false
		if selection_ring != null:
			selection_ring.visible = false
		if range_ring != null:
			range_ring.visible = false
		_set_virtual_cursor_visible(false)
		return
	if game != null and game.has_method("is_tech_open") and game.is_tech_open():
		if preview != null:
			preview.visible = false
		_set_virtual_cursor_visible(false)
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
		# Gamepad: A = option 1, X (upgrade) = option 2.
		_evo_pad_cooldown = max(0.0, _evo_pad_cooldown - delta)
		if _evo_pad_cooldown <= 0.0:
			if Input.is_action_just_pressed("build_place"):
				_evo_pad_cooldown = 0.3
				choose_evolution(0)
			elif Input.is_action_just_pressed("upgrade"):
				_evo_pad_cooldown = 0.3
				choose_evolution(1)
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
	# Gamepad: cycle the selected build with the shoulder buttons.
	if Input.is_action_just_pressed("build_next"):
		_cycle_build_selection(1)
	elif Input.is_action_just_pressed("build_prev"):
		_cycle_build_selection(-1)
	# Gamepad: move the virtual cursor and place/select with the confirm button.
	_update_virtual_cursor(delta)
	if _using_gamepad and Input.is_action_just_pressed("build_place"):
		if build_mode and current_id != "":
			_try_place()
		else:
			_try_select()
	_update_preview_position()

func _unhandled_input(event: InputEvent) -> void:
	# Track the active input device so build placement uses the matching pointer
	# (mouse position vs. virtual cursor). Cheap + reliable.
	if event is InputEventMouse:
		_using_gamepad = false
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_using_gamepad = true
	if game != null and game.has_method("is_game_started") and not game.is_game_started():
		return
	if game != null and game.has_method("is_menu_open") and game.is_menu_open():
		return
	if game != null and game.has_method("is_tech_open") and game.is_tech_open():
		return
	# While the evolution chooser is open, swallow world clicks so a stray click
	# off the cards doesn't place/select a tower behind the dialog. A right-click
	# (or ESC, handled in _process) cancels the chooser instead.
	if ui != null and ui.has_method("is_evolution_panel_open") and ui.is_evolution_panel_open():
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_hide_evolution_panel()
			get_viewport().set_input_as_handled()
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
	# Sit above gameplay FX so the selected tower is never lost in the horde.
	selection_ring.z_as_relative = false
	selection_ring.z_index = 60
	selection_ring.scale = Vector2.ONE * 1.18
	# Brighter, fully opaque cyan reads instantly against any backdrop.
	selection_ring.modulate = Color(0.35, 1.0, 1.0, 1.0)
	buildings_root.add_child(selection_ring)
	range_ring = Sprite2D.new()
	range_ring.texture = preload("res://assets/ui/ui_selection_ring_64x64_v001.png")
	range_ring.visible = false
	range_ring.z_as_relative = false
	range_ring.z_index = 58
	range_ring.modulate = Color(0.4, 0.95, 1.0, 0.7)
	buildings_root.add_child(range_ring)
	# Gamepad pointer: a small bright ring so controller players can see where the
	# virtual cursor is when aiming at a tower to select/upgrade or placing a build.
	_virtual_cursor_sprite = Sprite2D.new()
	_virtual_cursor_sprite.texture = preload("res://assets/ui/ui_selection_ring_64x64_v001.png")
	_virtual_cursor_sprite.visible = false
	_virtual_cursor_sprite.z_as_relative = false
	_virtual_cursor_sprite.z_index = 70
	_virtual_cursor_sprite.scale = Vector2.ONE * 0.5
	_virtual_cursor_sprite.modulate = Color(1.0, 0.95, 0.4, 0.95)
	buildings_root.add_child(_virtual_cursor_sprite)

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
	var pos = _get_build_world_position()
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
	var pos = _snap_to_grid(_get_build_world_position())
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
	# In FFA, charge the local player's pool and tag ownership so this builder's
	# towers go inert when they die/leave. Damage stays host-authoritative.
	var owner_id := 1
	if game != null and game.has_method("local_player_id"):
		owner_id = game.local_player_id()
	if game != null and not game.can_afford(cost, owner_id):
		_set_selection_text("Not enough resources")
		return
	var building: Node2D = scene.instantiate()
	building.global_position = pos
	if "owner_id" in building:
		building.owner_id = owner_id
	buildings_root.add_child(building)
	if building.has_method("configure"):
		building.configure(current_id, def, tier)
	if game != null:
		if game.has_method("mark_flow_field_dirty"):
			game.mark_flow_field_dirty()
		game.spend(cost, owner_id)
		if game.has_method("spawn_fx"):
			game.spawn_fx("build", pos)
		# Track tower built
		if game.has_method("track_tower_built"):
			game.track_tower_built()
	_invalidate_preview_cache()
	_set_selection_text("Built %s" % def.get("name", current_id))

# Host-side tower placement for an FFA bot. Mirrors _try_place() but charges the
# bot's own economy (owner_id) and runs without any local UI/preview side effects.
# Returns true if a tower was placed. Added to the scene tree so it auto-replicates
# to all peers, exactly like a real player's tower.
func bot_place_tower(owner_id: int, pos: Vector2, tower_id: String) -> bool:
	if game == null or buildings_root == null:
		return false
	var def = StructureDB.get_def(tower_id)
	if def.is_empty():
		return false
	var snapped = _snap_to_grid(pos)
	var footprint = _get_effective_footprint_radius(def)
	if not _is_clear(snapped, footprint):
		return false
	var blocks_path = bool(def.get("blocks_path", true))
	if blocks_path and not _check_path_validity(snapped, footprint):
		return false
	var tier_data = StructureDB.get_tier(def, 0)
	var cost = _apply_cost_mult(int(tier_data.get("cost", 0)))
	if not game.can_afford(cost, owner_id):
		return false
	var scene_path: String = str(def.get("scene", ""))
	if scene_path == "":
		return false
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return false
	var building: Node2D = scene.instantiate()
	building.global_position = snapped
	if "owner_id" in building:
		building.owner_id = owner_id
	buildings_root.add_child(building)
	if building.has_method("configure"):
		building.configure(tower_id, def, 0)
	game.spend(cost, owner_id)
	if game.has_method("mark_flow_field_dirty"):
		game.mark_flow_field_dirty()
	if game.has_method("spawn_fx"):
		game.spawn_fx("build", snapped)
	if game.has_method("track_tower_built"):
		game.track_tower_built()
	return true

func _try_select() -> void:
	selected_building = null
	var pos = _get_build_world_position()
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
		# FFA: only allow selecting/upgrading your OWN buildings.
		if game != null and game.has_method("is_ffa") and game.is_ffa():
			if "owner_id" in building and game.has_method("local_player_id"):
				if int(building.owner_id) != game.local_player_id():
					continue
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
	var upgrade_cost = int(selected_building.get_upgrade_cost())
	var upgrade_essence_cost = 0
	if selected_building.has_method("get_upgrade_essence_cost"):
		upgrade_essence_cost = int(selected_building.get_upgrade_essence_cost())
	if upgrade_essence_cost <= 0:
		upgrade_cost = _apply_cost_mult(upgrade_cost)
	var can_afford = game != null and game.can_afford(upgrade_cost)
	if not can_afford:
		_set_selection_text("Not enough resources")
		return
	if upgrade_essence_cost > 0:
		if game == null:
			_set_selection_text("Need %d Essence" % upgrade_essence_cost)
			return
		var has_essence = false
		if game.has_method("can_afford_essence"):
			has_essence = bool(game.can_afford_essence(upgrade_essence_cost))
		else:
			has_essence = int(game.essence) >= upgrade_essence_cost
		if not has_essence:
			_set_selection_text("Need %d Essence" % upgrade_essence_cost)
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
			if upgrade_essence_cost > 0:
				if game.has_method("spend_essence"):
					game.spend_essence(upgrade_essence_cost)
				else:
					game.essence -= upgrade_essence_cost
					if game.has_method("_update_ui"):
						game._update_ui()
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

func _on_evolution_card_clicked(index: int) -> void:
	# A card was clicked in the UI. Only act while we actually have a pending
	# evolution (guards against stray clicks after the panel closed).
	if _evolution_target == null or not is_instance_valid(_evolution_target):
		return
	choose_evolution(index)

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
	if game.has_method("spend_essence"):
		game.spend_essence(cost)
	else:
		game.essence -= cost
		if game.has_method("_update_ui"):
			game._update_ui()
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
		var cost = int(building.get_upgrade_cost())
		var essence_cost = 0
		if building.has_method("get_upgrade_essence_cost"):
			essence_cost = int(building.get_upgrade_essence_cost())
		if essence_cost <= 0:
			cost = _apply_cost_mult(cost)
		if essence_cost > 0:
			base_name += " [U:%dG + %dE]" % [cost, essence_cost]
		else:
			base_name += " [U:%d]" % cost

	# Add sell value
	if building.has_method("get_sell_value"):
		base_name += " [X: Sell +%d]" % building.get_sell_value()
	if building.has_method("get_health_ratio"):
		var hp_ratio := float(building.get_health_ratio())
		base_name += " [HP %d%%]" % int(round(clampf(hp_ratio, 0.0, 1.0) * 100.0))

	return base_name

func _describe_current_build() -> String:
	if current_id == "":
		return ""
	var def = StructureDB.get_def(current_id)
	if def.is_empty():
		return "Build: %s" % current_id
	var tier_data = StructureDB.get_tier(def, 0)
	var cost = _apply_cost_mult(int(tier_data.get("cost", 0)))
	var blocks_path := bool(def.get("blocks_path", false))
	var tags: Array[String] = []
	if current_id in RANGE_PREVIEW_IDS:
		tags.append("tower")
	if blocks_path:
		tags.append("wall")
	var suffix = ""
	if not tags.is_empty():
		suffix = " [%s]" % ", ".join(tags)
	return "Build: %s (Cost %d)%s" % [def.get("name", current_id), cost, suffix]

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

func _sync_build_focus() -> void:
	if game == null or not game.has_method("set_build_focus"):
		return
	var active = build_mode and current_id != "" and _is_unlocked(current_id)
	game.set_build_focus(active, current_id)

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
	_selection_ring_base_scale = scale
	selection_ring.scale = Vector2.ONE * scale
	selection_ring.global_position = selected_building.global_position
	selection_ring.visible = true
	_update_range_ring()

func _animate_selection_ring(delta: float) -> void:
	# Soft breathing pulse + position follow so the highlight feels alive and
	# is easy to track even while the camera and horde churn around it.
	if selection_ring == null or not selection_ring.visible:
		return
	_selection_pulse += delta * 4.5
	var pulse := 1.0 + sin(_selection_pulse) * 0.07
	selection_ring.scale = Vector2.ONE * _selection_ring_base_scale * pulse
	var glow := 0.85 + (sin(_selection_pulse) * 0.5 + 0.5) * 0.15
	selection_ring.modulate = Color(0.35, 1.0, 1.0, glow)
	if selected_building != null and is_instance_valid(selected_building):
		selection_ring.global_position = selected_building.global_position

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

func _get_build_world_position() -> Vector2:
	# Gamepad uses the virtual cursor; mouse/keyboard uses the real cursor.
	if _using_gamepad:
		return _virtual_cursor
	return _get_mouse_world_position()

func _update_virtual_cursor(delta: float) -> void:
	if not _using_gamepad:
		_virtual_cursor_seeded = false
		_set_virtual_cursor_visible(false)
		return
	# Seed the cursor near the player the first frame we need it so it starts
	# on-screen rather than at world origin.
	if not _virtual_cursor_seeded:
		if game != null and game.player != null and is_instance_valid(game.player):
			_virtual_cursor = game.player.global_position
		else:
			_virtual_cursor = _get_mouse_world_position()
		_virtual_cursor_seeded = true
	var move := Vector2(
		Input.get_action_strength("build_cursor_right") - Input.get_action_strength("build_cursor_left"),
		Input.get_action_strength("build_cursor_down") - Input.get_action_strength("build_cursor_up")
	)
	if move.length() > 1.0:
		move = move.normalized()
	if move != Vector2.ZERO:
		_virtual_cursor += move * VIRTUAL_CURSOR_SPEED * delta
		if game != null and game.has_method("clamp_to_play_area"):
			_virtual_cursor = game.clamp_to_play_area(_virtual_cursor)
	# Keep the visible pointer glued to the cursor whenever the pad is active.
	if _virtual_cursor_sprite != null and is_instance_valid(_virtual_cursor_sprite):
		_virtual_cursor_sprite.global_position = _virtual_cursor
	_set_virtual_cursor_visible(true)

func _set_virtual_cursor_visible(v: bool) -> void:
	if _virtual_cursor_sprite != null and is_instance_valid(_virtual_cursor_sprite):
		_virtual_cursor_sprite.visible = v

func _cycle_build_selection(step: int) -> void:
	# Cycle current_id through the unlocked buildable structures (LB/RB on a pad).
	var available: Array = []
	for id in BUILD_CYCLE_ORDER:
		if _is_unlocked(id):
			available.append(id)
	if available.is_empty():
		return
	var idx := available.find(current_id)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + step + available.size()) % available.size()
	current_id = available[idx]
	_set_build_mode(true)
	_set_selection_text(_describe_current_build())
	_notify_palette_active()

func _is_unlocked(id: String) -> bool:
	if game != null and game.has_method("is_build_unlocked"):
		return game.is_build_unlocked(id)
	return true

func _set_build_mode(active: bool) -> void:
	build_mode = active
	_invalidate_preview_cache()
	_update_preview_state()
	_sync_build_focus()
	# Surface the full controls hint whenever the player is actively building.
	if active and ui != null and ui.has_method("set_controls_visible"):
		ui.set_controls_visible(true)

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
	# The extractor is a one-per-run objective, not a normal build.
	if current_id == "resource_generator" and game != null \
			and game.has_method("has_extractor") and game.has_extractor():
		result["reason"] = "Extractor already deployed"
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
	return "LMB: place/select | RMB/Esc: cancel | U: upgrade | X: sell | B: build | H: resource dump | P: pause"
