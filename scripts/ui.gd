extends CanvasLayer

const UI_FONT_PATH = "res://assets/ui/pixel_font.ttf"
const USE_CUSTOM_FONT = true
const TECH_PANEL_TEX = "res://assets/ui/tech/ui_tech_panel_480x320_v001.png"
const TECH_LEDGER_TEX = "res://assets/ui/tech/ui_tech_ledger_360x56_v001.png"
const TECH_CARD_TEXTURES = {
	"common": "res://assets/ui/tech/ui_tech_card_common_420x74_v001.png",
	"rare": "res://assets/ui/tech/ui_tech_card_rare_420x74_v001.png",
	"epic": "res://assets/ui/tech/ui_tech_card_epic_420x74_v001.png",
	"diamond": "res://assets/ui/tech/ui_tech_card_diamond_420x74_v001.png"
}
const RARITY_FRAME_TEXTURES = {
	"common": "res://assets/ui_build_icons/ui_rarity_common_frame_32_v001.png",
	"rare": "res://assets/ui_build_icons/ui_rarity_rare_frame_32_v001.png",
	"epic": "res://assets/ui_build_icons/ui_rarity_epic_frame_32_v001.png",
	"legendary": "res://assets/ui_build_icons/ui_rarity_legendary_frame_32_v001.png",
	"mythic": "res://assets/ui_build_icons/ui_rarity_legendary_frame_32_v001.png",
	"diamond": "res://assets/ui_build_icons/ui_rarity_legendary_frame_32_v001.png"
}
const UPGRADE_POPUP_TEX = "res://assets/ui/ui_tooltip_frame_256x96_v001.png"
const TECH_PANEL_SIZE = Vector2(480, 320)
const TECH_CARD_SIZE = Vector2(420, 74)
const TECH_CARD_POSITIONS = [
	Vector2(30, 56),
	Vector2(30, 144),
	Vector2(30, 232)
]
const TECH_ICON_SIZE = Vector2(42, 42)
const TECH_ICON_FRAME_SIZE = Vector2(32, 32)
# Hover wash over a draft card. Kept low: it sits on top of the rarity art, which
# is the thing carrying "this one is an epic".
const TECH_ROW_HOVER_ON = Color(1.0, 1.0, 1.0, 0.12)
const TECH_ROW_HOVER_OFF = Color(1.0, 1.0, 1.0, 0.0)

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
@onready var tech_title_label: Label = $HUD/TechPanel/Title
@onready var tech_hint_label: Label = $HUD/TechPanel/Hint
@onready var start_panel: TextureRect = $HUD/StartPanel
@onready var start_title: Label = $HUD/StartPanel/StartTitle
@onready var start_body: Label = $HUD/StartPanel/StartBody
@onready var start_option1: Label = $HUD/StartPanel/Option1
@onready var start_option2: Label = $HUD/StartPanel/Option2
@onready var start_icon1: TextureRect = $HUD/StartPanel/Option1Icon
@onready var start_icon2: TextureRect = $HUD/StartPanel/Option2Icon
@onready var start_hint: Label = $HUD/StartHint

var rarity_colors = {
	# Brightened + lifted toward white so the upgrade-card text stays legible over
	# the busy battlefield behind the modal. The rarity hue still reads at a glance,
	# but every color is now high-luminance instead of muted/desaturated.
	"common": Color(1.0, 1.0, 1.0),
	"rare": Color(0.55, 0.82, 1.0),
	"epic": Color(0.85, 0.68, 1.0),
	"legendary": Color(1.0, 0.88, 0.4),
	"mythic": Color(1.0, 0.55, 0.55),
	"diamond": Color(0.75, 0.98, 1.0)
}

# --- Build Palette ---
const PALETTE_ORDER = [
	{"id": "arrow_turret", "key": "1"},
	{"id": "cannon_tower", "key": "2"},
	{"id": "tesla_tower", "key": "3"},
	{"id": "resource_generator", "key": "4"},
	{"id": "shrine", "key": "5"},
]
# NOTE: traps + extra towers/utility buildings (mine_trap, ice_trap, acid_trap,
# spike_trap, spike_burst_tower, flamethrower_tower, barracks, tech_lab, armory)
# were removed from the buildable set. See docs/REMOVED_BUILDINGS.md to re-add.

var palette_slots: Dictionary = {}
var palette_active_id: String = ""

# Tech rarity frames (ColorRects behind each option icon)
var tech_frames: Array = []
var tech_icon_frames: Array = []
var tech_hit_rows: Array = []
# How many of the three rows this draft actually filled. Rows past it stay inert
# rather than emitting a pick for a card that is not on screen.
var _tech_option_count: int = 0
var _ui_font: Font = null
var _last_level: int = -1
var _xp_tween: Tween = null
var _level_flash_tween: Tween = null
var _announcement_root: Control = null
# Center-screen warnings (boss/swarm/etc) are tracked here so they stack vertically
# instead of piling up on the exact same spot. World-anchored popups (essence
# pickups via at_position) are NOT tracked and keep their own placement.
var _active_announcements: Array[Label] = []
var _recent_announcements: Dictionary = {}  # text -> last-shown msec (dedupe)
const ANNOUNCE_DEDUPE_MS := 400
const ANNOUNCE_STACK_TOP := 78.0    # px below the top edge (under wave countdown)
const ANNOUNCE_STACK_GAP := 8.0     # vertical gap between stacked rows
# Keeps the essence hint inside the left HUD column instead of trailing across
# the battlefield.
const ESSENCE_HINT_MAX_WIDTH := 210.0
var _tech_ledger_panel: TextureRect = null
var _tech_ledger_container: HBoxContainer = null
var _tech_ledger_label: Label = null
var _tech_ledger_visible: bool = false
var _wave_announce_label: Label = null
var _wave_preview_enabled: bool = true
var _tech_backdrop: ColorRect = null
var _modal_backdrop_for_tech: bool = false
var _modal_backdrop_for_chest: bool = false

# Build mode focus overlay
var _build_focus_overlay: ColorRect = null
var _build_focus_label: Label = null
var _build_focus_visible: bool = false
var _build_focus_name: String = ""
var _build_focus_scale: float = 1.0

# Low health vignette
var _vignette: ColorRect = null
var _vignette_pulse_tween: Tween = null
var _vignette_active: bool = false

# Kill streak display
var _streak_label: Label = null
var _objective_root: VBoxContainer = null
var _objective_label: Label = null
var _objective_bar: ProgressBar = null
var _streak_fade_tween: Tween = null
var _last_streak_shown: int = 0

# Boss health bar + off-screen direction marker.
var _boss_tracker: Control = null

func _ready() -> void:
	_ui_font = _build_bitmap_font(UI_FONT_PATH) if USE_CUSTOM_FONT else null
	_apply_ui_fonts()
	_style_tech_panel()
	_style_start_panel()
	_build_palette()
	_add_tech_rarity_frames()
	_polish_start_panel()
	_build_upgrade_panel()
	_build_announcement_root()
	_build_wave_announcement()
	_build_tech_ledger()
	set_tech_ledger_visible(false)
	_build_vignette()
	_build_build_focus_ui()
	_build_streak_label()
	_build_objective_ui()
	_build_boss_tracker()

func _build_boss_tracker() -> void:
	if _boss_tracker != null and is_instance_valid(_boss_tracker):
		return
	var tracker_script := load("res://scripts/boss_tracker.gd")
	if tracker_script == null:
		return
	_boss_tracker = Control.new()
	_boss_tracker.set_script(tracker_script)
	$HUD.add_child(_boss_tracker)
	if _boss_tracker.has_method("setup"):
		_boss_tracker.setup(_ui_font)

# =========================================================
# UPGRADE PANEL
# =========================================================

var upgrade_panel: PanelContainer = null
var upgrade_title: Label = null
var upgrade_stats: Label = null
var upgrade_cost: Label = null
var upgrade_button: Button = null

func _ensure_upgrade_panel() -> void:
	if upgrade_panel != null and upgrade_title != null and upgrade_stats != null and upgrade_cost != null:
		if is_instance_valid(upgrade_panel) and is_instance_valid(upgrade_title) and is_instance_valid(upgrade_stats) and is_instance_valid(upgrade_cost):
			return
	if upgrade_panel != null and is_instance_valid(upgrade_panel):
		upgrade_panel.queue_free()
	upgrade_panel = null
	upgrade_title = null
	upgrade_stats = null
	upgrade_cost = null
	upgrade_button = null
	_build_upgrade_panel()

func _build_upgrade_panel() -> void:
	var hud = $HUD
	
	upgrade_panel = PanelContainer.new()
	upgrade_panel.name = "UpgradePanel"
	upgrade_panel.visible = false
	upgrade_panel.size = Vector2(200, 140)
	upgrade_panel.position = Vector2(10, 200)
	
	# Style the panel background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.3, 0.7, 0.6, 0.8)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	upgrade_panel.add_theme_stylebox_override("panel", panel_style)
	
	hud.add_child(upgrade_panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	upgrade_panel.add_child(vbox)
	
	upgrade_title = Label.new()
	upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_title.add_theme_font_size_override("font_size", 12)
	upgrade_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(upgrade_title)

# =========================================================
# ANNOUNCEMENTS
# =========================================================

func _build_announcement_root() -> void:
	var hud = $HUD
	_announcement_root = Control.new()
	_announcement_root.name = "AnnouncementLayer"
	_announcement_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announcement_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(_announcement_root)

func _build_wave_announcement() -> void:
	if _wave_announce_label != null and is_instance_valid(_wave_announce_label):
		return
	var hud = $HUD
	_wave_announce_label = Label.new()
	_wave_announce_label.name = "WaveAnnouncement"
	_wave_announce_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_announce_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_announce_label.add_theme_font_size_override("font_size", 14)
	_wave_announce_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.7))
	_wave_announce_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_wave_announce_label.add_theme_constant_override("outline_size", 1)
	if _ui_font != null:
		_wave_announce_label.add_theme_font_override("font", _ui_font)
	_wave_announce_label.anchor_left = 0.5
	_wave_announce_label.anchor_right = 0.5
	_wave_announce_label.anchor_top = 0.0
	_wave_announce_label.anchor_bottom = 0.0
	_wave_announce_label.offset_left = -140.0
	_wave_announce_label.offset_right = 140.0
	_wave_announce_label.offset_top = 40.0
	_wave_announce_label.offset_bottom = 58.0
	_wave_announce_label.visible = false
	hud.add_child(_wave_announce_label)

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport = get_viewport()
	if viewport == null:
		return world_pos
	var camera = viewport.get_camera_2d()
	if camera == null:
		return world_pos
	var screen_center = viewport.get_visible_rect().size * 0.5
	var zoom = camera.zoom
	return (world_pos - camera.global_position) * zoom + screen_center

