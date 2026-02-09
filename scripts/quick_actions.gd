extends Node
class_name QuickActionsManager

signal building_sold(building: Node, refund: int)
signal building_repaired(building: Node, cost: int)
signal all_upgraded(building_type: String, count: int)
signal gold_auto_collected(amount: int)

var game: Node = null
var build_manager: Node = null
var ui: Node = null

# Refund rate for selling buildings
const SELL_REFUND_RATE = 0.5  # 50% refund

# Repair cost multiplier (cost per HP)
const REPAIR_COST_PER_HP = 0.5

# Auto-collect settings
var _auto_collect_enabled: bool = false
var _auto_collect_range: float = 150.0
var _auto_collect_timer: float = 0.0
var _auto_collect_interval: float = 0.5

# Shift key state for batch operations
var _shift_pressed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_handle_input()
	
	if _auto_collect_enabled and game != null and not get_tree().paused:
		_auto_collect_timer += delta
		if _auto_collect_timer >= _auto_collect_interval:
			_auto_collect_timer = 0.0
			_auto_collect_gold()

func setup(game_ref: Node, build_manager_ref: Node, ui_ref: Node) -> void:
	game = game_ref
	build_manager = build_manager_ref
	ui = ui_ref
	
	# Load auto-collect preference from settings
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager:
		_auto_collect_enabled = settings_manager.get_setting("gameplay", "auto_collect_gold", false)

func _handle_input() -> void:
	_shift_pressed = Input.is_key_pressed(KEY_SHIFT)
	
	# Sell building - Delete key
	if Input.is_action_just_pressed("sell_building"):
		_sell_selected_building()
	
	# Repair building - R key (when not in build mode)
	if Input.is_action_just_pressed("repair_building"):
		_repair_selected_building()
	
	# Upgrade all of type - U key with Shift held
	if Input.is_action_just_pressed("upgrade_all") and _shift_pressed:
		_upgrade_all_of_selected_type()

func _sell_selected_building() -> void:
	if build_manager == null or game == null:
		return
	
	var selected = build_manager.get("selected_building")
	if selected == null or not is_instance_valid(selected):
		_show_notification("No building selected", Color.YELLOW)
		return
	
	# Calculate refund
	var building_cost = _get_building_cost(selected)
	var refund = int(building_cost * SELL_REFUND_RATE)
	
	# Confirm sale (could add confirmation dialog here)
	var building_name = _get_building_name(selected)
	
	# Remove building
	var building_pos = selected.global_position
	selected.queue_free()
	
	# Clear selection
	build_manager.set("selected_building", null)
	
	# Refund resources
	game.add_resources(refund)
	
	# FX
	if game.has_method("spawn_fx"):
		game.spawn_fx("build", building_pos)
	
	_show_notification("Sold %s for %d gold" % [building_name, refund], Color.GREEN)
	building_sold.emit(selected, refund)

func _repair_selected_building() -> void:
	if build_manager == null or game == null:
		return
	
	var selected = build_manager.get("selected_building")
	if selected == null or not is_instance_valid(selected):
		_show_notification("No building selected", Color.YELLOW)
		return
	
	# Check if building can be repaired
	if not selected.has_method("get_health") or not selected.has_method("get_max_health"):
		_show_notification("Cannot repair this building", Color.RED)
		return
	
	var current_health = selected.get_health()
	var max_health = selected.get_max_health()
	
	if current_health >= max_health:
		_show_notification("Building is already at full health", Color.YELLOW)
		return
	
	var health_needed = max_health - current_health
	var repair_cost = int(health_needed * REPAIR_COST_PER_HP)
	
	# Check if player can afford
	if not game.can_afford(repair_cost):
		_show_notification("Need %d gold to repair" % repair_cost, Color.RED)
		return
	
	# Repair building
	if selected.has_method("heal"):
		selected.heal(health_needed)
	elif "health" in selected:
		selected.health = max_health
	
	# Deduct cost
	game.spend(repair_cost)
	
	# FX
	if game.has_method("spawn_fx"):
		game.spawn_fx("upgrade_burst", selected.global_position)
	
	_show_notification("Repaired for %d gold" % repair_cost, Color.GREEN)
	building_repaired.emit(selected, repair_cost)

