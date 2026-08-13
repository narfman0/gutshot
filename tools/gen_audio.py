#!/usr/bin/env python3
"""Synthesize Gutshot's placeholder audio: gunfight SFX + a hive-city ambient
loop. 44.1 kHz 16-bit mono WAVs into assets/audio/. The loop is made seamless
by crossfading the tail into the head. Deliberately quiet — the game mixes
them at low default volume; placeholder quality, real identity.
(Lineage: wayfarer tools/gen_audio.py.)  Run from repo root."""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path("assets/audio")

rng = random.Random(13)


def write_wav(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    if peak > 0.98:
        samples = [s / peak * 0.98 for s in samples]
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))
    print("wrote", OUT / name, f"{len(samples)/SR:.2f}s")


def env_exp(n, i, k=6.0):
    return math.exp(-k * i / n)


def lowpass(xs, alpha):
    out, y = [], 0.0
    for x in xs:
        y += alpha * (x - y)
        out.append(y)
    return out


def seamless(samples, fade=0.5):
    nf = int(fade * SR)
    body = samples[:-nf]
    tail = samples[-nf:]
    for i in range(nf):
        t = i / nf
        body[i] = body[i] * t + tail[i] * (1.0 - t)
    return body


# ── Gunshots ─────────────────────────────────────────────────────────────────

def gunshot(length, crack_gain, thump_freq, thump_gain, snap_k):
    """Noise crack + low thump — the shared shape of every gun here."""
    n = int(length * SR)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.55)
    out = []
    for i, x in enumerate(noise):
        t = i / SR
        crack = x * env_exp(n, i, snap_k) * crack_gain
        thump = math.sin(2 * math.pi * (thump_freq - thump_freq * 0.4 * i / n) * t) \
            * env_exp(n, i, 11) * thump_gain
        out.append(crack + thump)
    return out


def sfx_shot_smg():
    return gunshot(0.09, 0.9, 130, 0.5, 26)


def sfx_shot_rifle():
    return gunshot(0.18, 0.8, 85, 0.9, 14)


def sfx_shot_pistol():
    return gunshot(0.12, 0.85, 110, 0.7, 20)


# ── Impacts ──────────────────────────────────────────────────────────────────

def sfx_impact():
    n = int(0.11 * SR)
    out = []
    for i in range(n):
        t = i / SR
        thump = math.sin(2 * math.pi * (100 - 45 * i / n) * t) * env_exp(n, i, 10)
        click = rng.uniform(-1, 1) * env_exp(n, i, 45) * 0.5
        out.append(0.85 * thump + click)
    return out


def sfx_shield_hit():
    n = int(0.14 * SR)
    out = []
    for i in range(n):
        t = i / SR
        zap = math.sin(2 * math.pi * (1400 - 700 * i / n) * t) * env_exp(n, i, 16) * 0.5
        fizz = rng.uniform(-1, 1) * env_exp(n, i, 22) * 0.3
        out.append(zap + fizz)
    return out


def sfx_explosion():
    n = int(0.7 * SR)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.08)
    out = []
    for i, x in enumerate(noise):
        t = i / SR
        rumble = math.sin(2 * math.pi * (60 - 25 * i / n) * t) * env_exp(n, i, 5)
        out.append(x * env_exp(n, i, 6) * 1.1 + rumble * 0.8)
    return out


# ── Handling ─────────────────────────────────────────────────────────────────

def _click(n, freq, gain):
    return [(math.sin(2 * math.pi * freq * i / SR) * env_exp(n, i, 30)
             + rng.uniform(-1, 1) * env_exp(n, i, 50) * 0.4) * gain for i in range(n)]


def sfx_reload():
    # click ... clack — magazine out, magazine in.
    gap = [0.0] * int(0.22 * SR)
    c1 = _click(int(0.06 * SR), 900, 0.6)
    c2 = _click(int(0.08 * SR), 600, 0.8)
    return c1 + gap + c2


def sfx_switch():
    return _click(int(0.05 * SR), 1200, 0.5)


# ── Squad states ─────────────────────────────────────────────────────────────

def sfx_down():
    n = int(0.5 * SR)
    out = []
    phase = 0.0
    for i in range(n):
        f = 220 * (1.0 - 0.7 * i / n)  # falling tone
        phase += 2 * math.pi * f / SR
        out.append((math.sin(phase) + 0.3 * math.sin(2 * phase)) * env_exp(n, i, 4) * 0.6)
    return out


def sfx_heal():
    n = int(0.12 * SR)
    out = []
    for i in range(n):
        t = i / SR
        beam = math.sin(2 * math.pi * (620 + 240 * i / n) * t) * env_exp(n, i, 9) * 0.4
        shimmer = math.sin(2 * math.pi * 1245 * t) * env_exp(n, i, 14) * 0.2
        out.append(beam + shimmer)
    return out


def sfx_revive():
    n = int(0.6 * SR)
    out = [0.0] * n
    for k, f in enumerate([440, 554, 659]):  # rising triad
        start = int(k * 0.09 * SR)
        for i in range(start, n):
            t = (i - start) / SR
            out[i] += math.sin(2 * math.pi * f * t) * math.exp(-4.5 * t) * 0.3
    return out


def sfx_telegraph():
    n = int(0.45 * SR)
    out = []
    phase = 0.0
    for i in range(n):
        f = 520 + 360 * (i / n)  # rising alarm
        phase += 2 * math.pi * f / SR
        trem = 0.6 + 0.4 * math.sin(2 * math.pi * 13 * i / SR)
        out.append(math.sin(phase) * trem * min(1.0, 4.0 * (1.0 - i / n)) * 0.5)
    return out


# ── Ambient: hive city (10 s seamless) ───────────────────────────────────────

def ambient_city():
    n = int(10.0 * SR)
    # deep structural drone + electrical hum + distant traffic wash
    out = []
    hum_gain = 0.10
    for i in range(n):
        t = i / SR
        drone = math.sin(2 * math.pi * 48 * t) * 0.20 \
            + math.sin(2 * math.pi * 72.3 * t) * 0.10
        hum = math.sin(2 * math.pi * 120 * t) * hum_gain \
            * (0.7 + 0.3 * math.sin(2 * math.pi * 0.13 * t))
        out.append(drone + hum)
    wash = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.015)
    swell = [0.5 + 0.5 * math.sin(2 * math.pi * 0.07 * i / SR) for i in range(n)]
    out = [o + w * s * 0.35 for o, w, s in zip(out, wash, swell)]
    return seamless(out)


def main():
    write_wav("sfx_shot_smg.wav", sfx_shot_smg())
    write_wav("sfx_shot_rifle.wav", sfx_shot_rifle())
    write_wav("sfx_shot_pistol.wav", sfx_shot_pistol())
    write_wav("sfx_impact.wav", sfx_impact())
    write_wav("sfx_shield_hit.wav", sfx_shield_hit())
    write_wav("sfx_explosion.wav", sfx_explosion())
    write_wav("sfx_reload.wav", sfx_reload())
    write_wav("sfx_switch.wav", sfx_switch())
    write_wav("sfx_heal.wav", sfx_heal())
    write_wav("sfx_down.wav", sfx_down())
    write_wav("sfx_revive.wav", sfx_revive())
    write_wav("sfx_telegraph.wav", sfx_telegraph())
    write_wav("ambient_city.wav", ambient_city())


if __name__ == "__main__":
    main()