var _ffa_clock_label: Label = null

# FFA match countdown shown top-center. Lazily built on first call so solo never
# pays for it. Turns amber under one minute.
func set_ffa_clock(time_left: float) -> void:
	if _ffa_clock_label == null or not is_instance_valid(_ffa_clock_label):
		_ffa_clock_label = Label.new()
		_ffa_clock_label.name = "FFAClock"
		_ffa_clock_label.anchor_left = 0.5
		_ffa_clock_label.anchor_right = 0.5
		_ffa_clock_label.offset_left = -120.0
		_ffa_clock_label.offset_right = 120.0
		_ffa_clock_label.offset_top = 12.0
		_ffa_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ffa_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _ui_font != null:
			_ffa_clock_label.add_theme_font_override("font", _ui_font)
		_ffa_clock_label.add_theme_font_size_override("font_size", 22)
		add_child(_ffa_clock_label)
	var secs := int(ceil(max(0.0, time_left)))
	_ffa_clock_label.text = "%d:%02d" % [secs / 60, secs % 60]
	var col := Color(1.0, 0.3, 0.25) if secs <= 60 else Color(0.9, 0.92, 1.0)
	_ffa_clock_label.add_theme_color_override("font_color", col)

func show_announcement(text: String, color: Color, size: int, duration: float = 2.5, at_position: Vector2 = Vector2.ZERO) -> void:
	if text == "":
		return
	if _announcement_root == null:
		_build_announcement_root()
	if _announcement_root == null:
		return
	if not is_inside_tree():
		return

	var is_centered := at_position == Vector2.ZERO

	# Drop rapid duplicate center warnings (same text within a short window) so a
	# repeated trigger doesn't stamp two copies on top of each other.
	if is_centered:
		var now := Time.get_ticks_msec()
		var last = _recent_announcements.get(text, -100000)
		if now - int(last) < ANNOUNCE_DEDUPE_MS:
			return
		_recent_announcements[text] = now

	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 200
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	# A subtle outline keeps stacked warnings legible over busy backgrounds.
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	if _ui_font != null:
		label.add_theme_font_override("font", _ui_font)
	_announcement_root.add_child(label)
	label.size = label.get_minimum_size()
	label.scale = Vector2.ONE * 0.5
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)

	if is_centered:
		# Track and stack vertically in the upper-center band.
		_active_announcements.append(label)
		_relayout_announcements()
	else:
		# World-anchored popup (e.g. essence pickup): keep its own placement.
		var view_size = Vector2.ZERO
		var viewport = get_viewport()
		if viewport != null:
			view_size = viewport.get_visible_rect().size
		var screen_pos = _world_to_screen(at_position)
		var pos = screen_pos - label.size * 0.5
		if view_size != Vector2.ZERO:
			pos.x = clamp(pos.x, 0.0, max(0.0, view_size.x - label.size.x))
			pos.y = clamp(pos.y, 0.0, max(0.0, view_size.y - label.size.y))
		label.position = pos

	if not label.is_inside_tree():
		_active_announcements.erase(label)
		label.queue_free()
		return
	var fade_in = 0.3
	var fade_out = 0.5
	var hold_time = max(0.0, duration - fade_in - fade_out)
	var tween = label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "scale", Vector2.ONE, fade_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold_time > 0.0:
		tween.tween_interval(hold_time)
	tween.tween_property(label, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_announcement_finished.bind(label))

# An active center warning expired: drop it from the stack, free it, and repack
# the remaining warnings so they slide up to fill the gap.
func _on_announcement_finished(label: Label) -> void:
	_active_announcements.erase(label)
	if label != null and is_instance_valid(label):
		label.queue_free()
	_relayout_announcements()

# Position all live center warnings as a centered vertical stack in the upper band.
func _relayout_announcements() -> void:
	# Prune any freed entries first.
	for i in range(_active_announcements.size() - 1, -1, -1):
		var l = _active_announcements[i]
		if l == null or not is_instance_valid(l):
			_active_announcements.remove_at(i)
	var view_size = Vector2.ZERO
	var viewport = get_viewport()
	if viewport != null:
		view_size = viewport.get_visible_rect().size
	var center_x: float = view_size.x * 0.5
	var y: float = ANNOUNCE_STACK_TOP
	for l in _active_announcements:
		l.size = l.get_minimum_size()
		var target: Vector2 = Vector2(center_x - l.size.x * 0.5, y)
		# A label that hasn't been placed yet (just spawned, still at origin) snaps
		# straight to its slot; already-placed labels slide to repack smoothly.
		if l.is_inside_tree() and l.position != Vector2.ZERO:
			var t = l.create_tween()
			t.tween_property(l, "position", target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			l.position = target
		y += l.size.y + ANNOUNCE_STACK_GAP

func show_wave_announcement(text: String, time_left: float, active: bool) -> void:
	if _wave_announce_label == null:
		_build_wave_announcement()
	if _wave_announce_label == null or not is_instance_valid(_wave_announce_label):
		return
	if not _wave_preview_enabled:
		_wave_announce_label.visible = false
		return
	if not active or text == "":
		_wave_announce_label.visible = false
		return
	var seconds = int(ceil(time_left))
	_wave_announce_label.text = "%s %ds" % [text, seconds]
	_wave_announce_label.visible = true

func show_upgrade_panel(building: Node) -> void:
	if building == null:
		return
	_ensure_upgrade_panel()
	if upgrade_panel == null or upgrade_stats == null or upgrade_cost == null or upgrade_title == null:
		return
	if not is_instance_valid(upgrade_panel) or not is_instance_valid(upgrade_stats) or not is_instance_valid(upgrade_cost) or not is_instance_valid(upgrade_title):
		return

	# Check for evolution-ready or already evolved towers
	if building.has_method("can_evolve") and building.can_evolve():
		upgrade_title.text = "EVOLVE (Press U)"
		upgrade_title.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
		upgrade_stats.text = "Tower is ready to evolve!\nChoose a specialization."
		upgrade_cost.text = "Costs Essence"
		var panel_style = upgrade_panel.get_theme_stylebox("panel")
		if panel_style != null:
			var panel_copy = panel_style.duplicate()
			panel_copy.border_color = Color(0.7, 0.3, 1.0)
			upgrade_panel.add_theme_stylebox_override("panel", panel_copy)
		upgrade_panel.visible = true
		return

	if "is_evolved" in building and building.is_evolved:
		upgrade_title.text = building.evolution_name if "evolution_name" in building else "EVOLVED"
		upgrade_title.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
		upgrade_stats.text = "Fully evolved tower."
		upgrade_cost.text = ""
		upgrade_panel.visible = true
		return

	if not building.has_method("can_upgrade") or not building.can_upgrade():
		upgrade_panel.visible = false
		return
	
	var def = {}
	if "definition" in building:
		def = building.definition
	
	var tier = 0
	if "tier" in building:
		tier = building.tier
	
	var tower_name = def.get("name", "Tower")
	var next_tier = tier + 1
	var tier_names = ["BASE", "ENHANCED", "MASTER"]
	var tier_colors = [Color.WHITE, Color(0.4, 0.8, 1.0), Color(1.0, 0.5, 0.9)]
	if next_tier >= tier_names.size():
		next_tier = tier_names.size() - 1
	if next_tier < 0:
		next_tier = 0
	
	var upgrade_label = "UPGRADE"
	if building.has_method("get_upgrade_label"):
		upgrade_label = str(building.get_upgrade_label()).to_upper()
	upgrade_title.text = "%s: %s" % [upgrade_label, tier_names[next_tier]]
	upgrade_title.add_theme_color_override("font_color", tier_colors[next_tier])
	
	# Update border color to match tier
	var panel_style = upgrade_panel.get_theme_stylebox("panel")
	if panel_style != null:
		var panel_copy = panel_style.duplicate()
		panel_copy.border_color = tier_colors[next_tier]
		upgrade_panel.add_theme_stylebox_override("panel", panel_copy)
	
	# Build stats description with comparison
	var stats_text = ""
	if not def.is_empty():
		var tier_data = _get_next_tier_data(def, next_tier)
		if not tier_data.is_empty():
			# Get current tier for comparison
			var current_tier_data = _get_next_tier_data(def, tier) if tier > 0 else tier_data
			
			var range_val = int(tier_data.get("range", 0))
			var damage_val = int(tier_data.get("damage", 0))
			var rate_val = tier_data.get("fire_rate", 0)
			
			stats_text += "Range: %d\n" % range_val
			stats_text += "Damage: %d\n" % damage_val
			stats_text += "Fire Rate: %.1f/s\n" % rate_val
			
			# Special abilities with icons
			if tier_data.has("pierce_count") and tier_data.get("pierce_count", 1) > 1:
				stats_text += "★ Pierce %d enemies\n" % tier_data.get("pierce_count")
			if tier_data.has("chain_count") and tier_data.get("chain_count", 3) > 5:
				stats_text += "★ Chain %d targets\n" % tier_data.get("chain_count")
			if tier_data.get("lightning_storm", false):
				stats_text += "★ ⚡ LIGHTNING STORM\n"
			if tier_data.get("cluster_bombs", false):
				stats_text += "★ 💥 CLUSTER BOMBS\n"
			if tier_data.get("burn_effect", false):
				stats_text += "★ 🔥 BURN EFFECT\n"
			if tier_data.get("stun_chance", 0.0) > 0:
				stats_text += "★ ⚡ %.0f%% STUN\n" % (tier_data.get("stun_chance") * 100)
	
	upgrade_stats.text = stats_text
	
	var upgrade_cost_value = 0
	if building.has_method("get_upgrade_cost"):
		upgrade_cost_value = building.get_upgrade_cost()
	var upgrade_essence_cost = 0
	if building.has_method("get_upgrade_essence_cost"):
		upgrade_essence_cost = int(building.get_upgrade_essence_cost())
	if upgrade_essence_cost > 0:
		upgrade_cost.text = "⚡ %d GOLD + %d ESSENCE" % [upgrade_cost_value, upgrade_essence_cost]
		if stats_text != "":
			stats_text += "\n"
		stats_text += "Infusion grants amplified tier power."
		upgrade_stats.text = stats_text
	else:
		upgrade_cost.text = "⚡ %d RESOURCES" % upgrade_cost_value
	upgrade_panel.visible = true
	
	# Animate panel entrance
	if not is_inside_tree():
		return
	var tween = create_tween()
	upgrade_panel.scale = Vector2(0.8, 0.8)
	upgrade_panel.modulate = Color(1, 1, 1, 0)
	tween.set_parallel(true)
	tween.tween_property(upgrade_panel, "scale", Vector2(1, 1), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(upgrade_panel, "modulate", Color(1, 1, 1, 1), 0.15)

func hide_upgrade_panel() -> void:
	if upgrade_panel != null and upgrade_panel.visible:
		# Animate out
		if not is_inside_tree():
			return
		var tween = create_tween()
		tween.tween_property(upgrade_panel, "scale", Vector2(0.8, 0.8), 0.15)
		tween.parallel().tween_property(upgrade_panel, "modulate:a", 0.0, 0.1)
		tween.tween_callback(func():
			if upgrade_panel != null and is_instance_valid(upgrade_panel):
				upgrade_panel.visible = false
		)

func _get_next_tier_data(def: Dictionary, next_tier: int) -> Dictionary:
	var tiers = def.get("tiers", [])
	if tiers.is_empty() or next_tier >= tiers.size():
		return {}
	return tiers[next_tier]

# =========================================================
# EVOLUTION PANEL
# =========================================================

# Emitted when a player clicks an evolution card. build_manager connects to this
# so the choice is selectable by mouse/touch in addition to keyboard/controller.
signal evolution_card_clicked(index: int)

# Same idea for the level-up draft: main.gd connects this to _choose_tech, so a
# click lands on exactly the path 1/2/3 and the gamepad already take.
signal tech_option_clicked(index: int)

var evolution_panel: PanelContainer = null
var _evo_cards: Array[PanelContainer] = []
var _evo_title: Label = null
var _build_manager_ref: Node = null

func _build_evolution_panel() -> void:
	var hud = $HUD

	evolution_panel = PanelContainer.new()
	evolution_panel.name = "EvolutionPanel"
	evolution_panel.visible = false
	evolution_panel.set_anchors_preset(Control.PRESET_CENTER)
	evolution_panel.size = Vector2(440, 220)
	evolution_panel.position = Vector2(-220, -110)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.04, 0.12, 0.97)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.7, 0.3, 1.0, 0.9)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	evolution_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	evolution_panel.add_child(vbox)

	_evo_title = Label.new()
	_evo_title.text = "EVOLVE YOUR TOWER"
	_evo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_evo_title.add_theme_font_size_override("font_size", 14)
	_evo_title.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
	if _ui_font != null:
		_evo_title.add_theme_font_override("font", _ui_font)
	vbox.add_child(_evo_title)

	var cards_row = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 12)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards_row)

	# Create 2 evolution cards
	for i in range(2):
		var card = _create_evo_card(cards_row, i)
		_evo_cards.append(card)

	var hint = Label.new()
	hint.text = "Click a card, press 1/2, or use your controller  |  ESC to cancel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	if _ui_font != null:
		hint.add_theme_font_override("font", _ui_font)
	vbox.add_child(hint)

	hud.add_child(evolution_panel)

