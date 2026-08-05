extends Node
class_name FeedbackConfig

# Master toggles (easy on/off for future config menus)
const ENABLE_DAMAGE_NUMBERS = true
const ENABLE_HIT_SPARKS = true
const ENABLE_CRIT_POP = true
const ENABLE_DEATH_FEEDBACK = true

# Damage numbers: pacing + readability
const DAMAGE_NUMBER_MIN = 1.0
const DAMAGE_NUMBER_COOLDOWN = 0.08 # seconds, per target
const DAMAGE_NUMBER_BUDGET_PER_SEC = 28
const DAMAGE_NUMBER_LIFETIME = 0.8
const DAMAGE_NUMBER_CRIT_LIFETIME = 1.1
const DAMAGE_NUMBER_DOT_LIFETIME = 0.45
const DAMAGE_NUMBER_RISE = 24.0
const DAMAGE_NUMBER_CRIT_RISE = 32.0
const DAMAGE_NUMBER_DOT_RISE = 12.0
const DAMAGE_NUMBER_JITTER_X = 10.0
const DAMAGE_NUMBER_JITTER_Y = 6.0

# Size is carried by the font size rather than by scaling a small glyph up, so
# the text rasterises crisply instead of turning into a blurry smear.
const DAMAGE_NUMBER_PX_MIN = 15.0          # weakest hit
const DAMAGE_NUMBER_PX_MAX = 28.0          # full-health-bar hit
const DAMAGE_NUMBER_PX_CRIT_BONUS = 9.0
const DAMAGE_NUMBER_PX_KILL_BONUS = 5.0
const DAMAGE_NUMBER_PX_ELITE_KILL_BONUS = 6.0
const DAMAGE_NUMBER_PX_CLAMP_MIN = 14
const DAMAGE_NUMBER_PX_CLAMP_MAX = 40      # hard cap: giant numbers were the worst offender
const DAMAGE_NUMBER_PX_STEP = 2            # quantise so the font atlas stays small

# Drop shadow (separate dilated label behind the number)
const DAMAGE_NUMBER_SHADOW_COLOR = Color(0.02, 0.02, 0.05, 0.72)
const DAMAGE_NUMBER_SHADOW_OUTLINE_RATIO = 0.11   # of font size
const DAMAGE_NUMBER_SHADOW_OFFSET_RATIO = 0.15    # of font size
const DAMAGE_NUMBER_OUTLINE_RATIO = 0.13          # main outline, of font size
const DAMAGE_NUMBER_OUTLINE_MIN = 2
const DAMAGE_NUMBER_OUTLINE_MAX = 5

# Per-instance colour variation so two identical numbers never look identical.
const DAMAGE_NUMBER_HUE_JITTER = 0.045     # +/- fraction of the hue wheel (~16 deg)
const DAMAGE_NUMBER_SAT_JITTER = 0.09
const DAMAGE_NUMBER_VAL_JITTER = 0.09
const DAMAGE_NUMBER_NEUTRAL_TINT_MIN = 0.14  # tint applied to near-white numbers
const DAMAGE_NUMBER_NEUTRAL_TINT_MAX = 0.34
const DAMAGE_NUMBER_GRADIENT_TOP = 0.3     # lighten at the top of the glyph
const DAMAGE_NUMBER_GRADIENT_BOTTOM = 0.22 # darken at the bottom

# Anti-overlap: nudge a new number away from ones spawned moments ago nearby.
# Separation is driven by how wide each number actually renders, so a 3-digit
# crit clears more space than a 2-digit chip hit.
const DAMAGE_NUMBER_DECLUMP_MIN_GAP = 26.0
const DAMAGE_NUMBER_DECLUMP_PAD = 7.0
const DAMAGE_NUMBER_DECLUMP_MAX_PUSH = 60.0
const DAMAGE_NUMBER_DECLUMP_WINDOW_MS = 620
const DAMAGE_NUMBER_DECLUMP_SAMPLES = 12
const DAMAGE_NUMBER_POP_START = 0.6
const DAMAGE_NUMBER_POP_TIME = 0.1
const DAMAGE_NUMBER_CRIT_POP_START = 0.52
const DAMAGE_NUMBER_CRIT_POP_TIME = 0.14
const DAMAGE_NUMBER_DOT_POP_START = 0.72
const DAMAGE_NUMBER_DOT_POP_TIME = 0.08
const DAMAGE_NUMBER_ROTATION_MAX = 0.06

const DAMAGE_NUMBER_FONT_PATH = "res://assets/ui/pixel_font.ttf"
const DAMAGE_NUMBER_OUTLINE_COLOR = Color(0.043, 0.043, 0.043, 1.0)

const DAMAGE_COLOR_NORMAL = Color(1.0, 1.0, 1.0)
const DAMAGE_COLOR_CRIT = Color(1.0, 0.133, 0.533)
const DAMAGE_COLOR_DOT = Color(0.4, 1.0, 0.267)
const DAMAGE_COLOR_KILL = Color(1.0, 0.843, 0.0)
const DAMAGE_COLOR_ELITE_KILL = Color(0.8, 0.4, 1.0)
const DAMAGE_COLOR_FIRE = Color(1.0, 0.4, 0.133)
const DAMAGE_COLOR_ICE = Color(0.431, 0.922, 1.0)
const DAMAGE_COLOR_LIGHTNING = Color(0.267, 0.867, 1.0)
const DAMAGE_COLOR_BLEED = Color(0.769, 0.0, 0.169)
const DAMAGE_COLOR_HOLY = Color(1.0, 0.914, 0.651)
const DAMAGE_COLOR_SHADOW = Color(0.416, 0.173, 1.0)
const DAMAGE_COLOR_ARCANE = Color(0.271, 0.949, 1.0)
const DAMAGE_COLOR_SHIELD = Color(0.616, 0.741, 0.949)

