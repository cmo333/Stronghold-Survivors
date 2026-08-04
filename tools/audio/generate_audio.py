#!/usr/bin/env python3
"""Procedural audio generator for Stronghold Survivors.

Synthesizes the complete SFX + music set from scratch (numpy + soundfile).
Everything is tuned around A minor so the whole soundscape hangs together.

Usage:
    pip install numpy soundfile
    python3 tools/audio/generate_audio.py

Outputs WAV SFX into assets/audio/{sfx,ui,ambient,special}/ and OGG music
loops into assets/audio/music/.
"""
import os
import numpy as np
import soundfile as sf
from scipy.signal import lfilter

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(1337)  # deterministic output


# ---------------------------------------------------------------- primitives
def t(dur):
    return np.arange(int(SR * dur)) / SR


def sine(freq, dur, phase=0.0):
    return np.sin(2 * np.pi * freq * t(dur) + phase)


def sweep(f0, f1, dur, curve=1.0):
    """Sine with exponential pitch glide f0 -> f1."""
    x = t(dur)
    k = np.linspace(0, 1, x.size) ** curve
    freq = f0 * (f1 / f0) ** k
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase)


def square(freq, dur, duty=0.5):
    x = (t(dur) * freq) % 1.0
    return np.where(x < duty, 1.0, -1.0)


def square_sweep(f0, f1, dur):
    x = t(dur)
    k = np.linspace(0, 1, x.size)
    freq = f0 * (f1 / f0) ** k
    phase = np.cumsum(freq) / SR
    return np.where((phase % 1.0) < 0.5, 1.0, -1.0)


def saw(freq, dur, detune=0.0):
    ph = (t(dur) * freq * (1 + detune)) % 1.0
    return 2 * ph - 1


def tri(freq, dur):
    ph = (t(dur) * freq) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def env_exp(dur, k=8.0):
    """Exponential decay envelope."""
    return np.exp(-k * np.linspace(0, 1, int(SR * dur)))


def env_adsr(dur, a=0.005, d=0.05, s=0.6, r=0.1):
    n = int(SR * dur)
    na, nd, nr = int(SR * a), int(SR * d), int(SR * r)
    ns = max(0, n - na - nd - nr)
    e = np.concatenate([
        np.linspace(0, 1, max(na, 1)),
        np.linspace(1, s, max(nd, 1)),
        np.full(ns, s),
        np.linspace(s, 0, max(nr, 1)),
    ])
    return e[:n] if e.size >= n else np.pad(e, (0, n - e.size))


def lp(x, cutoff):
    """One-pole lowpass."""
    dt = 1.0 / SR
    rc = 1.0 / (2 * np.pi * max(cutoff, 10.0))
    a = dt / (rc + dt)
    return lfilter([a], [1.0, -(1.0 - a)], x)


def hp(x, cutoff):
    return x - lp(x, cutoff)


def bandpass(x, lo, hi):
    return lp(hp(x, lo), hi)


def softclip(x, drive=1.5):
    return np.tanh(x * drive)


def bitcrush(x, bits=6):
    q = 2 ** (bits - 1)
    return np.round(x * q) / q


def echo(x, delay=0.12, fb=0.35, mix=0.3, taps=3):
    n = int(SR * delay)
    out = np.copy(x)
    pad = np.zeros(n * taps)
    out = np.concatenate([out, pad])
    wet = np.zeros_like(out)
    sig = np.concatenate([x, pad])
    for i in range(1, taps + 1):
        wet[n * i:] += sig[:sig.size - n * i] * (fb ** i)
    return out + wet * mix


def normalize(x, peak=0.72):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 1e-9 else x


def fade(x, fin=0.002, fout=0.01):
    nf, no = int(SR * fin), int(SR * fout)
    if nf > 0 and x.size > nf:
        x[:nf] *= np.linspace(0, 1, nf)
    if no > 0 and x.size > no:
        x[-no:] *= np.linspace(1, 0, no)
    return x