func _create_evo_card(parent: HBoxContainer, index: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(190, 140)
	# Make the whole card a click target (mouse/touch). Controller + keyboard
	# selection still works via build_manager; this adds pointer selection.
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(_on_evo_card_gui_input.bind(index))
	card.mouse_entered.connect(_on_evo_card_hover.bind(index, true))
	card.mouse_exited.connect(_on_evo_card_hover.bind(index, false))

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.06, 0.18, 0.95)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.5, 0.2, 0.8, 0.7)
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	# Let clicks fall through the inner content to the card so gui_input fires.
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var key_label = Label.new()
	key_label.name = "KeyLabel"
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.text = "[%d]" % (index + 1)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 10)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	if _ui_font != null:
		key_label.add_theme_font_override("font", _ui_font)
	vbox.add_child(key_label)

	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
	if _ui_font != null:
		name_label.add_theme_font_override("font", _ui_font)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if _ui_font != null:
		desc_label.add_theme_font_override("font", _ui_font)
	vbox.add_child(desc_label)

	var cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 9)
	cost_label.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
	if _ui_font != null:
		cost_label.add_theme_font_override("font", _ui_font)
	vbox.add_child(cost_label)

	parent.add_child(card)
	return card

func _on_evo_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if evolution_panel == null or not evolution_panel.visible:
			return
		# Consume so the click doesn't also fall through to the world (place/select).
		get_viewport().set_input_as_handled()
		evolution_card_clicked.emit(index)

func _on_evo_card_hover(index: int, entered: bool) -> void:
	if index < 0 or index >= _evo_cards.size():
		return
	var card = _evo_cards[index]
	if card == null or not is_instance_valid(card):
		return
	var sb = card.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var box := sb as StyleBoxFlat
		if entered:
			box.border_color = Color(1.0, 0.65, 1.0, 1.0)
			box.bg_color = Color(0.16, 0.1, 0.26, 0.98)
		else:
			box.border_color = Color(0.5, 0.2, 0.8, 0.7)
			box.bg_color = Color(0.1, 0.06, 0.18, 0.95)

func show_evolution_panel(options: Array, current_essence: int) -> void:
	if evolution_panel == null:
		_build_evolution_panel()

	for i in range(min(options.size(), _evo_cards.size())):
		var card = _evo_cards[i]
		var opt = options[i]
		var cost = int(opt.get("cost", 3))
		var can_afford = current_essence >= cost

		# Access through card's child VBox
		var vbox = card.get_child(0)
		var name_label = vbox.get_child(1) as Label
		var desc_label = vbox.get_child(2) as Label
		var cost_label = vbox.get_child(3) as Label

		name_label.text = opt.get("name", "???")
		desc_label.text = opt.get("desc", "")
		cost_label.text = "Cost: %d Essence" % cost

		if can_afford:
			cost_label.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
			name_label.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
		else:
			cost_label.add_theme_color_override("font_color", Color(0.5, 0.2, 0.2))
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	evolution_panel.visible = true
	# Animate entrance
	evolution_panel.scale = Vector2(0.7, 0.7)
	evolution_panel.modulate = Color(1, 1, 1, 0)
	if not is_inside_tree():
		return
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(evolution_panel, "scale", Vector2(1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(evolution_panel, "modulate", Color(1, 1, 1, 1), 0.2)

func hide_evolution_panel() -> void:
	if evolution_panel != null and evolution_panel.visible:
		if not is_inside_tree():
			return
		var tween = create_tween()
		tween.tween_property(evolution_panel, "scale", Vector2(0.7, 0.7), 0.15)
		tween.parallel().tween_property(evolution_panel, "modulate:a", 0.0, 0.1)
		tween.tween_callback(func():
			if evolution_panel != null and is_instance_valid(evolution_panel):
				evolution_panel.visible = false
		)

func is_evolution_panel_open() -> bool:
	return evolution_panel != null and evolution_panel.visible

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

var essence_label: Label = null
var _essence_hint_label: Label = null
var _essence_pulse_tween: Tween = null
var _evo_ready_announced: bool = false

func _build_essence_label() -> void:
	var hud = $HUD
	# Main essence counter - placed below Controls label to avoid overlap
	essence_label = Label.new()
	essence_label.name = "Essence"
	essence_label.text = ""
	essence_label.add_theme_font_size_override("font_size", 12)
	essence_label.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
	if _ui_font != null:
		essence_label.add_theme_font_override("font", _ui_font)
	essence_label.position = Vector2(16, 150)
	essence_label.visible = false  # Hidden until player has essence
	hud.add_child(essence_label)
	# Hint label below essence showing what it does. It sits over the world, so it
	# needs its own dark plate and an outline - low-contrast purple on a packed
	# tower base was unreadable, and the part that names the key comes first.
	_essence_hint_label = Label.new()
	_essence_hint_label.name = "EssenceHint"
	_essence_hint_label.text = ""
	_essence_hint_label.add_theme_font_size_override("font_size", 10)
	_essence_hint_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.8, 0.7))
	_essence_hint_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_essence_hint_label.add_theme_constant_override("outline_size", 3)
	var hint_plate := StyleBoxFlat.new()
	hint_plate.bg_color = Color(0.04, 0.02, 0.08, 0.55)
	hint_plate.content_margin_left = 4.0
	hint_plate.content_margin_right = 4.0
	hint_plate.content_margin_top = 1.0
	hint_plate.content_margin_bottom = 1.0
	hint_plate.corner_radius_top_left = 3
	hint_plate.corner_radius_top_right = 3
	hint_plate.corner_radius_bottom_left = 3
	hint_plate.corner_radius_bottom_right = 3
	_essence_hint_label.add_theme_stylebox_override("normal", hint_plate)
	if _ui_font != null:
		_essence_hint_label.add_theme_font_override("font", _ui_font)
	_essence_hint_label.position = Vector2(16, 166)
	# Never let a long hint run past the left column into the play area.
	_essence_hint_label.size = Vector2(ESSENCE_HINT_MAX_WIDTH, 0)
	_essence_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_essence_hint_label.clip_text = false
	_essence_hint_label.visible = false
	hud.add_child(_essence_hint_label)

