#!/usr/bin/env python3
"""Jackpot audio kit for treasure chests (Age of Aether).

Chest opens were a single flat sound. A chest should feel like a slot machine
landing: tension that builds, a reveal per item that climbs with rarity, and a
real payoff when something great drops.

Self-contained and additive — writes only the files listed in main(), so the
existing sound set is untouched.

Usage:
    pip install numpy scipy soundfile
    python3 tools/audio/generate_chest_audio.py
"""
import os
import numpy as np
import soundfile as sf
from scipy.signal import lfilter

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(90210)  # deterministic

A4 = 440.0


def t(dur):
    return np.arange(int(SR * dur)) / SR


def note(semi, base=A4):
    return base * 2 ** (semi / 12.0)


def sine(f, dur):
    return np.sin(2 * np.pi * f * t(dur))


def tri(f, dur):
    ph = (t(dur) * f) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


def saw(f, dur, detune=0.0):
    ph = (t(dur) * f * (1 + detune)) % 1.0
    return 2 * ph - 1


def square(f, dur):
    return np.where((t(dur) * f) % 1.0 < 0.5, 1.0, -1.0)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def sweep(f0, f1, dur, curve=1.0):
    x = np.linspace(0, 1, int(SR * dur)) ** curve
    freq = f0 * (f1 / f0) ** x
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def env_exp(dur, k=8.0):
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
    dt = 1.0 / SR
    rc = 1.0 / (2 * np.pi * max(cutoff, 10.0))
    a = dt / (rc + dt)
    return lfilter([a], [1.0, -(1.0 - a)], x)


def hp(x, cutoff):
    return x - lp(x, cutoff)


def softclip(x, drive=1.5):
    return np.tanh(x * drive)


def mix(*layers):
    n = max(l.size for l in layers)
    out = np.zeros(n)
    for l in layers:
        out[:l.size] += l
    return out


def fade(x, fin=0.002, fout=0.01):
    nf, no = int(SR * fin), int(SR * fout)
    if nf > 0 and x.size > nf:
        x[:nf] *= np.linspace(0, 1, nf)
    if no > 0 and x.size > no:
        x[-no:] *= np.linspace(1, 0, no)
    return x


def save(rel, x, peak=0.7):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = fade(np.asarray(x, dtype=np.float64))
    m = np.max(np.abs(x))
    if m > 1e-9:
        x = x * (peak / m)
    sf.write(path, x.astype(np.float32), SR, subtype="PCM_16")
    print(f"  {rel}  ({x.size / SR:.2f}s)")


def pluck(f, dur=0.16, bright=3000):
    x = mix(square(f, dur) * 0.5, sine(f, dur), sine(f * 2, dur) * 0.25)
    return lp(x, bright) * env_exp(dur, 18)


def arpeggio(freqs, step=0.06, note_dur=0.3, bright=4200):
    total = step * (len(freqs) - 1) + note_dur
    out = np.zeros(int(SR * total) + 8)
    for i, f in enumerate(freqs):
        n = pluck(f, note_dur, bright)
        s = int(SR * step * i)
        out[s:s + n.size] += n
    return out


def coin(f):
    return mix(sine(f, 0.11), sine(f * 2.01, 0.11) * 0.5) * env_exp(0.11, 22)


def sting(root_semi, voices, bright, dur_s, sparkle):
    """A rarity reveal hit: stacked voices, brighter and fuller as rarity climbs."""
    parts = []
    for semi, amp in voices:
        f = note(root_semi + semi)
        parts.append(mix(sine(f, dur_s), tri(f, dur_s) * 0.5) * env_exp(dur_s, 9) * amp)
    body = lp(mix(*parts), bright)
    glitter = hp(noise(dur_s), 5200) * env_exp(dur_s, 7) * sparkle
    return softclip(mix(body, glitter), 1.4)


def main():
    print("Generating chest jackpot kit...")

    # --- Anticipation riser: "the wheel is slowing down" ---
    dur = 1.1
    riser = sweep(220, 1500, dur, curve=1.6) * env_adsr(dur, 0.02, 0.1, 0.9, 0.08)
    x = t(dur)
    rate = 6.0 + 26.0 * (x / dur) ** 2          # tremolo accelerates into the reveal
    trem = 0.55 + 0.45 * np.sin(2 * np.pi * np.cumsum(rate) / SR)
    shimmer = hp(noise(dur), 4000) * env_adsr(dur, 0.3, 0.2, 0.7, 0.1) * 0.18
    save("special/chest_charge.wav", softclip(mix(riser * trem, shimmer), 1.5), 0.55)

    # --- Reveal stings, escalating with rarity ---
    save("special/reveal_common.wav",
         sting(0, [(0, 1.0), (12, 0.3)], 3000, 0.35, 0.05), 0.42)
    save("special/reveal_rare.wav",
         sting(2, [(0, 1.0), (7, 0.7), (12, 0.4)], 3800, 0.5, 0.09), 0.5)
    save("special/reveal_epic.wav",
         sting(5, [(0, 1.0), (4, 0.8), (7, 0.7), (12, 0.5)], 4600, 0.7, 0.14), 0.58)
    # Diamond gets a sub thump so it lands in the chest, not just the ears.
    diamond = sting(7, [(0, 1.0), (4, 0.85), (7, 0.8), (12, 0.7), (19, 0.4)], 6000, 1.1, 0.22)
    sub = sweep(120, 45, 0.5) * env_exp(0.5, 7) * 0.9
    save("special/reveal_diamond.wav", softclip(mix(diamond, sub), 1.6), 0.68)

    # --- Jackpot fanfare ---
    arp = arpeggio([note(0), note(4), note(7), note(12), note(16), note(19), note(24)],
                   0.055, 0.45, 5200)
    chord = mix(*[lp(saw(f, 1.5), 3000) * env_adsr(1.5, 0.02, 0.25, 0.6, 0.6)
                  for f in [note(0), note(4), note(7), note(12)]]) * 0.35
    bell = mix(sine(note(24), 1.4), sine(note(28), 1.4) * 0.6) * env_exp(1.4, 3.5) * 0.3
    boom = sweep(140, 50, 0.7) * env_exp(0.7, 6) * 0.8
    tail = np.concatenate([np.zeros(int(SR * 0.35)), mix(chord, bell)])
    save("special/jackpot_fanfare.wav", softclip(mix(arp, tail, boom), 1.4), 0.72)

    # --- Coin cascade for the gold payout ---
    dur = 1.2
    out = np.zeros(int(SR * dur) + SR)
    for i in range(26):
        at = (i / 26.0) ** 0.7 * 0.85           # front-loaded, thins out
        f = note([12, 16, 19, 24, 28][rng.integers(0, 5)]) * rng.uniform(0.98, 1.02)
        c = coin(f) * rng.uniform(0.35, 0.8)
        s = int(SR * at)
        out[s:s + c.size] += c
    save("special/coin_cascade.wav", softclip(out, 1.3), 0.6)

    print("Done.")


if __name__ == "__main__":
    main()
