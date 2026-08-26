extends Control

# Main menu / meta-progression hub. Boot scene. Lets the player pick a hero and
# level, spend Cores in the Unlocks shop, open settings, and start a run.
#
# Visual style: gothic-arcade. Retro pixel font (Press Start 2P), ornate metal
# panel frames, themed button textures, animated atmospheric background.

const GAME_SCENE := "res://scenes/main.tscn"
# By path, not the class_name global -- see run_manifest.gd for why.
const Run := preload("res://scripts/run_manifest.gd")
# Play drops into the descent cinematic, which hands off to GAME_SCENE itself.
const DESCENT_SCENE := "res://scenes/descent.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const SETTINGS_SCENE := preload("res://scenes/settings_menu.tscn")

# ---- Asset paths ----
const FONT_PIXEL := "res://assets/ui/pixel_font.ttf"
const PANEL_FRAME := "res://assets/ui/ui_panel_frame_large_512x256_v001.png"
const DIALOG_FRAME := "res://assets/ui/ui_dialog_frame_384x224_v001.png"
const BTN_NORMAL := "res://assets/ui/ui_button_primary_normal_128x32_v001.png"
const BTN_HOVER := "res://assets/ui/ui_button_primary_hover_128x32_v001.png"
const BTN_PRESSED := "res://assets/ui/ui_button_primary_pressed_128x32_v001.png"
const ICON_SKULL := "res://assets/ui/ui_icon_skull_32_v001.png"
const ICON_CRYSTAL := "res://assets/ui/ui_icon_crystal_32_v001.png"

# ---- Palette (gothic arcade) ----
const COLOR_BG_TOP := Color(0.06, 0.04, 0.10, 1.0)
const COLOR_BG_BOT := Color(0.02, 0.02, 0.04, 1.0)
const COLOR_TITLE := Color(1.0, 0.85, 0.35)      # molten gold
const COLOR_TITLE_SHADOW := Color(0.5, 0.05, 0.1) # blood red outline glow
const COLOR_ACCENT := Color(0.45, 0.95, 1.0)      # arcane cyan
const COLOR_CORE := Color(0.85, 0.5, 1.0)         # core purple
const COLOR_TEXT := Color(0.88, 0.86, 0.92)
const COLOR_DIM := Color(0.62, 0.60, 0.70)
const COLOR_LOCKED := Color(0.50, 0.48, 0.55)
const COLOR_GOOD := Color(0.55, 1.0, 0.55)

var _font: FontFile = null
var _cores_label: Label = null
var _save_notice: Label = null
var _content: VBoxContainer = null
var _settings_menu: CanvasLayer = null
var _selected_hero: String = "warlock"
var _selected_level: String = "graveyard"

var _bg_gradient: TextureRect = null
var _vignette: ColorRect = null
var _title_label: Label = null
var _title_glow: Label = null
var _flicker_t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_right = 1.0
	anchor_bottom = 1.0
	_font = _load_font()
	if _meta() != null:
		_selected_hero = _pick_default_hero()
		_selected_level = "graveyard"
	_build_background()
	_build_header()
	_build_content_holder()
	_show_root_menu()

func _process(delta: float) -> void:
	# Subtle atmospheric flicker on the title glow + vignette breathing.
	_flicker_t += delta
	if _title_glow != null and is_instance_valid(_title_glow):
		var pulse := 0.55 + 0.25 * sin(_flicker_t * 2.4) + 0.06 * sin(_flicker_t * 13.0)
		_title_glow.modulate.a = clamp(pulse, 0.0, 1.0)
	if _title_label != null and is_instance_valid(_title_label):
		var bob := 1.0 + 0.015 * sin(_flicker_t * 1.6)
		_title_label.scale = Vector2(bob, bob)

# Detect the active input device. When a controller is used and nothing is
# focused yet (e.g. the player launched and immediately grabbed the pad), grab the
# first button so d-pad / stick navigation works without touching the mouse first.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var owner := get_viewport().gui_get_focus_owner()
		if owner == null:
			_focus_first_button()

func _meta() -> Node:
	return get_node_or_null("/root/MetaProgression")