func set_resources(amount: int) -> void:
	resources_label.text = "Resources: %d" % amount

func set_essence(amount: int) -> void:
	if essence_label == null:
		_build_essence_label()
	if amount <= 0:
		essence_label.visible = false
		if _essence_hint_label != null:
			_essence_hint_label.visible = false
		return
	essence_label.visible = true
	essence_label.text = "Essence: %d" % amount
	if _essence_hint_label != null:
		_essence_hint_label.visible = true
		if amount >= 3:
			# Key first: that is the actionable part, and it is what got lost when
			# the line was long enough to trail off.
			# Explicit line break: left to autowrap it split at the separator and
			# left a dangling dash reading like a bullet.
			_essence_hint_label.text = "[U] Infuse tower\n500g + 1 Essence"
			_essence_hint_label.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0, 0.9))
			# Pulse the essence label when enough to evolve
			if _essence_pulse_tween == null and is_inside_tree():
				_essence_pulse_tween = create_tween()
				_essence_pulse_tween.set_loops()
				_essence_pulse_tween.tween_property(essence_label, "modulate:a", 0.5, 0.6).set_trans(Tween.TRANS_SINE)
				_essence_pulse_tween.tween_property(essence_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
		else:
			# Explicit line break: left to autowrap it split at the separator and
			# left a dangling dash reading like a bullet.
			_essence_hint_label.text = "[U] Infuse tower\n500g + 1 Essence"
			_essence_hint_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.8, 0.7))
			if _essence_pulse_tween != null:
				_essence_pulse_tween.kill()
				_essence_pulse_tween = null
				essence_label.modulate.a = 1.0

func set_time(seconds: float) -> void:
	time_label.text = "Time: %.1f" % seconds

func set_selection(text: String) -> void:
	selection_label.text = text

func set_controls(text: String) -> void:
	controls_label.text = text

var _controls_fade_tween: Tween = null

func set_controls_visible(v: bool) -> void:
	if controls_label == null:
		return
	var target_a := 1.0 if v else 0.0
	if is_equal_approx(controls_label.modulate.a, target_a):
		return
	if _controls_fade_tween != null and _controls_fade_tween.is_valid():
		_controls_fade_tween.kill()
	if not is_inside_tree():
		controls_label.modulate.a = target_a
		return
	_controls_fade_tween = create_tween()
	_controls_fade_tween.tween_property(controls_label, "modulate:a", target_a, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_level(level: int, xp: int, xp_next: int) -> void:
	level_label.text = "Level: %d (%d/%d)" % [level, xp, xp_next]
	if xp_bar != null:
		xp_bar.max_value = xp_next
		if _xp_tween != null:
			_xp_tween.kill()
		if is_inside_tree():
			_xp_tween = create_tween()
			_xp_tween.tween_property(xp_bar, "value", xp, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _last_level >= 0 and level > _last_level:
		if _level_flash_tween != null:
			_level_flash_tween.kill()
		var label_normal = level_label.modulate
		level_label.modulate = Color.WHITE
		var bar_normal = Color.WHITE
		if xp_bar != null:
			bar_normal = xp_bar.modulate
			xp_bar.modulate = Color.WHITE
		if is_inside_tree():
			_level_flash_tween = create_tween()
			_level_flash_tween.set_parallel(true)
			_level_flash_tween.tween_property(level_label, "modulate", label_normal, 0.3)
			if xp_bar != null:
				_level_flash_tween.tween_property(xp_bar, "modulate", bar_normal, 0.3)
	_last_level = level

func set_health(current: float, maximum: float) -> void:
	if health_bar == null:
		return
	health_bar.max_value = max(1.0, maximum)
	health_bar.value = clamp(current, 0.0, maximum)
	_update_vignette(current, maximum)

func _build_build_focus_ui() -> void:
	if _build_focus_overlay != null and is_instance_valid(_build_focus_overlay):
		return
	var hud = $HUD
	_build_focus_overlay = ColorRect.new()
	_build_focus_overlay.name = "BuildFocusOverlay"
	_build_focus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_focus_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_focus_overlay.color = Color(0.03, 0.11, 0.16, 0.34)
	_build_focus_overlay.visible = false
	hud.add_child(_build_focus_overlay)
	hud.move_child(_build_focus_overlay, 0)

	_build_focus_label = Label.new()
	_build_focus_label.name = "BuildFocusLabel"
	_build_focus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_focus_label.anchor_left = 0.5
	_build_focus_label.anchor_right = 0.5
	_build_focus_label.anchor_top = 0.0
	_build_focus_label.anchor_bottom = 0.0
	_build_focus_label.offset_left = -220.0
	_build_focus_label.offset_right = 220.0
	_build_focus_label.offset_top = 8.0
	_build_focus_label.offset_bottom = 32.0
	_build_focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_focus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_build_focus_label.add_theme_font_size_override("font_size", 14)
	_build_focus_label.add_theme_color_override("font_color", Color(0.85, 0.97, 1.0, 0.95))
	if _ui_font != null:
		_build_focus_label.add_theme_font_override("font", _ui_font)
	_build_focus_label.visible = false
	hud.add_child(_build_focus_label)

func set_build_focus(active: bool, build_name: String = "", time_scale: float = 1.0) -> void:
	"""Build-mode banner.

	This used to read 'BUILD MODE | <TOWER> | TIME 78%' — the tail advertised
	BUILD_FOCUS_TIME_SCALE. The actual slowdown was removed, but the banner kept
	claiming time was at 78%, so the game still *looked* like it was slowing
	down while building. It also overlapped the extractor objective banner at
	the top of the screen. Retired entirely: the build palette and placement
	preview already show the selected structure."""
	_build_focus_visible = false
	_build_focus_name = build_name.strip_edges()
	_build_focus_scale = time_scale
	if _build_focus_overlay != null and is_instance_valid(_build_focus_overlay):
		_build_focus_overlay.visible = false
	if _build_focus_label != null and is_instance_valid(_build_focus_label):
		_build_focus_label.visible = false

# =========================================================
# LOW HEALTH VIGNETTE
# =========================================================

func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.name = "DamageVignette"
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.8, 0.0, 0.0, 0.0)
	# Use a shader for edge-only vignette effect
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float vignette = smoothstep(0.4, 1.2, dist);
	COLOR = vec4(0.8, 0.05, 0.05, vignette * intensity);
}
"""
	mat.shader = shader
	_vignette.material = mat
	$HUD.add_child(_vignette)

func _update_vignette(current: float, maximum: float) -> void:
	if _vignette == null:
		return
	var ratio = current / max(1.0, maximum)
	if ratio <= 0.3 and ratio > 0.0:
		# Intensity scales: 0.3 ratio = mild, 0.0 = max
		var intensity = (0.3 - ratio) / 0.3
		var mat = _vignette.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("intensity", intensity * 0.7)
		# Start pulse if not already
		if not _vignette_active:
			_vignette_active = true
			_start_vignette_pulse()
	else:
		if _vignette_active:
			_vignette_active = false
			if _vignette_pulse_tween != null:
				_vignette_pulse_tween.kill()
				_vignette_pulse_tween = null
			var mat = _vignette.material as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter("intensity", 0.0)

func _start_vignette_pulse() -> void:
	if _vignette_pulse_tween != null:
		_vignette_pulse_tween.kill()
	if not is_inside_tree():
		return
	# We don't tween the shader param directly since set_health updates it
	# Instead, modulate the ColorRect alpha for a pulsing feel
	_vignette.modulate.a = 1.0
	_vignette_pulse_tween = create_tween()
	_vignette_pulse_tween.set_loops()
	_vignette_pulse_tween.tween_property(_vignette, "modulate:a", 0.4, 0.5).set_trans(Tween.TRANS_SINE)
	_vignette_pulse_tween.tween_property(_vignette, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

# =========================================================
# KILL STREAK DISPLAY
# =========================================================

func _build_objective_ui() -> void:
	"""Top-centre objective readout: the placement countdown during SCOUT, then
	the extraction progress bar for the rest of the run. One slot, two states,
	so the player always knows what the run is asking of them."""
	_objective_root = VBoxContainer.new()
	_objective_root.name = "ObjectiveHUD"
	_objective_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_root.offset_left = -190.0
	_objective_root.offset_right = 190.0
	_objective_root.offset_top = 8.0
	_objective_root.offset_bottom = 74.0
	_objective_root.add_theme_constant_override("separation", 3)
	_objective_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_objective_root)

	_objective_label = Label.new()
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 16)
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(_objective_label, 16)
	_objective_root.add_child(_objective_label)

	_objective_bar = ProgressBar.new()
	_objective_bar.custom_minimum_size = Vector2(360, 14)
	_objective_bar.min_value = 0.0
	_objective_bar.max_value = 1.0
	_objective_bar.value = 0.0
	_objective_bar.show_percentage = false
	_objective_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.07, 0.85)
	bg.border_color = Color(0.62, 0.52, 0.36, 0.95)
	bg.set_border_width_all(2)
	_objective_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.95, 0.6, 0.95)
	_objective_bar.add_theme_stylebox_override("fill", fill)
	_objective_root.add_child(_objective_bar)

func update_objective(phase: int, seconds_left: float, progress: float) -> void:
	"""phase mirrors main.gd's ExtractionPhase: 0 SCOUT, 1 SIEGE, 2 OVERRUN."""
	if _objective_label == null or _objective_bar == null:
		return
	match phase:
		0:
			var secs := int(ceil(maxf(seconds_left, 0.0)))
			# Spell out the key. Without this the objective is unactionable:
			# players saw a countdown with no idea what to press.
			_objective_label.text = "PRESS 4 TO PLACE EXTRACTOR  —  %d:%02d" % [secs / 60, secs % 60]
			# Calm gold, turning red as the window closes.
			var urgency := clampf(1.0 - seconds_left / 120.0, 0.0, 1.0)
			_objective_label.modulate = Color(1.0, 0.9 - urgency * 0.65, 0.35 - urgency * 0.25, 1.0)
			_objective_bar.value = 1.0 - clampf(seconds_left / 120.0, 0.0, 1.0)
			_set_objective_fill(Color(0.95, 0.75, 0.25, 0.95))
		1:
			_objective_label.text = "EXTRACTING  %d%%" % int(round(progress * 100.0))
			_objective_label.modulate = Color(0.55, 1.0, 0.7, 1.0)
			_objective_bar.value = progress
			_set_objective_fill(Color(0.35, 0.95, 0.6, 0.95))
		_:
			_objective_label.text = "OVERRUN — SURVIVE"
			_objective_label.modulate = Color(1.0, 0.35, 0.3, 1.0)
			_objective_bar.value = 1.0
			_set_objective_fill(Color(1.0, 0.3, 0.25, 0.95))

