extends Node

const BUILD_BINDINGS = {
	"build_1": "arrow_turret",
	"build_2": "cannon_tower",
	"build_3": "tesla_tower",
	"build_4": "mine_trap",
	"build_5": "ice_trap",
	"build_6": "acid_trap",
	"build_7": "wall",
	"build_8": "gate",
	"build_9": "resource_generator",
	"build_barracks": "barracks",
	"build_armory": "armory",
	"build_tech_lab": "tech_lab",
	"build_shrine": "shrine"
}

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
	_handle_hotkeys()
	if Input.is_action_just_pressed("upgrade"):
		_try_upgrade_selected()
	if Input.is_action_just_pressed("toggle_gate"):
		_try_toggle_selected()
	if Input.is_action_just_pressed("cancel"):
		build_mode = false
		_update_preview_state()
	_update_preview_position()

func _unhandled_input(event: InputEvent) -> void:
	if game != null and game.has_method("is_game_started") and not game.is_game_started():
		return
	if game != null and game.has_method("is_tech_open") and game.is_tech_open():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if build_mode and current_id != "":
			_try_place()
		else:
			_try_select()

func _handle_hotkeys() -> void:
	if Input.is_action_just_pressed("build_toggle"):
		build_mode = not build_mode
		_update_preview_state()
	for action in BUILD_BINDINGS.keys():
		if Input.is_action_just_pressed(action):
			var candidate = BUILD_BINDINGS[action]
			if not _is_unlocked(candidate):
				_set_selection_text("Locked: earn tech picks to unlock")
				continue
			current_id = candidate
			build_mode = true
			_update_preview_state()
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

func _update_preview_position() -> void:
	if preview == null or not preview.visible:
		return
	var pos = _get_mouse_world_position()
	var snapped = _snap_to_grid(pos)
	preview.global_position = snapped
	if current_id != "" and preview.has_method("set_color"):
		var def = StructureDB.get_def(current_id)
		if not def.is_empty():
			var radius = float(def.get("footprint_radius", 12))
			var clear = _is_clear(snapped, radius)
			if clear:
				preview.set_color(Color(0.2, 0.9, 0.8, 0.35))
			else:
				preview.set_color(Color(0.95, 0.2, 0.2, 0.35))
			if preview.has_method("set_state"):
				preview.set_state(clear)

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
		preview.set_color(Color(0.2, 0.9, 0.8, 0.35))
	if preview.has_method("set_ghost_texture"):
		var path = str(def.get("preview", ""))
		preview.set_ghost_texture(path)

func _try_place() -> void:
	var def = StructureDB.get_def(current_id)
	if def.is_empty():
		return
	if not _is_unlocked(current_id):
		_set_selection_text("Locked: earn tech picks to unlock")
		return
	var tier = 0
	var tier_data = StructureDB.get_tier(def, tier)
	var cost = int(tier_data.get("cost", 0))
	if game != null and not game.can_afford(cost):
		_set_selection_text("Not enough resources")
		return
	var pos = _snap_to_grid(_get_mouse_world_position())
	var footprint = float(def.get("footprint_radius", 12))
	if not _is_clear(pos, footprint):
		_set_selection_text("Blocked placement")
		return
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
		game.spend(cost)
	_set_selection_text("Built %s" % def.get("name", current_id))

func _try_select() -> void:
	selected_building = null
	var pos = _get_mouse_world_position()
	var best_dist = INF
	for building: Node2D in get_tree().get_nodes_in_group("buildings"):
		if building == null:
			continue
		var radius = 12.0
		if building.has_method("get_footprint_radius"):
			radius = building.get_footprint_radius()
		var dist = pos.distance_squared_to(building.global_position)
		if dist <= radius * radius and dist < best_dist:
			best_dist = dist
			selected_building = building
	if selected_building != null:
		_set_selection_text(_describe_building(selected_building))
		_update_selection_ring()
	else:
		_set_selection_text("")
		if selection_ring != null:
			selection_ring.visible = false
		if range_ring != null:
			range_ring.visible = false

func _try_upgrade_selected() -> void:
	if selected_building == null:
		return
	if not selected_building.has_method("can_upgrade"):
		return
	if not selected_building.can_upgrade():
		_set_selection_text("No upgrade available")
		return
	var upgrade_cost = int(selected_building.get_upgrade_cost())
	if game != null and not game.can_afford(upgrade_cost):
		_set_selection_text("Not enough resources")
		return
	if selected_building.has_method("upgrade"):
		selected_building.upgrade()
		if game != null:
			game.spend(upgrade_cost)
		_set_selection_text(_describe_building(selected_building))
		_update_selection_ring()

func _try_toggle_selected() -> void:
	if selected_building == null:
		return
	if selected_building.has_method("toggle"):
		selected_building.toggle()
		_set_selection_text(_describe_building(selected_building))
		_update_selection_ring()

func _describe_building(building: Node) -> String:
	if building == null:
		return ""
	if building.has_method("get_display_name"):
		return building.get_display_name()
	return building.name

func _describe_current_build() -> String:
	if current_id == "":
		return ""
	var def = StructureDB.get_def(current_id)
	if def.is_empty():
		return "Build: %s" % current_id
	var tier_data = StructureDB.get_tier(def, 0)
	var cost = int(tier_data.get("cost", 0))
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
	return hits.is_empty()

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

func _controls_text() -> String:
	return "Click: place | U: upgrade | G: gate | B: toggle build"
