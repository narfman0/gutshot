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


# Guns stay synthesized on purpose: the sample library on the asset server is
# a sci-fi set with no ballistic recordings, and a purpose-built crack beats a
# laser impersonating a pistol. What they DID need is variants — a single
# gunshot sample fired six times a second is the most fatiguing sound in the
# game, and no amount of fidelity fixes that. Three per weapon, jittered in
# length, pitch and snap, and SoundBank rotates them.
GUNS = {
    "smg":    (0.09, 0.9, 130, 0.5, 26),
    "rifle":  (0.18, 0.8, 85, 0.9, 14),
    "pistol": (0.12, 0.85, 110, 0.7, 20),
}


def gun_variant(base, jitter):
    length, crack, thump_f, thump_g, snap = base
    return gunshot(length * (1.0 + 0.10 * jitter), crack * (1.0 + 0.06 * jitter),
                   thump_f * (1.0 + 0.09 * jitter), thump_g * (1.0 - 0.05 * jitter),
                   snap * (1.0 + 0.12 * jitter))


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


def sfx_shot_laser():
    n = int(0.14 * SR)
    out = []
    for i in range(n):
        t = i / SR
        zap = math.sin(2 * math.pi * (1900 - 1300 * i / n) * t) * env_exp(n, i, 12) * 0.6
        body = math.sin(2 * math.pi * 300 * t) * env_exp(n, i, 10) * 0.3
        out.append(zap + body)
    return out


def sfx_land():
    n = int(0.16 * SR)
    out = []
    for i in range(n):
        t = i / SR
        thump = math.sin(2 * math.pi * (75 - 30 * i / n) * t) * env_exp(n, i, 9)
        scuff = rng.uniform(-1, 1) * env_exp(n, i, 18) * 0.25
        out.append(0.9 * thump + scuff)
    return lowpass(out, 0.35)


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


def sfx_swing():
    """Melee whoosh — bandpassed air with a swept envelope, no bang at all
    (steel is quiet; that's the melee identity)."""
    n = int(0.16 * SR)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.25)
    return [x * (math.sin(math.pi * i / n) ** 2) * 0.7 for i, x in enumerate(noise)]


def sfx_slash():
    """Blade connect: metallic ring + bite + body thack."""
    n = int(0.13 * SR)
    out = []
    for i in range(n):
        t = i / SR
        ring = math.sin(2 * math.pi * (2400 - 900 * i / n) * t) * env_exp(n, i, 18) * 0.4
        bite = rng.uniform(-1, 1) * env_exp(n, i, 30) * 0.6
        thack = math.sin(2 * math.pi * 140 * t) * env_exp(n, i, 14) * 0.4
        out.append(ring + bite + thack)
    return out


def sfx_levelup():
    """Crew level — a bright rising arpeggio, longer than the revive triad."""
    n = int(0.8 * SR)
    out = [0.0] * n
    for k, f in enumerate([392, 523, 659, 784]):  # G4 C5 E5 G5
        start = int(k * 0.08 * SR)
        for i in range(start, n):
            t = (i - start) / SR
            out[i] += math.sin(2 * math.pi * f * t) * math.exp(-3.5 * t) * 0.28
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


# ── Ambients: one 10 s seamless bed per site mood ────────────────────────────
# The street keeps the hive-city wash; the other sites get their own air.
# AudioManager crossfades between beds as the crew crosses the district.

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


def ambient_hideout():
    """The safe room: warm low drone, a fridge-hum wobble, air that barely
    moves. Deliberately the quietest bed — stepping in should feel like
    pressure coming off."""
    n = int(10.0 * SR)
    out = []
    for i in range(n):
        t = i / SR
        drone = math.sin(2 * math.pi * 55 * t) * 0.16
        fridge = math.sin(2 * math.pi * 118 * t) * 0.06 \
            * (0.8 + 0.2 * math.sin(2 * math.pi * 0.31 * t))
        out.append(drone + fridge)
    air = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.008)
    breathe = [0.6 + 0.4 * math.sin(2 * math.pi * 0.05 * i / SR) for i in range(n)]
    out = [o + a * b * 0.18 for o, a, b in zip(out, air, breathe)]
    return seamless(out)


def ambient_hall():
    """The Exchange: a big hollow hall — gusting wash through broken boards,
    a faint draft whistle, deep structural groan underneath."""
    n = int(10.0 * SR)
    wash = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.03)
    out = []
    for i, w in enumerate(wash):
        t = i / SR
        gust = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.11 * t + 1.7))
        whistle = math.sin(2 * math.pi
                           * (640 + 14 * math.sin(2 * math.pi * 0.09 * t)) * t) * 0.03
        drone = math.sin(2 * math.pi * 41 * t) * 0.12
        out.append(w * gust * 0.5 + whistle + drone)
    return seamless(out)


def ambient_industrial():
    """Depot 9: machinery thrum, duct rumble, and a slow conveyor thud.
    Thud period divides the post-seamless loop length exactly, so the
    rhythm survives the loop point."""
    n = int(10.0 * SR)
    period = 9.5 / 8.0  # seamless() trims to 9.5 s → 8 even thuds
    out = []
    for i in range(n):
        t = i / SR
        thrum = math.sin(2 * math.pi * 60 * t) * 0.18 \
            + math.sin(2 * math.pi * 90.5 * t) * 0.08
        ph = (t % period) / period
        thud = math.sin(2 * math.pi * 70 * t) * math.exp(-18 * ph) * 0.22
        out.append(thrum + thud)
    duct = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.02)
    out = [o + d * 0.22 for o, d in zip(out, duct)]
    return seamless(out)