func _set_objective_fill(color: Color) -> void:
	var fill := _objective_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		(fill as StyleBoxFlat).bg_color = color

func _build_streak_label() -> void:
	_streak_label = Label.new()
	_streak_label.name = "StreakLabel"
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_streak_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_streak_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_streak_label.offset_right = -20.0
	_streak_label.offset_left = -180.0
	_streak_label.offset_top = -20.0
	_streak_label.offset_bottom = 20.0
	_streak_label.add_theme_font_size_override("font_size", 18)
	_streak_label.modulate = Color(1.0, 0.9, 0.3, 0.0)  # Start invisible
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _ui_font != null:
		_streak_label.add_theme_font_override("font", _ui_font)
	$HUD.add_child(_streak_label)

func update_streak(streak: int) -> void:
	if _streak_label == null:
		return
	if streak < 5:
		# Below threshold, fade out if visible
		if _last_streak_shown >= 5:
			_fade_streak_out()
		_last_streak_shown = streak
		return
	_last_streak_shown = streak
	_streak_label.text = "x%d KILLS" % streak
	# Color escalation
	if streak >= 50:
		_streak_label.modulate = Color(1.0, 0.2, 0.2, 1.0)  # Red
		_streak_label.add_theme_font_size_override("font_size", 24)
	elif streak >= 25:
		_streak_label.modulate = Color(1.0, 0.5, 0.1, 1.0)  # Orange
		_streak_label.add_theme_font_size_override("font_size", 22)
	elif streak >= 10:
		_streak_label.modulate = Color(1.0, 0.85, 0.2, 1.0)  # Gold
		_streak_label.add_theme_font_size_override("font_size", 20)
	else:
		_streak_label.modulate = Color(0.9, 0.9, 0.9, 0.8)  # White
		_streak_label.add_theme_font_size_override("font_size", 18)
	# Quick pop animation
	if _streak_fade_tween != null:
		_streak_fade_tween.kill()
	if not is_inside_tree():
		return
	_streak_fade_tween = create_tween()
	var pop_scale = 1.2 if streak >= 25 else 1.1
	_streak_label.scale = Vector2.ONE * pop_scale
	_streak_fade_tween.tween_property(_streak_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fade_streak_out() -> void:
	if _streak_label == null:
		return
	if _streak_fade_tween != null:
		_streak_fade_tween.kill()
	if not is_inside_tree():
		return
	_streak_fade_tween = create_tween()
	_streak_fade_tween.tween_property(_streak_label, "modulate:a", 0.0, 0.5)

# =========================================================
# TECH PICK PANEL
# =========================================================

func _add_tech_rarity_frames() -> void:
	tech_frames.clear()
	for idx in range(TECH_CARD_POSITIONS.size()):
		var frame = TextureRect.new()
		frame.name = "TechCard_%d" % idx
		frame.size = TECH_CARD_SIZE
		frame.position = TECH_CARD_POSITIONS[idx]
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tech_panel.add_child(frame)
		tech_panel.move_child(frame, 0)
		tech_frames.append(frame)
	_add_tech_hit_rows()
	_add_tech_icon_frames()

func _add_tech_hit_rows() -> void:
	"""Clickable hit areas over the three draft cards.

	The draft used to be keyboard/gamepad only: its options are `Label`s, which
	default to MOUSE_FILTER_IGNORE, and they were laid out with zero-size rects
	anyway. Meanwhile the draft holds the game at `Engine.time_scale` 0, so a
	player who reaches for the mouse - the first instinct, and the one the evolve
	chooser already rewards - finds nothing to click and a game that has stopped.

	Each row is a child of its card so it draws over the card art and under the
	label and icon, which keeps the hover wash off the text."""
	tech_hit_rows.clear()
	for idx in range(tech_frames.size()):
		var card = tech_frames[idx]
		if card == null or not is_instance_valid(card):
			continue
		var row := ColorRect.new()
		row.name = "TechRowHit_%d" % idx
		row.color = TECH_ROW_HOVER_OFF
		row.size = TECH_CARD_SIZE
		row.position = Vector2.ZERO
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(_on_tech_row_gui_input.bind(idx))
		row.mouse_entered.connect(_on_tech_row_hover.bind(idx, true))
		row.mouse_exited.connect(_on_tech_row_hover.bind(idx, false))
		card.add_child(row)
		tech_hit_rows.append(row)

func _on_tech_row_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if tech_panel == null or not tech_panel.visible:
		return
	if index >= _tech_option_count:
		return
	# Consume it, or the same click also reaches the world underneath and places
	# or selects a building the moment the draft closes.
	get_viewport().set_input_as_handled()
	_play_ui_sound("click")
	tech_option_clicked.emit(index)

func _on_tech_row_hover(index: int, entered: bool) -> void:
	if index < 0 or index >= tech_hit_rows.size():
		return
	var row = tech_hit_rows[index]
	if row == null or not is_instance_valid(row):
		return
	if index >= _tech_option_count:
		row.color = TECH_ROW_HOVER_OFF
		return
	row.color = TECH_ROW_HOVER_ON if entered else TECH_ROW_HOVER_OFF
	if entered:
		_play_ui_sound("hover")

func _play_ui_sound(sound_name: String) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_ui_sound"):
		am.play_ui_sound(sound_name)

func _add_tech_icon_frames() -> void:
	for raw_frame in tech_icon_frames:
		if raw_frame != null and is_instance_valid(raw_frame):
			raw_frame.queue_free()
	tech_icon_frames.clear()
	var icons = [tech_icon1, tech_icon2, tech_icon3]
	for idx in range(icons.size()):
		var icon = icons[idx]
		if icon == null:
			continue
		var frame = TextureRect.new()
		frame.name = "TechIconFrame_%d" % idx
		frame.size = TECH_ICON_FRAME_SIZE
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.visible = false
		frame.z_index = icon.z_index + 1
		tech_panel.add_child(frame)
		tech_icon_frames.append(frame)
	_position_tech_icon_frames()

func _position_tech_icon_frames() -> void:
	var icons = [tech_icon1, tech_icon2, tech_icon3]
	for i in range(min(icons.size(), tech_icon_frames.size())):
		var icon = icons[i]
		var frame = tech_icon_frames[i]
		if icon == null or frame == null:
			continue
		frame.position = icon.position + (icon.size - TECH_ICON_FRAME_SIZE) * 0.5

func _ensure_tech_backdrop() -> void:
	if _tech_backdrop != null and is_instance_valid(_tech_backdrop):
		return
	_tech_backdrop = ColorRect.new()
	_tech_backdrop.name = "TechBackdrop"
	_tech_backdrop.color = Color(0.0, 0.0, 0.0, 0.88)
	_tech_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tech_backdrop.anchor_left = 0.0
	_tech_backdrop.anchor_top = 0.0
	_tech_backdrop.anchor_right = 1.0
	_tech_backdrop.anchor_bottom = 1.0
	_tech_backdrop.offset_left = 0.0
	_tech_backdrop.offset_top = 0.0
	_tech_backdrop.offset_right = 0.0
	_tech_backdrop.offset_bottom = 0.0
	_tech_backdrop.visible = false
	$HUD.add_child(_tech_backdrop)
	$HUD.move_child(_tech_backdrop, 0)

func _refresh_modal_backdrop() -> void:
	_ensure_tech_backdrop()
	if _tech_backdrop == null:
		return
	var visible = _modal_backdrop_for_tech or _modal_backdrop_for_chest
	_tech_backdrop.visible = visible
	if not visible:
		return
	if _modal_backdrop_for_chest and not _modal_backdrop_for_tech:
		_tech_backdrop.color = Color(0.0, 0.0, 0.0, 0.97)
	else:
		_tech_backdrop.color = Color(0.0, 0.0, 0.0, 0.88)

func set_chest_blackout(active: bool) -> void:
	_modal_backdrop_for_chest = active
	_refresh_modal_backdrop()

# ============================================
# CHEST REVEAL — full-screen jackpot takeover
#
# The world-space version read as "some particles happened near a crate". The
# reward moment has to own the screen: dim everything, land the chest dead
# centre, build tension, burst, then slam the prizes in one at a time.
#
# All tweens ignore time_scale because the chest modal freezes the game.
# ============================================

const CHEST_CARD_FRAMES := {
	"common": "res://assets/ui/tech/ui_tech_card_common_420x74_v001.png",
	"rare": "res://assets/ui/tech/ui_tech_card_rare_420x74_v001.png",
	"epic": "res://assets/ui/tech/ui_tech_card_epic_420x74_v001.png",
	"diamond": "res://assets/ui/tech/ui_tech_card_diamond_420x74_v001.png",
}
const CHEST_RARITY_COLORS := {
	"common": Color(0.55, 0.95, 0.55),
	"rare": Color(0.40, 0.70, 1.0),
	"epic": Color(0.85, 0.40, 1.0),
	"diamond": Color(0.35, 1.0, 1.0),
}
const CHEST_RARITY_RANK := {"common": 0, "rare": 1, "epic": 2, "diamond": 3}

var _chest_reveal_root: Control = null
var _chest_rays: TextureRect = null
var _chest_sprite: TextureRect = null
var _chest_cards: VBoxContainer = null
var _chest_banner: Label = null
var _chest_flash: ColorRect = null
static var _rays_texture: ImageTexture = null

# Chest lid states, in strip order: shut, straining, cracked, open.
const CHEST_STRIP_PATH := "res://assets/props/prop_treasure_chest_48_v001.png"
const CHEST_FRAME_SIZE := 48
const CHEST_FRAME_SHUT := 0
const CHEST_FRAME_STRAIN := 1
const CHEST_FRAME_CRACK := 2
const CHEST_FRAME_OPEN := 3


const CHEST_SPRITE_SIZE := 192.0
# How far above the viewport centre the chest sits, so it clears the prize
# cards that stack from the centre down.
#
# THE RAY BURST READS ITS CENTRE FROM THIS TOO, and must. The rays used to be
# pinned to the viewport centre while the chest was pinned 150px above it, so
# the burst did not originate at the chest -- it originated a chest-and-a-half
# below one, and the lid opened above the circle instead of out of it. Two
# separately-centred things that are meant to look like one event will drift
# apart the moment either is nudged, so they are derived from one number.
const CHEST_SPRITE_RISE := 150.0
const CHEST_RAYS_SIZE := 760.0


func _place_chest_sprite() -> void:
	"""Anchor the chest above the centre of the viewport.

	Via offsets rather than `position`: with PRESET_CENTER anchors, `position`
	is still parent-relative, so the `Vector2(-96, -150)` this used to be set to
	parked the sprite off the top-left corner of the screen. The chest has never
	actually been visible during the reveal -- only the rays, cards and banner
	were, which is why a 32px crate prop went unnoticed as the hero sprite.
	"""
	if _chest_sprite == null or not is_instance_valid(_chest_sprite):
		return
	var half := CHEST_SPRITE_SIZE * 0.5
	_chest_sprite.offset_left = -half
	_chest_sprite.offset_right = half
	_chest_sprite.offset_top = -half - CHEST_SPRITE_RISE
	_chest_sprite.offset_bottom = half - CHEST_SPRITE_RISE


func _place_chest_rays() -> void:
	"""Centre the ray burst on the CHEST, not on the viewport.

	Same offset mechanism as the chest and lifted by the same
	CHEST_SPRITE_RISE, so the burst originates exactly where the lid is. Set
	through offsets rather than `position` for the reason recorded above: with
	PRESET_CENTER anchors `position` is still parent-relative, which is what put
	the chest off the top-left corner for the whole life of the feature.

	pivot_offset stays at the burst's own centre so the rotation in the reveal
	still spins about the chest rather than swinging it around an off-centre
	point.
	"""
	if _chest_rays == null or not is_instance_valid(_chest_rays):
		return
	var half := CHEST_RAYS_SIZE * 0.5
	_chest_rays.offset_left = -half
	_chest_rays.offset_right = half
	_chest_rays.offset_top = -half - CHEST_SPRITE_RISE
	_chest_rays.offset_bottom = half - CHEST_SPRITE_RISE
	_chest_rays.pivot_offset = Vector2(CHEST_RAYS_SIZE, CHEST_RAYS_SIZE) * 0.5


func _set_chest_frame(index: int) -> void:
	if _chest_sprite == null or not is_instance_valid(_chest_sprite):
		return
	var atlas := _chest_sprite.texture as AtlasTexture
	if atlas == null:
		return
	atlas.region = Rect2(index * CHEST_FRAME_SIZE, 0, CHEST_FRAME_SIZE, CHEST_FRAME_SIZE)

static func _get_rays_texture() -> ImageTexture:
	"""Radial god-rays sprite, generated once. Alternating spokes fading out
	toward the rim — the classic 'something great is happening' backdrop."""
	if _rays_texture != null:
		return _rays_texture
	var size := 512
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size, size) * 0.5
	var spokes := 16.0
	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y) - center
			var dist := d.length() / (size * 0.5)
			if dist > 1.0:
				continue
			# Wedge pattern: smooth spokes, softened near the hub.
			var ang := atan2(d.y, d.x)
			var wedge := 0.5 + 0.5 * cos(ang * spokes)
			wedge = pow(wedge, 2.4)
			var falloff := clampf(1.0 - dist, 0.0, 1.0)
			falloff = pow(falloff, 1.4) * clampf(dist * 4.0, 0.0, 1.0)
			var a := wedge * falloff
			if a > 0.004:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_rays_texture = ImageTexture.create_from_image(img)
	return _rays_texture

