#!/usr/bin/env python3
"""Generates every sound of the game as 16-bit mono 22050 Hz WAV files.

Standard library only. Run from the project folder:  python3 tools/gen_sfx.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
random.seed(7)


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        data = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        )
        w.writeframes(data)
    print("%-12s %6.2f s  %7d bytes" % (name + ".wav", len(samples) / RATE, len(data)))


def n_samples(seconds):
    return int(seconds * RATE)


def tone(freq, seconds, volume=0.5, decay=8.0, shape="sine"):
    out = []
    for i in range(n_samples(seconds)):
        t = i / RATE
        ph = freq * t
        if shape == "sine":
            v = math.sin(2 * math.pi * ph)
        elif shape == "saw":
            v = 2.0 * (ph - math.floor(ph + 0.5))
        else:
            v = 1.0 if (ph % 1.0) < 0.5 else -1.0
        out.append(v * volume * math.exp(-decay * t))
    return out


def sweep(f0, f1, seconds, volume=0.5, decay=3.0, shape="sine"):
    out = []
    phase = 0.0
    total = n_samples(seconds)
    for i in range(total):
        k = i / total
        f = f0 + (f1 - f0) * k
        phase += f / RATE
        if shape == "sine":
            v = math.sin(2 * math.pi * phase)
        else:
            v = 2.0 * (phase - math.floor(phase + 0.5))
        out.append(v * volume * math.exp(-decay * i / RATE))
    return out


def noise(seconds, volume=0.5, decay=20.0):
    return [
        (random.random() * 2 - 1) * volume * math.exp(-decay * i / RATE)
        for i in range(n_samples(seconds))
    ]


def mix(a, b):
    n = max(len(a), len(b))
    a = a + [0.0] * (n - len(a))
    b = b + [0.0] * (n - len(b))
    return [x + y for x, y in zip(a, b)]


def fade(samples, seconds=0.005):
    n = min(n_samples(seconds), len(samples) // 2)
    out = list(samples)
    for i in range(n):
        k = i / n
        out[i] *= k
        out[-1 - i] *= k
    return out


def music():
    """About 19.2 s loop: 100 BPM, pentatonic arpeggio over a soft bass."""
    beat = 60.0 / 100.0
    bars = 8
    total = n_samples(bars * 4 * beat)
    buf = [0.0] * total
    penta = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25]
    chords = [(0, 2, 3, 5), (1, 3, 4, 6), (0, 2, 4, 5), (1, 2, 4, 6)]
    bass = [130.81, 146.83, 110.00, 98.00]

    def add(start, samples):
        for i, s in enumerate(samples):
            buf[(start + i) % total] += s      # wrap tails so the loop is seamless

    for bar in range(bars):
        chord = chords[bar % 4]
        pattern = [0, 1, 2, 3, 2, 1, 2, 3] if bar % 2 == 0 else [0, 2, 1, 3, 2, 3, 1, 2]
        for step in range(8):
            start = n_samples((bar * 4 + step * 0.5) * beat)
            f = penta[chord[pattern[step]]]
            add(start, fade(tone(f, 0.42, 0.11, 6.0)))
            add(start, fade(tone(f * 2, 0.2, 0.025, 12.0)))
        for half in range(2):
            start = n_samples((bar * 4 + half * 2) * beat)
            add(start, fade(tone(bass[bar % 4], 1.1, 0.16, 2.2), 0.02))
    return buf


def main():
    write("deliver", fade(tone(880, 0.09, 0.45, 14) + tone(1320, 0.16, 0.45, 16)))
    write("place", fade(tone(300, 0.08, 0.5, 30)))
    write("erase", fade(sweep(400, 200, 0.1, 0.45, 18)))
    write("tick", fade(noise(0.03, 0.25, 90), 0.002))
    write("warn", fade(sweep(140, 220, 0.6, 0.35, 1.5, "saw"), 0.02))
    write("crash", fade(mix(noise(0.35, 0.6, 9), tone(70, 0.35, 0.6, 7))))
    arp = []
    for f in (523.25, 659.25, 783.99, 1046.5):
        arp += fade(tone(f, 0.2, 0.4, 5))
    write("win", arp)
    write("lose", fade(sweep(400, 150, 0.8, 0.4, 2.0), 0.02))
    half = sweep(600, 900, 0.4, 0.12, 0.0) + sweep(900, 600, 0.4, 0.12, 0.0)
    write("siren", half)
    write("click", fade(tone(1000, 0.04, 0.3, 60), 0.002))
    write("music", music())


if __name__ == "__main__":
    main()