def ambient_machine():
    """Fab Level: clean electrical harmonics — the Assembly's turf sounds
    maintained, not derelict — with sparse servo chirps, curious rather
    than alarming."""
    n = int(10.0 * SR)
    out = []
    for i in range(n):
        t = i / SR
        hum = math.sin(2 * math.pi * 120 * t) * 0.10 \
            + math.sin(2 * math.pi * 240 * t) * 0.05 \
            + math.sin(2 * math.pi * 480 * t) * 0.02
        drone = math.sin(2 * math.pi * 52 * t) * 0.10
        out.append(hum + drone)
    for start_s, f0, f1 in [(2.1, 900, 1300), (5.6, 1100, 800), (8.3, 750, 1150)]:
        s0 = int(start_s * SR)
        dur = int(0.09 * SR)
        for j in range(dur):
            t = j / SR
            f = f0 + (f1 - f0) * j / dur
            out[s0 + j] += math.sin(2 * math.pi * f * t) * math.exp(-30 * j / dur) * 0.10
    return seamless(out)


def ambient_lobby():
    """Vantag Tower lobby: conditioned air, a soft power-hum, and glassy
    chime swells — money keeping the grime outside."""
    n = int(10.0 * SR)
    out = []
    for i in range(n):
        t = i / SR
        hvac = 0.7 + 0.3 * math.sin(2 * math.pi * 0.05 * t)
        hum = math.sin(2 * math.pi * 100 * t) * 0.06 \
            + math.sin(2 * math.pi * 200 * t) * 0.03
        out.append(hum * hvac)
    air = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.06)
    out = [o + a * 0.10 for o, a in zip(out, air)]
    for start_s, f in [(1.0, 523.25), (4.0, 659.25), (7.0, 783.99)]:
        s0 = int(start_s * SR)
        dur = int(2.4 * SR)
        for j in range(min(dur, n - s0)):
            t = j / SR
            env = math.sin(math.pi * j / dur) ** 2
            out[s0 + j] += math.sin(2 * math.pi * f * t) * env * 0.045
    return seamless(out)


def ambient_market():
    """Little Japan: a crowd murmur bed, sizzling stall griddles, and a
    shrine bell that rings twice in the loop. The one place in the district
    that sounds ALIVE."""
    n = int(10.0 * SR)
    out = []
    for i in range(n):
        t = i / SR
        hum = math.sin(2 * math.pi * 92 * t) * 0.05 \
            + math.sin(2 * math.pi * 138 * t) * 0.03
        out.append(hum)
    # Crowd murmur: band-limited noise with slow swells.
    murmur = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.05)
    swell = [0.55 + 0.45 * math.sin(2 * math.pi * 0.09 * i / SR) for i in range(n)]
    out = [o + m * s * 0.30 for o, m, s in zip(out, murmur, swell)]
    # Griddle sizzle: bright noise, quieter, always on.
    sizzle = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.6)
    out = [o + z * 0.05 for o, z in zip(out, sizzle)]
    # Shrine bell: a struck bowl with a long decay, twice per loop.
    for start_s in (2.2, 7.0):
        s0 = int(start_s * SR)
        dur = min(int(3.0 * SR), n - s0)
        for j in range(dur):
            t = j / SR
            env = math.exp(-1.6 * t)
            out[s0 + j] += (math.sin(2 * math.pi * 523.25 * t) * 0.5
                            + math.sin(2 * math.pi * 1046.5 * t) * 0.2
                            + math.sin(2 * math.pi * 1567.9 * t) * 0.08) * env * 0.10
    return seamless(out)


def main():
    for gun, base in GUNS.items():
        for tag, jitter in (("a", -1.0), ("b", 0.0), ("c", 1.0)):
            write_wav("sfx_shot_%s_%s.wav" % (gun, tag), gun_variant(base, jitter))
        # Unsuffixed base stays as the fallback for anything unbanked.
        write_wav("sfx_shot_%s.wav" % gun, gun_variant(base, 0.0))
    write_wav("sfx_impact.wav", sfx_impact())
    write_wav("sfx_shield_hit.wav", sfx_shield_hit())
    write_wav("sfx_explosion.wav", sfx_explosion())
    write_wav("sfx_reload.wav", sfx_reload())
    write_wav("sfx_switch.wav", sfx_switch())
    write_wav("sfx_heal.wav", sfx_heal())
    write_wav("sfx_land.wav", sfx_land())
    write_wav("sfx_shot_laser.wav", sfx_shot_laser())
    write_wav("sfx_down.wav", sfx_down())
    write_wav("sfx_revive.wav", sfx_revive())
    write_wav("sfx_telegraph.wav", sfx_telegraph())
    write_wav("sfx_swing.wav", sfx_swing())
    write_wav("sfx_slash.wav", sfx_slash())
    write_wav("sfx_levelup.wav", sfx_levelup())
    write_wav("ambient_city.wav", ambient_city())
    write_wav("ambient_hideout.wav", ambient_hideout())
    write_wav("ambient_hall.wav", ambient_hall())
    write_wav("ambient_industrial.wav", ambient_industrial())
    write_wav("ambient_machine.wav", ambient_machine())
    write_wav("ambient_lobby.wav", ambient_lobby())
    write_wav("ambient_market.wav", ambient_market())


if __name__ == "__main__":
    main()