func _pick_default_hero() -> String:
	var meta := _meta()
	if meta == null:
		return "warlock"
	if meta.is_hero_unlocked("warlock"):
		return "warlock"
	for h in meta.HERO_DEFS:
		var id := str(h.get("id", ""))
		if meta.is_hero_unlocked(id):
			return id
	return "hunter"

# ---- Asset loading ----

func _load_font() -> FontFile:
	if not ResourceLoader.exists(FONT_PIXEL):
		return null
	var f = load(FONT_PIXEL)
	if f is FontFile:
		return f
	return null

func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var t = load(path)
	if t is Texture2D:
		return t
	return null

func _apply_font(ctrl: Control, size: int, color: Color = COLOR_TEXT) -> void:
	if _font != null:
		ctrl.add_theme_font_override("font", _font)
	ctrl.add_theme_font_size_override("font_size", size)
	ctrl.add_theme_color_override("font_color", color)

# ---- Background ----

func _build_background() -> void:
	# Vertical gradient sky (dark gothic).
	var grad := Gradient.new()
	grad.set_color(0, COLOR_BG_TOP)
	grad.set_color(1, COLOR_BG_BOT)
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	grad_tex.width = 64
	grad_tex.height = 64

	_bg_gradient = TextureRect.new()
	_bg_gradient.texture = grad_tex
	_bg_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_gradient.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_gradient.anchor_right = 1.0
	_bg_gradient.anchor_bottom = 1.0
	_bg_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_gradient)

	# Radial vignette for arcade focus.
	var vrad := Gradient.new()
	vrad.set_color(0, Color(0, 0, 0, 0.0))
	vrad.set_color(1, Color(0, 0, 0, 0.7))
	var vtex := GradientTexture2D.new()
	vtex.gradient = vrad
	vtex.fill = GradientTexture2D.FILL_RADIAL
	vtex.fill_from = Vector2(0.5, 0.5)
	vtex.fill_to = Vector2(1.0, 1.0)
	vtex.width = 128
	vtex.height = 128
	var vrect := TextureRect.new()
	vrect.texture = vtex
	vrect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vrect.stretch_mode = TextureRect.STRETCH_SCALE
	vrect.anchor_right = 1.0
	vrect.anchor_bottom = 1.0
	vrect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vrect)

	# Decorative skull watermark behind the panel.
	var skull := _tex(ICON_SKULL)
	if skull != null:
		var deco := TextureRect.new()
		deco.texture = skull
		deco.modulate = Color(1, 1, 1, 0.05)
		deco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		deco.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		deco.anchor_left = 0.5
		deco.anchor_top = 0.5
		deco.anchor_right = 0.5
		deco.anchor_bottom = 0.5
		deco.offset_left = -260.0
		deco.offset_top = -260.0
		deco.offset_right = 260.0
		deco.offset_bottom = 260.0
		deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(deco)

# ---- Header ----

