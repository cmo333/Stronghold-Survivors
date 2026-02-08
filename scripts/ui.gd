extends CanvasLayer

const UI_FONT_PATH = "res://assets/ui/font_ui_gothic_ascii_12x16_v001.fnt"
const USE_CUSTOM_FONT = true

@onready var resources_label: Label = $HUD/Resources
@onready var time_label: Label = $HUD/Time
@onready var selection_label: Label = $HUD/Selection
@onready var controls_label: Label = $HUD/Controls
@onready var level_label: Label = $HUD/Level
@onready var xp_bar: TextureProgressBar = $HUD/XPBar
@onready var health_bar: TextureProgressBar = $HUD/HealthBar
@onready var tech_panel: TextureRect = $HUD/TechPanel
@onready var tech_option1: Label = $HUD/TechPanel/Option1
@onready var tech_option2: Label = $HUD/TechPanel/Option2
@onready var tech_option3: Label = $HUD/TechPanel/Option3
@onready var tech_icon1: TextureRect = $HUD/TechPanel/Option1Icon
@onready var tech_icon2: TextureRect = $HUD/TechPanel/Option2Icon
@onready var tech_icon3: TextureRect = $HUD/TechPanel/Option3Icon
@onready var start_panel: TextureRect = $HUD/StartPanel
@onready var start_title: Label = $HUD/StartPanel/StartTitle
@onready var start_body: Label = $HUD/StartPanel/StartBody
@onready var start_option1: Label = $HUD/StartPanel/Option1
@onready var start_option2: Label = $HUD/StartPanel/Option2
@onready var start_icon1: TextureRect = $HUD/StartPanel/Option1Icon
@onready var start_icon2: TextureRect = $HUD/StartPanel/Option2Icon
@onready var start_hint: Label = $HUD/StartHint

var rarity_colors = {
	"common": Color(0.85, 0.85, 0.85),
	"rare": Color(0.35, 0.65, 1.0),
	"epic": Color(0.72, 0.5, 1.0),
	"legendary": Color(1.0, 0.8, 0.2),
	"mythic": Color(1.0, 0.35, 0.35),
	"diamond": Color(0.6, 0.95, 1.0)
}

# --- Build Palette ---
const PALETTE_ORDER = [
	{"id": "arrow_turret", "key": "1"},
	{"id": "cannon_tower", "key": "2"},
	{"id": "tesla_tower", "key": "3"},
	{"id": "mine_trap", "key": "4"},
	{"id": "ice_trap", "key": "5"},
	{"id": "acid_trap", "key": "6"},
	{"id": "wall", "key": "7"},
	{"id": "gate", "key": "8"},
	{"id": "resource_generator", "key": "9"},
	{"id": "barracks", "key": "Q"},
	{"id": "armory", "key": "E"},
	{"id": "tech_lab", "key": "R"},
	{"id": "shrine", "key": "T"},
]

var palette_slots: Dictionary = {}
var palette_active_id: String = ""

# Tech rarity frames (ColorRects behind each option icon)
var tech_frames: Array = []
var _ui_font: Font = null

func _ready() -> void:
	_ui_font = _build_bitmap_font(UI_FONT_PATH) if USE_CUSTOM_FONT else null
	_apply_ui_fonts()
	_style_tech_panel()
	_style_start_panel()
	_build_palette()
	_add_tech_rarity_frames()
	_polish_start_panel()

# =========================================================
# BUILD PALETTE
# =========================================================

func _build_palette() -> void:
	var hud = $HUD
	var container = HBoxContainer.new()
	container.name = "BuildPalette"
	container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.add_theme_constant_override("separation", 2)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(container)

	for entry in PALETTE_ORDER:
		_create_palette_slot(container, entry["id"], entry["key"])

	var total_w = PALETTE_ORDER.size() * 40 + (PALETTE_ORDER.size() - 1) * 2
	container.offset_left = -total_w / 2.0
	container.offset_right = total_w / 2.0
	container.offset_top = -56.0
	container.offset_bottom = -8.0

