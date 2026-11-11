#!/usr/bin/env python3
"""Generates every sound of the game as 16-bit mono WAV files.

Standard library only. Run from anywhere:  python3 tools/gen_sfx.py

Sounds are built from a tiny synthesizer: marimba and bell tones (inharmonic partials
with their own decays), filtered noise, pitch sweeps, and a Schroeder reverb. Short
effects use 44.1 kHz; long ones and the music use 22.05 kHz to keep the files small
(everything together stays under 2 MB).
"""
import math
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
HI = 44100
LO = 22050
TAU = 2.0 * math.pi
random.seed(11)


# ------------------------------------------------------------------ basics

def n_of(seconds, rate):
    return int(seconds * rate)


def silence(seconds, rate):
    return [0.0] * n_of(seconds, rate)


def gain(x, g):
    return [v * g for v in x]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def place(buf, start, sig, wrap=False):
    """Adds `sig` into `buf` at sample `start` (optionally wrapping around the end)."""
    n = len(buf)
    for i, v in enumerate(sig):
        j = start + i
        if j >= n:
            if not wrap:
                break
            j %= n
        buf[j] += v


def fade(x, seconds, rate):
    n = min(n_of(seconds, rate), len(x) // 2)
    out = list(x)
    for i in range(n):
        k = i / n
        out[i] *= k
        out[-1 - i] *= k
    return out


def normalize(x, peak=0.8):
    m = max(abs(v) for v in x) or 1.0
    return [v * peak / m for v in x]


def lowpass(x, cutoff, rate):
    a = 1.0 - math.exp(-TAU * cutoff / rate)
    y = 0.0
    out = []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff, rate):
    a = math.exp(-TAU * cutoff / rate)
    out = []
    py = 0.0
    px = 0.0
    for v in x:
        py = a * (py + v - px)
        px = v
        out.append(py)
    return out


def envelope(n, rate, attack=0.003, decay=6.0):
    """Linear attack then exponential decay (decay in 1/s)."""
    na = max(1, int(attack * rate))
    out = []
    for i in range(n):
        a = min(1.0, i / na)
        out.append(a * math.exp(-decay * i / rate))
    return out


# ------------------------------------------------------------------ voices

def partials(freq, seconds, rate, parts, attack=0.003, vibrato=0.0):
    """parts = [(ratio, amplitude, decay), ...] -> additive tone."""
    n = n_of(seconds, rate)
    out = [0.0] * n
    for ratio, amp, decay in parts:
        f = freq * ratio
        if f * 1.0 >= rate / 2.0:
            continue
        env = envelope(n, rate, attack, decay)
        for i in range(n):
            t = i / rate
            ph = TAU * f * t
            if vibrato:
                ph += vibrato * math.sin(TAU * 5.0 * t)
            out[i] += amp * env[i] * math.sin(ph)
    return out


def marimba(freq, seconds, rate, vol=1.0, decay=7.0):
    """Warm wooden tone: a strong fundamental plus the 4x and 10x bar overtones."""
    return gain(partials(freq, seconds, rate, [(1.0, 1.0, decay), (4.0, 0.28, decay * 2.6), (10.0, 0.06, decay * 5)],
                         attack=0.002), vol)


def bell(freq, seconds, rate, vol=1.0, decay=4.0):
    """Glassy bell: inharmonic partials, the upper ones fading faster."""
    return gain(partials(freq, seconds, rate, [(1.0, 1.0, decay), (2.0, 0.45, decay * 1.5),
                                               (2.76, 0.35, decay * 2.0), (5.4, 0.18, decay * 3.0),
                                               (8.93, 0.08, decay * 4.5)], attack=0.002), vol)


def soft(freq, seconds, rate, vol=1.0, attack=0.02, decay=1.5):
    """Plain soft tone (sine with a hint of octave) for pads and bass."""
    return gain(partials(freq, seconds, rate, [(1.0, 1.0, decay), (2.0, 0.18, decay * 1.4)], attack=attack), vol)