# Time scale accents
const KILL_SLOW_TIME_SCALE = 0.45
const KILL_SLOW_DURATION = 0.08
const TECH_SLOW_TIME_SCALE = 0.2

# Screen shake
const SCREEN_SHAKE_PLAYER_HIT = 8.5
const SCREEN_SHAKE_BUILDING_DESTROY = 14.0
const SCREEN_SHAKE_EXPLOSION = 11.0
const SCREEN_SHAKE_DURATION = 0.22

const DAMAGE_TYPE_COLORS = {
	"normal": DAMAGE_COLOR_NORMAL,
	"crit": DAMAGE_COLOR_CRIT,
	"dot": DAMAGE_COLOR_DOT,
	"poison": DAMAGE_COLOR_DOT,
	"acid": DAMAGE_COLOR_DOT,
	"fire": DAMAGE_COLOR_FIRE,
	"ice": DAMAGE_COLOR_ICE,
	"lightning": DAMAGE_COLOR_LIGHTNING,
	"bleed": DAMAGE_COLOR_BLEED,
	"holy": DAMAGE_COLOR_HOLY,
	"shadow": DAMAGE_COLOR_SHADOW,
	"arcane": DAMAGE_COLOR_ARCANE,
	"shield": DAMAGE_COLOR_SHIELD
}

# Crit rules (visual-only)
const CRIT_MIN_DAMAGE = 18.0
const CRIT_PCT_MAX_HEALTH = 0.35
const CRIT_PCT_ELITE = 0.25

# Hit sparks (visual-only)
const HIT_SPARK_MIN_DAMAGE = 1.0
const HIT_SPARK_COOLDOWN = 0.06
const PLAYER_HIT_SPARK_COOLDOWN = 0.12

# Hitstop (crit freeze frame)
const HITSTOP_TIME_SCALE = 0.05
const HITSTOP_DURATION = 0.1

# Per-hit enemy flinch (white flash on every hit, scaled by crit/kill)
const ENABLE_HIT_FLASH = true
const HIT_FLASH_DURATION = 0.07          # normal hit flash length (s)
const HIT_FLASH_CRIT_DURATION = 0.12     # crit flash lingers a touch longer
const HIT_FLASH_STRENGTH = 0.65          # 0..1 lerp toward white on a normal hit
const HIT_FLASH_CRIT_STRENGTH = 1.0      # crits flash full white

# Per-hit knockback impulse (decaying push along the hit direction)
const ENABLE_HIT_KNOCKBACK = true
const HIT_KNOCKBACK_BASE = 70.0          # px/s impulse on a normal hit
const HIT_KNOCKBACK_CRIT_MULT = 1.8      # crits shove harder
const HIT_KNOCKBACK_KILL_MULT = 1.4      # the killing blow shoves the corpse
const HIT_KNOCKBACK_DECAY = 9.0          # higher = snappier settle
const HIT_KNOCKBACK_MAX = 260.0          # clamp so big hits don't fling across screen
const HIT_KNOCKBACK_SIEGE_RESIST = 0.35  # heavy/siege units barely flinch

# Death animation timings
const DEATH_FLASH_DURATION = 0.1
const DEATH_SCALE_DURATION = 0.3
const DEATH_FADE_DURATION = 0.2
const DEATH_CORPSE_FADE_DELAY = 3.0

# Screen effects
const SCREEN_SHAKE_BASE_INTENSITY = 1.0
const SCREEN_SHAKE_DAMAGE_MULTIPLIER = 0.15
const CHROMATIC_ABERRATION_DURATION = 0.25
const VIGNETTE_LOW_HP_THRESHOLD = 0.3

# Dynamic camera
const CAMERA_ENEMY_COUNT_THRESHOLD = 20
const CAMERA_ZOOM_OUT_AMOUNT = 0.9
const CAMERA_MOUSE_LEAN_AMOUNT = 30.0
const CAMERA_SMOOTH_SPEED = 4.0

# Projectile trails
const PROJECTILE_MOTION_BLUR_STRETCH = 1.5
const PROJECTILE_TRAIL_INTERVAL = 0.02

# Muzzle flash
const MUZZLE_FLASH_DURATION = 0.08
const SHELL_CASING_LIFETIME = 0.6
const IMPACT_SPARK_LIFETIME = 0.15

# Enhanced FX settings (new)
const PROJECTILE_TRAIL_FADE_TIME = 0.3
const PROJECTILE_TRAIL_WIDTH = 3.0
const PROJECTILE_TRAIL_MAX_POINTS = 12

const IMPACT_SPARK_COUNT_MIN = 6
const IMPACT_SPARK_COUNT_MAX = 12
const IMPACT_SPARK_COUNT_CRIT = 22
const GROUND_CRACK_FADE_TIME = 2.0

const DEATH_PARTICLE_COUNT = 20
const CORPSE_FADE_TIME = 1.0

const SHOCKWAVE_EXPAND_TIME = 0.4
const LIGHTNING_BEAM_LIFETIME = 0.15
const MULTISHOT_INDICATOR_LIFETIME = 0.25