func _create_palette_slot(container: HBoxContainer, id: String, key: String) -> void:
	var def = StructureDB.get_def(id)

	var slot = Control.new()
	slot.custom_minimum_size = Vector2(40, 48)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background
	var bg = ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(40, 48)
	bg.color = Color(0.1, 0.1, 0.12, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)

	# Icon (building preview image)
	var icon = TextureRect.new()
	icon.position = Vector2(4, 2)
	icon.size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_path = str(def.get("preview", ""))
	if preview_path != "" and ResourceLoader.exists(preview_path):
		icon.texture = load(preview_path)
	slot.add_child(icon)

	# Hotkey label (bottom-left)
	var key_label = Label.new()
	key_label.text = key
	key_label.add_theme_font_size_override("font_size", 9)
	key_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	key_label.position = Vector2(2, 34)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(key_label)

	# Cost label (bottom-right)
	var tier_data = StructureDB.get_tier(def, 0)
	var cost = int(tier_data.get("cost", 0))
	if cost > 0:
		var cost_label = Label.new()
		cost_label.text = str(cost)
		cost_label.add_theme_font_size_override("font_size", 8)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		cost_label.position = Vector2(22, 34)
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cost_label)

	container.add_child(slot)
	palette_slots[id] = {"root": slot, "bg": bg, "icon": icon, "key_label": key_label}

func update_palette(unlocked: Dictionary, active_id: String) -> void:
	palette_active_id = active_id
	for id in palette_slots.keys():
		var slot = palette_slots[id]
		var is_unlocked = bool(unlocked.get(id, false))
		var is_active = (id == active_id)
		var bg: ColorRect = slot["bg"]
		var icon: TextureRect = slot["icon"]

		if is_active and is_unlocked:
			bg.color = Color(0.2, 0.65, 0.55, 0.9)
		elif is_unlocked:
			bg.color = Color(0.1, 0.1, 0.12, 0.75)
		else:
			bg.color = Color(0.06, 0.06, 0.07, 0.5)

		if is_unlocked:
			icon.modulate = Color.WHITE
			slot["key_label"].modulate = Color.WHITE
		else:
			icon.modulate = Color(0.3, 0.3, 0.3, 0.5)
			slot["key_label"].modulate = Color(0.3, 0.3, 0.3, 0.5)

func set_palette_active(id: String) -> void:
	var old_id = palette_active_id
	palette_active_id = id
	if palette_slots.has(old_id):
		palette_slots[old_id]["bg"].color = Color(0.1, 0.1, 0.12, 0.75)
	if palette_slots.has(id):
		palette_slots[id]["bg"].color = Color(0.2, 0.65, 0.55, 0.9)

# =========================================================
# HUD LABELS
# =========================================================

func set_resources(amount: int) -> void:
	resources_label.text = "Resources: %d" % amount

func set_time(seconds: float) -> void:
	time_label.text = "Time: %.1f" % seconds

func set_selection(text: String) -> void:
	selection_label.text = text

func set_controls(text: String) -> void:
	controls_label.text = text

func set_level(level: int, xp: int, xp_next: int) -> void:
	level_label.text = "Level: %d (%d/%d)" % [level, xp, xp_next]
	if xp_bar != null:
		xp_bar.max_value = xp_next
		xp_bar.value = xp

func set_health(current: float, maximum: float) -> void:
	if health_bar == null:
		return
	health_bar.max_value = max(1.0, maximum)
	health_bar.value = clamp(current, 0.0, maximum)

# =========================================================
# TECH PICK PANEL
# =========================================================

func _add_tech_rarity_frames() -> void:
	tech_frames.clear()
	var icons = [tech_icon1, tech_icon2, tech_icon3]
	for icon in icons:
		if icon == null:
			tech_frames.append(null)
			continue
		var frame = ColorRect.new()
		frame.size = Vector2(icon.size.x + 6, icon.size.y + 6)
		frame.position = Vector2(icon.position.x - 3, icon.position.y - 3)
		frame.color = Color(0.5, 0.5, 0.5, 0.0)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tech_panel.add_child(frame)
		tech_panel.move_child(frame, 0)
		tech_frames.append(frame)

