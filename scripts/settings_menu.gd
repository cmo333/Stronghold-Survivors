extends CanvasLayer
class_name SettingsMenu

signal closed
signal settings_applied

@onready var background: ColorRect = $Background
@onready var panel: Panel = $Panel
@onready var close_button: Button = $Panel/CloseButton
@onready var tab_container: TabContainer = $Panel/TabContainer
@onready var reset_button: Button = $Panel/BottomButtons/ResetButton
@onready var apply_button: Button = $Panel/BottomButtons/ApplyButton
@onready var cancel_button: Button = $Panel/BottomButtons/CancelButton

# Audio controls
@onready var master_slider: HSlider = %MasterSlider
@onready var master_label: Label = %MasterSlider.get_parent().get_node("ValueLabel")
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_label: Label = %SFXSlider.get_parent().get_node("ValueLabel")
@onready var music_slider: HSlider = %MusicSlider
@onready var music_label: Label = %MusicSlider.get_parent().get_node("ValueLabel")
@onready var ui_slider: HSlider = %UISlider
@onready var ui_label: Label = %UISlider.get_parent().get_node("ValueLabel")

# Graphics controls
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var vsync_check: CheckBox = %VSyncCheck
@onready var quality_dropdown: OptionButton = %QualityDropdown

# Gameplay controls
@onready var screenshake_slider: HSlider = %ScreenshakeSlider
@onready var screenshake_label: Label = %ScreenshakeSlider.get_parent().get_node("ValueLabel")
@onready var damage_numbers_check: CheckBox = %DamageNumbersCheck
@onready var tower_range_check: CheckBox = %TowerRangeCheck
@onready var auto_collect_check: CheckBox = %AutoCollectCheck
@onready var wave_preview_check: CheckBox = %WavePreviewCheck

# Accessibility controls
@onready var colorblind_dropdown: OptionButton = %ColorblindDropdown
@onready var font_slider: HSlider = %FontSlider
@onready var font_label: Label = %FontSlider.get_parent().get_node("ValueLabel")
@onready var flash_slider: HSlider = %FlashSlider
@onready var flash_label: Label = %FlashSlider.get_parent().get_node("ValueLabel")
@onready var reduced_motion_check: CheckBox = %ReducedMotionCheck
@onready var high_contrast_check: CheckBox = %HighContrastCheck

var _settings_manager: Node = null
var _pending_changes: Dictionary = {}
var _is_popup: bool = false

func _ready() -> void:
	layer = 101
	visible = false
	
	_settings_manager = get_node_or_null("/root/SettingsManager")
	if _settings_manager == null:
		# Create default settings manager if not present
		_settings_manager = preload("res://scripts/settings_manager.gd").new()
		_settings_manager.name = "SettingsManager"
		get_tree().root.add_child(_settings_manager)
	
	_connect_signals()
	_load_current_settings()

func _connect_signals() -> void:
	if close_button:
		close_button.pressed.connect(close)
	if reset_button:
		reset_button.pressed.connect(_on_reset_defaults)
	if apply_button:
		apply_button.pressed.connect(_on_apply)
	if cancel_button:
		cancel_button.pressed.connect(close)
	
	# Audio sliders
	master_slider.value_changed.connect(func(v): _on_volume_changed("master", v))
	sfx_slider.value_changed.connect(func(v): _on_volume_changed("sfx", v))
	music_slider.value_changed.connect(func(v): _on_volume_changed("music", v))
	ui_slider.value_changed.connect(func(v): _on_volume_changed("ui", v))
	
	# Graphics toggles
	fullscreen_check.toggled.connect(func(v): _pending_changes["graphics:fullscreen"] = v)
	vsync_check.toggled.connect(func(v): _pending_changes["graphics:vsync"] = v)
	quality_dropdown.item_selected.connect(func(i): _pending_changes["graphics:quality"] = quality_dropdown.get_item_text(i).to_lower())
	
	# Gameplay settings
	screenshake_slider.value_changed.connect(func(v): _on_screenshake_changed(v))
	damage_numbers_check.toggled.connect(func(v): _pending_changes["gameplay:damage_numbers"] = v)
	tower_range_check.toggled.connect(func(v): _pending_changes["gameplay:show_tower_range"] = v)
	auto_collect_check.toggled.connect(func(v): _pending_changes["gameplay:auto_collect_gold"] = v)
	wave_preview_check.toggled.connect(func(v): _pending_changes["gameplay:wave_preview"] = v)
	
	# Accessibility settings
	colorblind_dropdown.item_selected.connect(func(i): _on_colorblind_changed(i))
	font_slider.value_changed.connect(func(v): _on_font_size_changed(v))
	flash_slider.value_changed.connect(func(v): _on_flash_reduction_changed(v))
	reduced_motion_check.toggled.connect(func(v): _pending_changes["accessibility:reduced_motion"] = v)
	high_contrast_check.toggled.connect(func(v): _pending_changes["accessibility:high_contrast"] = v)