def mix(*layers):
    n = max(l.size for l in layers)
    out = np.zeros(n)
    for l in layers:
        out[:l.size] += l
    return out


def save(rel, x, peak=0.72):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = fade(normalize(np.asarray(x, dtype=np.float64), peak))
    sf.write(path, data.astype(np.float32), SR, subtype="PCM_16")
    print(f"  {rel}  ({data.size / SR:.2f}s)")


def save_ogg(rel, x, peak=0.6):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    m = np.max(np.abs(x))
    if m > 1e-9:
        x = x * (peak / m)
    sf.write(path, x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print(f"  {rel}  ({x.shape[0] / SR:.2f}s)")


# A minor reference pitches
A2, A3, A4 = 110.0, 220.0, 440.0
NOTE = lambda semi, base=A3: base * 2 ** (semi / 12.0)  # noqa: E731


# ---------------------------------------------------------------- weapons
def gun_fire(seed_pitch):
    """Punchy retro gunshot: noise crack + descending square blip."""
    crack = hp(noise(0.07), 900) * env_exp(0.07, 26)
    blip = square_sweep(720 * seed_pitch, 140, 0.09) * env_exp(0.09, 30) * 0.5
    thump = sweep(180, 60, 0.08) * env_exp(0.08, 22) * 0.8
    return softclip(mix(crack, blip, thump), 2.2)


def make_weapons():
    save("sfx/gun_fire_01.wav", gun_fire(1.00), 0.62)
    save("sfx/gun_fire_02.wav", gun_fire(1.09), 0.62)
    save("sfx/gun_fire_03.wav", gun_fire(0.93), 0.62)

    # Arrow: airy whoosh with a snap release
    snap = hp(noise(0.03), 2000) * env_exp(0.03, 40)
    whoosh = bandpass(noise(0.16), 700, 3800) * env_adsr(0.16, 0.004, 0.05, 0.4, 0.08)
    save("sfx/arrow_shoot.wav", softclip(mix(snap, whoosh * 0.8), 1.8), 0.55)

    # Cannon: deep boom with body and tail
    body = sweep(120, 34, 0.55, curve=0.6) * env_exp(0.55, 7)
    burst = lp(noise(0.4), 900) * env_exp(0.4, 10)
    crackle = hp(noise(0.12), 1500) * env_exp(0.12, 18) * 0.5
    save("sfx/cannon_boom.wav", softclip(mix(body * 1.2, burst, crackle), 2.5), 0.82)

    # Tesla: crackling zap
    n = noise(0.28)
    zap = hp(n, 2400) * env_exp(0.28, 12)
    buzz = square_sweep(1600, 300, 0.22) * env_exp(0.22, 14) * 0.35
    sparkle = hp(noise(0.28), 5000) * (rng.uniform(0, 1, zap.size) > 0.86) * env_exp(0.28, 10)
    save("sfx/lightning_crack.wav", softclip(mix(zap, buzz, sparkle * 0.7), 2.0), 0.6)

    # Mortar: hollow thoomp
    thoomp = sweep(220, 55, 0.3, curve=0.5) * env_exp(0.3, 10)
    puff = lp(noise(0.25), 600) * env_exp(0.25, 12)
    save("sfx/mortar_fire.wav", softclip(mix(thoomp, puff * 0.8), 2.0), 0.7)


# ---------------------------------------------------------------- impacts
def make_impacts():
    for i, p in enumerate([1.0, 1.12, 0.9], start=1):
        thock = tri(190 * p, 0.07) * env_exp(0.07, 30)
        grit = bandpass(noise(0.05), 400, 2600) * env_exp(0.05, 34)
        save(f"sfx/enemy_hit_0{i}.wav", softclip(mix(thock, grit * 0.9), 2.0), 0.5)

    # Crit: brighter, ringing zing on top
    zing = sweep(1400, 2600, 0.09) * env_exp(0.09, 24) * 0.5
    punch = tri(240, 0.09) * env_exp(0.09, 26)
    grit = hp(noise(0.07), 1800) * env_exp(0.07, 28)
    save("sfx/crit_hit.wav", softclip(mix(punch, grit, zing), 2.2), 0.62)

    # Deaths: squelchy downward splat
    for i, p in enumerate([1.0, 1.15, 0.85], start=1):
        splat = lp(noise(0.2), 1200 * p) * env_exp(0.2, 14)
        drop = sweep(300 * p, 70, 0.18) * env_exp(0.18, 12) * 0.9
        gurgle = tri(90 * p, 0.16) * sine(28, 0.16) * env_exp(0.16, 10) * 0.6
        save(f"sfx/enemy_death_0{i}.wav", softclip(mix(splat, drop, gurgle), 2.0), 0.56)

    # Heavy hit (boss slams)
    slam = sweep(150, 40, 0.35, curve=0.5) * env_exp(0.35, 9)
    crunch = lp(noise(0.22), 800) * env_exp(0.22, 14)
    save("sfx/heavy_hit.wav", softclip(mix(slam * 1.2, crunch), 2.4), 0.78)

    # Building hit: woody knock
    knock = tri(140, 0.09) * env_exp(0.09, 28)
    tok = sine(300, 0.04) * env_exp(0.04, 40) * 0.6
    save("sfx/building_hit.wav", softclip(mix(knock, tok), 1.8), 0.5)

    # Shield hit: metallic inharmonic ping
    ping = mix(*[sine(f, 0.22) * env_exp(0.22, 16) * a for f, a in
                 [(620, 1.0), (1710, 0.55), (2390, 0.4), (3170, 0.25)]])
    save("sfx/shield_hit.wav", softclip(ping, 1.4), 0.5)

    # Shield break: glassy shatter
    parts = []
    for k in range(7):
        d = 0.03 + 0.02 * k
        f = 2200 - 220 * k
        frag = sine(f * rng.uniform(0.9, 1.1), 0.1) * env_exp(0.1, 30)
        parts.append(np.concatenate([np.zeros(int(SR * d * 0.4)), frag]))
    crash = hp(noise(0.3), 1400) * env_exp(0.3, 12)
    save("sfx/shield_break.wav", softclip(mix(crash, *[p * 0.5 for p in parts]), 1.8), 0.66)

    # Shield restore: soft rising shimmer
    rise = sweep(400, 900, 0.4) * env_adsr(0.4, 0.05, 0.1, 0.7, 0.2) * 0.7
    shimmer = mix(sine(NOTE(0, A4), 0.4), sine(NOTE(7, A4), 0.4)) * env_adsr(0.4, 0.1, 0.1, 0.5, 0.2) * 0.3
    save("sfx/shield_restore.wav", mix(rise, shimmer), 0.5)

    # Poison hit: bubbly squelch
    wob = sine(160, 0.22, 0) * (1 + 0.6 * sine(23, 0.22)) * env_exp(0.22, 12)
    blub = lp(noise(0.2), 700) * (0.5 + 0.5 * sine(31, 0.2)) * env_exp(0.2, 12)
    save("sfx/poison_hit.wav", softclip(mix(wob, blub), 2.0), 0.5)


# ---------------------------------------------------------------- explosions
def explosion(dur, f0, f1, brightness, peak):
    body = sweep(f0, f1, dur, curve=0.55) * env_exp(dur, 6.5)
    burst = lp(noise(dur * 0.8), brightness) * env_exp(dur * 0.8, 8)
    crackle = hp(noise(dur * 0.4), 1200) * env_exp(dur * 0.4, 12) * 0.5
    x = softclip(mix(body * 1.25, burst, crackle), 2.6)
    return x, peak


def make_explosions():
    x, p = explosion(0.5, 140, 38, 1000, 0.78)
    save("sfx/explosion.wav", x, p)
    x, p = explosion(0.9, 110, 26, 700, 0.85)
    save("sfx/explosion_large.wav", echo(x, 0.09, 0.3, 0.25, 2), p)

    # Nova charge: rising tension sweep
    riser = sweep(140, 1100, 1.0, curve=1.4) * env_adsr(1.0, 0.05, 0.2, 0.85, 0.1)
    flutter = square_sweep(70, 550, 1.0) * 0.25 * np.linspace(0.2, 1, int(SR * 1.0))
    save("sfx/nova_charge.wav", softclip(lp(mix(riser, flutter), 3000), 1.6), 0.55)

    # Nova explosion: sub drop + wide boom
    subdrop = sweep(90, 24, 1.0, curve=0.5) * env_exp(1.0, 5)
    boom = lp(noise(0.8), 900) * env_exp(0.8, 7)
    zap = hp(noise(0.25), 2600) * env_exp(0.25, 14) * 0.6
    save("sfx/nova_explosion.wav", softclip(mix(subdrop * 1.4, boom, zap), 2.4), 0.85)


# ---------------------------------------------------------------- ui + jingles
def pluck(freq, dur=0.16, bright=3000):
    x = mix(square(freq, dur) * 0.5, sine(freq, dur), sine(freq * 2, dur) * 0.25)
    return lp(x, bright) * env_exp(dur, 18)


def arpeggio(freqs, step=0.07, note_dur=0.18, bright=3200):
    total = step * (len(freqs) - 1) + note_dur
    out = np.zeros(int(SR * total) + 8)
    for i, f in enumerate(freqs):
        n = pluck(f, note_dur, bright)
        s = int(SR * step * i)
        out[s:s + n.size] += n
    return out


def make_ui():
    save("ui/click.wav", pluck(NOTE(0, A4), 0.05, 4000), 0.4)
    save("ui/hover.wav", pluck(NOTE(-5, A4), 0.04, 2400) * 0.6, 0.25)

    err = square(NOTE(-24), 0.09) * env_exp(0.09, 16)
    err2 = square(NOTE(-26), 0.12) * env_exp(0.12, 14)
    save("ui/error.wav", softclip(np.concatenate([err, err2 * 0.9]), 1.6), 0.42)

    # upgrade: rising A minor arpeggio
    save("ui/upgrade.wav", arpeggio([NOTE(0), NOTE(3), NOTE(7), NOTE(12)]), 0.5)

    # level up: longer, brighter, with sparkle tail
    arp = arpeggio([NOTE(0), NOTE(3), NOTE(7), NOTE(12), NOTE(15), NOTE(19)], 0.065, 0.3, 4200)
    spark = hp(noise(0.5), 5000) * env_exp(0.5, 9) * 0.12
    tail = mix(sine(NOTE(12, A4), 0.5), sine(NOTE(19, A4), 0.5)) * env_exp(0.5, 6) * 0.2
    save("ui/level_up.wav", mix(arp, np.concatenate([np.zeros(int(SR * 0.3)), mix(spark, tail)])), 0.55)

    # wave start: dark horn stab (A + E, slight detune swell)
    horn = mix(saw(A2, 0.7), saw(A2, 0.7, 0.006), saw(A2 * 1.5, 0.7) * 0.7,
               saw(A2 * 2, 0.7) * 0.4)
    horn = lp(horn, 1400) * env_adsr(0.7, 0.02, 0.15, 0.7, 0.3)
    save("ui/wave_start.wav", softclip(horn, 1.8), 0.6)

    # build place: solid mechanical thunk + confirm tick
    thunk = tri(120, 0.1) * env_exp(0.1, 24)
    tick = pluck(NOTE(7, A4), 0.05, 5000) * 0.5
    save("ui/build_place.wav", softclip(mix(thunk, np.concatenate([np.zeros(int(SR * 0.04)), tick])), 1.8), 0.5)

    # build sell: descending coins
    save("ui/build_sell.wav", arpeggio([NOTE(12, A4), NOTE(7, A4), NOTE(3, A4)], 0.05, 0.12, 5000), 0.42)


# ---------------------------------------------------------------- pickups + special
def coin(freq):
    body = mix(sine(freq, 0.11), sine(freq * 2.01, 0.11) * 0.5) * env_exp(0.11, 22)
    return body


def make_special():
    # coin pickups (3 pitch variants, subtle)
    save("special/coin_pickup_01.wav", coin(NOTE(12, A4)), 0.34)
    save("special/coin_pickup_02.wav", coin(NOTE(15, A4)), 0.34)
    save("special/coin_pickup_03.wav", coin(NOTE(19, A4)), 0.34)

    # xp / essence pickup: soft crystal blip
    blip = mix(sine(NOTE(7, A4), 0.09), tri(NOTE(19, A4), 0.09) * 0.4) * env_exp(0.09, 26)
    save("special/essence_pickup.wav", blip, 0.3)

    # heal pickup: warm rising third
    save("special/heal_pickup.wav", arpeggio([NOTE(0, A4), NOTE(4, A4)], 0.06, 0.2, 2600), 0.4)

    # chest open: creak + coin sparkle
    creak = square_sweep(80, 240, 0.3) * env_adsr(0.3, 0.02, 0.1, 0.6, 0.1)
    creak = lp(creak, 700) * 0.5
    coins = arpeggio([NOTE(12, A4), NOTE(16, A4), NOTE(19, A4), NOTE(24, A4)], 0.06, 0.15, 5200)
    save("special/chest_open.wav", mix(creak, np.concatenate([np.zeros(int(SR * 0.22)), coins])), 0.55)

    # powerups
    shimmer_up = sweep(500, 1600, 0.5) * env_adsr(0.5, 0.05, 0.1, 0.7, 0.25) * 0.6
    glitter = hp(noise(0.5), 4500) * env_adsr(0.5, 0.1, 0.1, 0.5, 0.25) * 0.15
    save("special/powerup_spawn.wav", mix(shimmer_up, glitter), 0.45)
    save("special/powerup_pickup.wav",
         arpeggio([NOTE(0, A4), NOTE(7, A4), NOTE(12, A4), NOTE(16, A4)], 0.05, 0.22, 4200), 0.55)

    # generator destroyed: crunchy blast + debris
    x, _ = explosion(0.6, 130, 34, 800, 0.8)
    debris = bandpass(noise(0.5), 300, 1800) * env_exp(0.5, 8) * \
        (rng.uniform(0, 1, int(SR * 0.5)) > 0.6)
    save("special/generator_destroyed.wav", softclip(mix(x, debris * 0.4), 2.0), 0.78)

    # heartbeat: two low thumps
    th1 = sweep(85, 45, 0.14) * env_exp(0.14, 16)
    th2 = sweep(75, 40, 0.16) * env_exp(0.16, 14) * 0.85
    beat = np.concatenate([th1, np.zeros(int(SR * 0.12)), th2, np.zeros(int(SR * 0.1))])
    save("special/heartbeat.wav", lp(beat, 250), 0.66)

    # berserk: aggressive rising growl
    growl = square_sweep(55, 220, 0.6) * env_adsr(0.6, 0.02, 0.1, 0.85, 0.15)
    growl = softclip(lp(growl, 1200) * (1 + 0.5 * sine(30, 0.6)), 3.0)
    roar = bandpass(noise(0.6), 200, 1200) * env_adsr(0.6, 0.1, 0.1, 0.6, 0.2) * 0.5
    save("special/berserk_activate.wav", softclip(mix(growl, roar), 1.6), 0.68)

    # teleport out / in
    save("special/teleport.wav",
         mix(sweep(1200, 200, 0.35, curve=0.8) * env_exp(0.35, 9),
             hp(noise(0.3), 3000) * env_exp(0.3, 12) * 0.3), 0.5)
    save("special/teleport_arrive.wav",
         mix(sweep(200, 1200, 0.3, curve=1.2) * env_exp(0.3, 8),
             hp(noise(0.25), 3500) * env_exp(0.25, 12) * 0.3), 0.5)

    # summons: dark swelling drone (single + army variant)
    def summon_drone(dur, voices, peak):
        vs = [saw(A2 * r, dur, d) for r, d in voices]
        pad = lp(mix(*vs), 900) * env_adsr(dur, dur * 0.25, 0.1, 0.8, dur * 0.3)
        breath = lp(noise(dur), 500) * env_adsr(dur, dur * 0.3, 0.1, 0.5, dur * 0.3) * 0.4
        return softclip(mix(pad, breath), 1.8), peak

    x, p = summon_drone(0.8, [(1, 0), (1, 0.008), (1.5, 0.004)], 0.5)
    save("special/summon.wav", x, p)
    x, p = summon_drone(1.3, [(0.5, 0), (1, 0.009), (1.5, 0.005), (2, 0.012)], 0.62)
    save("special/summon_army.wav", echo(x, 0.15, 0.4, 0.3, 2), p)

    # boss warning: ominous tritone horn, twice
    def horn(f, dur):
        h = mix(saw(f, dur), saw(f, dur, 0.007), saw(f * 2, dur) * 0.5)
        return lp(h, 1100) * env_adsr(dur, 0.03, 0.1, 0.8, 0.2)

    blast = softclip(mix(horn(A2, 0.55), horn(A2 * 2 ** (6 / 12), 0.55) * 0.9), 2.0)
    gap = np.zeros(int(SR * 0.18))
    save("special/boss_warning.wav", np.concatenate([blast, gap, blast * 0.9]), 0.72)

    # boss phase: rising growl into stinger
    rise = square_sweep(60, 440, 0.7) * env_adsr(0.7, 0.02, 0.1, 0.9, 0.1)
    rise = softclip(lp(rise, 1500), 2.2)
    sting = softclip(mix(horn(A2, 0.4), horn(A2 * 2 ** (3 / 12), 0.4)), 2.0)
    save("special/boss_phase.wav", np.concatenate([rise * 0.8, sting]), 0.7)

    # game over: slow dark descent (A - G - F# - F)
    notes = [NOTE(0, A3), NOTE(-2, A3), NOTE(-3, A3), NOTE(-4, A3)]
    parts = []
    for i, f in enumerate(notes):
        v = mix(saw(f, 0.8), saw(f, 0.8, 0.006), sine(f / 2, 0.8) * 0.8)
        v = lp(v, 1000) * env_adsr(0.8, 0.05, 0.2, 0.7, 0.35)
        parts.append(v * (1.0 - i * 0.08))
    seq = np.concatenate(parts)
    save("special/game_over.wav", softclip(echo(seq, 0.22, 0.35, 0.3, 3), 1.5), 0.6)

    # victory: bright fanfare
    fan = arpeggio([NOTE(0), NOTE(7), NOTE(12), NOTE(16), NOTE(19), NOTE(24)], 0.09, 0.5, 4500)
    chord = mix(*[lp(saw(f, 1.2), 2200) * env_adsr(1.2, 0.02, 0.2, 0.6, 0.5)
                  for f in [NOTE(0), NOTE(7), NOTE(12), NOTE(16)]]) * 0.4
    save("special/victory.wav", mix(fan, np.concatenate([np.zeros(int(SR * 0.45)), chord])), 0.6)


# ---------------------------------------------------------------- ambient loops
def make_ambient():
    # generator hum: 2s seamless loop
    dur = 2.0
    hum = mix(sine(55, dur), sine(110, dur) * 0.5, sine(165, dur) * 0.2,
              tri(55.5, dur) * 0.3)
    wob = 1 + 0.08 * sine(1.0, dur)  # 1 Hz — loops cleanly over 2s
    x = hum * wob
    save("ambient/generator_hum.wav", x, 0.35)

    # wind: 6s loop of slowly-swelling filtered noise
    dur = 6.0
    n = lp(noise(dur), 420)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * t(dur) / dur * 2 + 1.3)  # 2 cycles -> loops
    save("ambient/wind.wav", n * swell, 0.3)

    # distant battle: sparse muffled rumbles, 8s loop
    dur = 8.0
    bed = lp(noise(dur), 160) * 0.35
    x = bed.copy()
    for pos in [0.7, 2.1, 3.4, 5.2, 6.6]:
        boom = sweep(70, 30, 0.7) * env_exp(0.7, 6)
        s = int(SR * pos)
        seg = lp(boom, 200) * rng.uniform(0.4, 0.9)
        x[s:s + seg.size] += seg[:max(0, min(seg.size, x.size - s))]
    save("ambient/distant_battle.wav", x, 0.4)