func show_tech(options: Array) -> void:
	tech_panel.visible = true
	tech_option1.text = _format_option(1, options, 0)
	tech_option2.text = _format_option(2, options, 1)
	tech_option3.text = _format_option(3, options, 2)
	_set_icon(tech_icon1, options, 0)
	_set_icon(tech_icon2, options, 1)
	_set_icon(tech_icon3, options, 2)
	_apply_rarity_style(tech_option1, tech_icon1, options, 0)
	_apply_rarity_style(tech_option2, tech_icon2, options, 1)
	_apply_rarity_style(tech_option3, tech_icon3, options, 2)
	_apply_tech_frames(options)

func hide_tech() -> void:
	tech_panel.visible = false

func _format_option(number: int, options: Array, index: int) -> String:
	if index >= options.size():
		return "%d) --" % number
	var option: Dictionary = options[index]
	return "%d) %s\n   %s" % [number, option.get("name", ""), option.get("desc", "")]

func _set_icon(icon: TextureRect, options: Array, index: int) -> void:
	if icon == null:
		return
	if index >= options.size():
		icon.texture = null
		return
	var path: String = str(options[index].get("icon", ""))
	if path == "":
		icon.texture = null
		return
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	else:
		icon.texture = null

func _apply_rarity_style(label: Label, icon: TextureRect, options: Array, index: int) -> void:
	if label == null:
		return
	if index >= options.size():
		return
	var option: Dictionary = options[index]
	var rarity = str(option.get("rarity", "common"))
	var color: Color = rarity_colors.get(rarity, Color.WHITE)
	label.add_theme_color_override("font_color", color)
	if icon != null:
		icon.modulate = color

func _apply_tech_frames(options: Array) -> void:
	for i in range(tech_frames.size()):
		var frame = tech_frames[i]
		if frame == null:
			continue
		if i >= options.size():
			frame.color = Color(0.5, 0.5, 0.5, 0.0)
			continue
		var rarity = str(options[i].get("rarity", "common"))
		var color: Color = rarity_colors.get(rarity, Color.WHITE)
		frame.color = Color(color.r, color.g, color.b, 0.35)

# =========================================================
# FONT + LAYOUT POLISH
# =========================================================

func _build_bitmap_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		push_warning("UI font resource not found: " + path)
		return null
	var font = load(path)
	if font is Font:
		print("UI font loaded successfully: " + path)
		return font
	push_warning("Loaded resource is not a Font: " + path + " (type: " + str(typeof(font)) + ")")
	return null

func _apply_font(label: Label, size: int = 8) -> void:
	if label == null:
		return
	if _ui_font != null:
		label.add_theme_font_override("font", _ui_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 1)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _apply_ui_fonts() -> void:
	_apply_font(resources_label, 10)
	_apply_font(time_label, 10)
	_apply_font(selection_label, 10)
	_apply_font(controls_label, 10)
	_apply_font(level_label, 10)
	_apply_font(tech_option1, 12)
	_apply_font(tech_option2, 12)
	_apply_font(tech_option3, 12)
	_apply_font(start_title, 12)
	_apply_font(start_body, 10)
	_apply_font(start_option1, 10)
	_apply_font(start_option2, 10)
	_apply_font(start_hint, 10)
	var tech_title: Label = $HUD/TechPanel/Title
	var tech_hint: Label = $HUD/TechPanel/Hint
	_apply_font(tech_title, 12)
	_apply_font(tech_hint, 10)

