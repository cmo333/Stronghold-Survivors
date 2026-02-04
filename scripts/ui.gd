extends CanvasLayer

@onready var resources_label: Label = $HUD/Resources
@onready var time_label: Label = $HUD/Time
@onready var selection_label: Label = $HUD/Selection
@onready var controls_label: Label = $HUD/Controls
@onready var level_label: Label = $HUD/Level
@onready var xp_bar: TextureProgressBar = $HUD/XPBar
@onready var tech_panel: TextureRect = $HUD/TechPanel
@onready var tech_option1: Label = $HUD/TechPanel/Option1
@onready var tech_option2: Label = $HUD/TechPanel/Option2
@onready var tech_option3: Label = $HUD/TechPanel/Option3
@onready var tech_icon1: TextureRect = $HUD/TechPanel/Option1Icon
@onready var tech_icon2: TextureRect = $HUD/TechPanel/Option2Icon
@onready var tech_icon3: TextureRect = $HUD/TechPanel/Option3Icon

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

func show_tech(options: Array) -> void:
    tech_panel.visible = true
    tech_option1.text = _format_option(1, options, 0)
    tech_option2.text = _format_option(2, options, 1)
    tech_option3.text = _format_option(3, options, 2)
    _set_icon(tech_icon1, options, 0)
    _set_icon(tech_icon2, options, 1)
    _set_icon(tech_icon3, options, 2)

func hide_tech() -> void:
    tech_panel.visible = false

func _format_option(number: int, options: Array, index: int) -> String:
    if index >= options.size():
        return "%d) --" % number
    var option := options[index]
    return "%d) %s - %s" % [number, option.get("name", ""), option.get("desc", "")]

func _set_icon(icon: TextureRect, options: Array, index: int) -> void:
    if icon == null:
        return
    if index >= options.size():
        icon.texture = null
        return
    var path := options[index].get("icon", "")
    if path == "":
        icon.texture = null
        return
    if ResourceLoader.exists(path):
        icon.texture = load(path)
    else:
        icon.texture = null