func _build_header() -> void:
	# AVARICE is the headline, AGE OF AETHER the subtitle beneath it. Rendered
	# glow-behind-crisp like the main title so it reads as one lockup rather
	# than a small credit line floating above the logo.
	var brand_glow := Label.new()
	brand_glow.text = "AVARICE"
	_apply_font(brand_glow, 62, COLOR_TITLE_SHADOW)
	brand_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand_glow.anchor_left = 0.5
	brand_glow.anchor_right = 0.5
	brand_glow.offset_left = -480.0
	brand_glow.offset_right = 480.0
	brand_glow.offset_top = 22.0
	brand_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand_glow.add_theme_constant_override("outline_size", 18)
	brand_glow.add_theme_color_override("font_outline_color", COLOR_TITLE_SHADOW)
	add_child(brand_glow)

	var brand := Label.new()
	brand.text = "AVARICE"
	_apply_font(brand, 62, COLOR_TITLE)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.anchor_left = 0.5
	brand.anchor_right = 0.5
	brand.offset_left = -480.0
	brand.offset_right = 480.0
	brand.offset_top = 20.0
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_theme_constant_override("outline_size", 8)
	brand.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.04, 1.0))
	add_child(brand)

	# Title glow (rendered behind, animated) + crisp title on top.
	_title_glow = Label.new()
	_title_glow.text = "AGE OF AETHER"
	_apply_font(_title_glow, 30, COLOR_TITLE_SHADOW)
	_title_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_glow.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_glow.anchor_left = 0.5
	_title_glow.anchor_right = 0.5
	_title_glow.offset_left = -460.0
	_title_glow.offset_right = 460.0
	_title_glow.offset_top = 104.0
	_title_glow.pivot_offset = Vector2(460, 60)
	_title_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_glow.add_theme_constant_override("outline_size", 14)
	_title_glow.add_theme_color_override("font_outline_color", COLOR_TITLE_SHADOW)
	add_child(_title_glow)

	_title_label = Label.new()
	_title_label.text = "AGE OF AETHER"
	_apply_font(_title_label, 30, COLOR_TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_label.anchor_left = 0.5
	_title_label.anchor_right = 0.5
	_title_label.offset_left = -460.0
	_title_label.offset_right = 460.0
	_title_label.offset_top = 102.0
	_title_label.pivot_offset = Vector2(460, 60)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_constant_override("outline_size", 6)
	_title_label.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.04, 1.0))
	add_child(_title_label)

	# Cores readout pill (top-right) with crystal icon.
	var pill := PanelContainer.new()
	pill.anchor_left = 1.0
	pill.anchor_right = 1.0
	pill.offset_left = -300.0
	pill.offset_right = -24.0
	pill.offset_top = 24.0
	pill.offset_bottom = 64.0
	pill.add_theme_stylebox_override("panel", _make_pill_stylebox())
	add_child(pill)

	var pill_row := HBoxContainer.new()
	pill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill_row.add_theme_constant_override("separation", 8)
	pill.add_child(pill_row)

	var crystal := _tex(ICON_CRYSTAL)
	if crystal != null:
		var icon := TextureRect.new()
		icon.texture = crystal
		icon.custom_minimum_size = Vector2(24, 24)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pill_row.add_child(icon)

	_cores_label = Label.new()
	_apply_font(_cores_label, 16, COLOR_CORE)
	_cores_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill_row.add_child(_cores_label)
	_refresh_cores()
	_watch_save_health()

func _watch_save_health() -> void:
	"""Surface save trouble instead of letting it pass as a fresh start.

	A corrupt save used to be indistinguishable from a first launch: cores and
	unlocks simply vanished with no message. The player deserves to know which
	of the two just happened."""
	var meta := _meta()
	if meta == null:
		return
	if meta.has_signal("save_recovered") and not meta.save_recovered.is_connected(_on_save_recovered):
		meta.save_recovered.connect(_on_save_recovered)
	if meta.has_signal("save_failed") and not meta.save_failed.is_connected(_on_save_failed):
		meta.save_failed.connect(_on_save_failed)
	# The autoload loads in _ready, before this menu exists, so a recovery that
	# already happened has to be read rather than waited for.
	if meta.has_method("get_load_warning"):
		var warning := str(meta.get_load_warning())
		if warning != "":
			_show_save_notice(warning)

func _on_save_recovered(recovered: bool) -> void:
	if recovered:
		_show_save_notice("Save was damaged and restored from backup.")
	else:
		_show_save_notice("Save could not be read. Progress has been reset.")

func _on_save_failed() -> void:
	_show_save_notice("Could not write save. Progress will not be kept.")

func _show_save_notice(text: String) -> void:
	if _save_notice != null and is_instance_valid(_save_notice):
		_save_notice.text = text
		_save_notice.visible = true
		return
	_save_notice = Label.new()
	_save_notice.name = "SaveNotice"
	_save_notice.text = text
	_save_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD
	_apply_font(_save_notice, 12, Color(1.0, 0.55, 0.35))
	_save_notice.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_save_notice.offset_left = 24.0
	_save_notice.offset_right = -24.0
	_save_notice.offset_top = -34.0
	_save_notice.offset_bottom = -10.0
	add_child(_save_notice)

func _make_pill_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.06, 0.16, 0.85)
	sb.border_color = COLOR_CORE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

# ---- Content holder (ornate framed panel) ----