func _build_chest_reveal() -> void:
	if _chest_reveal_root != null and is_instance_valid(_chest_reveal_root):
		return
	_chest_reveal_root = Control.new()
	_chest_reveal_root.name = "ChestReveal"
	_chest_reveal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chest_reveal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_reveal_root.z_index = 200
	_chest_reveal_root.visible = false
	$HUD.add_child(_chest_reveal_root)

	_chest_rays = TextureRect.new()
	_chest_rays.texture = _get_rays_texture()
	_chest_rays.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_chest_rays.set_anchors_preset(Control.PRESET_CENTER)
	_chest_rays.custom_minimum_size = Vector2(CHEST_RAYS_SIZE, CHEST_RAYS_SIZE)
	_chest_rays.size = Vector2(CHEST_RAYS_SIZE, CHEST_RAYS_SIZE)
	_place_chest_rays()
	_chest_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_rays.modulate = Color(1.0, 0.9, 0.5, 0.0)
	var ray_mat := CanvasItemMaterial.new()
	ray_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_chest_rays.material = ray_mat
	_chest_reveal_root.add_child(_chest_rays)

	_chest_sprite = TextureRect.new()
	if ResourceLoader.exists(CHEST_STRIP_PATH):
		# One frame of the strip at a time. The reveal blows the sprite up to
		# 192px and then past 2x again on the burst, so this is the single
		# largest the chest art ever gets -- it used to be a 32px crate prop
		# borrowed from the graveyard set.
		var atlas := AtlasTexture.new()
		atlas.atlas = load(CHEST_STRIP_PATH)
		atlas.region = Rect2(0, 0, CHEST_FRAME_SIZE, CHEST_FRAME_SIZE)
		# Scaling an atlas region with nearest filtering samples the neighbouring
		# frame at the seam unless clipping is on.
		atlas.filter_clip = true
		_chest_sprite.texture = atlas
	_chest_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chest_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_chest_sprite.set_anchors_preset(Control.PRESET_CENTER)
	_chest_sprite.custom_minimum_size = Vector2(CHEST_SPRITE_SIZE, CHEST_SPRITE_SIZE)
	_chest_sprite.size = Vector2(CHEST_SPRITE_SIZE, CHEST_SPRITE_SIZE)
	_chest_sprite.pivot_offset = Vector2(CHEST_SPRITE_SIZE, CHEST_SPRITE_SIZE) * 0.5
	_chest_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_chest_sprite()
	_chest_reveal_root.add_child(_chest_sprite)

	_chest_cards = VBoxContainer.new()
	_chest_cards.set_anchors_preset(Control.PRESET_CENTER)
	_chest_cards.custom_minimum_size = Vector2(440, 0)
	_chest_cards.position = Vector2(-220, -10)
	_chest_cards.add_theme_constant_override("separation", 8)
	_chest_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_reveal_root.add_child(_chest_cards)

	_chest_banner = Label.new()
	_chest_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chest_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_chest_banner.offset_left = -400.0
	_chest_banner.offset_right = 400.0
	_chest_banner.offset_top = 54.0
	_chest_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(_chest_banner, 44)
	_chest_banner.add_theme_constant_override("outline_size", 8)
	_chest_banner.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.03))
	_chest_banner.modulate.a = 0.0
	_chest_reveal_root.add_child(_chest_banner)

	_chest_flash = ColorRect.new()
	_chest_flash.color = Color(1, 1, 1, 0)
	_chest_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chest_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_reveal_root.add_child(_chest_flash)

func _rt(obj: Object, prop: String, to, dur: float, trans := Tween.TRANS_QUAD, ease_t := Tween.EASE_OUT) -> Tween:
	"""Tween that keeps running while the chest modal has the game frozen."""
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(obj, prop, to, dur).set_trans(trans).set_ease(ease_t)
	return tw