def noise(seconds, rate, vol=1.0, decay=20.0, low=None, high=None):
    n = n_of(seconds, rate)
    env = envelope(n, rate, 0.0005, decay)
    x = [(random.random() * 2 - 1) * env[i] for i in range(n)]
    if low:
        x = lowpass(x, low, rate)
    if high:
        x = highpass(x, high, rate)
    return gain(x, vol)


def sweep(f0, f1, seconds, rate, vol=1.0, decay=8.0, curve=1.0, second=0.0):
    n = n_of(seconds, rate)
    phase = 0.0
    out = []
    for i in range(n):
        k = (i / n) ** curve
        f = f0 + (f1 - f0) * k
        phase += f / rate
        v = math.sin(TAU * phase) + second * math.sin(TAU * phase * 2.0)
        out.append(v * vol * math.exp(-decay * i / rate) * min(1.0, i / (0.004 * rate)))
    return out


def reverb(x, rate, wet=0.2, size=1.0, circular=False):
    """Schroeder reverb. With circular=True the tail wraps, so loops stay seamless."""
    src = x + x if circular else x + [0.0] * int(rate * 0.8)
    combs = [(0.0297, 0.80), (0.0371, 0.78), (0.0411, 0.76), (0.0437, 0.74)]
    acc = [0.0] * len(src)
    for delay, fb in combs:
        d = max(1, int(delay * size * rate))
        buf = [0.0] * d
        idx = 0
        for i, v in enumerate(src):
            y = buf[idx]
            buf[idx] = v + y * fb
            idx = (idx + 1) % d
            acc[i] += y
    for delay, g in ((0.005, 0.7), (0.0017, 0.7)):
        d = max(1, int(delay * rate))
        buf = [0.0] * d
        idx = 0
        for i, v in enumerate(acc):
            y = buf[idx]
            out = -g * v + y
            buf[idx] = v + g * y
            idx = (idx + 1) % d
            acc[i] = out
    wetsig = [a * 0.25 for a in acc]
    if circular:
        n = len(x)
        return [x[i] * (1 - wet * 0.4) + wetsig[n + i] * wet for i in range(n)]
    return [(src[i] if i < len(src) else 0.0) * (1 - wet * 0.4) + wetsig[i] * wet for i in range(len(src))]


def write(name, samples, rate, peak=0.8):
    os.makedirs(OUT, exist_ok=True)
    samples = normalize(samples, peak)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    print("%-12s %5.2f s  %4d kHz  %7d bytes" % (name + ".wav", len(samples) / rate, rate // 1000,
                                                   len(samples) * 2))


def seq(notes, total, rate, voice):
    """notes = [(time, freq, seconds, volume)] rendered with `voice` into one buffer."""
    buf = silence(total, rate)
    for t, f, d, v in notes:
        place(buf, n_of(t, rate), voice(f, d, rate, v))
    return buf


# ------------------------------------------------------------------ effects

C5, D5, E5, G5, A5, C6 = 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5


def fx_deliver():
    # A bright two-note "ding": a bell and its fifth, with a tiny room.
    r = HI
    a = bell(1046.5, 0.5, r, 1.0, decay=7.0)
    b = bell(1568.0, 0.45, r, 0.8, decay=8.0)
    buf = silence(0.55, r)
    place(buf, 0, a)
    place(buf, n_of(0.075, r), b)
    return fade(reverb(buf, r, 0.12, 0.6)[:n_of(0.55, r)], 0.01, r)


def fx_place():
    r = HI
    tap = marimba(392.0, 0.16, r, 1.0, decay=26.0)
    click = noise(0.012, r, 0.35, decay=300.0, high=1500.0)
    return fade(mix(tap, click), 0.004, r)


def fx_bridge():
    r = HI
    buf = silence(0.4, r)
    place(buf, 0, marimba(262.0, 0.2, r, 0.9, decay=20.0))
    place(buf, n_of(0.06, r), marimba(330.0, 0.2, r, 0.9, decay=20.0))
    place(buf, n_of(0.12, r), marimba(392.0, 0.25, r, 0.8, decay=18.0))
    place(buf, 0, sweep(110.0, 55.0, 0.3, r, 0.7, decay=14.0))
    place(buf, 0, noise(0.05, r, 0.18, decay=70.0, low=1800.0))
    return fade(buf, 0.004, r)