func _build_content_holder() -> void:
	# The frame sits BELOW the title (which occupies roughly the top ~170px) and
	# fills down to a bottom margin so it can never run off-screen or overlap the
	# logo. We TOP-align (not vertically center) so the panel grows downward from
	# under the title rather than creeping up over it. Content taller than the
	# frame scrolls instead of clipping.
	var center := CenterContainer.new()
	center.anchor_left = 0.0
	center.anchor_top = 0.0
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 0.0
	center.offset_top = 196.0
	center.offset_right = 0.0
	center.offset_bottom = -20.0
	# Center horizontally only; keep the panel pinned to the top of this region.
	center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(center)

	var panel := PanelContainer.new()
	# Fixed width, flexible height (clamped by the CenterContainer's available
	# space) so the ornate frame stays compact but never forces overflow.
	panel.custom_minimum_size = Vector2(600, 0)
	panel.add_theme_stylebox_override("panel", _make_frame_stylebox())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 44)
	panel.add_child(margin)

	# Scroll wrapper: longer panels (heroes/levels/unlocks) scroll vertically
	# rather than spilling past the frame; the root menu fits without scrolling.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A ScrollContainer reports a near-zero minimum height, which lets the parent
	# PanelContainer collapse to just its ornate frame border (no visible content).
	# Give it a sensible minimum so the framed panel always has room for the menu;
	# taller panels still scroll. Height is kept small enough that the whole framed
	# panel (frame border + margins ~130px) fits the ~504px region under the title.
	scroll.custom_minimum_size = Vector2(504, 372)
	margin.add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

func _make_frame_stylebox() -> StyleBox:
	# Prefer the ornate 9-slice metal frame; fall back to a flat gothic box.
	var tex := _tex(PANEL_FRAME)
	if tex != null:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		# 512x256 source — inset margins so the ornate border isn't stretched.
		sb.texture_margin_left = 48
		sb.texture_margin_right = 48
		sb.texture_margin_top = 56
		sb.texture_margin_bottom = 48
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		return sb
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.10, 0.08, 0.14, 0.96)
	flat.border_color = COLOR_ACCENT
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(8)
	return flat

# ---- Cores ----

func _refresh_cores() -> void:
	if _cores_label == null:
		return
	var cores := 0
	if _meta() != null:
		cores = _meta().get_cores()
	_cores_label.text = "%d CORES" % cores

func _clear_content() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()

# ---- Themed buttons ----

func _make_button(text: String, handler: Callable, enabled: bool = true) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 48)
	_apply_font(btn, 16, COLOR_TEXT)
	btn.disabled = not enabled
	_style_button(btn, enabled)
	if enabled:
		btn.mouse_entered.connect(_on_button_hover)
		# Controller players navigate by focus (d-pad / stick); play the same hover
		# cue on focus so menu movement is audible without a mouse.
		btn.focus_entered.connect(_on_button_hover)
		btn.pressed.connect(func():
			_play_click()
			handler.call())
	return btn

func _style_button(btn: Button, enabled: bool) -> void:
	var n := _tex(BTN_NORMAL)
	var h := _tex(BTN_HOVER)
	var p := _tex(BTN_PRESSED)
	if n != null:
		btn.add_theme_stylebox_override("normal", _btn_box(n))
		btn.add_theme_stylebox_override("hover", _btn_box(h if h != null else n))
		btn.add_theme_stylebox_override("pressed", _btn_box(p if p != null else n))
		btn.add_theme_stylebox_override("focus", _btn_box(h if h != null else n))
		btn.add_theme_stylebox_override("disabled", _btn_box(n))
		btn.add_theme_color_override("font_hover_color", COLOR_TITLE)
		btn.add_theme_color_override("font_pressed_color", COLOR_ACCENT)
		btn.add_theme_color_override("font_focus_color", COLOR_TITLE)
		btn.add_theme_color_override("font_disabled_color", COLOR_LOCKED)
	else:
		# Flat fallback styling.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.12, 0.20, 0.95)
		sb.border_color = COLOR_ACCENT
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
	if not enabled:
		btn.modulate = Color(1, 1, 1, 0.5)

