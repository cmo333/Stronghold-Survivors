extends CanvasLayer

# Local-only "you died" overlay for FFA. Shown ONLY on the machine whose own
# player was eliminated. It does NOT pause or end the shared match: the host keeps
# simulating for everyone, the clock keeps running, and the dead player's score is
# already locked in the econ ledger. The player can keep spectating the live arena
# or LEAVE TO MENU. When the 20-minute clock ends, the normal results scoreboard
# replaces this overlay for everyone.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const FONT_PIXEL := "res://assets/ui/pixel_font.ttf"

const COLOR_PANEL := Color(0.08, 0.04, 0.06, 0.92)
const COLOR_TEXT := Color(0.88, 0.86, 0.92)
const COLOR_DEAD := Color(1.0, 0.32, 0.30)
const COLOR_ACCENT := Color(0.45, 0.95, 1.0)
const COLOR_DIM := Color(0.62, 0.60, 0.70)

var _font: FontFile = null
var _panel: PanelContainer = null

func _ready() -> void:
	layer = 80
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = _load_font()

# placement: the dead player's current standing (1 = best). total: player count.
func show_death(placement: int, total: int) -> void:
	for c in get_children():
		c.queue_free()

	# A translucent top-strip panel so the live match stays visible underneath
	# (the player is spectating, not staring at a black screen).
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.offset_top = 36.0
	center.offset_bottom = 220.0
	add_child(center)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_DEAD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(440, 0)
	_panel.add_child(col)

	var title := Label.new()
	title.text = "YOU DIED"
	_apply_font(title, 30, COLOR_DEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var rank := Label.new()
	rank.text = "Currently #%d of %d" % [placement, total]
	_apply_font(rank, 15, COLOR_TEXT)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rank)

	var note := Label.new()
	note.text = "Spectating - the match continues. Your score is locked in."
	_apply_font(note, 12, COLOR_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)

	var btn := Button.new()
	btn.text = "LEAVE TO MENU"
	btn.custom_minimum_size = Vector2(0, 42)
	_apply_font(btn, 13, COLOR_TEXT)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.14, 0.12, 0.20, 0.95)
	bsb.border_color = COLOR_ACCENT
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", bsb)
	btn.add_theme_stylebox_override("hover", bsb)
	btn.add_theme_stylebox_override("pressed", bsb)
	btn.add_theme_stylebox_override("focus", bsb)
	btn.pressed.connect(_on_leave_pressed)
	col.add_child(btn)

	visible = true

# When the match actually ends, the results scoreboard takes over; hide this.
func hide_death() -> void:
	visible = false

func _on_leave_pressed() -> void:
	var net := get_node_or_null("/root/Net")
	if net != null and net.has_method("shutdown"):
		net.shutdown()
	get_tree().change_scene_to_file(MENU_SCENE)

func _load_font() -> FontFile:
	if not ResourceLoader.exists(FONT_PIXEL):
		return null
	var f = load(FONT_PIXEL)
	return f if f is FontFile else null

func _apply_font(ctrl: Control, size: int, color: Color) -> void:
	if _font != null:
		ctrl.add_theme_font_override("font", _font)
	ctrl.add_theme_font_size_override("font_size", size)
	ctrl.add_theme_color_override("font_color", color)
