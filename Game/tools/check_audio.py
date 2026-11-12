#!/usr/bin/env python3
"""Checks every generated sound. Standard library only. Exit code 1 if anything is wrong.

Run:  python3 tools/check_audio.py
"""
import math
import os
import struct
import sys
import wave

AUDIO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
LOOPS = ["siren", "ambience_traffic", "music_base", "music_melody", "music_tension", "music_menu"]
MUSIC_LAYERS = ["music_base", "music_melody", "music_tension"]
EXPECTED = (
    ["deliver_%d" % i for i in range(5)]
    + ["place_road", "place_bridge", "place_light", "place_sorter", "erase", "invalid", "tool_select",
       "ui_click", "ui_hover", "ui_toggle_on", "ui_toggle_off", "panel_open", "panel_close", "light_switch",
       "speed_up", "speed_down", "pause", "resume", "jam_warn", "gridlock_warn", "patience_low", "crash",
       "siren", "countdown_tick", "goal_reached", "goal_failed", "star_1", "star_2", "star_3", "win", "lose",
       "tutorial_step", "lesson_complete", "ambience_traffic", "music_base", "music_melody",
       "music_tension", "music_menu"]
)
PEAK_LIMIT_DB = -0.5
EDGE_SAMPLES = 20
EDGE_LIMIT = 0.02            # of full scale: a click risk above this
SEAM_LIMIT = 0.05            # of full scale: loop first/last sample difference
DC_LIMIT = 0.01
MAX_TOTAL_BYTES = 6 * 1024 * 1024


def load(name):
    path = os.path.join(AUDIO, name + ".wav")
    with wave.open(path, "rb") as w:
        meta = (w.getnchannels(), w.getsampwidth(), w.getframerate())
        raw = w.readframes(w.getnframes())
    n = len(raw) // 2
    return meta, [v / 32768.0 for v in struct.unpack("<%dh" % n, raw)]


def db(v):
    return 20.0 * math.log10(max(v, 1e-9))


def main():
    problems = []
    rows = []
    music_lengths = {}
    for name in EXPECTED:
        path = os.path.join(AUDIO, name + ".wav")
        if not os.path.exists(path):
            problems.append("%s: missing" % name)
            continue
        meta, x = load(name)
        if meta != (1, 2, 22050):
            problems.append("%s: not 16-bit mono 22050 Hz (%s)" % (name, meta))
        if not x:
            problems.append("%s: empty" % name)
            continue
        peak = max(abs(v) for v in x)
        rms = math.sqrt(sum(v * v for v in x) / len(x))
        rows.append((name, len(x) / 22050.0, db(peak), db(rms)))
        if peak < 0.001:
            problems.append("%s: silent" % name)
        if db(peak) > PEAK_LIMIT_DB:
            problems.append("%s: peak %.2f dBFS is above %.1f (clipping risk)" % (name, db(peak), PEAK_LIMIT_DB))
        if name in LOOPS:
            if abs(x[-1] - x[0]) > SEAM_LIMIT:
                problems.append("%s: loop seam jumps by %.3f" % (name, abs(x[-1] - x[0])))
        else:
            if max(abs(v) for v in x[:EDGE_SAMPLES]) > EDGE_LIMIT:
                problems.append("%s: start is not near zero (click risk)" % name)
            if max(abs(v) for v in x[-EDGE_SAMPLES:]) > EDGE_LIMIT:
                problems.append("%s: end is not near zero (click risk)" % name)
        if abs(sum(x) / len(x)) > DC_LIMIT:
            problems.append("%s: DC offset %.4f" % (name, sum(x) / len(x)))
        if name in MUSIC_LAYERS:
            music_lengths[name] = len(x)
    if len(set(music_lengths.values())) > 1:
        problems.append("music layers differ in length: %s" % music_lengths)
    extra = [f[:-4] for f in os.listdir(AUDIO) if f.endswith(".wav") and f[:-4] not in EXPECTED]
    if extra:
        problems.append("unexpected files: %s" % extra)
    total = sum(os.path.getsize(os.path.join(AUDIO, f)) for f in os.listdir(AUDIO) if f.endswith(".wav"))
    if total > MAX_TOTAL_BYTES:
        problems.append("audio/ is %.2f MB, above 6 MB" % (total / 1048576.0))

    print("%-18s %8s %10s %10s" % ("file", "seconds", "peak dBFS", "rms dBFS"))
    for name, sec, p, r in rows:
        print("%-18s %8.2f %10.1f %10.1f" % (name, sec, p, r))
    print("total %.2f MB, %d files" % (total / 1048576.0, len(rows)))
    if problems:
        print("\nFAILED:")
        for p in problems:
            print("  - " + p)
        return 1
    print("\nOK: all audio checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
