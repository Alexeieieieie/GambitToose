#!/usr/bin/env python3
"""Generates every sound of the game as 16-bit mono 22050 Hz WAV files.

Standard library only, deterministic (fixed seeds), offline. Run:  python3 tools/gen_sfx.py
Then check the result with:  python3 tools/check_audio.py

Design rules: soft envelopes (attack >= 3 ms, release reaches exactly zero, plus a 5 ms
fade-in and 10 ms fade-out on everything), warm tones (sine / triangle / band-limited soft
saw), a small three-tap room for softness, tanh soft clipping, and loops that wrap their
tails into their own start so the loop point has neither a gap nor a click.
"""
import math
import os
import random
import struct
import wave

SR = 22050
TAU = 2.0 * math.pi
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")

# ---------------------------------------------------------------- loudness table
# Peak targets in dBFS before bus gain. Tune the whole mix here.
PEAK_DB = {
    "event": -6.0,
    "action": -6.0,
    "ui": -12.0,
    "warning": -8.0,
    "reward": -5.0,
    "jingle": -6.0,
    "loop": -18.0,
    "music": -14.0,
}
RMS_TOLERANCE_DB = 2.0       # similar classes are pulled to within this of their median RMS
PEAK_CEILING_DB = -1.0       # RMS matching never pushes a peak above this

NOTE = {
    "C2": 65.41, "G2": 98.0, "A2": 110.0, "F2": 87.31,
    "D4": 293.66, "A3": 220.0, "B3": 246.94, "C4": 261.63, "E4": 329.63, "F4": 349.23,
    "G4": 392.0, "A4": 440.0, "B4": 493.88, "F3": 174.61, "G3": 196.0,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.0, "B5": 987.77,
    "C6": 1046.5, "D6": 1174.66, "E6": 1318.51, "G6": 1567.98,
    "Eb4": 311.13, "Bb4": 466.16, "Ab4": 415.3, "Eb5": 622.25, "Bb3": 233.08,
}


# ---------------------------------------------------------------- DSP helpers

def n_of(seconds):
    return int(round(seconds * SR))


def osc(kind, phase, width=0.5):
    """One oscillator sample for a phase in cycles. All shapes are soft."""
    p = phase - math.floor(phase)
    if kind == "sine":
        return math.sin(TAU * p)
    if kind == "tri":
        return 4.0 * abs(p - 0.5) - 1.0
    if kind == "saw":    # additive: six harmonics, decreasing amplitude
        return sum(math.sin(TAU * k * p) / (k ** 1.6) for k in range(1, 7)) * 0.8
    if kind == "pulse":  # soft pulse: a smoothed square of adjustable width
        return 0.55 * (math.sin(TAU * p) - math.sin(TAU * (p + (1.0 - width))))
    raise ValueError(kind)


def adsr(n, a, d, s, r):
    """Envelope of n samples. Attack >= 3 ms; release ends exactly at zero."""
    a_n = max(n_of(max(a, 0.003)), 1)
    d_n = max(n_of(d), 1)
    r_n = max(min(n_of(r), n - 1), 1)
    env = []
    for i in range(n):
        if i < a_n:
            v = i / a_n
        elif i < a_n + d_n:
            v = 1.0 + (s - 1.0) * ((i - a_n) / d_n)
        else:
            v = s
        if i >= n - r_n:
            v *= (n - 1 - i) / r_n
        env.append(v)
    env[-1] = 0.0
    return env


