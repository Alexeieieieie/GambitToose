# GridFlow update brief: better sound + per-level star goals (Godot 3.x)

You are updating an **existing, working** Godot 3 game called GridFlow (a 2D traffic-automation puzzle game, English UI by default with an optional Russian table, a first-launch tutorial, a deterministic simulation in `sim/`). Two features must be added:

1. **Better sound.** A richer, better-balanced, dynamic audio system, fully generated offline by a Python script (no downloads).
2. **Per-level star goals.** Every normal level has three listed goals. Each goal the player achieves earns one star. The goals are shown before the run, tracked live during the run, and scored on the results screen.

Read this whole file first. Work in the phases in section 14, verify each phase, and commit at the end of each. Everything here is **Godot 3** (GDScript 1.0): no `@export`, no `Vector2i`, no `await`, no typed arrays, no `class_name` (use `const X = preload("res://...")`). Prefer building UI in code over hand-writing `.tscn` or `.tres` files.

## 1. Hard constraints that still apply

2D only. Offline only (no `HTTPRequest`, sockets, telemetry, or downloaded assets). At least 30 FPS on a low-end laptop, load in under 30 seconds, no crashes. The player never controls a vehicle. All simulation logic stays free of scene-tree references and stays deterministic (same level, seed and build actions give the same result). A full level run is still 3 to 5 minutes. All visible text lives in `autoload/strings.gd` (`Strings.t("KEY")`, `Strings.tf("KEY", [args])`) with matching `EN` and `RU` tables, and the strings parity tests must keep passing.

**Do not change game rules, balance, level layouts, or the tutorial lessons**, except where this file says so. Audio and goals are observers: they read simulation state and events and never change them.

## 2. First: inspect the project (change nothing yet)

Report in 12 lines or fewer, then continue:

1. Godot version (`config_version=4` means Godot 3; run `godot --version`; the binary may be `godot3` or a full path). Run `godot --help` once and note the flags for headless runs (`--no-window`), running a script (`-s`), and quitting.
2. The current audio: files in `audio/`, how `autoload/sfx.gd` works, what events trigger which sounds, the buses that exist. Run a small Python check that prints, for each WAV, the length, peak level, and RMS level in dBFS, and flag clipping, a non-zero first or last sample (clicks), and big loudness differences between files.
3. The current star logic (the old rule was: 1 star for winning, 2 if jam time under 20 s, 3 if under 5 s), where it is computed, and where stars are shown (results screen, level select, save file).
4. The structure of level data in `autoload/levels.gd`, `sim/metrics.gd`, `sim/warehouse.gd`, the HUD, the results screen, level select, and `autoload/save_data.gd`, and the exact names of the events the simulation pushes to `sim.events`.
5. How the existing tests are run and whether they pass right now. Run them and note the result.

## 3. Part A: sound, overview

The goals of the audio upgrade:
- **Cleaner sounds:** soft envelopes (no clicks or pops), warm tones, no harsh or piercing sounds.
- **Balanced mix:** every sound has a defined loudness relative to the others; nothing clips; the music never fights the effects.
- **Less repetition:** the delivery sound is a melody that climbs with the delivery streak; frequent sounds get slight pitch variation; rapid sounds are merged or rate limited.
- **Feedback for every action:** build, erase, invalid action, panel open and close, tool select, speed change, pause.
- **Game-state audio:** quiet ambient traffic that scales with the number of vehicles, a siren when an urgent truck is driving, a calm warning before a loss, and music that gets more tense as the network struggles.
- **Player control:** Master, Music, and Effects volume sliders saved between launches.

Keep total audio size under about 6 MB and load time unchanged (load every sound once at startup and never during play).

## 4. Part A: audio generator (`tools/gen_sfx.py`)

Rewrite the generator using only the Python standard library (`wave`, `math`, `struct`, `random`). It must be **deterministic** (seed `random` with a fixed number) and offline. It writes 16-bit mono 22050 Hz WAV files into `audio/`. Run it once and commit the output, so the project works without Python.

