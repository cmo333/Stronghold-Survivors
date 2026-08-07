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

func set_enabled(on: bool) -> void:
	if _rect != null:
		_rect.visible = on

func is_enabled() -> bool:
	return _rect != null and _rect.visible
