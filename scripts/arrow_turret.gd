extends Tower

var pierce_count = 1

# Shared static textures (created once, reused by all arrow turrets)
static var _shared_crystal_tex: ImageTexture = null
static var _shared_arrow_tex: ImageTexture = null

# Arrow tower specific visuals (note: _crystal_core is inherited from Tower)
var _floating_arrows: Array[Sprite2D] = []
var _arrow_orbit_angle: float = 0.0

# Evolution: Gatling
var _gatling_spin_time: float = 0.0
var _gatling_max_spin: float = 2.0  # Time to reach max fire rate
var _gatling_base_rate: float = 1.0
var _gatling_max_rate: float = 4.0
var _gatling_firing: bool = false
var _gatling_idle_timer: float = 0.0

# Evolution: Sniper
var _sniper_laser_line: Line2D = null
var _sniper_charge_timer: float = 0.0
var _sniper_charging: bool = false
var _sniper_target: Node = null

# Evolution presentation: the evolved arrow tower keeps its most-upgraded base
# (directional T3) art and is distinguished by a per-evolution color tint plus a
# slow pulsating glow (same spirit as the cannon's tint-only evolution look).
var _evo_pulse_tween: Tween = null
const EVO_TINT_GATLING := Color(1.35, 1.0, 0.55, 1.0)  # warm orange/gold
const EVO_TINT_SNIPER := Color(1.3, 0.55, 0.55, 1.0)   # hot red

const MISSILE_BODY_VARIANTS := {
	"base_t1": [
		"res://assets/level1/level1_anim60/tower_missile_t1_2x2_fire_f001_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_t1_2x2_fire_f002_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_t1_2x2_fire_f003_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_t1_2x2_fire_f004_v001.png"
	],
	"base_t2": [
		"res://assets/level1/level1_anim60/tower_missile_t2_2x2_fire_f001_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_t2_2x2_fire_f002_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_t2_2x2_fire_f003_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_t2_2x2_fire_f004_v001.png"
	],
	"base_t3": [
		"res://assets/level1/level1_anim60/tower_missile_t3_2x2_fire_f001_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_t3_2x2_fire_f002_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_t3_2x2_fire_f003_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_t3_2x2_fire_f004_v001.png"
	],
	"evo_gatling": [
		"res://assets/level1/level1_anim60/tower_missile_evo_gatling_2x2_fire_f001_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_evo_gatling_2x2_fire_f002_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_evo_gatling_2x2_fire_f003_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_evo_gatling_2x2_fire_f004_v001.png"
	],
	"evo_sniper": [
		"res://assets/level1/level1_anim60/tower_missile_evo_sniper_2x2_fire_f001_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_evo_sniper_2x2_fire_f002_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_evo_sniper_2x2_fire_f003_v001.png",
		"res://assets/level1/level1_anim60/tower_missile_evo_sniper_2x2_fire_f004_v001.png"
	]
}

const MISSILE_SHOT_FRAMES = [
	"res://assets/fx/fx_arrow_bolt_16_f001_v002.png",
	"res://assets/fx/fx_arrow_bolt_16_f002_v002.png",
	"res://assets/fx/fx_arrow_bolt_16_f003_v002.png",
	"res://assets/fx/fx_arrow_bolt_16_f004_v002.png"
]