func play_chest_reveal(items: Array, best_rarity: String) -> void:
	"""Full jackpot sequence. Awaited by treasure_chest.gd."""
	_build_chest_reveal()
	if _chest_reveal_root == null:
		return
	var tree := get_tree()
	if tree == null:
		return

	# Reset state
	_chest_reveal_root.visible = true
	_chest_reveal_root.modulate.a = 1.0
	for c in _chest_cards.get_children():
		c.queue_free()
	_chest_banner.modulate.a = 0.0
	_chest_flash.color = Color(1, 1, 1, 0)
	_chest_rays.modulate = Color(1.0, 0.9, 0.5, 0.0)
	_chest_rays.rotation = 0.0
	_chest_sprite.scale = Vector2.ZERO
	_chest_sprite.modulate = Color.WHITE
	# Both re-placed every reveal, not just at build time: the panel is built
	# once and outlives any number of resolution changes, and a burst that has
	# drifted off its chest is the bug this pair exists to prevent.
	_place_chest_sprite()
	_place_chest_rays()
	_set_chest_frame(CHEST_FRAME_SHUT)

	# 1. Chest slams in from nothing and overshoots — physical arrival.
	_rt(_chest_sprite, "scale", Vector2(1.15, 1.15), 0.28, Tween.TRANS_BACK)
	_rt(_chest_rays, "modulate", Color(1.0, 0.9, 0.5, 0.35), 0.5)
	await tree.create_timer(0.3, true, false, true).timeout
	if not is_inside_tree():
		return

	# 2. Anticipation: rattle harder and brighter as the riser builds. The lid
	#    strains, then cracks, so the chest itself escalates alongside the
	#    sound instead of being a static prop that shakes.
	var base_pos := _chest_sprite.position
	for i in range(6):
		# The rattle steps shorten as they go, so these indices are not evenly
		# spaced in time: strain lands ~0.35s before the crack, and the crack
		# holds ~0.2s before the burst. Pushed one step later, the cracked lid
		# would flash for a single frame.
		if i == 2:
			_set_chest_frame(CHEST_FRAME_STRAIN)
		elif i == 4:
			_set_chest_frame(CHEST_FRAME_CRACK)
		var amp := 4.0 + float(i) * 3.0
		var step := 0.09 - float(i) * 0.008
		var t1 := create_tween()
		t1.set_ignore_time_scale(true)
		t1.tween_property(_chest_sprite, "position", base_pos + Vector2(amp, 0), step * 0.5)
		t1.tween_property(_chest_sprite, "position", base_pos - Vector2(amp, 0), step)
		t1.tween_property(_chest_sprite, "position", base_pos, step * 0.5)
		var glow := 1.0 + float(i) * 0.32
		_rt(_chest_sprite, "modulate", Color(glow, glow * 0.92, glow * 0.7), step * 2.0)
		_rt(_chest_rays, "modulate", Color(1.0, 0.9, 0.5, 0.35 + float(i) * 0.09), step * 2.0)
		_chest_rays.rotation += 0.12
		await tree.create_timer(step * 2.0, true, false, true).timeout
		if not is_inside_tree():
			return

	# 3. BURST. White flash, chest blows out, rays flare wide.
	_set_chest_frame(CHEST_FRAME_OPEN)
	_chest_flash.color = Color(1, 1, 1, 0.85)
	_rt(_chest_flash, "color", Color(1, 1, 1, 0.0), 0.45)
	_rt(_chest_sprite, "scale", Vector2(2.6, 2.6), 0.35, Tween.TRANS_QUAD)
	_rt(_chest_sprite, "modulate", Color(3.0, 2.6, 1.6, 0.0), 0.35)
	_rt(_chest_rays, "modulate", Color(1.0, 0.95, 0.7, 0.75), 0.25)
	await tree.create_timer(0.28, true, false, true).timeout
	if not is_inside_tree():
		return

	# 4. Prizes slam in one at a time, each louder than the last.
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var card := _make_chest_card(item)
		_chest_cards.add_child(card)
		card.modulate.a = 0.0
		card.pivot_offset = Vector2(220, 34)
		card.scale = Vector2(1.7, 1.7)
		card.position.x = 260.0
		var tw := create_tween()
		tw.set_ignore_time_scale(true)
		tw.set_parallel(true)
		tw.tween_property(card, "modulate:a", 1.0, 0.16)
		tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Rarer prizes get a brighter pop and a longer beat to land.
		var rank := int(CHEST_RARITY_RANK.get(str(item.get("rarity", "common")), 0))
		_chest_rays.rotation += 0.18 + rank * 0.1
		await tree.create_timer(0.3 + rank * 0.12, true, false, true).timeout
		if not is_inside_tree():
			return

	# 5. Jackpot banner for a genuinely rare haul.
	if int(CHEST_RARITY_RANK.get(best_rarity, 0)) >= 2:
		var jc: Color = CHEST_RARITY_COLORS.get(best_rarity, Color(1.0, 0.9, 0.4))
		_chest_banner.text = "DIAMOND!" if best_rarity == "diamond" else "JACKPOT!"
		_chest_banner.add_theme_color_override("font_color", jc)
		_chest_banner.scale = Vector2(2.2, 2.2)
		_chest_banner.pivot_offset = Vector2(400, 26)
		var bt := create_tween()
		bt.set_ignore_time_scale(true)
		bt.set_parallel(true)
		bt.tween_property(_chest_banner, "modulate:a", 1.0, 0.18)
		bt.tween_property(_chest_banner, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_chest_flash.color = Color(jc.r, jc.g, jc.b, 0.45)
		_rt(_chest_flash, "color", Color(jc.r, jc.g, jc.b, 0.0), 0.6)
		await tree.create_timer(0.75, true, false, true).timeout
		if not is_inside_tree():
			return

	# 6. Hold so the player can actually read the prizes, then clear.
	await tree.create_timer(0.55, true, false, true).timeout
	if not is_inside_tree():
		return
	_rt(_chest_reveal_root, "modulate:a", 0.0, 0.3)
	await tree.create_timer(0.32, true, false, true).timeout
	if not is_inside_tree():
		return
	_chest_reveal_root.visible = false
	for c in _chest_cards.get_children():
		c.queue_free()

func _make_chest_card(item: Dictionary) -> Control:
	var rarity := str(item.get("rarity", "common"))
	var color: Color = CHEST_RARITY_COLORS.get(rarity, Color.WHITE)
	var card := Control.new()
	card.custom_minimum_size = Vector2(440, 68)

	var frame_path := str(CHEST_CARD_FRAMES.get(rarity, CHEST_CARD_FRAMES["common"]))
	if ResourceLoader.exists(frame_path):
		var frame := TextureRect.new()
		frame.texture = load(frame_path)
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
	else:
		# No frame art for this rarity — fall back to a tinted panel so the
		# card still reads instead of rendering as bare text.
		var bg := ColorRect.new()
		bg.color = Color(color.r * 0.18, color.g * 0.18, color.b * 0.18, 0.9)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bg)

	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", "UPGRADE")).to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_lbl.offset_top = -8.0
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(name_lbl, 18)
	name_lbl.add_theme_color_override("font_color", color)
	name_lbl.add_theme_constant_override("outline_size", 5)
	name_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
	card.add_child(name_lbl)

	var desc := str(item.get("desc", ""))
	if desc != "":
		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		desc_lbl.offset_top = -26.0
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_font(desc_lbl, 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		card.add_child(desc_lbl)
	return card

func show_tech(options: Array, essence_amount: int = 0, reroll_cost: int = 0, meta: Dictionary = {}) -> void:
	_modal_backdrop_for_tech = true
	_refresh_modal_backdrop()
	_tech_option_count = options.size()
	_reset_tech_hit_rows()
	tech_panel.visible = true
	tech_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	tech_panel.scale = Vector2.ONE
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
	_apply_tech_icon_frames(options)
	if tech_title_label != null:
		tech_title_label.text = "Choose an Upgrade"
	if tech_hint_label != null:
		var reroll_hint = "R  Reroll"
		if reroll_cost > 0:
			if essence_amount >= reroll_cost:
				reroll_hint = "R  Reroll (%d essence)" % reroll_cost
			else:
				reroll_hint = "R  Reroll (need %d essence)" % reroll_cost
		tech_hint_label.text = "Click a card, 1 / 2 / 3, or stick + A        %s" % reroll_hint
	# Start with no gamepad highlight; main.gd sets it when a controller is active.
	set_tech_highlight(-1)

# Controller support: highlight one of the three tech options (0..2) so a gamepad
# user can see which choice the cursor is on. -1 clears all highlights. The rarity
# font color stays intact; we cue selection with brightness + scale on the label and
# its icon. Mouse/keyboard users simply never move the cursor, so nothing changes.
func set_tech_highlight(idx: int) -> void:
	var labels := [tech_option1, tech_option2, tech_option3]
	var icons := [tech_icon1, tech_icon2, tech_icon3]
	# idx == -1 means "no gamepad cursor" (the default for mouse/keyboard players):
	# keep ALL options at full brightness so every card stays easy to read. Only when
	# a controller is actively highlighting one option do we dim the other two.
	var no_highlight := (idx < 0)
	for i in range(labels.size()):
		var lbl: Label = labels[i]
		if lbl == null or not is_instance_valid(lbl):
			continue
		var selected := (i == idx)
		if no_highlight or selected:
			lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			lbl.modulate = Color(0.72, 0.72, 0.78, 1.0)
		var ic: TextureRect = icons[i]
		if ic != null and is_instance_valid(ic):
			if no_highlight:
				ic.modulate = Color(1.15, 1.15, 1.15, 1.0)
			elif selected:
				ic.modulate = Color(1.25, 1.25, 1.25, 1.0)
			else:
				ic.modulate = Color(0.75, 0.75, 0.8, 1.0)

func _reset_tech_hit_rows() -> void:
	for i in range(tech_hit_rows.size()):
		var row = tech_hit_rows[i]
		if row == null or not is_instance_valid(row):
			continue
		row.color = TECH_ROW_HOVER_OFF
		# A row with no card behind it must not swallow clicks either.
		row.mouse_filter = Control.MOUSE_FILTER_STOP if i < _tech_option_count else Control.MOUSE_FILTER_IGNORE

func hide_tech() -> void:
	tech_panel.visible = false
	_modal_backdrop_for_tech = false
	_tech_option_count = 0
	_reset_tech_hit_rows()
	set_tech_highlight(-1)
	for frame in tech_icon_frames:
		if frame != null and is_instance_valid(frame):
			frame.visible = false
	_refresh_modal_backdrop()
	if tech_title_label != null:
		tech_title_label.text = "Choose an Upgrade"
	if tech_hint_label != null:
		tech_hint_label.text = "Click a card, or 1 / 2 / 3"

func _build_tech_ledger() -> void:
	if _tech_ledger_panel != null and is_instance_valid(_tech_ledger_panel):
		return
	var hud = $HUD
	_tech_ledger_panel = TextureRect.new()
	_tech_ledger_panel.name = "TechLedger"
	_tech_ledger_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(TECH_LEDGER_TEX):
		_tech_ledger_panel.texture = load(TECH_LEDGER_TEX)
	_tech_ledger_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tech_ledger_panel.anchor_left = 1.0
	_tech_ledger_panel.anchor_right = 1.0
	_tech_ledger_panel.anchor_top = 0.0
	_tech_ledger_panel.anchor_bottom = 0.0
	_tech_ledger_panel.offset_left = -372.0
	_tech_ledger_panel.offset_right = -12.0
	_tech_ledger_panel.offset_top = 160.0
	_tech_ledger_panel.offset_bottom = 216.0
	_tech_ledger_panel.visible = _tech_ledger_visible
	hud.add_child(_tech_ledger_panel)

	_tech_ledger_label = Label.new()
	_tech_ledger_label.text = "Build Path"
	_tech_ledger_label.position = Vector2(10, 6)
	_tech_ledger_label.size = Vector2(100, 16)
	_tech_ledger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tech_ledger_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _ui_font != null:
		_tech_ledger_label.add_theme_font_override("font", _ui_font)
	_tech_ledger_label.add_theme_font_size_override("font_size", 10)
	_tech_ledger_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.65))
	_tech_ledger_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_tech_ledger_label.add_theme_constant_override("outline_size", 1)
	_tech_ledger_panel.add_child(_tech_ledger_label)

	_tech_ledger_container = HBoxContainer.new()
	_tech_ledger_container.position = Vector2(100, 12)
	_tech_ledger_container.size = Vector2(250, 40)
	_tech_ledger_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_tech_ledger_container.add_theme_constant_override("separation", 6)
	_tech_ledger_panel.add_child(_tech_ledger_container)

