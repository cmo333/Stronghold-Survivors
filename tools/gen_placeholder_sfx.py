#!/usr/bin/env python3
"""
Placeholder SFX generator for Stronghold Survivors.

Synthesizes short, characterful 16-bit mono WAV files using only the Python
standard library (no numpy). These are intentionally simple stand-ins so the
already-wired AudioManager turns on and the game stops being silent. Swap in
real audio later by overwriting the same filenames.

Filenames/paths match exactly what scripts/audio_manager.gd::_cache_sounds()
loads, so no code changes are required to enable audio.
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100
BASE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


# ----------------------------------------------------------------------------
# Low-level synthesis helpers (operate on lists of floats in [-1, 1])
# ----------------------------------------------------------------------------

def _n(seconds):
    return int(SAMPLE_RATE * seconds)


def sine(freq, seconds, amp=1.0, phase=0.0):
    out = []
    for i in range(_n(seconds)):
        t = i / SAMPLE_RATE
        out.append(amp * math.sin(2.0 * math.pi * freq * t + phase))
    return out


def noise(seconds, amp=1.0):
    return [amp * (random.random() * 2.0 - 1.0) for _ in range(_n(seconds))]


def silence(seconds):
    return [0.0] * _n(seconds)


def mix(*tracks):
    """Sum several equal-or-different-length tracks (zero-padded)."""
    length = max((len(t) for t in tracks), default=0)
    out = [0.0] * length
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def concat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def env_ad(samples, attack, decay, sustain_level=0.0, release=0.0):
    """Apply an attack/decay (and optional release) amplitude envelope in-place style."""
    n = len(samples)
    a = _n(attack)
    d = _n(decay)
    r = _n(release)
    out = [0.0] * n
    for i in range(n):
        if i < a and a > 0:
            g = i / a
        elif i < a + d and d > 0:
            g = 1.0 - (1.0 - sustain_level) * ((i - a) / d)
        elif i >= n - r and r > 0:
            g = sustain_level * ((n - i) / r)
        else:
            g = sustain_level
        out[i] = samples[i] * g
    return out


def exp_decay(samples, tau=0.12):
    """Exponential amplitude decay across the whole buffer."""
    out = [0.0] * len(samples)
    for i, v in enumerate(samples):
        t = i / SAMPLE_RATE
        out[i] = v * math.exp(-t / tau)
    return out


def pitch_sweep(f_start, f_end, seconds, amp=1.0):
    """Linear-frequency sweep sine (chirp)."""
    out = []
    n = _n(seconds)
    phase = 0.0
    for i in range(n):
        frac = i / max(1, n)
        freq = f_start + (f_end - f_start) * frac
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        out.append(amp * math.sin(phase))
    return out


def lowpass(samples, alpha=0.25):
    """One-pole lowpass to dull harsh noise."""
    out = [0.0] * len(samples)
    prev = 0.0
    for i, v in enumerate(samples):
        prev = prev + alpha * (v - prev)
        out[i] = prev
    return out


def normalize(samples, peak=0.85):
    m = max((abs(v) for v in samples), default=0.0)
    if m <= 1e-9:
        return samples
    g = peak / m
    return [v * g for v in samples]


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    samples = normalize(samples, 0.85)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for v in samples:
            clamped = max(-1.0, min(1.0, v))
            frames += struct.pack("<h", int(clamped * 32767))
        w.writeframes(bytes(frames))


# ----------------------------------------------------------------------------
# Individual sound designs
# ----------------------------------------------------------------------------

def s_gun_fire(variant):
    base = 220 + variant * 30
    body = exp_decay(mix(
        pitch_sweep(base * 3, base, 0.09, 0.6),
        lowpass(noise(0.09, 0.5), 0.4),
    ), tau=0.04)
    return env_ad(body, 0.001, 0.08)


def s_cannon_boom():
    boom = exp_decay(mix(
        sine(70, 0.45, 0.9),
        pitch_sweep(160, 45, 0.45, 0.5),
        lowpass(noise(0.45, 0.6), 0.15),
    ), tau=0.16)
    return env_ad(boom, 0.002, 0.44)


def s_lightning_crack():
    crackle = lowpass(noise(0.28, 1.0), 0.7)
    tone = mix(sine(1400, 0.28, 0.25), sine(2300, 0.28, 0.15))
    body = exp_decay(mix(crackle, tone), tau=0.07)
    return env_ad(body, 0.0008, 0.26)


def s_arrow_shoot():
    body = exp_decay(mix(
        pitch_sweep(900, 1700, 0.06, 0.5),
        lowpass(noise(0.06, 0.4), 0.5),
    ), tau=0.03)
    return env_ad(body, 0.001, 0.05)


def s_enemy_hit(variant):
    base = 150 + variant * 40
    body = exp_decay(mix(
        sine(base, 0.12, 0.7),
        lowpass(noise(0.12, 0.6), 0.3),
    ), tau=0.05)
    return env_ad(body, 0.001, 0.11)


def s_crit_hit():
    body = exp_decay(mix(
        sine(880, 0.18, 0.5),
        sine(1320, 0.18, 0.35),
        pitch_sweep(600, 1800, 0.05, 0.4),
        lowpass(noise(0.10, 0.4), 0.4),
    ), tau=0.07)
    return env_ad(body, 0.0008, 0.17)


def s_enemy_death(variant):
    base = 120 + variant * 25
    body = exp_decay(mix(
        pitch_sweep(base * 2, base * 0.4, 0.3, 0.7),
        lowpass(noise(0.3, 0.7), 0.25),
    ), tau=0.11)
    return env_ad(body, 0.002, 0.28)


def s_building_hit():
    body = exp_decay(mix(
        sine(90, 0.16, 0.8),
        lowpass(noise(0.16, 0.5), 0.2),
    ), tau=0.06)
    return env_ad(body, 0.001, 0.15)


def s_shield_hit():
    body = exp_decay(mix(
        sine(520, 0.16, 0.5),
        sine(780, 0.16, 0.3),
        lowpass(noise(0.10, 0.3), 0.5),
    ), tau=0.06)
    return env_ad(body, 0.001, 0.15)


def s_ui_click():
    body = exp_decay(sine(660, 0.05, 0.7), tau=0.02)
    return env_ad(body, 0.001, 0.045)


def s_ui_hover():
    body = exp_decay(sine(440, 0.04, 0.5), tau=0.02)
    return env_ad(body, 0.001, 0.035)


def s_ui_error():
    body = exp_decay(mix(sine(160, 0.18, 0.7), sine(120, 0.18, 0.5)), tau=0.08)
    return env_ad(body, 0.001, 0.17)


def s_upgrade():
    return concat(
        env_ad(exp_decay(sine(523, 0.10, 0.6), tau=0.05), 0.002, 0.09),
        env_ad(exp_decay(sine(659, 0.10, 0.6), tau=0.05), 0.002, 0.09),
        env_ad(exp_decay(sine(784, 0.14, 0.6), tau=0.06), 0.002, 0.13),
    )


def s_level_up():
    return concat(
        env_ad(exp_decay(sine(523, 0.10, 0.6), tau=0.05), 0.002, 0.09),
        env_ad(exp_decay(sine(659, 0.10, 0.6), tau=0.05), 0.002, 0.09),
        env_ad(exp_decay(sine(784, 0.10, 0.6), tau=0.05), 0.002, 0.09),
        env_ad(exp_decay(sine(1046, 0.20, 0.7), tau=0.10), 0.002, 0.19),
    )


def s_wave_start():
    return concat(
        env_ad(exp_decay(sine(330, 0.16, 0.7), tau=0.08), 0.003, 0.15),
        env_ad(exp_decay(sine(247, 0.24, 0.7), tau=0.12), 0.003, 0.23),
    )


def s_chest_open():
    return concat(
        env_ad(exp_decay(sine(392, 0.12, 0.5), tau=0.06), 0.002, 0.11),
        env_ad(exp_decay(mix(sine(659, 0.25, 0.5), sine(988, 0.25, 0.35)), tau=0.12), 0.002, 0.24),
    )


def s_powerup_spawn():
    return env_ad(pitch_sweep(300, 900, 0.35, 0.6), 0.01, 0.34)


def s_powerup_pickup():
    return concat(
        env_ad(exp_decay(sine(784, 0.08, 0.6), tau=0.04), 0.002, 0.07),
        env_ad(exp_decay(sine(1175, 0.14, 0.6), tau=0.07), 0.002, 0.13),
    )


def s_generator_destroyed():
    body = exp_decay(mix(
        pitch_sweep(300, 50, 0.5, 0.7),
        lowpass(noise(0.5, 0.7), 0.2),
        sine(60, 0.5, 0.6),
    ), tau=0.18)
    return env_ad(body, 0.002, 0.48)


def s_heartbeat():
    beat = env_ad(exp_decay(sine(60, 0.18, 0.9), tau=0.07), 0.004, 0.17)
    return concat(beat, silence(0.12), beat, silence(0.45))


def s_game_over():
    return concat(
        env_ad(exp_decay(sine(196, 0.30, 0.7), tau=0.15), 0.004, 0.29),
        env_ad(exp_decay(sine(147, 0.30, 0.7), tau=0.15), 0.004, 0.29),
        env_ad(exp_decay(sine(98, 0.55, 0.8), tau=0.28), 0.004, 0.54),
    )


def s_victory():
    return concat(
        env_ad(exp_decay(sine(523, 0.14, 0.6), tau=0.07), 0.003, 0.13),
        env_ad(exp_decay(sine(659, 0.14, 0.6), tau=0.07), 0.003, 0.13),
        env_ad(exp_decay(sine(784, 0.14, 0.6), tau=0.07), 0.003, 0.13),
        env_ad(exp_decay(mix(sine(1046, 0.4, 0.6), sine(784, 0.4, 0.4)), tau=0.2), 0.003, 0.39),
    )


def s_berserk_activate():
    body = exp_decay(mix(
        pitch_sweep(120, 320, 0.4, 0.7),
        lowpass(noise(0.4, 0.5), 0.3),
    ), tau=0.2)
    return env_ad(body, 0.005, 0.39)


# ----------------------------------------------------------------------------
# Manifest: maps output path -> generator
# ----------------------------------------------------------------------------

FILES = {
    "sfx/gun_fire_01.wav": lambda: s_gun_fire(0),
    "sfx/gun_fire_02.wav": lambda: s_gun_fire(1),
    "sfx/gun_fire_03.wav": lambda: s_gun_fire(2),
    "sfx/cannon_boom.wav": s_cannon_boom,
    "sfx/lightning_crack.wav": s_lightning_crack,
    "sfx/arrow_shoot.wav": s_arrow_shoot,
    "sfx/enemy_hit_01.wav": lambda: s_enemy_hit(0),
    "sfx/enemy_hit_02.wav": lambda: s_enemy_hit(1),
    "sfx/enemy_hit_03.wav": lambda: s_enemy_hit(2),
    "sfx/crit_hit.wav": s_crit_hit,
    "sfx/enemy_death_01.wav": lambda: s_enemy_death(0),
    "sfx/enemy_death_02.wav": lambda: s_enemy_death(1),
    "sfx/enemy_death_03.wav": lambda: s_enemy_death(2),
    "sfx/building_hit.wav": s_building_hit,
    "sfx/shield_hit.wav": s_shield_hit,
    "ui/click.wav": s_ui_click,
    "ui/hover.wav": s_ui_hover,
    "ui/upgrade.wav": s_upgrade,
    "ui/error.wav": s_ui_error,
    "ui/wave_start.wav": s_wave_start,
    "ui/level_up.wav": s_level_up,
    "special/chest_open.wav": s_chest_open,
    "special/powerup_spawn.wav": s_powerup_spawn,
    "special/powerup_pickup.wav": s_powerup_pickup,
    "special/generator_destroyed.wav": s_generator_destroyed,
    "special/heartbeat.wav": s_heartbeat,
    "special/game_over.wav": s_game_over,
    "special/victory.wav": s_victory,
    "special/berserk_activate.wav": s_berserk_activate,
}


def main():
    random.seed(1337)  # deterministic placeholders
    count = 0
    for rel, gen in FILES.items():
        path = os.path.join(BASE_DIR, rel)
        write_wav(path, gen())
        count += 1
        print("wrote", rel)
    print("\nGenerated %d placeholder SFX into %s" % (count, BASE_DIR))


if __name__ == "__main__":
    main()