# Hand-drawn isometric base tower with the ballista pre-rotated for each compass
# heading. We snap to the nearest available orientation by aim direction instead
# of rotating a single sprite (these are baked iso views; free rotation looks wrong).
# NW art isn't authored yet, so it falls back to the nearest neighbour at runtime.
const DIRECTIONAL_BASE_FRAMES := {
	"N": "res://assets/level1/towers_directional/arrow_t1_N.png",
	"NE": "res://assets/level1/towers_directional/arrow_t1_NE.png",
	"E": "res://assets/level1/towers_directional/arrow_t1_E.png",
	"SE": "res://assets/level1/towers_directional/arrow_t1_SE.png",
	"S": "res://assets/level1/towers_directional/arrow_t1_S.png",
	"SW": "res://assets/level1/towers_directional/arrow_t1_SW.png",
	"W": "res://assets/level1/towers_directional/arrow_t1_W.png",
	"NW": "res://assets/level1/towers_directional/arrow_t1_W.png"
}
# Level-2 upgrade art: same baked iso heading set as T1, with the flaming-bolt
# ballista. NW has no authored view yet, so it falls back to the W frame.
const DIRECTIONAL_BASE_FRAMES_T2 := {
	"N": "res://assets/level1/towers_directional/arrow_t2_N.png",
	"NE": "res://assets/level1/towers_directional/arrow_t2_NE.png",
	"E": "res://assets/level1/towers_directional/arrow_t2_E.png",
	"SE": "res://assets/level1/towers_directional/arrow_t2_SE.png",
	"S": "res://assets/level1/towers_directional/arrow_t2_S.png",
	"SW": "res://assets/level1/towers_directional/arrow_t2_SW.png",
	"W": "res://assets/level1/towers_directional/arrow_t2_W.png",
	"NW": "res://assets/level1/towers_directional/arrow_t2_W.png"
}
# Eight compass headings in screen-space angle order (radians, atan2 convention:
# +x right, +y down). N = up = -PI/2.
const _DIR_ORDER := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const _DIR_ANGLES := {
	"E": 0.0,
	"SE": PI * 0.25,
	"S": PI * 0.5,
	"SW": PI * 0.75,
	"W": PI,
	"NW": -PI * 0.75,
	"N": -PI * 0.5,
	"NE": -PI * 0.25
}
# World-space scale tuned for the 1254px source art (large hand-drawn tower).
# Grid cells are 32px and the tower's build footprint is ~28-32px. The iso art has
# transparent margins, so the visible tower is smaller than its bounding box; ~0.070
# (~88px box) fills the cell with confident presence and a natural overhang while
# still keeping the maze pathing readable between tower walls.
const DIRECTIONAL_BODY_SCALE := 0.070

# The evolved tower uses the 64px missile flipbook art (evo_gatling/evo_sniper),
# NOT the 1254px baked iso directional art. Reusing the tiny directional scale
# (~0.07) on the 64px sheet shrinks the tower to a few pixels (looks "gone"), so
# evolved bodies get this dedicated scale instead — matching the missile body
# family's world footprint (~64px * 1.8 ≈ 115px, in line with the T3 base scale).
const EVOLVED_BODY_SCALE := 1.8

# Per-tier baked iso frame maps: tier 1 (base) and tier 2 (upgraded). Tier 3 has
# no authored set and reuses the tier-2 art (see _dir_tex_set).
var _dir_tex_t1: Dictionary = {}
var _dir_tex_t2: Dictionary = {}
var _directional_loaded: bool = false
var _directional_active: bool = false
var _current_dir_key: String = ""
var _current_dir_tier: int = 0

var _active_body_variant: String = ""
const MISSILE_BODY_STABLE_FRAME_INDEX := {
	"base_t1": 0,
	"base_t2": 0,
	"base_t3": 0,
	"evo_gatling": 0,
	"evo_sniper": 0
}

func _ready() -> void:
	tower_type = "arrow"
	_load_directional_textures()
	super._ready()
	if _use_directional_art():
		_directional_active = true
		_apply_directional_body(_dir_key_for(_last_fire_dir), true)
	else:
		_refresh_body_frames(true)

func _load_directional_textures() -> void:
	if _directional_loaded:
		return
	_directional_loaded = true
	_dir_tex_t1 = _load_dir_frame_set(DIRECTIONAL_BASE_FRAMES)
	# T2 art is optional: if the files aren't present the map stays empty and the
	# tower gracefully keeps using the T1 art at higher tiers.
	_dir_tex_t2 = _load_dir_frame_set(DIRECTIONAL_BASE_FRAMES_T2)