**DSP helpers to write** (keep them small and tested by the check script):
- Oscillators: sine, triangle, soft saw (additive harmonics with decreasing amplitude, to avoid harshness), pulse with adjustable width.
- Envelopes: ADSR with an attack of at least 3 ms and a release that reaches exactly zero. Every sound also gets a 5 ms fade-in and a 10 ms fade-out so there are no clicks.
- Filters: one-pole low-pass and high-pass, and a simple band-pass made from them.
- Noise: seeded white noise, plus brown noise (integrated and normalized) for ambience.
- Effects: a short feedback-delay "room" (three taps under 80 ms) for softness, and a `tanh` soft clipper for warmth.
- **Loudness matching:** each sound is normalized to a peak target from a gain table (see below), then verified so the RMS of similar sound classes is within 2 dB.
- **Seamless loops:** loop files must contain a whole number of bars or cycles, and their decay tails must wrap around and mix into the start, so the loop point has no gap or click.

**Sound list.** Design each sound by its description; tune by ear and by the check script.

| File | Class | Design |
|---|---|---|
| `deliver_0.wav` to `deliver_4.wav` | event | A soft bell (sine plus a quiet 2x harmonic, 0.3 s) on the notes C5, D5, E5, G5, A5. The streak index picks the note, so a run of clean deliveries plays a rising melody. |
| `place_road.wav` | action | A soft wooden "tock": a short low sine thump with a tiny noise tap, 0.09 s. |
| `place_bridge.wav` | action | Two hollow plank taps a few ms apart, 0.14 s. |
| `place_light.wav` | action | A relay click followed by a short soft beep, 0.16 s. |
| `place_sorter.wav` | action | A mechanical ratchet of 3 quick ticks, 0.15 s. |
| `erase.wav` | action | A short downward swoosh (filtered noise sweep), 0.12 s. |
| `invalid.wav` | feedback | A short low double buzz, soft, 0.15 s. Never harsh. |
| `tool_select.wav` | UI | A tiny rounded pop, 0.05 s. |
| `ui_click.wav` | UI | A clean soft click, 0.04 s. |
| `ui_hover.wav` | UI | A barely audible tick, 0.02 s. |
| `ui_toggle_on.wav`, `ui_toggle_off.wav` | UI | Two short notes, rising and falling, 0.08 s each. |
| `panel_open.wav`, `panel_close.wav` | UI | A soft airy whoosh, up and down, 0.15 s. |
| `light_switch.wav` | event | A very quiet tick, 0.03 s. |
| `speed_up.wav`, `speed_down.wav` | UI | A quick pitch sweep up or down, 0.12 s. |
| `pause.wav`, `resume.wav` | UI | A tape-stop style fall and a quick rise, 0.2 s. |
| `jam_warn.wav` | warning | Two soft descending "bloop" pulses, 0.35 s. Calm, not an alarm. |
| `gridlock_warn.wav` | warning | A slow, low, soft pulse (like a heartbeat), 0.5 s. Played repeatedly while the network is frozen. |
| `patience_low.wav` | warning | Three quick gentle high pings, 0.3 s. |
| `crash.wav` | event | A dull thump with a short filtered noise burst, 0.3 s. |
| `siren.wav` | loop | A quiet two-tone "wee-woo", 1.0 s loop, low-passed so it is not piercing. |
| `countdown_tick.wav` | event | A soft tick, 0.05 s, played each second for the last 10 seconds. |
| `goal_reached.wav` | reward | A short sparkling rise of 3 notes, 0.4 s. |
| `goal_failed.wav` | feedback | Two soft falling notes, 0.35 s. Gentle, not punishing. |
| `star_1.wav`, `star_2.wav`, `star_3.wav` | reward | A bright chime, each one rising a third higher than the last, with a light shimmer tail, 0.6 s. |
| `win.wav` | jingle | A 4-note rising phrase with a bell harmony, 1.2 s. |
| `lose.wav` | jingle | A soft, slow falling phrase, 1.0 s. Never harsh. |
| `tutorial_step.wav` | UI | A small friendly two-note chime, 0.2 s. |
| `lesson_complete.wav` | jingle | A short mini-fanfare, 0.8 s. |
| `ambience_traffic.wav` | loop | A 8 s loop of brown noise through a low-pass filter plus a faint low engine hum, very quiet. |
| `music_base.wav` | music loop | A soft pad and bass, 24 s, 100 BPM, 10 bars, in a major pentatonic feel. |
| `music_melody.wav` | music loop | A gentle plucked arpeggio over the same 24 s, same key, aligned to the base. |
| `music_tension.wav` | music loop | A subtle pulse with a few minor-color notes, same length, same key, aligned to the base. |
| `music_menu.wav` | music loop | A calm 24 s loop for the menus (base plus melody feel, slower). |