func _upgrade_all_of_selected_type() -> void:
	if build_manager == null or game == null:
		return
	
	var selected = build_manager.get("selected_building")
	if selected == null or not is_instance_valid(selected):
		_show_notification("No building selected", Color.YELLOW)
		return
	
	# Get building type
	var building_type = _get_building_type(selected)
	if building_type == "":
		return
	
	# Find all buildings of same type
	var buildings_of_type: Array[Node] = []
	var total_cost = 0
	
	for building in get_tree().get_nodes_in_group("buildings"):
		if building != null and is_instance_valid(building):
			if _get_building_type(building) == building_type:
				if building.has_method("can_upgrade") and building.can_upgrade():
					var upgrade_cost = building.get_upgrade_cost() if building.has_method("get_upgrade_cost") else 0
					if game.can_afford(total_cost + upgrade_cost):
						buildings_of_type.append(building)
						total_cost += upgrade_cost
	
	if buildings_of_type.is_empty():
		_show_notification("No %s available to upgrade" % building_type, Color.YELLOW)
		return
	
	# Confirm upgrade all
	if not game.can_afford(total_cost):
		_show_notification("Need %d more gold" % (total_cost - game.resources), Color.RED)
		return
	
	# Upgrade all
	var upgrade_count = 0
	for building in buildings_of_type:
		if building.has_method("upgrade"):
			var cost = building.get_upgrade_cost() if building.has_method("get_upgrade_cost") else 0
			if game.can_afford(cost):
				game.spend(cost)
				building.upgrade()
				upgrade_count += 1
				
				# FX
				if game.has_method("spawn_fx"):
					game.spawn_fx("upgrade_burst", building.global_position)
	
	if upgrade_count > 0:
		_show_notification("Upgraded %d %s for %d gold" % [upgrade_count, building_type, total_cost], Color.GREEN)
		
		# Camera shake
		if game.has_method("shake_camera"):
			game.shake_camera(4.0 + upgrade_count * 0.5, 0.3)
		
		all_upgraded.emit(building_type, upgrade_count)

func _auto_collect_gold() -> void:
	if game == null or game.player == null:
		return
	
	var player_pos = game.player.global_position
	var total_collected = 0
	
	# Find pickups within range
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup == null or not is_instance_valid(pickup):
			continue
		
		var pickup_pos = pickup.global_position
		var distance_sq = player_pos.distance_squared_to(pickup_pos)
		
		if distance_sq <= _auto_collect_range * _auto_collect_range:
			if pickup.has_method("collect"):
				pickup.collect()
				total_collected += 1
	
	if total_collected > 0:
		gold_auto_collected.emit(total_collected)

func _get_building_cost(building: Node) -> int:
	if building.has_method("get_cost"):
		return building.get_cost()
	if "cost" in building:
		return building.cost
	if building.has_meta("cost"):
		return building.get_meta("cost")
	
	# Default costs based on building type
	var type = _get_building_type(building)
	var default_costs = {
		"arrow_turret": 50,
		"cannon_tower": 100,
		"tesla_tower": 150,
		"sniper_tower": 120,
		"barrage_tower": 130,
		"wall": 30,
		"gate": 50,
		"resource_generator": 80,
		"barracks": 150,
		"tech_lab": 200,
		"armory": 180,
		"shrine": 150,
		"mine_trap": 60,
		"ice_trap": 80,
		"acid_trap": 100
	}
	return default_costs.get(type, 50)

func _get_building_name(building: Node) -> String:
	if building.has_method("get_display_name"):
		return building.get_display_name()
	if "display_name" in building:
		return building.display_name
	return building.name

func _get_building_type(building: Node) -> String:
	if building.has_method("get_building_type"):
		return building.get_building_type()
	if "building_id" in building:
		return building.building_id
	if building.has_meta("building_id"):
		return building.get_meta("building_id")
	return ""

func _show_notification(text: String, color: Color) -> void:
	if ui != null and ui.has_method("show_notification"):
		ui.show_notification(text, color)
	else:
		print("QuickAction: %s" % text)

# Public API for enabling/disabling auto-collect
func set_auto_collect(enabled: bool) -> void:
	_auto_collect_enabled = enabled

func is_auto_collect_enabled() -> bool:
	return _auto_collect_enabled

func set_auto_collect_range(range_val: float) -> void:
	_auto_collect_range = range_val