# ---------------------------------------------------------------- music
def kick(dur=0.24):
    return sweep(150, 42, dur, curve=0.4) * env_exp(dur, 12)


def hat(dur=0.05):
    return hp(noise(dur), 6500) * env_exp(dur, 45) * 0.5


def snare(dur=0.18):
    return (bandpass(noise(dur), 900, 4200) * env_exp(dur, 18) +
            tri(190, dur) * env_exp(dur, 24) * 0.5)


def bass_note(freq, dur):
    x = mix(square(freq, dur) * 0.6, sine(freq, dur))
    return lp(x, 500) * env_adsr(dur, 0.004, 0.03, 0.8, min(0.08, dur * 0.3))


def pad_chord(freqs, dur):
    vs = []
    for f in freqs:
        vs += [saw(f, dur, 0.004), saw(f, dur, -0.004)]
    x = lp(mix(*vs), 1300)
    return x * env_adsr(dur, dur * 0.2, 0.1, 0.8, dur * 0.25)


def pluck_note(freq, dur=0.3):
    return lp(mix(square(freq, dur) * 0.5, sine(freq * 2, dur) * 0.3, sine(freq, dur)),
              2800) * env_exp(dur, 11)


def place(buf, x, at_sec, gain=1.0, pan=0.0):
    """Mix mono signal into stereo buffer at time with constant-power pan."""
    s = int(SR * at_sec)
    n = min(x.size, buf.shape[0] - s)
    if n <= 0:
        return
    gl = np.cos((pan + 1) * np.pi / 4)
    gr = np.sin((pan + 1) * np.pi / 4)
    buf[s:s + n, 0] += x[:n] * gain * gl
    buf[s:s + n, 1] += x[:n] * gain * gr