The three in-game music layers must be exactly the same length (a whole number of samples), so they stay in sync when started together. Music layers are quiet by design, roughly 12 to 18 dB below the effects.

**Loudness table (peak targets in dBFS, before bus gain):** events and actions about -6, UI about -12, warnings about -8, rewards about -5, jingles about -6, loops (siren and ambience) about -18, music layers about -14. Keep these numbers in one dictionary at the top of the script, so they are easy to tune.

### 4.1 Audio check script (`tools/check_audio.py`)

Standard library only. It fails (exit code 1) if any of these is wrong, and prints a table of every file with length, peak dBFS, and RMS dBFS:
- Any file is missing, not 16-bit mono 22050 Hz, or silent.
- A peak is above -0.5 dBFS (clipping risk).
- A non-loop file's first or last 20 samples are not near zero (a click risk).
- A loop file's last sample and first sample differ by more than a small threshold (a seam click).
- The three music layers have different sample counts.
- A DC offset (mean sample value) is above 1 percent of full scale.
- The total size of `audio/` is above 6 MB.

## 5. Part A: runtime audio (`autoload/sfx.gd` and a new `audio/audio_director.gd`)

Split the runtime into two parts, so the decisions can be tested headless:

- `audio_director.gd` (`extends Reference`, no scene tree): decides **what** to play. It takes sim events and game state, and returns sound requests (name, volume offset, pitch, priority) plus the target layer volumes. It holds the streak counter, cooldowns, ducking state, and music intensity.
- `sfx.gd` (autoload `Node`): does the playing. It owns the audio players and buses and executes the director's requests.

### 5.1 Buses and effects

Create the buses in code (`AudioServer.add_bus`) if they do not exist: `Master`, `Music`, `SFX`, `UI`, and `Ambience` (send of `Ambience` is `SFX`). Add an `AudioEffectLimiter` on `Master` with a ceiling of about -1 dB, and an `AudioEffectLowPassFilter` on `Music` that is switched on (cutoff about 900 Hz) when the game is paused and off when it resumes (fade the cutoff over 0.2 s).

### 5.2 Playback rules (the registry)

A dictionary maps each sound name to its settings:

```gdscript
"deliver": {"bus": "SFX", "base_db": 0.0, "priority": 3, "cooldown_ms": 0, "max_voices": 3, "pitch_jitter": 0.0},
"place_road": {"bus": "SFX", "base_db": -2.0, "priority": 2, "cooldown_ms": 40, "max_voices": 2, "pitch_jitter": 0.03},
"light_switch": {"bus": "SFX", "base_db": -12.0, "priority": 1, "cooldown_ms": 120, "max_voices": 2, "pitch_jitter": 0.02},
```

- Use a pool of 10 `AudioStreamPlayer` nodes created once. When all are busy, steal the lowest-priority voice (oldest first). Never create players during play.
- Enforce each sound's `cooldown_ms` and `max_voices`.
- **Merge rapid deliveries:** at 2x and 4x speed many deliveries can land within a few frames. If several deliveries occur within 150 ms, play only one, using the highest streak note.
- Pitch jitter uses a separate `RandomNumberGenerator` randomized at startup. It must never touch the simulation's RNG or any `sim/` code.
- Preload every stream at startup into a dictionary. Set looping for loop files in code: `stream.loop_mode = AudioStreamSample.LOOP_FORWARD`, `stream.loop_begin = 0`, `stream.loop_end = stream.data.size() / 2` (16-bit mono is two bytes per frame).

### 5.3 Event to sound mapping

