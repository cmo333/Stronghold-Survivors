extends CanvasLayer

# End-of-match ranked scoreboard for FFA. Built in code (like the lobby) so it
# stays decoupled from the gothic menu asset pipeline. Shows every player's
# collected resources, highlights the local player, and reports Cores earned.
# A single RETURN TO MENU button tears down the net session.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const FONT_PIXEL := "res://assets/ui/pixel_font.ttf"

const COLOR_DIM_BG := Color(0.02, 0.02, 0.05, 0.86)
const COLOR_PANEL := Color(0.08, 0.06, 0.13, 0.98)
const COLOR_TEXT := Color(0.88, 0.86, 0.92)
const COLOR_TITLE := Color(1.0, 0.85, 0.35)
const COLOR_ACCENT := Color(0.45, 0.95, 1.0)
const COLOR_GOLD := Color(1.0, 0.84, 0.3)
const COLOR_DIM := Color(0.62, 0.60, 0.70)
const COLOR_YOU := Color(0.55, 1.0, 0.55)

var _font: FontFile = null

func _ready() -> void:
	layer = 90
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = _load_font()

func show_results(board: Array, my_id: int, placement: int, cores: int) -> void:
	for c in get_children():
		c.queue_free()

	var dim := ColorRect.new()
	dim.color = COLOR_DIM_BG
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(560, 0)
	panel.add_child(col)

	var won := placement == 1 and board.size() > 0
	var title := Label.new()
	title.text = "VICTORY" if won else "MATCH OVER"
	_apply_font(title, 30, COLOR_TITLE if won else COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var sub := Label.new()
	sub.text = "You placed #%d of %d" % [placement, board.size()]
	_apply_font(sub, 14, COLOR_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	col.add_child(_divider())

	var header := _row_box()
	header.add_child(_cell("#", 40, COLOR_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(_cell("PLAYER", 240, COLOR_ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	header.add_child(_cell("RESOURCES", 150, COLOR_ACCENT, HORIZONTAL_ALIGNMENT_RIGHT))
	header.add_child(_cell("CHESTS", 90, COLOR_ACCENT, HORIZONTAL_ALIGNMENT_RIGHT))
	col.add_child(header)

	for i in range(board.size()):
		var entry: Dictionary = board[i]
		var is_me := int(entry["peer_id"]) == my_id
		var name_color := COLOR_YOU if is_me else COLOR_TEXT
		var tag := "  [BOT]" if bool(entry.get("is_bot", false)) else ""
		var you := "  (you)" if is_me else ""
		var rank_color := COLOR_GOLD if i == 0 else name_color
		var row := _row_box()
		row.add_child(_cell(str(i + 1), 40, rank_color, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(_cell(str(entry["name"]) + tag + you, 240, name_color, HORIZONTAL_ALIGNMENT_LEFT))
		row.add_child(_cell(str(int(entry["currency"])), 150, name_color, HORIZONTAL_ALIGNMENT_RIGHT))
		row.add_child(_cell(str(int(entry["treasures"])), 90, name_color, HORIZONTAL_ALIGNMENT_RIGHT))
		col.add_child(row)

	col.add_child(_divider())

	var cores_label := Label.new()
	cores_label.text = "Cores earned:  %d" % cores
	_apply_font(cores_label, 16, COLOR_GOLD)
	cores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cores_label)

	var btn := Button.new()
	btn.text = "RETURN TO MENU"
	btn.custom_minimum_size = Vector2(0, 46)
	_apply_font(btn, 14, COLOR_TEXT)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.14, 0.12, 0.20, 0.95)
	bsb.border_color = COLOR_ACCENT
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", bsb)
	btn.add_theme_stylebox_override("hover", bsb)
	btn.add_theme_stylebox_override("pressed", bsb)
	btn.add_theme_stylebox_override("focus", bsb)
	btn.pressed.connect(_on_return_pressed)
	col.add_child(btn)

	visible = true
	btn.grab_focus()

func _on_return_pressed() -> void:
	var net := get_node_or_null("/root/Net")
	if net != null and net.has_method("shutdown"):
		net.shutdown()
	get_tree().change_scene_to_file(MENU_SCENE)

# ---- helpers ----

func _row_box() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	return h

func _cell(text: String, width: float, color: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = align
	_apply_font(l, 13, color)
	return l

func _divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(0.3, 0.28, 0.4, 0.6)
	line.custom_minimum_size = Vector2(0, 2)
	return line

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