func _btn_box(tex: Texture2D) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	# 128x32 source with metal end-caps — keep caps crisp via 9-slice.
	sb.texture_margin_left = 16
	sb.texture_margin_right = 16
	sb.texture_margin_top = 6
	sb.texture_margin_bottom = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _make_heading(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	_apply_font(lbl, 22, COLOR_ACCENT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.12, 1.0))
	return lbl

func _on_button_hover() -> void:
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("play_ui_sound"):
			am.play_ui_sound("hover")

func _play_click() -> void:
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("play_ui_sound"):
			am.play_ui_sound("button_click")

# ---- Root menu ----

func _show_root_menu() -> void:
	_clear_content()
	_refresh_cores()

	# No hand to show: the Rift deals when PLAY is pressed (RunManifest.deal),
	# not while you sit on the menu. The menu promises the deal; the descent
	# narrates what was dealt.
	var info := Label.new()
	info.text = "THE RIFT DEALS YOUR HAND ON ENTRY   |   %s" % _modifier_display_name()
	_apply_font(info, 12, COLOR_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(info)

	_content.add_child(_spacer(6))
	_content.add_child(_make_button("PLAY", _on_play))
	# FFA (PROTOTYPE) removed from the menu: the online free-for-all is ~2,000
	# lines of frozen prototype (NORTHSTAR.md, "Deliberately deferred") and the
	# button was a door into a lobby for a mode that does not exist. _on_ffa and
	# the net code stay for if it ever does.
	#
	# HEROES and LEVELS removed with the Rift pivot: you are dealt a hand, not
	# given a menu (NORTHSTAR.md). The roll above is the whole selection. The
	# panels and their unlock plumbing stay on disk; _selected_hero and
	# _selected_level are no longer read by PLAY.
	_content.add_child(_make_button("MODIFIERS", _show_modifiers_panel))
	_content.add_child(_make_button("UNLOCKS", _show_unlocks_panel))
	_content.add_child(_make_button("SETTINGS", _on_settings))
	_content.add_child(_make_button("QUIT", _on_quit))
	call_deferred("_focus_first_button")

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

func _focus_first_button() -> void:
	# Give a controller something to navigate from: focus the first enabled
	# button in the current panel. Deferred so it runs after the tree settles.
	if _content == null:
		return
	for child in _content.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return
		# Buttons inside rows (heroes/levels/etc.).
		if child is Container:
			for sub in (child as Container).get_children():
				if sub is Button and not (sub as Button).disabled:
					(sub as Button).grab_focus()
					return

func _hero_display_name(id: String) -> String:
	if _meta() != null:
		var def = _meta().get_hero_def(id)
		if not def.is_empty():
			return str(def.get("name", id)).to_upper()
	return id.capitalize().to_upper()

func _level_display_name(id: String) -> String:
	if _meta() != null:
		for l in _meta().LEVEL_DEFS:
			if str(l.get("id", "")) == id:
				return str(l.get("name", id)).to_upper()
	return id.capitalize().to_upper()

func _modifier_display_name() -> String:
	var meta := _meta()
	if meta != null:
		var def: Dictionary = meta.get_modifier_def(meta.pending_modifier)
		if not def.is_empty():
			return str(def.get("name", meta.pending_modifier)).to_upper()
	return "STANDARD"

# ---- Play ----

func _on_play() -> void:
	# Solo campaign. Explicitly reset any prior multiplayer session so the
	# single-player code path stays fully intact.
	var net := get_node_or_null("/root/Net")
	if net != null and net.has_method("shutdown"):
		net.shutdown()
	var meta := _meta()
	# THE moment the run comes into existence: press PLAY, get dealt. deal()
	# rolls everything from one seed and forwards body and region through
	# pending_hero/pending_level -- the carrier main.gd and every harness
	# already read. The descent narrates the hand on the way down.
	Run.deal(meta)
	if meta != null:
		meta.autostart_run = true
	get_tree().change_scene_to_file(DESCENT_SCENE)

func _on_ffa() -> void:
	# Online Free-For-All. Hand off to the lobby; the match scene is loaded by
	# the host once the roster is locked in.
	var net := get_node_or_null("/root/Net")
	if net != null:
		net.mode = "ffa"
	var meta := _meta()
	if meta != null:
		meta.pending_hero = _selected_hero
		meta.pending_level = _selected_level
		meta.autostart_run = false
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_quit() -> void:
	get_tree().quit()

func _on_settings() -> void:
	if _settings_menu != null and is_instance_valid(_settings_menu):
		return
	_settings_menu = SETTINGS_SCENE.instantiate()
	add_child(_settings_menu)
	if _settings_menu.has_signal("closed"):
		_settings_menu.closed.connect(_on_settings_closed)
	if _settings_menu.has_method("show_menu"):
		_settings_menu.show_menu(true)

func _on_settings_closed() -> void:
	if _settings_menu != null and is_instance_valid(_settings_menu):
		_settings_menu.queue_free()
	_settings_menu = null

# ---- Heroes panel ----

func _show_heroes_panel() -> void:
	_clear_content()
	_content.add_child(_make_heading("HEROES"))
	_content.add_child(_spacer(4))
	var meta := _meta()
	if meta != null:
		for h in meta.HERO_DEFS:
			_content.add_child(_make_hero_row(h))
	_content.add_child(_spacer(4))
	_content.add_child(_make_button("BACK", _show_root_menu))
	call_deferred("_focus_first_button")

func _make_hero_row(h: Dictionary) -> Control:
	var meta := _meta()
	var id := str(h.get("id", ""))
	var unlocked: bool = meta != null and meta.is_hero_unlocked(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = str(h.get("name", id)).to_upper()
	_apply_font(name_lbl, 13, COLOR_TEXT)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.custom_minimum_size = Vector2(190, 0)
	if id == _selected_hero:
		name_lbl.add_theme_color_override("font_color", COLOR_TITLE)
	elif not unlocked:
		name_lbl.add_theme_color_override("font_color", COLOR_LOCKED)
	row.add_child(name_lbl)

	if unlocked:
		var sel := _make_button(("ACTIVE" if id == _selected_hero else "SELECT"),
			func():
				_select_hero(id)
		, id != _selected_hero)
		sel.custom_minimum_size = Vector2(170, 44)
		row.add_child(sel)
	else:
		var cost := int(h.get("core_cost", 0))
		var can: bool = meta != null and meta.can_afford(cost)
		var buy := _make_button("UNLOCK %d" % cost, func():
			_unlock_hero(id)
		, can)
		buy.custom_minimum_size = Vector2(170, 44)
		row.add_child(buy)
	return row

func _select_hero(id: String) -> void:
	_selected_hero = id
	_show_heroes_panel()

func _unlock_hero(id: String) -> void:
	var meta := _meta()
	if meta != null and meta.unlock_hero(id):
		_selected_hero = id
	_refresh_cores()
	_show_heroes_panel()

# ---- Levels panel ----

func _show_levels_panel() -> void:
	_clear_content()
	_content.add_child(_make_heading("LEVELS"))
	_content.add_child(_spacer(4))
	var meta := _meta()
	if meta != null:
		for l in meta.LEVEL_DEFS:
			_content.add_child(_make_level_row(l))
	_content.add_child(_spacer(4))
	_content.add_child(_make_button("BACK", _show_root_menu))
	call_deferred("_focus_first_button")

func _make_level_row(l: Dictionary) -> Control:
	var id := str(l.get("id", ""))
	var coming_soon := bool(l.get("coming_soon", false))
	var meta := _meta()
	var unlocked: bool = meta != null and meta.is_level_unlocked(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = str(l.get("name", id)).to_upper()
	_apply_font(name_lbl, 13, COLOR_TEXT)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.custom_minimum_size = Vector2(230, 0)
	if not unlocked:
		name_lbl.add_theme_color_override("font_color", COLOR_LOCKED)
	elif id == _selected_level:
		name_lbl.add_theme_color_override("font_color", COLOR_TITLE)
	row.add_child(name_lbl)

	# A "coming soon" level becomes playable once it is actually unlocked
	# (e.g. the milestone victory unlock for "space").
	if (coming_soon and not unlocked) or not unlocked:
		var soon := Label.new()
		soon.text = "SOON"
		_apply_font(soon, 11, COLOR_LOCKED)
		soon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(soon)
	else:
		var sel := _make_button(("ACTIVE" if id == _selected_level else "SELECT"),
			func():
				_select_level(id)
		, id != _selected_level)
		sel.custom_minimum_size = Vector2(170, 44)
		row.add_child(sel)
	return row

func _select_level(id: String) -> void:
	_selected_level = id
	_show_levels_panel()

# ---- Modifiers (challenges) panel ----

func _show_modifiers_panel() -> void:
	_clear_content()
	_content.add_child(_make_heading("MODIFIERS"))
	_content.add_child(_spacer(4))
	var meta := _meta()
	if meta != null:
		for m in meta.MODIFIER_DEFS:
			_content.add_child(_make_modifier_row(m))
	_content.add_child(_spacer(4))
	_content.add_child(_make_button("BACK", _show_root_menu))
	call_deferred("_focus_first_button")

func _make_modifier_row(m: Dictionary) -> Control:
	var meta := _meta()
	var id := str(m.get("id", ""))
	var active: bool = meta != null and meta.pending_modifier == id
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.custom_minimum_size = Vector2(290, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	var mult := float(m.get("cores_reward_mult", 1.0))
	if mult > 1.0:
		name_lbl.text = "%s  (+%d%% CORES)" % [str(m.get("name", id)).to_upper(), int(round((mult - 1.0) * 100.0))]
	else:
		name_lbl.text = str(m.get("name", id)).to_upper()
	_apply_font(name_lbl, 12, COLOR_TITLE if active else COLOR_TEXT)
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = str(m.get("desc", ""))
	_apply_font(desc_lbl, 9, COLOR_DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)
	row.add_child(info)

	var sel := _make_button(("ACTIVE" if active else "SELECT"), func():
		_select_modifier(id)
	, not active)
	sel.custom_minimum_size = Vector2(150, 44)
	row.add_child(sel)
	return row

func _select_modifier(id: String) -> void:
	var meta := _meta()
	if meta != null:
		meta.pending_modifier = id
	_show_modifiers_panel()

# ---- Unlocks (permanent upgrades) shop ----

func _show_unlocks_panel() -> void:
	_clear_content()
	_content.add_child(_make_heading("UNLOCKS"))
	_content.add_child(_spacer(2))
	_refresh_cores()
	var meta := _meta()
	if meta != null:
		for u in meta.UPGRADE_DEFS:
			_content.add_child(_make_upgrade_row(u))
	_content.add_child(_spacer(2))
	_content.add_child(_make_button("BACK", _show_root_menu))
	call_deferred("_focus_first_button")

func _make_upgrade_row(u: Dictionary) -> Control:
	var meta := _meta()
	var id := str(u.get("id", ""))
	var lvl := 0
	var max_lvl := int(u.get("max_level", 0))
	var next_cost := -1
	if meta != null:
		lvl = meta.get_upgrade_level(id)
		next_cost = meta.get_upgrade_next_cost(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.custom_minimum_size = Vector2(290, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = "%s  %d/%d" % [str(u.get("name", id)).to_upper(), lvl, max_lvl]
	_apply_font(name_lbl, 12, COLOR_TEXT)
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = str(u.get("desc", ""))
	_apply_font(desc_lbl, 9, COLOR_DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)
	row.add_child(info)

	if next_cost < 0:
		var maxed := Label.new()
		maxed.text = "MAX"
		_apply_font(maxed, 12, COLOR_GOOD)
		maxed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		maxed.custom_minimum_size = Vector2(150, 0)
		maxed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(maxed)
	else:
		var can: bool = meta != null and meta.can_afford(next_cost)
		var buy := _make_button("BUY %d" % next_cost, func():
			_buy_upgrade(id)
		, can)
		buy.custom_minimum_size = Vector2(150, 44)
		row.add_child(buy)
	return row

func _buy_upgrade(id: String) -> void:
	var meta := _meta()
	if meta != null:
		meta.buy_upgrade(id)
	_refresh_cores()
	_show_unlocks_panel()