| Source | Sound |
|---|---|
| `delivery` event | `deliver_N`, where N is the streak index (0 to 4, then stays at 4). The streak resets on a `jam_started` event or after 15 s without a delivery. |
| `jam_started` | `jam_warn` (at most once per 5 s), music ducks 4 dB for 1 s. |
| No vehicle moved for 8 s (new event `gridlock_risk`) | `gridlock_warn`, repeated every 2 s while true. |
| A warehouse crosses 25 percent and 10 percent patience (new event `patience_low`, once per threshold per warehouse) | `patience_low`. |
| `crash` | `crash`. |
| `light_switched` | `light_switch`. |
| Build, erase, tool select | the matching action sound. A rejected action (no inventory left, blocked tile, water without a bridge) plays `invalid` and briefly flashes the toolbar count red. |
| UI button press, toggle, panel open or close, speed change, pause or resume | the matching UI sound. Hover sounds only on main-menu and panel buttons. |
| An urgent truck exists and is driving | `siren` loop fades in over 0.3 s and fades out when none remain. |
| Time left is 10 s or less in a timed level | `countdown_tick` every second. |
| `goal_reached` and `goal_failed` events (section 8) | `goal_reached` and `goal_failed`. |
| Results screen | `win` or `lose`, then `star_1`, `star_2`, `star_3` one after another (0.6 s apart) for the stars earned. Music ducks 8 dB for 2 s. |
| Tutorial step completed, lesson completed | `tutorial_step`, `lesson_complete`. |

The sim must push the new events `gridlock_risk` and `patience_low` itself (they are pure observations of existing state, and do not change any simulation behavior). Add tests that the new events do not change the results of a determinism run.

### 5.4 Dynamic music

- In levels, start `music_base`, `music_melody`, and `music_tension` **in the same frame** on three players so they stay aligned. Every second, if any layer's playback position drifts more than 30 ms from the base, restart the drifting layer at the base's position.
- Base is always on. Melody fades in (1.5 s) after the first delivery. Tension fades in (1 s) when `intensity > 0.5` and out below 0.35.
- `intensity` (0 to 1) is computed in the director each half second: `0.5 * jam_fraction + 0.3 * (1 - lowest_patience_ratio) + 0.2 * gridlock_timer_fraction`, where `jam_fraction` is the share of road tiles with smoothed density above 0.8. Smooth it so layers never flicker.
- Music `pitch_scale` follows the speed: 1.0 at 1x, 1.04 at 2x, 1.08 at 4x, applied to all layers equally.
- On pause: low-pass on, music volume down 6 dB. On the results screen: fade out the layers over 1 s. In menus: `music_menu` only.

### 5.5 Settings

Add a **Settings** panel (a button in the main menu and an entry in the in-game menu), built in code in the same visual style as the other panels, with sliders for Master, Music, and Effects (0 to 100), plus the existing sound toggle. Convert slider values with `linear2db`, apply them to the buses immediately, and save them in `SaveData`. Defaults: Master 100, Music 60, Effects 90. All new text goes into `strings.gd` (EN and RU): `SETTINGS`, `VOL_MASTER`, `VOL_MUSIC`, `VOL_EFFECTS`.

### 5.6 Documentation

Write `AUDIO.md`: a table of every sound with its trigger, bus, base volume, and notes, plus how to regenerate (`python tools/gen_sfx.py`) and check (`python tools/check_audio.py`) the files and how to tune the loudness table.

## 6. Part B: per-level star goals, overview

Replace the old star rule. Every normal level defines **three star goals**. Each goal achieved is one star, so a level has 0 to 3 stars. Goals are independent: a player can earn the third goal without the second. Goals are shown before the run, tracked live, and scored on the results screen. Tutorial lessons and the tutorial final test have **no** star goals, and for them none of the goals UI appears.

### 6.1 Goal types

| Type | Meaning | Value | English text (`EN`) | Evaluated |
|---|---|---|---|---|
| `complete` | Finish the level (win, or survive to the end in score mode) | none | Complete the level | at the end |
| `time_left_min` | Win with at least this many seconds left | seconds | Finish with %d s to spare | at the end |
| `jam_seconds_max` | Total time in jams at most | seconds | Spend at most %d s in jams | at the end; fails early when exceeded |
| `avg_delivery_max` | Average delivery time at most | seconds | Average delivery under %d s | at the end |
| `urgent_min` | Deliver at least this many urgent trucks | count | Deliver %d urgent trucks | reached live |
| `patience_min` | No warehouse ever drops below this percent | percent | Keep every warehouse above %d%% patience | fails early when violated |
| `roads_max` | Use at most this many road tiles | count | Use at most %d road tiles | at the end |
| `deliver_min` | Deliver at least this many trucks (score mode) | count | Deliver at least %d trucks | reached live |
| `score_min` | Reach at least this score (score mode) | score | Score at least %d | reached live |