def fx_erase():
    r = HI
    n = n_of(0.22, r)
    swish = [0.0] * n
    phase_noise = noise(0.22, r, 1.0, decay=9.0)
    for i in range(n):
        k = i / n
        swish[i] = phase_noise[i] * (1.0 - k)
    swish = lowpass(swish, 1400.0, r)
    return fade(mix(gain(swish, 0.9), sweep(520.0, 190.0, 0.2, r, 0.35, decay=12.0)), 0.006, r)


def fx_tick():
    r = HI
    a = noise(0.006, r, 1.0, decay=500.0, high=2000.0)
    b = silence(0.04, r)
    place(b, n_of(0.004, r), marimba(1800.0, 0.03, r, 0.25, decay=120.0))
    place(b, 0, a)
    return fade(b, 0.001, r)


def fx_warn():
    r = HI
    buf = silence(0.78, r)
    for rep in range(2):
        for j, f in enumerate((660.0, 495.0)):
            t = rep * 0.4 + j * 0.15
            tone = partials(f, 0.13, r, [(1.0, 1.0, 6.0), (2.0, 0.25, 8.0), (3.0, 0.1, 10.0)], attack=0.012)
            place(buf, n_of(t, r), tone)
    return fade(lowpass(buf, 3500.0, r), 0.006, r)


def fx_crash():
    r = HI
    n = 0.65
    burst = noise(0.45, r, 1.0, decay=7.0, low=3200.0)
    crunch = noise(0.12, r, 0.8, decay=40.0, high=700.0)
    thump = sweep(130.0, 38.0, n, r, 1.1, decay=6.0, curve=0.5)
    clang = bell(196.0, n, r, 0.28, decay=5.0)
    buf = silence(n, r)
    for t in (burst, crunch, thump, clang):
        place(buf, 0, t)
    place(buf, n_of(0.09, r), noise(0.2, r, 0.35, decay=18.0, low=1500.0))
    return fade(buf, 0.003, r)


def fx_win():
    r = LO
    buf = silence(1.9, r)
    for i, f in enumerate((C5, E5, G5, C6, E5 * 2.0)):
        place(buf, n_of(i * 0.11, r), bell(f, 0.9, r, 0.7, decay=4.0))
    for f in (C5, E5, G5, C6):
        place(buf, n_of(0.58, r), soft(f, 1.2, r, 0.28, attack=0.03, decay=1.6))
    return fade(reverb(buf, r, 0.22, 1.0)[:n_of(1.9, r)], 0.02, r)


def fx_lose():
    r = LO
    buf = silence(1.5, r)
    for i, f in enumerate((440.0, 349.23, 293.66, 220.0)):
        place(buf, n_of(i * 0.2, r), marimba(f, 0.7 - i * 0.05, r, 0.9, decay=5.0))
    place(buf, n_of(0.6, r), soft(110.0, 0.8, r, 0.5, attack=0.03, decay=2.5))
    return fade(reverb(lowpass(buf, 2500.0, r), r, 0.2, 1.0)[:n_of(1.5, r)], 0.02, r)


def fx_siren():
    # Two seamless cycles of a soft two-tone sweep: the carrier completes whole cycles per loop.
    r = LO
    n = n_of(1.0, r)
    phase = 0.0
    out = []
    for i in range(n):
        t = i / r
        f = 730.0 + 110.0 * math.sin(TAU * t / 0.5)
        phase += f / r
        out.append(math.sin(TAU * phase) * 0.8 + math.sin(TAU * phase * 2.0) * 0.15)
    return out


def fx_click():
    r = HI
    return fade(mix(marimba(1250.0, 0.04, r, 0.8, decay=70.0), noise(0.004, r, 0.3, decay=500.0, high=2500.0)),
                0.001, r)