func update_tech_ledger(levels: Dictionary, defs: Dictionary) -> void:
	if _tech_ledger_container == null or not is_instance_valid(_tech_ledger_container):
		_build_tech_ledger()
	if _tech_ledger_container == null:
		return
	for child in _tech_ledger_container.get_children():
		child.queue_free()
	var entries: Array = []
	for id in levels.keys():
		var lvl = int(levels.get(id, 0))
		if lvl <= 0:
			continue
		entries.append({"id": id, "lvl": lvl})
	entries.sort_custom(func(a, b):
		return int(a["lvl"]) > int(b["lvl"])
	)
	var max_slots = 8
	var shown = 0
	for entry in entries:
		if shown >= max_slots:
			break
		var id = str(entry["id"])
		var lvl = int(entry["lvl"])
		var def: Dictionary = defs.get(id, {})
		var icon_path = str(def.get("icon", ""))
		var rarity = str(def.get("rarity", "common"))
		var chip = _build_tech_chip(icon_path, lvl, rarity)
		if chip != null:
			_tech_ledger_container.add_child(chip)
			shown += 1
	if entries.size() > max_slots:
		var more = Label.new()
		more.text = "+%d" % (entries.size() - max_slots)
		more.add_theme_font_size_override("font_size", 10)
		more.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		more.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		more.add_theme_constant_override("outline_size", 1)
		_tech_ledger_container.add_child(more)
	set_tech_ledger_visible(_tech_ledger_visible)

func clear_tech_ledger() -> void:
	if _tech_ledger_container == null:
		return
	for child in _tech_ledger_container.get_children():
		child.queue_free()

func set_tech_ledger_visible(visible: bool) -> void:
	_tech_ledger_visible = visible
	if _tech_ledger_panel != null and is_instance_valid(_tech_ledger_panel):
		_tech_ledger_panel.visible = visible

func set_wave_preview_enabled(enabled: bool) -> void:
	_wave_preview_enabled = enabled
	if not enabled and _wave_announce_label != null and is_instance_valid(_wave_announce_label):
		_wave_announce_label.visible = false

func _build_tech_chip(icon_path: String, level: int, rarity: String) -> Control:
	var chip = Control.new()
	chip.custom_minimum_size = Vector2(28, 28)
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.position = Vector2(2, 2)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	var color = rarity_colors.get(rarity, Color.WHITE)
	icon.modulate = color
	chip.add_child(icon)
	var badge = Label.new()
	badge.text = "x%d" % level
	badge.position = Vector2(14, 14)
	badge.size = Vector2(14, 12)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	if _ui_font != null:
		badge.add_theme_font_override("font", _ui_font)
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	badge.add_theme_constant_override("outline_size", 1)
	chip.add_child(badge)
	return chip

func _format_option(number: int, options: Array, index: int) -> String:
	if index >= options.size():
		return "%d)  --" % number
	var option: Dictionary = options[index]
	var name = str(option.get("name", ""))
	var level = int(option.get("level", 0))
	var max_level = int(option.get("max_level", 1))
	# Rank readout: show current/max only for multi-rank picks so single-rank
	# upgrades stay clean. "MAX" when the next pick would cap it out.
	var rank_tag = ""
	if max_level > 1:
		if level + 1 >= max_level:
			rank_tag = "  (MAX)"
		else:
			rank_tag = "  Lv %d/%d" % [level + 1, max_level]
	return "%d)  %s%s\n%s" % [number, name, rank_tag, option.get("desc", "")]

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
	# Heavy black outline + drop shadow so the (now bright) rarity text reads clearly
	# over the busy battlefield behind the modal, regardless of what's underneath.
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	if icon != null:
		icon.modulate = Color(1.1, 1.1, 1.1, 1.0)

func _apply_tech_frames(options: Array) -> void:
	for i in range(tech_frames.size()):
		var frame = tech_frames[i]
		if frame == null:
			continue
		if i >= options.size():
			if frame is TextureRect:
				frame.texture = null
			continue
		var rarity = str(options[i].get("rarity", "common"))
		if frame is TextureRect:
			var tex_path = str(TECH_CARD_TEXTURES.get(rarity, TECH_CARD_TEXTURES["common"]))
			if ResourceLoader.exists(tex_path):
				frame.texture = load(tex_path)
			else:
				frame.texture = null

func _apply_tech_icon_frames(options: Array) -> void:
	var rarity_alias = {
		"legendary": "legendary",
		"mythic": "legendary",
		"diamond": "legendary"
	}
	for i in range(tech_icon_frames.size()):
		var frame = tech_icon_frames[i]
		if frame == null:
			continue
		if i >= options.size():
			frame.texture = null
			frame.visible = false
			continue
		var rarity = str(options[i].get("rarity", "common"))
		if rarity_alias.has(rarity):
			rarity = str(rarity_alias[rarity])
		var tex_path = str(RARITY_FRAME_TEXTURES.get(rarity, RARITY_FRAME_TEXTURES["common"]))
		if tex_path != "" and ResourceLoader.exists(tex_path):
			frame.texture = load(tex_path)
			frame.visible = true
		else:
			frame.texture = null
			frame.visible = false

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
	_apply_font(tech_option1, 13)
	_apply_font(tech_option2, 13)
	_apply_font(tech_option3, 13)
	_apply_font(start_title, 12)
	_apply_font(start_body, 10)
	_apply_font(start_option1, 10)
	_apply_font(start_option2, 10)
	_apply_font(start_hint, 10)
	var tech_title: Label = $HUD/TechPanel/Title
	var tech_hint: Label = $HUD/TechPanel/Hint
	_apply_font(tech_title, 14)
	_apply_font(tech_hint, 9)

func _style_label(label: Label, pos: Vector2, size: Vector2, wrap: bool = true, clip: bool = true) -> void:
	if label == null:
		return
	label.position = pos
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.clip_text = clip
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _style_tech_panel() -> void:
	if tech_panel == null:
		return
	var panel_w = TECH_PANEL_SIZE.x
	var panel_h = TECH_PANEL_SIZE.y
	tech_panel.anchor_left = 0.5
	tech_panel.anchor_top = 0.5
	tech_panel.anchor_right = 0.5
	tech_panel.anchor_bottom = 0.5
	tech_panel.offset_left = -panel_w / 2.0
	tech_panel.offset_top = -panel_h / 2.0
	tech_panel.offset_right = panel_w / 2.0
	tech_panel.offset_bottom = panel_h / 2.0
	tech_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(TECH_PANEL_TEX):
		tech_panel.texture = load(TECH_PANEL_TEX)

	var tech_title: Label = $HUD/TechPanel/Title
	var tech_hint: Label = $HUD/TechPanel/Hint

	_style_label(tech_title, Vector2(20, 12), Vector2(440, 20), false)
	# Option labels: wide + tall enough for a two-line "name / description"
	# layout, and clipping disabled so wrapped descriptions are never cut off.
	_style_label(tech_option1, Vector2(100, 60), Vector2(360, 68), true, false)
	_style_label(tech_option2, Vector2(100, 148), Vector2(360, 68), true, false)
	_style_label(tech_option3, Vector2(100, 236), Vector2(360, 68), true, false)
	_style_label(tech_hint, Vector2(20, 294), Vector2(440, 24), false)
	for lbl in [tech_title, tech_hint, tech_option1, tech_option2, tech_option3]:
		if lbl == null:
			continue
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))

	for icon in [tech_icon1, tech_icon2, tech_icon3]:
		if icon == null:
			continue
		icon.size = TECH_ICON_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.z_index = 3
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(1.2, 1.2, 1.2, 1.0)

	if tech_icon1 != null:
		tech_icon1.position = Vector2(44, 66)
	if tech_icon2 != null:
		tech_icon2.position = Vector2(44, 154)
	if tech_icon3 != null:
		tech_icon3.position = Vector2(44, 242)
	_position_tech_icon_frames()

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