Each type has a text key `GOAL_<TYPE>` in `EN` and `RU`, and a short live-progress key `GOALP_<TYPE>`, for example `GOALP_JAM_SECONDS_MAX` = `%d / %d s`. Note the `%%` for a literal percent sign in format strings.

### 6.2 Level data

Add `"star_goals"` to each normal level. Exactly three entries; the first is always `complete`.

```gdscript
"star_goals": [
  {"type": "complete"},
  {"type": "time_left_min", "value": 25},
  {"type": "jam_seconds_max", "value": 5},
],
```

Starting values (calibrate them in Phase 4 with the headless tests; see 6.4):

| Level | Goal 1 | Goal 2 | Goal 3 |
|---|---|---|---|
| Level 1: First Roads | `complete` | `time_left_min` 25 | `jam_seconds_max` 5 |
| Level 2: River Crossing | `complete` | `jam_seconds_max` 20 | `urgent_min` 3 |
| Level 3: Rush Hour (score mode) | `complete` | `score_min` 2000 | `patience_min` 40 |

### 6.3 Evaluation (`sim/goals.gd`, `extends Reference`)

```gdscript
extends Reference

enum Status { PENDING, DONE, FAILED }

var defs = []        # from the level
var status = []      # one Status per goal

func setup(level):                  # reads level["star_goals"] (empty array if absent)
func tick(sim):                     # called each step; updates live goals, pushes events
func finalize(sim, won):            # called once when the run ends; decides the rest
func value_text_args(i, sim):       # the numbers for the live progress text
func earned_mask():                 # bit i set if goal i is DONE
func stars():                       # number of DONE goals
```

Rules:
- "Reached live" goals (`urgent_min`, `deliver_min`, `score_min`) become `DONE` the moment the value is reached, and push a `goal_reached` event with the goal index.
- "Fails early" goals (`jam_seconds_max`, `patience_min`) become `FAILED` the moment the limit is broken, and push a `goal_failed` event. If they are still pending at the end, `finalize` makes them `DONE` only if the run was not lost.
- "At the end" goals are decided in `finalize`. Goals evaluated at the end must be `FAILED` if the run was lost, except `complete`'s own definition: `complete` is `DONE` only when the level was won (goal mode) or the time ended with no lose condition (score mode).
- A goal never changes from `DONE` or `FAILED` back to `PENDING` within a run.
- The goals object only **reads** simulation state. It must not change simulation behavior or consume the simulation RNG. Add what it needs to metrics: `min_patience_ratio` (the lowest ratio any warehouse reached during the run), `urgent_deliveries`, `roads_used` (player-placed road and bridge tiles at the end), and `time_left`.
- When a level has no `star_goals`, `stars()` returns 0 and no goals UI is shown.

### 6.4 Calibration and tests

Write the goal numbers, then check them with the headless simulation, using each level's `solution` build actions:

- The **intended solution** must earn **all three** goals (so every goal is achievable).
- A **baseline** run (no lights, no sorters, only the roads needed) must earn at most **one** star (usually `complete` or none).
- Adjust the values until both hold, and write a line in `DECISIONS.md` for each level with the values you chose.

Tests to add:
1. Unit tests for every goal type: pending, done, failed, and the early-fail behavior, with fake metrics.
2. Level data validity: every normal level has exactly three goals, the first is `complete`, all types are valid, all values are positive, and all text keys exist in `EN` and `RU`.
3. Intended solution earns three stars, and the baseline earns at most one (6.4).
4. Goals are read-only: running the same level and build actions with goals enabled and disabled gives identical simulation results.
5. Save mask roundtrip (section 7.4) and the old-save migration.
6. Strings parity still passes with all the new keys.

## 7. Part B: where goals appear

### 7.1 Level intro card (`ui/level_intro.gd`)

Shown each time a normal level loads, with the simulation paused behind it. Contents: the level name, the objective line (`Objective: deliver %d trucks in %d s`, or `Objective: survive %d s and score as high as you can` in score mode), a heading `Star goals`, then the three goals, each with a star icon (gold and filled if the player has earned that goal in a previous run, outlined otherwise) and its text. A `Start` button closes the card; the simulation stays paused so the player can build first. Below the button, a small hint: `Press G any time to see your goals.`

### 7.2 Live goal tracker (HUD)