def decay_env(n, a, tau):
    """Soft attack, exponential decay, forced to exactly zero at the end."""
    a_n = max(n_of(max(a, 0.003)), 1)
    out = []
    for i in range(n):
        out.append((i / a_n) if i < a_n else math.exp(-(i - a_n) / (tau * SR)))
    r_n = max(min(n_of(0.02), n // 3), 1)
    for i in range(n - r_n, n):
        out[i] *= (n - 1 - i) / r_n
    out[-1] = 0.0
    return out


def tone(freq, dur, kind="sine", env=None, f_end=None, amp=1.0, width=0.5, detune=0.0):
    """A tone; `freq` may glide exponentially to `f_end`. `env` is a list or None (a soft ADSR)."""
    n = n_of(dur)
    if env is None:
        env = adsr(n, 0.01, 0.05, 0.7, min(0.08, dur * 0.5))
    out = []
    ph = 0.0
    for i in range(n):
        f = freq if f_end is None else freq * (f_end / freq) ** (i / max(n - 1, 1))
        ph += f * (1.0 + detune) / SR
        out.append(amp * env[i] * osc(kind, ph, width))
    return out


def bell(freq, dur, amp=1.0, tau=0.12, harm2=0.25, harm3=0.0):
    """Soft bell: a sine plus quiet harmonics under a decaying envelope."""
    n = n_of(dur)
    env = decay_env(n, 0.004, tau)
    out = []
    for i in range(n):
        t = i / SR
        v = math.sin(TAU * freq * t) + harm2 * math.sin(TAU * 2 * freq * t) * math.exp(-t / (tau * 0.7))
        if harm3:
            v += harm3 * math.sin(TAU * 2.76 * freq * t) * math.exp(-t / (tau * 0.5))
        out.append(amp * env[i] * v)
    return out


def white(n, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def brown(n, rng):
    """Brown noise: leaky-integrated white noise, normalized to +-1."""
    out = []
    v = 0.0
    for _ in range(n):
        v = v * 0.995 + rng.uniform(-1.0, 1.0) * 0.1
        out.append(v)
    peak = max(abs(x) for x in out) or 1.0
    return [x / peak for x in out]


def lowpass(x, cutoff):
    a = 1.0 - math.exp(-TAU * cutoff / SR)
    y = 0.0
    out = []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    return [v - l for v, l in zip(x, lowpass(x, cutoff))]


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def sweep_noise(n, rng, f_from, f_to, q_mix=0.6):
    """Noise through a two-pole low-pass whose cutoff glides from f_from to f_to (a soft swoosh)."""
    out = []
    y = 0.0
    z = 0.0
    for i in range(n):
        f = f_from * (f_to / f_from) ** (i / max(n - 1, 1))
        a = 1.0 - math.exp(-TAU * f / SR)
        y += a * (rng.uniform(-1.0, 1.0) - y)
        z += a * (y - z)
        out.append(q_mix * y + (1.0 - q_mix) * z)
    return out


def apply_env(x, env):
    return [a * b for a, b in zip(x, env)]


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
    n = len(buf)
    for i, v in enumerate(sig):
        j = start + i
        if j >= n:
            if not wrap:
                break
            j %= n
        buf[j] += v


def at(total, *parts):
    """Lays (start_seconds, signal) parts into a buffer of `total` seconds."""
    buf = [0.0] * n_of(total)
    for start, sig in parts:
        place(buf, n_of(start), sig)
    return buf


def room(x, wet=0.22, cyclic=False):
    """A tiny feedback-style room: three taps under 80 ms, for softness."""
    taps = [(n_of(0.023), 0.50), (n_of(0.047), 0.32), (n_of(0.071), 0.20)]
    out = list(x)
    n = len(x)
    for d, g in taps:
        for i in range(n):
            j = i - d
            if j >= 0:
                out[i] += wet * g * x[j]
            elif cyclic:
                out[i] += wet * g * x[j % n]
    return out


def softclip(x, drive=1.4):
    norm = math.tanh(drive)
    return [math.tanh(drive * v) / norm for v in x]


def peak_of(x):
    return max(abs(v) for v in x) if x else 0.0


def finish(x, fade_in=0.005, fade_out=0.010):
    """Fades that guarantee no click at either end."""
    x = list(x)
    fi = min(n_of(fade_in), len(x) // 2)
    fo = min(n_of(fade_out), len(x) // 2)
    for i in range(fi):
        x[i] *= (i / fi) ** 2          # quadratic: the first 20 samples are practically silent
    for i in range(fo):
        x[len(x) - 1 - i] *= (i / fo) ** 2
    if x:
        x[-1] = 0.0
    return x


def close_loop(x, xfade=0.05):
    """Makes a steady sound loop: the last `xfade` seconds are crossfaded into the start."""
    k = n_of(xfade)
    n = len(x) - k
    out = x[:n]
    for i in range(k):
        w = i / k
        out[i] = x[i] * math.sin(w * math.pi / 2) + x[n + i] * math.cos(w * math.pi / 2)
    return out


def db_to_lin(db):
    return 10.0 ** (db / 20.0)


def normalize(x, peak_db):
    return gain(x, db_to_lin(peak_db) / (peak_of(x) or 1.0))


def rms_db(x):
    r = math.sqrt(sum(v * v for v in x) / len(x)) if x else 0.0
    return 20.0 * math.log10(max(r, 1e-9))


def delayed(seconds, sig):
    return [0.0] * n_of(seconds) + sig


# ---------------------------------------------------------------- the sounds

def s_deliver(note):
    return room(bell(NOTE[note], 0.3, tau=0.09, harm2=0.18), 0.18)


def s_place_road():
    rng = random.Random(101)
    n = n_of(0.09)
    thump = tone(150, 0.09, env=decay_env(n, 0.003, 0.025), f_end=85)
    tap = apply_env(lowpass(white(n, rng), 1800), decay_env(n, 0.003, 0.006))
    return softclip(mix(thump, gain(tap, 0.12)), 1.2)


def s_place_bridge():
    rng = random.Random(102)
    parts = []
    for start, f in [(0.0, 230.0), (0.05, 310.0)]:
        n = n_of(0.085)
        body = mix(tone(f, 0.085, env=decay_env(n, 0.003, 0.03), f_end=f * 0.9),
                   gain(tone(f * 2.4, 0.085, env=decay_env(n, 0.003, 0.012)), 0.25))
        knock = apply_env(bandpass(white(n, rng), 400, 1600), decay_env(n, 0.003, 0.01))
        parts.append((start, mix(body, gain(knock, 0.2))))
    return room(at(0.14, *parts), 0.2)


def s_place_light():
    rng = random.Random(103)
    n = n_of(0.012)
    click = apply_env(highpass(white(n, rng), 1800), decay_env(n, 0.003, 0.003))
    beep = tone(880, 0.1, env=adsr(n_of(0.1), 0.01, 0.02, 0.6, 0.05), amp=0.7)
    return at(0.16, (0.0, gain(click, 0.5)), (0.045, beep))


def s_place_sorter():
    rng = random.Random(104)
    parts = []
    for i in range(3):
        n = n_of(0.03)
        tick = apply_env(bandpass(white(n, rng), 900, 3500), decay_env(n, 0.003, 0.006))
        body = tone(420 + 60 * i, 0.03, env=decay_env(n, 0.003, 0.008))
        parts.append((i * 0.045, mix(gain(tick, 0.5), gain(body, 0.6))))
    return at(0.15, *parts)


def s_erase():
    rng = random.Random(105)
    n = n_of(0.12)
    return apply_env(sweep_noise(n, rng, 3200, 350), decay_env(n, 0.005, 0.045))


def s_invalid():
    n = n_of(0.055)
    parts = []
    for start in (0.0, 0.075):
        b = tone(118, 0.055, kind="saw", env=adsr(n, 0.008, 0.01, 0.8, 0.02))
        parts.append((start, lowpass(b, 450)))
    return softclip(at(0.15, *parts), 1.1)


def s_tool_select():
    return tone(480, 0.05, env=decay_env(n_of(0.05), 0.004, 0.012), f_end=640)


def s_ui_click():
    rng = random.Random(106)
    n = n_of(0.04)
    body = tone(1050, 0.04, env=decay_env(n, 0.003, 0.008))
    tick = apply_env(lowpass(white(n, rng), 3000), decay_env(n, 0.003, 0.004))
    return mix(body, gain(tick, 0.25))


def s_ui_hover():
    return tone(1500, 0.02, env=decay_env(n_of(0.02), 0.003, 0.005))


def s_toggle(up):
    notes = (NOTE["E5"], NOTE["A5"]) if up else (NOTE["A5"], NOTE["E5"])
    n = n_of(0.04)
    return mix(*[delayed(i * 0.04, tone(f, 0.04, env=decay_env(n, 0.004, 0.015))) for i, f in enumerate(notes)])


def s_panel(opening):
    rng = random.Random(107 if opening else 108)
    n = n_of(0.15)
    f0, f1 = (700, 2800) if opening else (2800, 700)
    sw = sweep_noise(n, rng, f0, f1, q_mix=0.4)
    return apply_env(highpass(sw, 300), adsr(n, 0.04, 0.03, 0.6, 0.07))


def s_light_switch():
    rng = random.Random(109)
    n = n_of(0.03)
    t = tone(720, 0.03, env=decay_env(n, 0.003, 0.006))
    k = apply_env(lowpass(white(n, rng), 2500), decay_env(n, 0.003, 0.004))
    return mix(t, gain(k, 0.3))


def s_speed(up):
    n = n_of(0.12)
    a, b = (420, 900) if up else (900, 420)
    return tone(a, 0.12, env=adsr(n, 0.01, 0.02, 0.7, 0.06), f_end=b)


def s_pause():
    return tone(640, 0.2, env=decay_env(n_of(0.2), 0.005, 0.07), f_end=130, kind="tri")


def s_resume():
    return tone(260, 0.2, env=adsr(n_of(0.2), 0.01, 0.04, 0.6, 0.12), f_end=720, kind="tri")


def s_jam_warn():
    parts = []
    for start, f in [(0.0, 540), (0.17, 450)]:
        n = n_of(0.16)
        parts.append((start, tone(f, 0.16, env=decay_env(n, 0.012, 0.07), f_end=f * 0.72, amp=0.9)))
    return room(at(0.35, *parts), 0.2)


def s_gridlock_warn():
    parts = []
    for start, amp in [(0.0, 1.0), (0.2, 0.75)]:
        n = n_of(0.2)
        pulse = mix(tone(72, 0.2, env=decay_env(n, 0.012, 0.05)),
                    gain(tone(144, 0.2, env=decay_env(n, 0.012, 0.04)), 0.45))
        parts.append((start, gain(pulse, amp)))
    return at(0.5, *parts)


def s_patience_low():
    parts = [(i * 0.1, bell(NOTE["G6"], 0.14, tau=0.05, harm2=0.1, amp=0.8 - 0.15 * i)) for i in range(3)]
    return room(at(0.3, *parts), 0.18)


def s_crash():
    rng = random.Random(110)
    n = n_of(0.3)
    thump = tone(95, 0.3, env=decay_env(n, 0.004, 0.07), f_end=42)
    burst = apply_env(lowpass(white(n, rng), 1400), decay_env(n, 0.003, 0.03))
    return softclip(mix(thump, gain(burst, 0.5)), 1.5)


def s_siren():
    # Two-tone "wee-woo", 1 s loop, soft saw through a low-pass so it is never piercing.
    n = n_of(1.05)
    out = []
    ph = 0.0
    for i in range(n):
        s = 0.5 + 0.5 * math.tanh(4.0 * math.sin(TAU * i / SR))
        ph += (440.0 + (587.0 - 440.0) * s) / SR
        out.append(osc("saw", ph))
    return close_loop(lowpass(out, 1100), 0.05)


def s_countdown_tick():
    rng = random.Random(111)
    n = n_of(0.05)
    t = tone(940, 0.05, env=decay_env(n, 0.003, 0.01))
    k = apply_env(lowpass(white(n, rng), 3500), decay_env(n, 0.003, 0.004))
    return mix(t, gain(k, 0.2))


def s_goal_reached():
    parts = [(i * 0.1, bell(NOTE[nm], 0.22, tau=0.07, harm2=0.2, harm3=0.1)) for i, nm in enumerate(["C6", "E6", "G6"])]
    return room(at(0.4, *parts), 0.22)


def s_goal_failed():
    parts = []
    for start, nm in [(0.0, "E5"), (0.15, "C5")]:
        n = n_of(0.2)
        parts.append((start, tone(NOTE[nm], 0.2, kind="tri", env=decay_env(n, 0.008, 0.09), amp=0.9)))
    return room(at(0.35, *parts), 0.18)


def s_star(i):
    f = [NOTE["G5"], NOTE["B5"], NOTE["D6"]][i]
    body = bell(f, 0.6, tau=0.17, harm2=0.3, harm3=0.12)
    shimmer = gain(bell(f * 2.0 * 1.003, 0.6, tau=0.22, harm2=0.0), 0.22)
    return room(mix(body, shimmer), 0.25)[:n_of(0.6)]


def s_win():
    parts = [(i * 0.2, bell(NOTE[nm], 0.55, tau=0.14, harm2=0.2)) for i, nm in enumerate(["C5", "E5", "G5", "C6"])]
    for nm in ("E5", "G5", "C6"):          # bell harmony under the last note
        parts.append((0.6, gain(bell(NOTE[nm], 0.6, tau=0.3, harm2=0.1), 0.45)))
    return room(at(1.2, *parts), 0.26)


def s_lose():
    parts = []
    for start, nm in [(0.0, "A4"), (0.3, "F4"), (0.6, "D4")]:
        n = n_of(0.4)
        f = NOTE[nm]
        sig = mix(tone(f, 0.4, kind="tri", env=decay_env(n, 0.02, 0.15)),
                  gain(tone(f * 0.5, 0.4, env=decay_env(n, 0.02, 0.2)), 0.5))
        parts.append((start, sig))
    return room(at(1.0, *parts), 0.24)


def s_tutorial_step():
    parts = [(0.0, bell(NOTE["E5"], 0.12, tau=0.05)), (0.08, bell(NOTE["A5"], 0.12, tau=0.06))]
    return room(at(0.2, *parts), 0.16)


def s_lesson_complete():
    parts = [(i * 0.1, bell(NOTE[nm], 0.35, tau=0.1, harm2=0.2)) for i, nm in enumerate(["C5", "E5", "G5", "C6", "E6"])]
    parts.append((0.5, gain(bell(NOTE["G5"], 0.3, tau=0.2), 0.4)))
    return room(at(0.8, *parts), 0.24)


def s_ambience():
    # 8 s loop: brown noise through a low-pass plus a faint low engine hum, with a slow swell.
    rng = random.Random(112)
    n = n_of(8.5)
    rumble = lowpass(brown(n, rng), 320)
    out = []
    for i in range(n):
        t = i / SR
        hum = 0.5 * math.sin(TAU * 55.0 * t) + 0.25 * math.sin(TAU * 110.0 * t + 0.7)
        out.append((rumble[i] * 0.7 + hum * 0.18) * (0.8 + 0.2 * math.sin(TAU * 0.25 * t)))
    return close_loop(out, 0.5)


# ---------------------------------------------------------------- music

def pad_note(freq, dur):
    n = n_of(dur)
    env = adsr(n, 0.7, 0.4, 0.8, 0.9)
    return mix(tone(freq, dur, kind="tri", env=env, amp=0.5),
               tone(freq, dur, kind="sine", env=env, amp=0.5, detune=0.004))


def bass_note(freq, dur):
    return tone(freq, dur, env=adsr(n_of(dur), 0.02, 0.1, 0.6, dur * 0.4))


def pluck(freq, dur=0.5, amp=1.0):
    n = n_of(dur)
    env = decay_env(n, 0.005, 0.14)
    return [amp * env[i] * (math.sin(TAU * freq * i / SR)
            + 0.3 * math.sin(TAU * 2 * freq * i / SR) * math.exp(-i / SR / 0.06)) for i in range(n)]


CHORDS = {   # bass root, three pad notes, eight arpeggio notes (all pentatonic-friendly)
    "C": ("C2", ["C4", "E4", "G4"], ["C5", "E5", "G5", "A5", "G5", "E5", "D5", "E5"]),
    "Am": ("A2", ["A3", "C4", "E4"], ["A4", "C5", "E5", "A5", "E5", "D5", "C5", "E5"]),
    "F": ("F2", ["F3", "A3", "C4"], ["C5", "D5", "E5", "G5", "E5", "D5", "C5", "A4"]),
    "G": ("G2", ["G3", "B3", "D4"], ["G4", "B4", "D5", "G5", "D5", "B4", "A4", "D5"]),
}
PROGRESSION = ["C", "Am", "F", "G", "C", "Am", "F", "G", "F", "G"]   # 10 bars at 100 BPM = 24 s


def _geometry(bpm, bars):
    beat = 60.0 / bpm
    bar = 4 * beat
    return beat, bar, int(round(bars * bar * SR))


def music_base(bpm=100, bars=10, prog=PROGRESSION):
    beat, bar, total = _geometry(bpm, bars)
    buf = [0.0] * total
    for b, name in enumerate(prog):
        root, pad, _ = CHORDS[name]
        t0 = n_of(b * bar)
        for nm in pad:
            place(buf, t0, gain(pad_note(NOTE[nm], bar + 0.3), 0.33), wrap=True)
        for k in (0, 2):
            place(buf, t0 + n_of(k * beat), gain(bass_note(NOTE[root], beat * 1.8), 0.7), wrap=True)
    return buf


def music_melody(bpm=100, bars=10, prog=PROGRESSION):
    beat, bar, total = _geometry(bpm, bars)
    buf = [0.0] * total
    for b, name in enumerate(prog):
        for i, nm in enumerate(CHORDS[name][2]):
            vel = 1.0 if i % 2 == 0 else 0.6
            place(buf, n_of(b * bar + i * beat / 2.0), gain(pluck(NOTE[nm], 0.6), 0.5 * vel), wrap=True)
    return room(buf, 0.3, cyclic=True)


def music_tension(bpm=100, bars=10, prog=PROGRESSION):
    beat, bar, total = _geometry(bpm, bars)
    buf = [0.0] * total
    minor_color = ["Eb4", "Bb3", "Ab4", "Eb5", "Bb4"]
    for b, name in enumerate(prog):
        root = NOTE[CHORDS[name][0]] * 2
        for k in range(4):                       # a soft pulse on every beat
            n = n_of(beat * 0.5)
            place(buf, n_of(b * bar + k * beat),
                  tone(root, beat * 0.5, kind="tri", env=decay_env(n, 0.01, 0.12), amp=0.8), wrap=True)
        if b % 2 == 1:                           # a few minor-colour notes
            nm = minor_color[(b // 2) % len(minor_color)]
            place(buf, n_of(b * bar + 2.5 * beat), gain(pluck(NOTE[nm], 0.9), 0.55), wrap=True)
    return room(buf, 0.25, cyclic=True)


def music_menu():
    # Calmer and slower: 80 BPM, 8 bars = 24 s. The melody sits well under the pad.
    prog = ["C", "Am", "F", "G", "C", "Am", "F", "G"]
    return mix(music_base(80, 8, prog), gain(music_melody(80, 8, prog), 0.55))


# ---------------------------------------------------------------- file list

def sound_table():
    """file name -> (class, builder, is_loop)."""
    t = {}
    for i, nm in enumerate(["C5", "D5", "E5", "G5", "A5"]):
        t["deliver_%d" % i] = ("event", (lambda nm=nm: s_deliver(nm)), False)
    t["place_road"] = ("action", s_place_road, False)
    t["place_bridge"] = ("action", s_place_bridge, False)
    t["place_light"] = ("action", s_place_light, False)
    t["place_sorter"] = ("action", s_place_sorter, False)
    t["erase"] = ("action", s_erase, False)
    t["invalid"] = ("warning", s_invalid, False)
    t["tool_select"] = ("ui", s_tool_select, False)
    t["ui_click"] = ("ui", s_ui_click, False)
    t["ui_hover"] = ("ui", s_ui_hover, False)
    t["ui_toggle_on"] = ("ui", (lambda: s_toggle(True)), False)
    t["ui_toggle_off"] = ("ui", (lambda: s_toggle(False)), False)
    t["panel_open"] = ("ui", (lambda: s_panel(True)), False)
    t["panel_close"] = ("ui", (lambda: s_panel(False)), False)
    t["light_switch"] = ("event", s_light_switch, False)
    t["speed_up"] = ("ui", (lambda: s_speed(True)), False)
    t["speed_down"] = ("ui", (lambda: s_speed(False)), False)
    t["pause"] = ("ui", s_pause, False)
    t["resume"] = ("ui", s_resume, False)
    t["jam_warn"] = ("warning", s_jam_warn, False)
    t["gridlock_warn"] = ("warning", s_gridlock_warn, False)
    t["patience_low"] = ("warning", s_patience_low, False)
    t["crash"] = ("event", s_crash, False)
    t["siren"] = ("loop", s_siren, True)
    t["countdown_tick"] = ("event", s_countdown_tick, False)
    t["goal_reached"] = ("reward", s_goal_reached, False)
    t["goal_failed"] = ("ui", s_goal_failed, False)
    for i in range(3):
        t["star_%d" % (i + 1)] = ("reward", (lambda i=i: s_star(i)), False)
    t["win"] = ("jingle", s_win, False)
    t["lose"] = ("jingle", s_lose, False)
    t["tutorial_step"] = ("ui", s_tutorial_step, False)
    t["lesson_complete"] = ("jingle", s_lesson_complete, False)
    t["ambience_traffic"] = ("loop", s_ambience, True)
    t["music_base"] = ("music", music_base, True)
    t["music_melody"] = ("music", music_melody, True)
    t["music_tension"] = ("music", music_tension, True)
    t["music_menu"] = ("music", music_menu, True)
    return t


def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(round(v * 32767.0))))) for v in x))


def main():
    os.makedirs(OUT, exist_ok=True)
    random.seed(20240607)
    table = sound_table()
    built = {}
    for name, (cls, fn, is_loop) in table.items():
        x = fn()
        if not is_loop:
            x = finish(x)
        elif cls == "music":
            x = softclip(x, 1.2)          # loops keep their exact length: no fades
        built[name] = normalize(x, PEAK_DB[cls])
    # Pull similar classes to within RMS_TOLERANCE_DB of their median RMS (peak stays under the ceiling).
    by_class = {}
    for name, (cls, _, is_loop) in table.items():
        if not is_loop:
            by_class.setdefault(cls, []).append(name)
    for cls, names in by_class.items():
        levels = sorted(rms_db(built[n]) for n in names)
        med = levels[len(levels) // 2]
        for n in names:
            diff = max(-RMS_TOLERANCE_DB, min(RMS_TOLERANCE_DB, med - rms_db(built[n])))
            headroom = PEAK_CEILING_DB - 20.0 * math.log10(max(peak_of(built[n]), 1e-9))
            built[n] = gain(built[n], db_to_lin(min(diff, headroom)))
    for name, x in built.items():
        write_wav(os.path.join(OUT, name + ".wav"), x)
    for f in os.listdir(OUT):             # remove files of the previous sound set
        if f.endswith(".wav") and f[:-4] not in built:
            os.remove(os.path.join(OUT, f))
            imp = os.path.join(OUT, f + ".import")
            if os.path.exists(imp):
                os.remove(imp)
    print("wrote %d files to %s" % (len(built), os.path.abspath(OUT)))


if __name__ == "__main__":
    main()