def make_music():
    bpm = 112
    beat = 60.0 / bpm
    bar = beat * 4

    # ---- battle theme: 16 bars, Am Am F G | Am Am F E, A/B texture
    prog = ["Am", "Am", "F", "G", "Am", "Am", "F", "E"]
    chords = {
        "Am": [A2, A2 * 2 ** (3 / 12), A2 * 2 ** (7 / 12)],
        "F":  [A2 * 2 ** (-4 / 12), A2, A2 * 2 ** (3 / 12) * 2 ** (12 / 12) / 2],
        "G":  [A2 * 2 ** (-2 / 12), A2 * 2 ** (2 / 12), A2 * 2 ** (5 / 12)],
        "E":  [A2 * 2 ** (-5 / 12), A2 * 2 ** (-1 / 12), A2 * 2 ** (2 / 12)],
    }
    roots = {"Am": A2, "F": A2 * 2 ** (-4 / 12), "G": A2 * 2 ** (-2 / 12),
             "E": A2 * 2 ** (-5 / 12)}
    total = bar * 16
    buf = np.zeros((int(SR * total) + SR, 2))

    # A-minor pentatonic pool for the lead (relative to A3)
    penta = [0, 3, 5, 7, 10, 12, 15]
    lead_rng = np.random.default_rng(7)

    for rep in range(2):  # two 8-bar passes: A (sparse) then B (full)
        full = rep == 1
        for bi, ch in enumerate(prog):
            bstart = (rep * 8 + bi) * bar
            root = roots[ch]
            # drums
            for b in range(4):
                place(buf, kick(), bstart + b * beat, 0.9)
                place(buf, hat(), bstart + (b + 0.5) * beat, 0.55, 0.25)
                if full:
                    place(buf, hat(0.03), bstart + (b + 0.25) * beat, 0.25, -0.3)
            if full:
                place(buf, snare(), bstart + 1 * beat, 0.5)
                place(buf, snare(), bstart + 3 * beat, 0.5)
            # bass: driving eighths, octave bounce
            for e in range(8):
                f = root if e % 2 == 0 else root * 2
                place(buf, bass_note(f, beat * 0.48), bstart + e * beat * 0.5, 0.62)
            # pad
            place(buf, pad_chord(chords[ch], bar * 0.98), bstart, 0.16 if not full else 0.22)
            # lead plucks (B section only): sparse pentatonic phrases
            if full:
                for pos in [0, 1.5, 2.5, 3.0]:
                    if lead_rng.uniform() < 0.75:
                        semi = penta[lead_rng.integers(0, len(penta))]
                        f = A3 * 2 ** (semi / 12.0) * 2
                        pan = float(lead_rng.uniform(-0.5, 0.5))
                        place(buf, pluck_note(f, beat * 0.9), bstart + pos * beat, 0.3, pan)

    x = buf[:int(SR * total)]
    # gentle stereo echo on the whole mix for space
    d = int(SR * beat * 0.75)
    x[d:, 0] += x[:-d, 0] * 0.18
    x[int(d * 1.33):, 1] += x[:-int(d * 1.33), 1] * 0.15
    save_ogg("music/battle_theme.ogg", softclip(x, 1.2), 0.62)

    # ---- menu theme: slow dark pads, 8 bars at 60 BPM (32s)
    mbeat = 1.0
    mbar = 4.0
    mprog = ["Am", "F", "Am", "G", "Am", "F", "E", "Am"]
    mtotal = mbar * len(mprog)
    mbuf = np.zeros((int(SR * mtotal) + SR, 2))
    bell_rng = np.random.default_rng(21)
    for bi, ch in enumerate(mprog):
        bstart = bi * mbar
        place(mbuf, pad_chord([f / 2 for f in chords[ch]], mbar * 1.05), bstart, 0.3)
        place(mbuf, pad_chord(chords[ch], mbar * 1.05), bstart, 0.14)
        # sparse far-away bells
        for pos in [0.5, 2.0, 3.2]:
            if bell_rng.uniform() < 0.5:
                semi = [0, 3, 7, 12][bell_rng.integers(0, 4)]
                f = A4 * 2 ** (semi / 12.0)
                bell = sine(f, 1.6) * env_exp(1.6, 4) * 0.12
                place(mbuf, bell, bstart + pos, 1.0, float(bell_rng.uniform(-0.7, 0.7)))
    m = mbuf[:int(SR * mtotal)]
    d = int(SR * 0.9)
    m[d:, 0] += m[:-d, 0] * 0.25
    m[int(d * 1.5):, 1] += m[:-int(d * 1.5), 1] * 0.22
    save_ogg("music/menu_theme.ogg", m, 0.5)


if __name__ == "__main__":
    print("Generating Stronghold Survivors audio set...")
    make_weapons()
    make_impacts()
    make_explosions()
    make_ui()
    make_special()
    make_ambient()
    make_music()
    print("Done.")