func _load_dir_frame_set(frame_paths: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in frame_paths.keys():
		var path := str(frame_paths[key])
		if ResourceLoader.exists(path):
			var tex = load(path)
			if tex is Texture2D:
				out[key] = tex
	return out

# The active heading->texture map for the current upgrade level. Tier >=2 uses the
# T2 set when authored; otherwise falls back to T1 (which is also tier-1 art).
func _dir_tex_set() -> Dictionary:
	if upgrade_level >= 2 and not _dir_tex_t2.is_empty():
		return _dir_tex_t2
	return _dir_tex_t1

# Use the hand-drawn directional art only when the full set loaded and the tower
# is in its un-evolved base form. Evolutions keep their procedural launcher look
# until directional art for those tiers exists.
func _use_directional_art() -> bool:
	if is_evolved:
		return false
	return not _dir_tex_t1.is_empty()

func _dir_key_for(aim: Vector2) -> String:
	if aim.length_squared() <= 0.0001:
		return "S"
	var angle := aim.angle()
	var best_key := "S"
	var best_diff := TAU
	var tex_set := _dir_tex_set()
	for key in _DIR_ORDER:
		if not tex_set.has(key):
			continue
		var diff: float = abs(wrapf(angle - float(_DIR_ANGLES[key]), -PI, PI))
		if diff < best_diff:
			best_diff = diff
			best_key = key
	return best_key

func _apply_directional_body(dir_key: String, force: bool = false) -> void:
	if body_sprite == null:
		return
	var tex_set := _dir_tex_set()
	if not tex_set.has(dir_key):
		return
	var tier := 2 if (upgrade_level >= 2 and not _dir_tex_t2.is_empty()) else 1
	if not force and dir_key == _current_dir_key and tier == _current_dir_tier:
		return
	_current_dir_key = dir_key
	_current_dir_tier = tier
	var tex: Texture2D = tex_set[dir_key]
	var frames := SpriteFrames.new()
	# SpriteFrames ships with a built-in "default" animation; re-adding it logs
	# "already has animation 'default'", so only add it if somehow missing.
	if not frames.has_animation("default"):
		frames.add_animation("default")
	frames.set_animation_speed("default", 1.0)
	frames.set_animation_loop("default", false)
	frames.add_frame("default", tex)
	body_sprite.sprite_frames = frames
	body_sprite.animation = "default"
	body_sprite.stop()
	body_sprite.frame = 0
	body_sprite.visible = true
	if _glow_sprite != null:
		_glow_sprite.texture = tex

func get_fire_windup_time() -> float:
	if is_evolved and evolution_id == "sniper":
		return 0.16
	if is_evolved and evolution_id == "gatling":
		return 0.02
	return 0.04

func get_fire_recover_time() -> float:
	if is_evolved and evolution_id == "sniper":
		return 0.14
	if is_evolved and evolution_id == "gatling":
		return 0.03
	return 0.07

func get_fire_impulse_scale() -> float:
	if is_evolved and evolution_id == "sniper":
		return 1.35
	if is_evolved and evolution_id == "gatling":
		return 0.65
	return 0.95

func get_body_anim_idle_speed() -> float:
	return 0.78

func get_body_anim_target_speed() -> float:
	return 1.12

func get_body_anim_windup_speed() -> float:
	if is_evolved and evolution_id == "sniper":
		return 1.38
	return 1.22

func get_body_anim_recover_speed() -> float:
	if is_evolved and evolution_id == "gatling":
		return 1.18
	return 1.0

func get_body_orientation_offset() -> float:
	return 0.0

func get_body_idle_direction() -> Vector2:
	return Vector2.DOWN

func get_body_tracking_speed() -> float:
	return 13.5

func uses_split_body_presentation() -> bool:
	# Directional art is a single baked iso view; never split/rotate it.
	# Evolved bodies are front-facing flipbook art: keep them whole too.
	if _use_directional_art() or is_evolved:
		return false
	return true

# Planted & mechanical: the base stays put, only the head tracks the target and
# kicks back on fire. No body lunge, no rotational roll = no "flop".
func get_body_motion_tuning() -> Dictionary:
	if _use_directional_art():
		# Baked iso art: no rotation/lunge, but a crisp recoil kick + scale punch
		# on fire so the heavy ballista reads as bracing when it looses a bolt.
		return {
			"lunge": 0.0,
			"roll": 0.0,
			"bob": 0.28,
			"recoil": 1.0,
			"fire_punch": 0.9,
		}
	return {
		"lunge": 0.0,        # kill the forward body lunge entirely
		"roll": 0.0,         # no windup/recover/idle rotation sway
		"bob": 0.35,         # keep a faint idle life only
		"recoil": 1.0,       # crisp backward kick along aim on fire
		"fire_punch": 0.8,   # slightly softer scale punch
	}

func get_body_tracking_enabled() -> bool:
	# Orientation is chosen by swapping the baked iso frame, not by rotating.
	# Evolved bodies are front-facing flipbook art, so never rotate them either.
	if _use_directional_art() or is_evolved:
		return false
	return super.get_body_tracking_enabled()

func get_body_motion_profile() -> Dictionary:
	# Evolved bodies are single front-facing flipbook views: no tracking/split.
	if is_evolved:
		return {
			"idle_direction": Vector2.DOWN,
			"tracking_enabled": false,
			"tracking_speed": 0.0,
			"tracking_max_angle": 0.0,
			"split_presentation": false,
		}
	return {
		"idle_direction": Vector2.DOWN,
		"tracking_enabled": true,
		"tracking_speed": 13.5,
		"tracking_max_angle": PI,
		"split_presentation": true,
		"split_ratio": 0.58,
		"split_overlap_px": 5,
	}

func get_projectile_visual_profile() -> Dictionary:
	var tier = clampi(upgrade_level, 1, 3)
	var profile = {
		"projectile_frames": MISSILE_SHOT_FRAMES,
		"projectile_fps": 16.0,
		"projectile_static_frame": 0,
		"projectile_scale": 1.35,
		"trail_damage_type": "normal",
		"impact_damage_type": "normal",
		"impact_fx_kind": "hit",
		"projectile_tint": Color(1.0, 0.95, 0.72, 1.0)
	}
	if tier == 2:
		profile["projectile_fps"] = 18.0
		profile["projectile_scale"] = 1.5
		profile["impact_fx_kind"] = "crit"
		profile["projectile_tint"] = Color(1.0, 0.72, 0.35, 1.0)
	elif tier >= 3:
		profile["projectile_fps"] = 20.0
		profile["projectile_scale"] = 1.65
		profile["impact_fx_kind"] = "hero_energy_impact"
		profile["projectile_tint"] = Color(0.42, 0.95, 1.0, 1.0)
	if is_evolved:
		if evolution_id == "gatling":
			profile["projectile_fps"] = 26.0
			profile["projectile_scale"] = 1.12
			profile["impact_fx_kind"] = "fire_burst"
			profile["projectile_tint"] = Color(1.0, 0.65, 0.24, 1.0)
		elif evolution_id == "sniper":
			profile["impact_fx_kind"] = "hero_cannon_impact"
			profile["projectile_tint"] = Color(1.0, 0.4, 0.24, 1.0)
	return profile

func get_muzzle_fx_profile() -> Dictionary:
	var profile = {
		"core_color": Color(1.0, 0.95, 0.72, 0.95),
		"glow_color": Color(1.0, 0.62, 0.26, 0.76),
		"pulse_mult": 1.0,
		"beam_length_mult": 1.0,
		"beam_width_mult": 1.0,
		"ring_scale_mult": 1.0,
		"particle_mult": 1.0
	}
	if upgrade_level == 2:
		profile["pulse_mult"] = 1.1
		profile["beam_length_mult"] = 1.2
		profile["glow_color"] = Color(1.0, 0.55, 0.18, 0.82)
	elif upgrade_level >= 3:
		profile["pulse_mult"] = 1.22
		profile["beam_length_mult"] = 1.35
		profile["beam_width_mult"] = 1.1
		profile["core_color"] = Color(0.85, 0.98, 1.0, 0.98)
		profile["glow_color"] = Color(0.26, 0.88, 1.0, 0.84)
	if is_evolved and evolution_id == "gatling":
		profile["pulse_mult"] = 0.85
		profile["beam_length_mult"] = 0.92
		profile["beam_width_mult"] = 0.88
		profile["particle_mult"] = 1.25
		profile["core_color"] = Color(1.0, 0.85, 0.38, 0.92)
		profile["glow_color"] = Color(1.0, 0.48, 0.18, 0.72)
	elif is_evolved and evolution_id == "sniper":
		profile["pulse_mult"] = 1.45
		profile["beam_length_mult"] = 1.8
		profile["beam_width_mult"] = 1.25
		profile["ring_scale_mult"] = 1.25
		profile["particle_mult"] = 1.5
		profile["core_color"] = Color(1.0, 0.68, 0.45, 0.98)
		profile["glow_color"] = Color(1.0, 0.25, 0.18, 0.88)
	return profile

func _select_body_variant() -> String:
	if is_evolved:
		if evolution_id == "gatling":
			return "evo_gatling"
		if evolution_id == "sniper":
			return "evo_sniper"
	if upgrade_level >= 3:
		return "base_t3"
	if upgrade_level >= 2:
		return "base_t2"
	return "base_t1"

# The hand-drawn art is ~1254px square; the base tier-scale logic assumes small
# (~64px) sprites. After the base applies its tier scale we re-clamp the body to
# a sane world size that grows modestly per tier.
func _apply_tier_visuals_immediate(scale: float, element_color: Color) -> void:
	super._apply_tier_visuals_immediate(scale, element_color)
	_enforce_directional_scale()

func _enforce_directional_scale() -> void:
	if not _use_directional_art() or body_sprite == null:
		return
	var tier := clampi(upgrade_level, 1, 3)
	var s: float = DIRECTIONAL_BODY_SCALE * (1.0 + (tier - 1) * 0.12)
	body_sprite.scale = Vector2.ONE * s
	_sync_body_anim_base_scale(true)

# Distance from the tower centre to the ballista mouth, scaled with the body so
# the muzzle flare lands on the bow tip across tiers.
func _muzzle_flare_offset() -> float:
	var tier := clampi(upgrade_level, 1, 3)
	return 22.0 * (1.0 + (tier - 1) * 0.12)

func _refresh_body_frames(force: bool = false) -> void:
	if body_sprite == null:
		return
	var variant = _select_body_variant()
	if not force and variant == _active_body_variant:
		return
	if not MISSILE_BODY_VARIANTS.has(variant):
		return
	var paths: Array = MISSILE_BODY_VARIANTS.get(variant, [])
	if paths.is_empty():
		return
	var stable_frame_index = int(MISSILE_BODY_STABLE_FRAME_INDEX.get(variant, 0))
	stable_frame_index = clampi(stable_frame_index, 0, paths.size() - 1)
	var stable_path := str(paths[stable_frame_index])
	if stable_path == "" or not ResourceLoader.exists(stable_path):
		return
	var stable_tex = load(stable_path)
	if not (stable_tex is Texture2D):
		return
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("default")
	frames.set_animation_speed("default", 1.0)
	frames.set_animation_loop("default", true)
	frames.add_frame("default", stable_tex)
	body_sprite.sprite_frames = frames
	body_sprite.animation = "default"
	body_sprite.stop()
	body_sprite.frame = 0
	_active_body_variant = variant
	if _glow_sprite != null and body_sprite.sprite_frames != null and body_sprite.sprite_frames.get_frame_count("default") > 0:
		_glow_sprite.texture = body_sprite.sprite_frames.get_frame_texture("default", 0)
	_sync_body_anim_base_scale(true)
	refresh_body_presentation(true)

func get_evolution_options() -> Array:
	return [
		{
			"id": "gatling",
			"name": "Gatling Turret",
			"desc": "Rapid fire that spins up over 2s. Lower damage, overwhelming volume.",
			"cost": 3
		},
		{
			"id": "sniper",
			"name": "Sniper Turret",
			"desc": "Massive single-target damage. Infinite pierce hitscan. Extended range.",
			"cost": 3
		}
	]

func _apply_evolution_stats() -> void:
	match evolution_id:
		"gatling":
			_gatling_base_rate = fire_rate
			fire_rate = 4.0
			damage = 8.0
			pierce_count = 1
			projectile_speed = 1200.0
		"sniper":
			fire_rate = 0.3
			damage = 85.0
			range = 600.0
			projectile_range = 700.0
			pierce_count = 999  # Infinite pierce

func _apply_evolution_visuals() -> void:
	# The final evolution KEEPS the most-upgraded base tower art (the baked
	# directional T3 look) rather than swapping to separate evo art. It's
	# distinguished — like the cannon — by a per-evolution color tint plus a slow
	# pulsating glow. So we keep directional art active and re-assert the highest
	# tier frame at its normal directional scale.
	if _use_directional_art_when_evolved():
		_directional_active = true
		_apply_directional_body(_dir_key_for(_last_fire_dir), true)
		_enforce_directional_scale_evolved()
	else:
		# No directional art available: keep whatever body frames exist visible.
		_setup_body_presentation()
		_refresh_body_frames(true)
		if body_sprite != null:
			body_sprite.scale = Vector2.ONE * EVOLVED_BODY_SCALE
			body_sprite.visible = true
			_sync_body_anim_base_scale(true)
		_ensure_evolution_body_visible()
	# Per-evolution tint + pulsating glow on the (most-upgraded) body art.
	match evolution_id:
		"gatling":
			_start_evolution_pulse(EVO_TINT_GATLING)
			# Hide crystal and arrows, they don't fit gatling
			if _crystal_core != null:
				_crystal_core.visible = false
			for arrow in _floating_arrows:
				if arrow != null:
					arrow.visible = false
		"sniper":
			_start_evolution_pulse(EVO_TINT_SNIPER)
			# Create laser sight line (start empty + hidden so it never renders a
			# stray segment toward the origin before the first target update).
			_sniper_laser_line = Line2D.new()
			_sniper_laser_line.width = 1.0
			_sniper_laser_line.default_color = Color(1.0, 0.15, 0.1, 0.35)
			_sniper_laser_line.z_index = 15
			_sniper_laser_line.points = PackedVector2Array()
			_sniper_laser_line.visible = false
			add_child(_sniper_laser_line)
			# Hide crystal and arrows
			if _crystal_core != null:
				_crystal_core.visible = false
			for arrow in _floating_arrows:
				if arrow != null:
					arrow.visible = false

# Whether the evolved tower should reuse the baked directional art. True when the
# directional set loaded (the normal case); _use_directional_art() itself returns
# false once is_evolved, so this is a dedicated check that ignores is_evolved.
func _use_directional_art_when_evolved() -> bool:
	return not _dir_tex_t1.is_empty()

# Re-clamp the directional body to the highest-tier world scale (T3 = tier 2 art
# scale step) so the evolved tower matches the most-upgraded base footprint.
func _enforce_directional_scale_evolved() -> void:
	if body_sprite == null:
		return
	var tier := clampi(upgrade_level, 1, 3)
	var s: float = DIRECTIONAL_BODY_SCALE * (1.0 + (tier - 1) * 0.12)
	body_sprite.scale = Vector2.ONE * s
	body_sprite.visible = true
	_sync_body_anim_base_scale(true)

# Slow, looping brightness pulse on the body, tinted by the evolution. Mirrors the
# cannon's "tint to signal evolution" approach but adds the pulsate the user asked
# for so the final form reads as a charged-up version of the top-tier tower.
func _start_evolution_pulse(tint: Color) -> void:
	if body_sprite == null:
		return
	if _evo_pulse_tween != null:
		_evo_pulse_tween.kill()
		_evo_pulse_tween = null
	body_sprite.modulate = tint
	if not is_inside_tree():
		return
	var dim := tint
	var bright := Color(tint.r * 1.35, tint.g * 1.35, tint.b * 1.35, tint.a)
	_evo_pulse_tween = create_tween()
	_evo_pulse_tween.set_loops()
	_evo_pulse_tween.tween_property(body_sprite, "modulate", bright, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_evo_pulse_tween.tween_property(body_sprite, "modulate", dim, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Guarantees the evolved arrow tower has a visible body even though its dedicated
# evo flipbook art isn't authored. If _refresh_body_frames() couldn't load any
# frame, build a one-frame SpriteFrames from the best available directional art
# (T2 preferred, then T1) so the tower never renders blank.
func _ensure_evolution_body_visible() -> void:
	if body_sprite == null:
		return
	var has_frame := false
	if body_sprite.sprite_frames != null and body_sprite.sprite_frames.has_animation("default"):
		has_frame = body_sprite.sprite_frames.get_frame_count("default") > 0
	if has_frame:
		body_sprite.visible = true
		return
	# Pick a fallback texture from the authored directional sets (front-facing S view).
	var tex: Texture2D = null
	var set_t2 := _dir_tex_t2
	var set_t1 := _dir_tex_t1
	if set_t2.has("S"):
		tex = set_t2["S"]
	elif set_t1.has("S"):
		tex = set_t1["S"]
	elif not set_t1.is_empty():
		tex = set_t1[set_t1.keys()[0]]
	if tex == null:
		return
	var frames := SpriteFrames.new()
	# SpriteFrames ships with a built-in "default" animation; re-adding it logs
	# "already has animation 'default'", so only add it if somehow missing.
	if not frames.has_animation("default"):
		frames.add_animation("default")
	frames.set_animation_speed("default", 1.0)
	frames.set_animation_loop("default", false)
	frames.add_frame("default", tex)
	body_sprite.sprite_frames = frames
	body_sprite.animation = "default"
	body_sprite.stop()
	body_sprite.frame = 0
	body_sprite.visible = true
	# Scale the large (~1254px) iso art down to the same world size the base tower
	# uses so the evolved tower matches its footprint instead of dwarfing the map.
	body_sprite.scale = Vector2.ONE * (DIRECTIONAL_BODY_SCALE * (1.0 + 2 * 0.12))
	if _glow_sprite != null:
		_glow_sprite.texture = tex
	_sync_body_anim_base_scale(true)

static func _get_crystal_tex() -> ImageTexture:
	if _shared_crystal_tex != null:
		return _shared_crystal_tex
	var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(12, 12)
	for x in range(24):
		for y in range(24):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 10:
				var intensity = 1.0 - (dist / 10.0)
				img.set_pixel(x, y, Color(0.2, 0.95, 0.3, intensity * 0.9))
	_shared_crystal_tex = ImageTexture.create_from_image(img)
	return _shared_crystal_tex

static func _get_arrow_tex() -> ImageTexture:
	if _shared_arrow_tex != null:
		return _shared_arrow_tex
	var img = Image.create(12, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(12):
		for y in range(16):
			if y < 6 and abs(x - 6) < (6 - y) * 0.8:
				img.set_pixel(x, y, Color(0.9, 0.95, 0.9, 1.0))
			if y >= 6 and y < 14 and abs(x - 6) < 2:
				img.set_pixel(x, y, Color(0.8, 0.9, 0.8, 1.0))
			if y >= 14 and abs(x - 6) < 4:
				img.set_pixel(x, y, Color(0.6, 0.8, 0.6, 0.9))
	_shared_arrow_tex = ImageTexture.create_from_image(img)
	return _shared_arrow_tex

func _setup_tower_specific_visuals() -> void:
	# Legacy T2 gray "metal bands" overlay + T3 pulsing crystal core + orbiting
	# "floating arrows" removed (the baked directional art already depicts each
	# tier's upgraded look).
	pass

func _update_tower_specific_visuals() -> void:
	if _use_directional_art():
		_enforce_directional_scale()
		# Tier may have changed (e.g. upgraded to lvl 2): force the baked iso frame
		# to re-apply so the new-tier art swaps in immediately, then let _process
		# resume per-heading swapping.
		_current_dir_key = ""
		_apply_directional_body(_dir_key_for(_last_fire_dir), true)
	else:
		_refresh_body_frames()
	if not is_inside_tree():
		return

	# Legacy T2 gray metal-bands + T3 crystal/orbiting-arrow reveal removed.

func _play_tower_specific_upgrade_effects() -> void:
	# Legacy T2 gray metal-bands shimmer removed; baked directional art handles
	# the upgraded look.
	pass

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	pierce_count = int(tier_data.get("pierce_count", 1))

func _process(delta: float) -> void:
	super._process(delta)

	# Directional base art: swap to the baked iso frame nearest the aim heading.
	if _directional_active and not is_evolved:
		_apply_directional_body(_dir_key_for(_last_fire_dir))

	# Gatling spin-up mechanic
	if is_evolved and evolution_id == "gatling":
		if _gatling_firing:
			_gatling_spin_time = min(_gatling_spin_time + delta, _gatling_max_spin)
			_gatling_idle_timer = 0.0
		else:
			_gatling_idle_timer += delta
			if _gatling_idle_timer > 0.5:
				_gatling_spin_time = max(0.0, _gatling_spin_time - delta * 2.0)
		_gatling_firing = false
		# Spin-up only drives the effective fire rate; the body itself is a
		# front-facing flipbook and must not be rotated (caused visible wobble).
		var spin_pct = _gatling_spin_time / _gatling_max_spin
		# Adjust effective fire rate based on spin
		fire_rate = lerpf(_gatling_base_rate, _gatling_max_rate, spin_pct)

	# Sniper laser sight
	if is_evolved and evolution_id == "sniper" and _sniper_laser_line != null:
		var enemies = _get_enemies()
		var closest: Node2D = null
		var closest_dist = range * range
		for enemy in enemies:
			if enemy == null or not is_instance_valid(enemy):
				continue
			var d = global_position.distance_squared_to(enemy.global_position)
			if d < closest_dist:
				closest_dist = d
				closest = enemy
		if closest != null:
			var dir = (closest.global_position - global_position).normalized()
			_sniper_laser_line.points = [Vector2.ZERO, dir * range]
			_sniper_laser_line.default_color.a = 0.2 + sin(Time.get_ticks_msec() * 0.005) * 0.1
			_sniper_laser_line.visible = true
		else:
			_sniper_laser_line.points = PackedVector2Array()
			_sniper_laser_line.visible = false

func _fire_at(target: Node2D) -> void:
	if _game == null:
		return

	# Sniper evolution: hitscan line
	if is_evolved and evolution_id == "sniper":
		_fire_sniper(target)
		return

	# Gatling evolution: mark as firing for spin-up
	if is_evolved and evolution_id == "gatling":
		_gatling_firing = true
		_trigger_fire_motion(0.7)
	else:
		_trigger_fire_motion(0.95)

	var dir = (target.global_position - global_position).normalized()
	_spawn_tower_fire_emitter(dir, 0.72 if (is_evolved and evolution_id == "gatling") else 0.95)
	var dmg_bonus = 0.0
	if _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()

	# Get multishot level and angles
	var level = 0
	if _game.has_method("get_tech_level"):
		level = _game.get_tech_level("arrow_fan")
	var extra_angles: Array[float] = []
	if not is_evolved:  # Fan only for non-evolved
		if level == 1:
			extra_angles = [-0.2, 0.2]
		elif level == 2:
			extra_angles = [-0.35, -0.15, 0.15, 0.35]
		elif level >= 3:
			extra_angles = [-0.5, -0.3, -0.1, 0.1, 0.3, 0.5]

	# Spawn multishot indicator if we have spread shots
	if extra_angles.size() > 0 and _game != null and _game.fx_manager != null:
		_game.fx_manager.spawn_multishot_indicator(global_position, dir, extra_angles)

	# Spawn main projectile with pierce capability
	var projectile_profile = get_projectile_visual_profile()
	_game.spawn_projectile(global_position, dir, projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius, pierce_count, 1.0, 0.0, "normal", projectile_profile)

	# Spawn extra projectiles
	for angle in extra_angles:
		_game.spawn_projectile(global_position, dir.rotated(angle), projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius, pierce_count, 1.0, 0.0, "normal", projectile_profile)
	AudioManager.play_weapon_sound(tower_type, global_position)

	# Directional base art: pop an oriented muzzle flare from the ballista mouth so
	# the shot reads as launching from the tower itself.
	if _directional_active and not is_evolved and _game.has_method("spawn_muzzle_flash"):
		_game.spawn_muzzle_flash(global_position + dir * _muzzle_flare_offset(), dir)

	# Gatling muzzle flash
	if is_evolved and evolution_id == "gatling" and _game.has_method("spawn_fx"):
		_game.spawn_fx("hit", global_position + dir * 12.0)

func _fire_sniper(target: Node2D) -> void:
	_trigger_fire_motion(1.35)
	var dir = (target.global_position - global_position).normalized()
	_spawn_tower_fire_emitter(dir, 1.28)
	var dmg_bonus = 0.0
	if _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()

	# Hitscan: damage ALL enemies in a line
	var total_dmg = damage + dmg_bonus
	var enemies = _get_enemies()
	var hit_count = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		# Check if enemy is roughly on the line (within 20px perpendicular distance)
		var to_enemy = enemy.global_position - global_position
		var proj = to_enemy.dot(dir)
		if proj < 0 or proj > range:
			continue
		var perp_dist = abs(to_enemy.cross(dir))
		if perp_dist < 20.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(total_dmg, enemy.global_position, false, false)
			hit_count += 1

	# Visual: bright line flash
	if _sniper_laser_line != null and is_inside_tree():
		_sniper_laser_line.default_color = Color(1.0, 0.3, 0.2, 0.9)
		_sniper_laser_line.width = 3.0
		_sniper_laser_line.points = [Vector2.ZERO, dir * range]
		var tween = create_tween()
		tween.tween_property(_sniper_laser_line, "default_color:a", 0.2, 0.15)
		tween.parallel().tween_property(_sniper_laser_line, "width", 1.0, 0.15)

	# Screen shake for sniper
	if _game.has_method("shake_camera"):
		_game.shake_camera(3.0, 0.1)
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("crit", global_position + dir * 16.0)
	AudioManager.play_weapon_sound(tower_type, global_position)
