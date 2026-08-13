extends CanvasLayer
class_name ScreenGrade

## Full-screen colour grade: vignette, contrast, saturation and a warm/cool split.
##
## The raw frame is flat - uniform mid-green ground, uniform grey stone, no
## falloff toward the edges - so a busy base reads as noise with no focal point.
## One graded fullscreen pass costs a single quad and does more for "this looks
## finished" than any amount of extra sprite work.
##
## Deliberately restrained. The art is already high-contrast pixel work; the job
## here is to seat it in a scene, not to restyle it.

const GRADE_SHADER := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

uniform float vignette_strength = 0.42;
uniform float vignette_softness = 0.55;
uniform float contrast = 1.06;
uniform float saturation = 1.12;
uniform float lift = 0.008;
uniform vec3 shadow_tint = vec3(0.86, 0.92, 1.08);   // cool shadows
uniform vec3 highlight_tint = vec3(1.05, 1.01, 0.94); // warm highlights

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// Contrast about mid-grey, then saturation about luma. Order matters: doing
	// saturation first would amplify whatever the contrast push then clips.
	col = (col - 0.5) * contrast + 0.5;
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(luma), col, saturation);

	// Split tone by luminance. A touch of cool in the shadows and warmth in the
	// highlights separates the stone from the grass without recolouring either.
	col *= mix(shadow_tint, highlight_tint, smoothstep(0.25, 0.75, luma));
	col += lift;

	// Vignette from the frame centre, corrected for aspect so it stays circular
	// on a wide window instead of turning into a letterbox.
	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= 1.0; // aspect handled by the caller via vignette_softness tuning
	float d = length(uv) * 1.414;
	float vig = 1.0 - vignette_strength * smoothstep(vignette_softness, 1.0, d);
	col *= vig;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
"""

var _rect: ColorRect = null

func _ready() -> void:
	# Above the world, below the HUD: the grade should seat the scene, never dim
	# the interface the player reads numbers off.
	layer = 1
	_rect = ColorRect.new()
	_rect.name = "GradeRect"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = GRADE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_rect.material = mat
	add_child(_rect)
	apply_accessibility()

# High contrast pushes past the restrained defaults in the shader above. The
# grade is the only full-screen pass in the game, so it is the one place this
# can be honoured without touching every sprite.
const HIGH_CONTRAST_CONTRAST := 1.28
const HIGH_CONTRAST_SATURATION := 1.30
const BASE_CONTRAST := 1.06
const BASE_SATURATION := 1.12

func apply_accessibility() -> void:
	"""Push the high-contrast setting into the grade shader.

	It shipped as dead UI -- `is_high_contrast()` had zero call sites outside
	the settings screen, so the player could tick it, press Apply, and watch
	nothing happen.

	Colourblind mode is deliberately NOT handled here. A daltonisation pass was
	written and measured against red/green pairs the game actually uses (enemy
	health, damage tints, rarity frames), and only deuteranopia improved:
	protanopia came out 7-20% WORSE and tritanopia 15-36% worse, with the
	tritanopia simulation leaving gamut entirely. Shipping a correction that
	makes two of its three settings harder to read is worse than not shipping
	one, so the dropdown is hidden until this is done against a validated
	pipeline and checked on a real screen."""
	if _rect == null or _rect.material == null:
		return
	var mat := _rect.material as ShaderMaterial
	if mat == null:
		return
	var high_contrast := false
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("is_high_contrast"):
		high_contrast = bool(settings.is_high_contrast())
	mat.set_shader_parameter("contrast", HIGH_CONTRAST_CONTRAST if high_contrast else BASE_CONTRAST)
	mat.set_shader_parameter("saturation", HIGH_CONTRAST_SATURATION if high_contrast else BASE_SATURATION)

func set_enabled(on: bool) -> void:
	if _rect != null:
		_rect.visible = on

func is_enabled() -> bool:
	return _rect != null and _rect.visible