A compact panel under the top bar on the left: the heading `Goals` and three rows. Each row shows a star icon, the goal text, and, where useful, the live progress (for example `Spend at most 5 s in jams  3 / 5 s`). Icon states, readable without color: **pending** is an outlined star, **done** is a gold filled star with a small check mark, **failed** is a gray star with a small X. `G` toggles the panel (it is open by default for the first 10 seconds of each run, then collapses to a single row of three star icons that can be expanded). It never blocks clicks on the map (small, and `mouse_filter` set correctly). When a goal is reached or failed, show a short toast (`Goal reached!` or `Star goal missed`) and play the matching sound, with a small pop tween on the icon.

### 7.3 Results screen

Replace the old star display. The three stars animate in one at a time (0.6 s apart), matching `star_1` to `star_3` sounds, with an earned star filled gold and an unearned star gray. Under them, list each goal with its icon, its text, and the final value (`Result: 4 s`), and a `New!` badge if it was not earned before. Keep the stats cards, and the hint now targets the **first failed goal**:

| Failed goal | Hint (use the existing jam location when available) |
|---|---|
| `time_left_min` or `avg_delivery_max` | `Shorter routes and fewer stops deliver faster. Try a second bridge or a Sensor light.` |
| `jam_seconds_max` | the existing jam hint (`The longest jam was at %s. Try a Sensor light on the busiest road.`) |
| `urgent_min` | `Urgent trucks need a clear road. Try a Priority light, or build a bypass.` |
| `patience_min` | `A warehouse ran low. Make sure every color has a short, clear route.` |
| `roads_max` | `Use fewer, straighter roads. Every extra tile counts.` |
| `deliver_min` or `score_min` | `More deliveries and fewer jams raise your score. Check the heatmap for weak spots.` |

If all goals are earned, show `Perfect run! All stars earned.`

### 7.4 Save data and level select

- Store a goals bit mask per level in `SaveData` (for example key `level_<id>/goals`). On a finished run, OR the new mask with the old one, so earned goals stay earned. `get_stars(level_id)` is the number of set bits. Keep best score as before.
- **Migration:** old saves have a single `stars` integer from the old rule. Ignore it and start all masks at 0 (the goals have new meanings). Never crash on an old or corrupt file.
- Level select cards show the three star icons (filled for earned goals) and, on hover or tap, the three goal texts.

### 7.5 Text and consistency updates

- Add all new text to `EN` and `RU` (the Russian text can be a straightforward translation).
- **Tutorial:** change lesson 6 step 5 (`TUT_L6_S5`) to: `Every level has three star goals, like finishing early or keeping jams short. Earn each goal to win a star.` Update its `RU` text, and the `_HINT` key if present.
- **Help overlay:** add a line `Stars: each level has three goals. Press G to see them. Every goal you achieve earns a star.`
- **Old rule removal:** delete the old `1 star / jam < 20 s / jam < 5 s` code and any text that mentions "third star" in the old sense. Check results hints.
- The goals panel and intro card are hidden in tutorial lessons and the tutorial final test.

## 8. New simulation events (all read-only observations)

| Event | Fields | Pushed when |
|---|---|---|
| `gridlock_risk` | `seconds` | No vehicle has moved for 8 s while at least 3 vehicles exist (once per second after that) |
| `patience_low` | `warehouse`, `threshold` (25 or 10) | A warehouse's patience first falls below a threshold |
| `goal_reached` | `index` | A live goal becomes `DONE` |
| `goal_failed` | `index` | A goal becomes `FAILED` |

Add them to whatever event documentation exists. Remember that they must not change any simulation outcome (see test 4 in 6.4 and the determinism test).

## 9. Tests for the audio part

Add to the existing headless test script:
1. **Director streak logic:** deliveries raise the streak index up to 4; a `jam_started` event or 15 s without a delivery resets it.
2. **Merging:** several deliveries within 150 ms produce one `deliver` request with the highest note.
3. **Cooldowns and voices:** a sound with a cooldown does not repeat within it, and `max_voices` is respected.
4. **Ducking and intensity:** `intensity` stays within 0 to 1, tension fades in above 0.5 and out below 0.35, and ducking returns to zero after its time.
5. **Registry completeness:** every sound name used in the event table exists in the registry, has a file in `audio/`, and every file in `audio/` is used by the registry.
6. **New events do not change simulation results** (determinism test with and without audio and goals).
7. **Audio files:** run `python tools/check_audio.py` if Python is available and assert it passes.
8. The earlier tests (performance, offline, no manual control, strings, tutorial) still pass. The "no manual control" and "offline" static checks cover the new files too.

