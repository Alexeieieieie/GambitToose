# GambitToose audio

Every sound is generated offline by `tools/gen_sfx.py` (Python standard library only, fixed seeds) as 16-bit mono 22050 Hz WAV. The runtime is split in two:

- `audio/audio_director.gd` decides **what** to play (streak, merging, cooldowns, voice limits, ducking, music intensity). It has no scene tree and is unit tested.
- `autoload/sfx.gd` **plays** it: buses, a pool of 10 players, three synchronized music layers, ambience, siren, the pause low-pass.

## Buses

`Master` (limiter, ceiling -1 dB) > `Music` (low-pass at 900 Hz while paused), `SFX`, `UI`, `Ambience` (sends to `SFX`). Settings sliders set Master, Music and Effects (`SFX` and `UI`); defaults 100 / 60 / 90, saved in `user://save.cfg`.

## One-shot sounds

| Sound | Trigger | Bus | Base dB | Priority | Cooldown ms | Voices |
|---|---|---|---|---|---|---|
| `deliver` | `deliver` event; note climbs C5 D5 E5 G5 A5 with the streak; bursts within 150 ms merge | SFX | 0.0 | 3 | 0 | 3 |
| `place_road` | road built | SFX | -2.0 | 2 | 40 | 2 |
| `place_bridge` | bridge built | SFX | -2.0 | 2 | 60 | 2 |
| `place_light` | light placed or applied | SFX | -2.0 | 2 | 60 | 2 |
| `place_sorter` | sorter placed or applied | SFX | -2.0 | 2 | 60 | 2 |
| `erase` | something erased | SFX | -3.0 | 2 | 50 | 2 |
| `invalid` | rejected action (no items, blocked tile, no water), locked tool | SFX | -3.0 | 3 | 150 | 1 |
| `tool_select` | a different tool chosen | UI | -2.0 | 1 | 40 | 1 |
| `ui_click` | any button | UI | 0.0 | 1 | 30 | 2 |
| `ui_hover` | hover on main-menu and panel buttons | UI | -4.0 | 0 | 60 | 1 |
| `ui_toggle_on` | sound or heatmap switched on | UI | 0.0 | 1 | 80 | 1 |
| `ui_toggle_off` | sound or heatmap switched off | UI | 0.0 | 1 | 80 | 1 |
| `panel_open` | light/sorter/goals/settings panel opens | UI | 0.0 | 1 | 100 | 1 |
| `panel_close` | panel closes | UI | 0.0 | 1 | 100 | 1 |
| `light_switch` | `light_switch` sim event | SFX | -12.0 | 1 | 120 | 2 |
| `speed_up` | speed raised | UI | 0.0 | 1 | 80 | 1 |
| `speed_down` | speed lowered | UI | 0.0 | 1 | 80 | 1 |
| `pause` | paused | UI | 0.0 | 2 | 150 | 1 |
| `resume` | resumed from pause | UI | 0.0 | 2 | 150 | 1 |
| `jam_warn` | `jam_start` (once per 5 s), music ducks 4 dB for 1 s | SFX | -1.0 | 4 | 5000 | 1 |
| `gridlock_warn` | `gridlock_risk` (nothing moved for 8 s), repeats every 2 s | SFX | -1.0 | 4 | 2000 | 1 |
| `patience_low` | `patience_low` (warehouse below 25 % / 10 %) | SFX | -1.0 | 4 | 1500 | 1 |
| `crash` | `crash` (tutorial lesson 2) | SFX | 0.0 | 5 | 300 | 2 |
| `countdown_tick` | each second of the last 10 s of a timed level | SFX | -3.0 | 2 | 700 | 1 |
| `goal_reached` | `goal_reached` event | SFX | 0.0 | 4 | 300 | 2 |
| `goal_failed` | `goal_failed` event | SFX | 0.0 | 4 | 300 | 2 |
| `star_1` | results: first earned star | SFX | 0.0 | 5 | 0 | 1 |
| `star_2` | results: second earned star | SFX | 0.0 | 5 | 0 | 1 |
| `star_3` | results: third earned star | SFX | 0.0 | 5 | 0 | 1 |
| `win` | level won, tutorial completed | SFX | 0.0 | 6 | 0 | 1 |
| `lose` | level lost | SFX | 0.0 | 6 | 0 | 1 |
| `tutorial_step` | tutorial step done, new building appears | UI | 0.0 | 3 | 100 | 1 |
| `lesson_complete` | tutorial lesson done | SFX | 0.0 | 5 | 300 | 1 |

`deliver` plays one of `deliver_0` to `deliver_4`. Pitch jitter (a few percent on frequent sounds) comes from a separate random generator inside `Sfx`, never from the simulation.

## Loops and music

| File | Use |
|---|---|
| `siren` | fades in over 0.3 s while an urgent truck is driving, out when none remain |
| `ambience_traffic` | quiet traffic bed, volume follows the vehicle count (0 to 40 vehicles) |
| `music_base` | always on in levels (24 s, 100 BPM, 10 bars) |
| `music_melody` | fades in (1.5 s) after the first delivery |
| `music_tension` | fades in (1 s) when intensity > 0.5, out below 0.35 |
| `music_menu` | menus only (24 s, 80 BPM, 8 bars) |

The three level layers have exactly the same length and start in the same frame. Every second a layer more than 30 ms away from the base is restarted at the base position. Music pitch follows the speed (1.0, 1.04, 1.08). Pausing lowers the music 6 dB and low-passes it; the results screen fades the layers out over 1 s.

Music intensity (every 0.5 s, smoothed): `0.5 * jam_fraction + 0.3 * (1 - lowest_patience_ratio) + 0.2 * gridlock_fraction`, where `jam_fraction` is the share of road tiles above 0.8 density (scaled so that a quarter of the roads jammed counts as full).

## Regenerate and check

```
python3 tools/gen_sfx.py      # writes audio/*.wav, removes files of older sound sets
python3 tools/check_audio.py  # table of length, peak and RMS; exit code 1 on any problem
```

After changing audio files run `godot --path . --editor --quit` once so Godot imports them.

## Tuning the loudness

Open `tools/gen_sfx.py` and edit the `PEAK_DB` table at the top (peak target in dBFS per class: event, action, ui, warning, reward, jingle, loop, music). After that every non-loop class is pulled to within 2 dB of its median RMS (never above -1 dBFS peak). Per-sound offsets and cooldowns live in the `REGISTRY` of `audio/audio_director.gd`. The check script fails on clipping (peak above -0.5 dBFS), clicks at the start or end of one-shots, loop seams, DC offset, different music layer lengths, and more than 6 MB in total.