func _style_label(label: Label, pos: Vector2, size: Vector2, wrap: bool = true) -> void:
	if label == null:
		return
	label.position = pos
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _style_tech_panel() -> void:
	if tech_panel == null:
		return
	var panel_w = 384.0
	var panel_h = 192.0
	tech_panel.anchor_left = 0.5
	tech_panel.anchor_top = 0.5
	tech_panel.anchor_right = 0.5
	tech_panel.anchor_bottom = 0.5
	tech_panel.offset_left = -panel_w / 2.0
	tech_panel.offset_top = -panel_h / 2.0
	tech_panel.offset_right = panel_w / 2.0
	tech_panel.offset_bottom = panel_h / 2.0
	tech_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var tech_title: Label = $HUD/TechPanel/Title
	var tech_hint: Label = $HUD/TechPanel/Hint

	_style_label(tech_title, Vector2(16, 10), Vector2(352, 16), false)
	_style_label(tech_option1, Vector2(52, 38), Vector2(312, 36), true)
	_style_label(tech_option2, Vector2(52, 82), Vector2(312, 36), true)
	_style_label(tech_option3, Vector2(52, 126), Vector2(312, 36), true)
	_style_label(tech_hint, Vector2(16, 168), Vector2(352, 16), false)

	for icon in [tech_icon1, tech_icon2, tech_icon3]:
		if icon == null:
			continue
		icon.size = Vector2(24, 24)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if tech_icon1 != null:
		tech_icon1.position = Vector2(20, 44)
	if tech_icon2 != null:
		tech_icon2.position = Vector2(20, 88)
	if tech_icon3 != null:
		tech_icon3.position = Vector2(20, 132)

func _style_start_panel() -> void:
	if start_panel == null:
		return
	var panel_w = 384.0
	var panel_h = 224.0
	start_panel.anchor_left = 0.5
	start_panel.anchor_top = 0.5
	start_panel.anchor_right = 0.5
	start_panel.anchor_bottom = 0.5
	start_panel.offset_left = -panel_w / 2.0
	start_panel.offset_top = -panel_h / 2.0
	start_panel.offset_right = panel_w / 2.0
	start_panel.offset_bottom = panel_h / 2.0
	start_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_style_label(start_title, Vector2(16, 12), Vector2(352, 18), false)
	_style_label(start_body, Vector2(16, 36), Vector2(352, 44), true)
	_style_label(start_option1, Vector2(64, 92), Vector2(280, 16), false)
	_style_label(start_option2, Vector2(64, 128), Vector2(280, 16), false)

# =========================================================
# CHARACTER SELECT
# =========================================================

func _polish_start_panel() -> void:
	# Enlarge character icons to 48x48
	for icon in [start_icon1, start_icon2]:
		if icon == null:
			continue
		icon.size = Vector2(48, 48)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Shift option labels right to account for larger icons
	if start_option1 != null:
		start_option1.position.x = 80
	if start_option2 != null:
		start_option2.position.x = 80

func show_start(show: bool) -> void:
	if start_panel != null:
		start_panel.visible = show
	if start_hint != null:
		start_hint.visible = false

func set_start_text(title: String, body: String) -> void:
	if start_title != null:
		start_title.text = title
	if start_body != null:
		start_body.text = body

func set_start_options(options: Array, selected_index: int) -> void:
	_set_start_option(start_option1, start_icon1, options, 0, selected_index)
	_set_start_option(start_option2, start_icon2, options, 1, selected_index)

func _set_start_option(label: Label, icon: TextureRect, options: Array, index: int, selected_index: int) -> void:
	if label == null:
		return
	if index >= options.size():
		label.text = ""
		if icon != null:
			icon.texture = null
		return
	var option: Dictionary = options[index]
	var hero_name = str(option.get("name", ""))
	var desc = str(option.get("desc", ""))
	var is_selected = (index == selected_index)

	if is_selected:
		label.text = "%d) %s\n   %s" % [index + 1, hero_name, desc]
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	else:
		label.text = "%d) %s\n   %s" % [index + 1, hero_name, desc]
		label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))

	var path: String = str(option.get("icon", ""))
	if icon != null:
		if path != "" and ResourceLoader.exists(path):
			icon.texture = load(path)
			icon.modulate = Color.WHITE if is_selected else Color(0.6, 0.6, 0.6)
		else:
			icon.texture = null