## 10. Quality checklist

- No clicks, pops, or distorted sounds. Nothing clips at 4x speed with 120 vehicles.
- Effects are clearly louder than the music, and no single sound is much louder than the others.
- A run of clean deliveries plays a rising melody; the music gets more tense as jams grow, and relaxes when they clear.
- The jam warning is calm, and the player is warned before a warehouse patience loss, never surprised.
- Volume sliders and the mute toggle work and are remembered after restart.
- Every normal level shows its three goals before the run, tracks them live, and scores them on the results screen. Earned goals persist across launches and runs.
- The intended solution of each level earns three stars in the headless test; the baseline earns at most one.
- The tutorial still works, and no goals UI appears in it.
- FPS is unchanged (check with the `F3` overlay at 4x), and the load time is still under 30 seconds.
- Everything visible is in the strings tables (English by default), with no hardcoded text.
- The hard constraints in section 1 all still hold.

## 11. Cut order if time runs short

Audio: ambience first, then hover sounds, then the dynamic tension layer, then merged settings sliders (keep the mute toggle). Goals: the level select hover list first, then the HUD auto-collapse, then the `patience_min` and `roads_max` goal types. Never cut: the sound check script, the loudness balance, the delivery melody, the three goals per level, the results screen scoring, or the tests for the hard constraints.

## 12. Estimated effort

Sound: about 6 to 7 hours (generator 2.5, runtime 3, settings and docs 1.5). Goals: about 5 hours (logic and tests 2, UI 2.5, calibration 0.5).

## 13. Working rules

- Read this file again at the start of each phase.
- Do not add features that are not in this file without asking, and do not change game rules or level layouts.
- Keep `audio_director.gd` and `sim/goals.gd` free of scene-tree references so the tests can run them headless.
- Use static typing where it is simple, and no Godot 4 features.
- After adding or changing audio files, run `godot --path . --editor --quit` so Godot imports them.
- After each phase, report in 3 to 5 lines: what works, what you ran to verify it, and anything you could not verify (for example, you cannot judge how a sound feels, so list the sounds you want the user to listen to first).
- When something in this file seems wrong or contradictory, pick the simplest option that satisfies the constraints, note the decision in `DECISIONS.md`, and continue.
- If the existing code is structured differently from what this file assumes, adapt to it instead of rewriting it, and say what you adapted.

## 14. Phases (do them in order, verify each, commit each)

**Phase 1: Inspect and report (about 20 min).** Section 2. No code changes. Report before continuing.

**Phase 2: Sound generator and check script (about 3 h).** `tools/gen_sfx.py`, `tools/check_audio.py`, the full sound list, run both, commit the generated `audio/` files and the import pass. *Done when:* `check_audio.py` passes, every file in the sound list exists, and the loudness table results are printed.

**Phase 3: Runtime audio (about 3.5 h).** `audio_director.gd`, the upgraded `sfx.gd` (buses, limiter, pool, registry, event mapping), the new `gridlock_risk` and `patience_low` events, dynamic music with layer sync, ambience and siren, the Settings panel with saved sliders, `AUDIO.md`, and the audio tests from section 9. *Done when:* the audio tests pass and a full play of Level 1 uses every mapped sound correctly.

**Phase 4: Star goals logic (about 2.5 h).** `sim/goals.gd`, the metrics additions, the goal events, the level data for all three levels, the calibration with `solution` runs, removal of the old star rule, and the goal tests. *Done when:* the intended solutions earn three stars, the baselines earn at most one, and all tests pass.

**Phase 5: Star goals UI and flow (about 3 h).** The level intro card, the HUD tracker with toasts and sounds, the new results screen with the animated stars and failed-goal hints, level select stars and tooltips, the save mask and migration, the tutorial and Help text updates. *Done when:* a full play of each level shows goals before, during, and after the run, and the saved stars persist after a restart.

**Phase 6: Integration and polish (about 1.5 h).** The full checklist in section 10, a listening pass (list the sounds the user should check first), the README update, and the final performance check at 4x. *Done when:* every item in section 10 is true.