func show_menu(popup_mode: bool = false) -> void:
	_is_popup = popup_mode
	visible = true
	_load_current_settings()
	
	# Pause game if not in popup mode
	if not popup_mode:
		get_tree().paused = true
	
	# Focus first control
	if master_slider:
		master_slider.grab_focus()

func close() -> void:
	visible = false
	_pending_changes.clear()
	
	if not _is_popup:
		get_tree().paused = false
	
	closed.emit()

func _load_current_settings() -> void:
	if _settings_manager == null:
		return
	
	# Audio
	master_slider.value = _settings_manager.get_master_volume()
	_update_volume_label(master_label, master_slider.value)
	sfx_slider.value = _settings_manager.get_volume("sfx")
	_update_volume_label(sfx_label, sfx_slider.value)
	music_slider.value = _settings_manager.get_volume("music")
	_update_volume_label(music_label, music_slider.value)
	ui_slider.value = _settings_manager.get_volume("ui")
	_update_volume_label(ui_label, ui_slider.value)
	
	# Graphics
	fullscreen_check.button_pressed = _settings_manager.is_fullscreen()
	vsync_check.button_pressed = _settings_manager.is_vsync()
	_select_quality_option(_settings_manager.get_quality())
	
	# Gameplay
	screenshake_slider.value = _settings_manager.get_screenshake_intensity()
	screenshake_label.text = "%.1fx" % screenshake_slider.value
	damage_numbers_check.button_pressed = _settings_manager.show_damage_numbers()
	tower_range_check.button_pressed = _settings_manager.get_setting("gameplay", "show_tower_range", true)
	auto_collect_check.button_pressed = _settings_manager.get_setting("gameplay", "auto_collect_gold", false)
	wave_preview_check.button_pressed = _settings_manager.get_setting("gameplay", "wave_preview", true)
	
	# Accessibility
	_select_colorblind_option(_settings_manager.get_colorblind_mode())
	font_slider.value = _settings_manager.get_font_size()
	font_label.text = str(int(font_slider.value))
	flash_slider.value = _settings_manager.get_screen_flash_reduction()
	flash_label.text = "%d%%" % int(flash_slider.value * 100)
	reduced_motion_check.button_pressed = _settings_manager.is_reduced_motion()
	high_contrast_check.button_pressed = _settings_manager.is_high_contrast()

func _update_volume_label(label: Label, value: float) -> void:
	label.text = "%d%%" % int(value * 100)

func _select_quality_option(quality: String) -> void:
	var options = ["low", "medium", "high", "ultra"]
	var index = options.find(quality)
	if index >= 0:
		quality_dropdown.select(index)

func _select_colorblind_option(mode: String) -> void:
	var options = ["none", "deuteranopia", "protanopia", "tritanopia"]
	var index = options.find(mode)
	if index >= 0:
		colorblind_dropdown.select(index)
	else:
		colorblind_dropdown.select(0)

func _on_volume_changed(bus: String, value: float) -> void:
	_pending_changes["audio:%s_volume" % bus] = value
	
	# Update label
	match bus:
		"master": _update_volume_label(master_label, value)
		"sfx": _update_volume_label(sfx_label, value)
		"music": _update_volume_label(music_label, value)
		"ui": _update_volume_label(ui_label, value)
	
	# Preview volume change
	if _settings_manager:
		match bus:
			"master": _settings_manager.set_master_volume(value)
			"sfx": _settings_manager.set_sfx_volume(value)
			"music": _settings_manager.set_music_volume(value)
			"ui": _settings_manager.set_ui_volume(value)

func _on_screenshake_changed(value: float) -> void:
	_pending_changes["gameplay:screenshake_intensity"] = value
	screenshake_label.text = "%.1fx" % value

func _on_colorblind_changed(index: int) -> void:
	var modes = ["none", "deuteranopia", "protanopia", "tritanopia"]
	if index >= 0 and index < modes.size():
		_pending_changes["accessibility:colorblind_mode"] = modes[index]

func _on_font_size_changed(value: float) -> void:
	_pending_changes["accessibility:font_size"] = int(value)
	font_label.text = str(int(value))

func _on_flash_reduction_changed(value: float) -> void:
	_pending_changes["accessibility:screen_flash_reduction"] = value
	flash_label.text = "%d%%" % int(value * 100)

func _on_apply() -> void:
	if _settings_manager == null:
		return
	
	# Apply all pending changes
	for key in _pending_changes.keys():
		var parts = key.split(":")
		if parts.size() == 2:
			var category = parts[0]
			var setting_key = parts[1]
			var value = _pending_changes[key]
			_settings_manager.set_setting(category, setting_key, value)
	
	_pending_changes.clear()
	settings_applied.emit()
	close()

func _on_reset_defaults() -> void:
	if _settings_manager == null:
		return
	
	_settings_manager.reset_to_defaults()
	_load_current_settings()
	_pending_changes.clear()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()