def fx_step():
    r = HI
    buf = silence(0.55, r)
    place(buf, 0, bell(880.0, 0.45, r, 0.7, decay=9.0))
    place(buf, n_of(0.09, r), bell(1318.5, 0.45, r, 0.6, decay=9.0))
    return fade(reverb(buf, r, 0.1, 0.5)[:n_of(0.55, r)], 0.004, r)


def fx_lesson():
    r = LO
    buf = silence(1.5, r)
    for i, f in enumerate((C5, G5, C6)):
        place(buf, n_of(i * 0.13, r), bell(f, 0.8, r, 0.75, decay=4.5))
    for f in (C5, E5, G5):
        place(buf, n_of(0.4, r), soft(f, 1.0, r, 0.3, attack=0.02, decay=2.0))
    place(buf, n_of(0.4, r), bell(E5 * 2.0, 0.9, r, 0.55, decay=4.0))
    return fade(reverb(buf, r, 0.22, 1.0)[:n_of(1.5, r)], 0.02, r)


def fx_fanfare():
    r = LO
    buf = silence(2.8, r)
    run = (C5, E5, G5, C6, E5 * 2.0, G5 * 2.0)
    for i, f in enumerate(run):
        place(buf, n_of(i * 0.12, r), bell(f, 1.0, r, 0.6, decay=3.5))
    for f in (C5, E5, G5, C6):
        place(buf, n_of(0.8, r), soft(f, 1.8, r, 0.3, attack=0.12, decay=1.1))
    for i, f in enumerate((G5 * 2.0, C6 * 2.0, E5 * 4.0)):
        place(buf, n_of(1.05 + i * 0.09, r), bell(f, 0.9, r, 0.3, decay=5.0))
    return fade(reverb(buf, r, 0.28, 1.2)[:n_of(2.8, r)], 0.03, r)


def fx_deny():
    r = HI
    buf = silence(0.3, r)
    for t in (0.0, 0.11):
        tone = partials(165.0, 0.09, r, [(1.0, 1.0, 14.0), (2.0, 0.5, 14.0), (3.0, 0.3, 14.0)], attack=0.004)
        place(buf, n_of(t, r), lowpass(tone, 900.0, r))
    return fade(buf, 0.003, r)


def fx_speed():
    r = HI
    return fade(mix(sweep(520.0, 820.0, 0.09, r, 0.7, decay=18.0), marimba(1040.0, 0.08, r, 0.2, decay=40.0)),
                0.003, r)


# ------------------------------------------------------------------ music

BPM = 96.0
BEAT = 60.0 / BPM
BARS = 12

NOTE = {"C2": 65.41, "D2": 73.42, "E2": 82.41, "F2": 87.31, "G2": 98.0, "A2": 110.0,
        "B2": 123.47, "C3": 130.81, "E3": 164.81, "B3": 246.94, "F3": 174.61, "G3": 196.0, "A3": 220.0,
        "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.0, "A4": 440.0, "B4": 493.88,
        "C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46, "G5": 783.99, "A5": 880.0}

CHORDS = {
    "C": {"arp": ["C4", "E4", "G4", "C5"], "pad": ["C4", "E4", "G4"], "bass": ["C2", "G2"]},
    "Am": {"arp": ["A3", "C4", "E4", "A4"], "pad": ["A3", "C4", "E4"], "bass": ["A2", "E2"]},
    "F": {"arp": ["F4", "A4", "C5", "F5"], "pad": ["F3", "A3", "C4"], "bass": ["F2", "C3"]},
    "G": {"arp": ["G4", "B4", "D5", "G5"], "pad": ["G3", "B3", "D4"], "bass": ["G2", "D2"]},
    "Em": {"arp": ["E4", "G4", "B4", "E5"], "pad": ["E3", "G3", "B3"], "bass": ["E2", "B2"]},
}
PROGRESSION = ["C", "Am", "F", "G", "C", "Em", "F", "G", "Am", "F", "C", "G"]
ARP_A = [0, 2, 1, 3, 1, 2, 1, 3]
ARP_B = [0, 1, 2, 3, 2, 1, 2, 1]

# (beat in bar, note, beats long) per bar of the second and third sections.
MELODY = {
    4: [(0, "E5", 1), (1, "G5", 1), (2, "A5", 1), (3, "G5", 1)],
    5: [(0, "E5", 2), (2, "D5", 1), (3, "E5", 1)],
    6: [(0, "A5", 1), (1, "G5", 1), (2, "F5", 2)],
    7: [(0, "G5", 1), (1, "D5", 1), (2, "E5", 1), (3, "D5", 1)],
    8: [(0, "E5", 2), (2, "C5", 1), (3, "D5", 1)],
    9: [(0, "C5", 1), (1, "A4", 1), (2, "C5", 2)],
    10: [(0, "E5", 1), (1, "D5", 1), (2, "C5", 2)],
    11: [(0, "D5", 2), (2, "G4", 2)],
}


def music():
    r = LO
    total = n_of(BARS * 4 * BEAT, r)
    buf = [0.0] * total
    for bar in range(BARS):
        chord = CHORDS[PROGRESSION[bar]]
        t0 = bar * 4 * BEAT
        # Soft pad under the whole bar.
        for name in chord["pad"]:
            place(buf, n_of(t0, r), soft(NOTE[name], 4 * BEAT * 1.05, r, 0.06, attack=0.25, decay=0.35), True)
        # Bass on beats 1 and 3 (root, then fifth).
        for j, name in enumerate(chord["bass"]):
            place(buf, n_of(t0 + j * 2 * BEAT, r), soft(NOTE[name], 1.6 * BEAT, r, 0.32, attack=0.01, decay=3.0), True)
        # Eighth-note arpeggio.
        pattern = ARP_A if bar % 2 == 0 else ARP_B
        for step in range(8):
            name = chord["arp"][pattern[step] % 4]
            accent = 1.0 if step % 2 == 0 else 0.7
            vol = (0.20 if bar >= 4 else 0.17) * accent
            place(buf, n_of(t0 + step * BEAT / 2.0, r), marimba(NOTE[name], 0.55, r, vol, decay=9.0), True)
        # Bell melody in the second and third sections.
        for beat, name, length in MELODY.get(bar, []):
            place(buf, n_of(t0 + beat * BEAT, r), bell(NOTE[name], 0.5 + length * BEAT * 0.6, r, 0.15, decay=3.0), True)
        # Gentle drums: kick on 1 and 3, soft hat on the off-beats, a brush on 2 and 4 in the last section.
        for j in (0, 2):
            place(buf, n_of(t0 + j * BEAT, r), sweep(120.0, 46.0, 0.2, r, 0.30, decay=14.0, curve=0.5), True)
        for step in range(8):
            if step % 2 == 1 and bar >= 2:
                place(buf, n_of(t0 + step * BEAT / 2.0, r), noise(0.04, r, 0.045, decay=90.0, high=6000.0), True)
        if bar >= 8:
            for j in (1, 3):
                place(buf, n_of(t0 + j * BEAT, r), noise(0.09, r, 0.05, decay=40.0, low=5000.0, high=1500.0), True)
    buf = reverb(buf, r, 0.30, 1.4, circular=True)
    return buf


# ------------------------------------------------------------------ main

def main():
    write("deliver", fx_deliver(), HI)
    write("place", fx_place(), HI)
    write("bridge", fx_bridge(), HI)
    write("erase", fx_erase(), HI)
    write("tick", fx_tick(), HI, 0.7)
    write("warn", fx_warn(), HI, 0.55)
    write("crash", fx_crash(), HI, 0.9)
    write("win", fx_win(), LO)
    write("lose", fx_lose(), LO)
    write("siren", fx_siren(), LO, 0.6)
    write("click", fx_click(), HI, 0.7)
    write("step", fx_step(), HI, 0.7)
    write("lesson", fx_lesson(), LO)
    write("fanfare", fx_fanfare(), LO)
    write("deny", fx_deny(), HI, 0.7)
    write("speed", fx_speed(), HI, 0.7)
    write("music", music(), LO, 0.55)


if __name__ == "__main__":
    main()
