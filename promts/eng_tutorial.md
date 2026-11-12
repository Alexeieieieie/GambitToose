# GridFlow update brief: English UI + first-launch tutorial (Godot 3.x)

You are updating an **existing, working** Godot 3 game called GridFlow (a 2D traffic-automation puzzle). Two things must change:

1. **The game must be in English.** English is the default and only language the player sees on first launch.
2. **First launch must run a tutorial.** The first time the game is opened after download, the player must go through an interactive tutorial that teaches every mechanic, before they reach the main menu.

Read this whole file first. Work in the phases in section 12, verify each one, and make a git commit at the end of each phase. Everything here is **Godot 3** (GDScript 1.0): no `@export`, no `Vector2i`, no `await`, no typed arrays, no `class_name`. Section 4 repeats the rules.

## 1. Goals and non-goals

**Goals**
- All player-facing text in English, kept in one place, with the existing Russian text preserved as an optional second language.
- A first-run flow: Welcome screen, then 6 short interactive lessons and a final test, then a completion screen, then the main menu.
- The tutorial can be replayed from the main menu and skipped (with confirmation).
- A quick-reference Help overlay available during every level.
- Tests that protect all of this.

**Non-goals (do not do these)**
- Do not change game rules, balance, levels 1 to 3 layouts, or the simulation behavior. Tutorial code attaches to the simulation through events and a few small hooks only.
- Do not add networking, analytics, or any addon.
- Do not add any way for the player to control a vehicle. Tutorial trucks are spawned by factories like normal.

## 2. First: inspect the project (change nothing yet)

The project may differ from the original brief. Before writing code, find out and report in 10 lines or fewer:

1. The Godot version (`project.godot` `config_version=4` means Godot 3; run `godot --version` too, it may be `godot3` or a full path). If the project is Godot 4, apply the same plan with Godot 4 syntax and tell the user.
2. How strings are stored now (probably `autoload/strings.gd` with `const NAME = "..."`) and every place that still hardcodes UI text (search `.text =`, `draw_string`, `Label`, `Button`, `tooltip`, `window_title`, `application/config/name`).
3. Whether an old in-level tutorial overlay exists (for example `tutorial_overlay.gd` for Level 1). The new tutorial replaces it: Level 1 becomes a normal level without scripted steps.
4. How saving works (`user://save.cfg`?), how scenes are created (code or `.tscn`), the names of the HUD, light panel, sorter panel, results, and menu scripts, and what events the simulation already emits (`sim.events`).
5. How the existing tests are run, and whether they currently pass. Run them now and note the result, so you know what you broke later.

Then continue with Phase 1.

## 3. Constraints that still apply

2D only. Offline only (no `HTTPRequest`, sockets, or telemetry). At least 30 FPS on a low-end laptop, load in under 30 seconds, no crashes. The player never controls a vehicle. A full level run is still 3 to 5 minutes (the tutorial is separate and is not the scored session). All simulation logic stays free of scene-tree references.

## 4. Godot 3 reminders

- Use `export var`, `onready var`, `update()`, `Reference`, `yield`, `connect("sig", self, "_fn")`, `emit_signal("sig", arg)`, `event.scancode`, `rect_position`, `rect_size`, `margin_*`, a `Tween` node.
- Cells are `Vector2` with whole numbers. Use untyped `Array` and `Pool*Array`.
- Do not use `class_name`; use `const X = preload("res://path.gd")`.
- Prefer building UI in code over hand-writing `.tscn` or `.tres` files.
- Never iterate a dictionary in a way that changes simulation results; iterate arrays.
- If you are unsure a method exists in Godot 3.5, check the docs or test it in a tiny script.
- After adding or changing fonts or audio, run `godot --path . --editor --quit` so Godot imports them.

## 5. Part A: English localization

### 5.1 Strings system

Refactor `autoload/strings.gd` into two tables and a lookup function. Keep the existing Russian text as the `RU` table.

```gdscript
extends Node

const EN = { "PLAY": "Play", ... }
const RU = { "PLAY": "Играть", ... }

var lang = "en"

func t(key):
    var table = EN if lang == "en" else RU
    if table.has(key):
        return table[key]
    if EN.has(key):
        return EN[key]
    return "!" + str(key) + "!"      # visible marker for missing keys

func tf(key, args):
    return t(key) % args             # args is always an Array
```

- Replace every `Strings.NAME` usage with `Strings.t("NAME")`, and every formatted string with `Strings.tf("NAME", [..])`. No UI text may remain anywhere else in the code.
- Autoload order in `project.godot`: `SaveData` first, then `Strings`, so `Strings` can read the saved language in `_ready()`.
- **Language option:** add a small `Language: English` / `Language: Русский` button to the main menu. Changing it saves the choice and reloads the current scene (`get_tree().reload_current_scene()`), which rebuilds the UI. Default is English. Keep this simple: it exists only so the Russian text is not thrown away.
- The font (Nunito or similar) already covers Latin. Keep Cyrillic glyph support for the Russian option.
- Set the window title and `application/config/name` to `GridFlow`. The game title in menus is `GridFlow`, with the subtitle `Build the system. Let it run itself.`
- English is usually shorter than Russian, so check that no button or panel looks broken or oddly empty after the change.

### 5.2 English table for existing text

Use these keys if they exist; map them to the real key names you found in Phase 1, and translate any other existing text in the same style (short, friendly, sentence case).

| Key | English |
|---|---|
| TITLE | GridFlow |
| SUBTITLE | Build the system. Let it run itself. |
| PLAY | Play |
| LEVELS | Levels |
| TUTORIAL | Tutorial |
| SOUND_ON / SOUND_OFF | Sound: on / Sound: off |
| EXIT | Quit |
| PAUSE | Pause |
| HEATMAP | Heatmap |
| HEATMAP_ON | On |
| FREE / BUSY / JAM | Clear / Busy / Jam |
| JAM_STRIPED | Jam (striped) |
| DELIVERED | Delivered |
| LEVEL_FMT | Level %d |
| PROGRESS_FMT | %d / %d |
| ROAD / BRIDGE / ERASE | Road / Bridge / Erase |
| LIGHT | Light |
| SORTER | Sorter |
| MODE_TIMER / MODE_SENSOR / MODE_PRIORITY | Timer / Sensor / Priority |
| URGENT_FIRST | Urgent trucks go first |
| APPLY / CANCEL | Apply / Cancel |
| RESTART | Retry |
| NEXT_LEVEL | Next level |
| WIN_TITLE | Level complete! |
| LOSE_PATIENCE | A warehouse ran out of patience |
| LOSE_GRIDLOCK | Total gridlock |
| AVG_DELIVERY | Avg. delivery time |
| TIME_IN_JAMS | Time in jams |
| LIGHT_PANEL_TITLE | Traffic light, junction %s |
| LIGHT_PANEL_SUB | Choose how this light decides who goes |
| THRESHOLD_FMT | Switch when more than %d trucks wait |
| PERIOD_FMT | Switch every %d s |
| SORTER_PANEL_TITLE | Sorter, junction %s |
| HINT_SENSOR | The longest jam was at %s. Try a Sensor light on the busiest road. |
| HINT_BRIDGE | Trucks queued at the river near %s. A second bridge would split the traffic. |
| HINT_SORTER | Different colors shared one road near %s. A Sorter can separate them. |
| HINT_PATIENCE | A warehouse ran dry. Make sure every color has a route to its warehouse. |
| LEVEL_1 / LEVEL_2 / LEVEL_3 | First Roads / River Crossing / Rush Hour |
| HELP | Help |

## 6. Part B: save data and first-run detection

Create (or extend) `autoload/save_data.gd` using `ConfigFile` at `user://save.cfg`. It must provide:

- `tutorial_done` (bool, default `false`), `tutorial_skipped` (bool, default `false`), `language` (default `"en"`), `sound_on`, best score and stars per level (keep whatever already exists).
- `is_first_run()` returns `not tutorial_done`.
- Saving after every change, with guards so a missing or corrupt file never crashes the game (treat it as a fresh install).
- In debug builds only (`OS.is_debug_build()`), `F9` deletes the save and restarts, so the first-run flow can be tested repeatedly.
- Never ship a save file in the project or the export.

**Startup flow:** `Boot` checks `SaveData.is_first_run()`. If true, go to the **Welcome screen**; otherwise go to the **main menu**.

## 7. Part C: tutorial system architecture

Keep the logic separate from the drawing so it can be tested headless.

```
res://
├─ tutorial/
│  ├─ tutorial_data.gd      lesson and step definitions (data only)
│  ├─ tutorial_manager.gd   extends Reference, NO scene-tree dependencies
│  ├─ coach_panel.gd        the instruction card (UI)
│  ├─ highlight_layer.gd    pulsing outlines and arrows (draws only)
│  ├─ welcome_screen.gd
│  └─ complete_screen.gd
├─ ui/help_overlay.gd
└─ ui/ui_registry.gd        autoload: name -> Control lookup
```

### 7.1 UI registry

Add an autoload `UiRegistry` with `register(name, node)` and `get_rect(name)` (uses `get_global_rect()`). The HUD, toolbar, and panels register their controls with these names, so the tutorial can highlight them without knowing the layout:

`tool_road, tool_bridge, tool_light, tool_sorter, tool_erase, btn_pause, btn_speed_1, btn_speed_2, btn_speed_4, btn_heatmap, btn_help, deliveries_bar, light_mode_timer, light_mode_sensor, light_mode_priority, light_apply, sorter_apply`

### 7.2 Lesson and step data

A lesson is a level dictionary (same format as `levels.gd`) plus tutorial fields. Lessons live in `tutorial_data.gd`, not in the main level list.

```gdscript
{
  "id": "l1", "title_key": "TUT_L1_TITLE",
  "level": { ...normal level fields..., "seed": 101, "lose_enabled": false,
             "allowed_tools": [ROAD, ERASE], "prebuilt": [], "time": 0 },
  "steps": [ ...step dictionaries... ],
  "solution": [ ...headless actions used by tests... ]
}
```

A step dictionary:

```gdscript
{
  "id": "l1_s3",
  "text_key": "TUT_L1_S3",
  "highlight_cells": [Vector2(4, 7), Vector2(27, 7)],   # optional
  "highlight_ui": ["tool_road"],                          # optional
  "wait": {"event": "road_connected", "color": 0},        # or {"event": "continue"}
  "pause_sim": true,                                      # optional
  "on_enter": [],                                         # optional hooks, see 7.5
  "checklist": []                                         # optional sub-goals
}
```

### 7.3 Events and wait conditions

`tutorial_manager.notify(event_name, data)` is the only way things reach the manager. The simulation, the build system, and the UI call it (or `game.gd` forwards `sim.events` to it). Supported events:

| Event | Fired when |
|---|---|
| `continue` | The player presses the coach panel's Continue button |
| `road_connected` (color) | A road path exists between that color's factory and warehouse |
| `bridge_placed` (count) | The total number of placed bridge tiles reaches the count |
| `light_placed` | A traffic light is placed |
| `light_mode_set` (mode) | A light's Apply was pressed with that mode |
| `sorter_placed` | A sorter is placed |
| `sorter_rule_set` | Apply was pressed and two different colors have different exits |
| `speed_started` | The speed changes from paused to 1x, 2x, or 4x |
| `speed_set` (value) | The speed is set to that value |
| `heatmap_toggled` (on) | The heatmap is switched on or off |
| `delivered_count` (n) | Total deliveries in this lesson reach n |
| `urgent_delivered` (n) | Urgent deliveries in this lesson reach n |
| `crash` | The first conflict at an uncontrolled junction (scripted, lesson 2 only) |
| `level_won` / `level_lost` | The final test ends |

Conditions that are already true when a step starts complete immediately, so a player who builds ahead is never stuck.

### 7.4 Manager behavior

- Holds the current lesson, step index, and timers. Emits `step_changed(step)`, `lesson_completed`, and `tutorial_finished` signals.
- **Hint timer:** if a step is not completed after 15 seconds of real time, the coach panel shows a Hint button (a one-line extra hint, key `<text_key>_HINT`). After 30 seconds, a subtle `Skip step` link appears. This prevents any soft lock.
- If the player breaks a lesson (for example erases a required road or causes a gridlock), the coach panel offers `Reset lesson`, which reloads the lesson's level data.
- The tutorial can never lose: `lose_enabled = false` for lessons 1 to 6 (patience bars clamp at 1 and refill, gridlock detection is off). Only the final test can be failed, and it offers Retry.
- While a modal panel (light or sorter) is open, the simulation is paused.

### 7.5 Hooks (the only allowed changes to the simulation)

- `pause_sim` on a step pauses the game when the step starts. `resume` is up to the player (they press 1x).
- `force_crash`: lesson 2 only. When the first two vehicles from different axes reach the same uncontrolled junction, push a `crash` event, pause the game, and flash the junction. The existing simulation rules are unchanged.
- `spawn_urgent`: lesson 5 only. The first blue spawn after the step starts is an urgent truck, so the lesson does not depend on random timing.
- `tool_lock`: lessons restrict `allowed_tools`. Locked tools are disabled and dimmed, with the tooltip `Unlocked later in the tutorial`. Keyboard shortcuts for locked tools are ignored.

### 7.6 Coach panel (UI)

A card, about 520 px wide, rounded, navy background (`#1F2340`) with a yellow title. It floats near the top of the map, below the top bar, and moves to the bottom (above the toolbar) when the highlighted cells are in the top third of the map.

Contents: a lesson tag (`Lesson 2 of 6`), the lesson title, the step text (at most 2 or 3 lines), an optional checklist with check marks, progress dots, and buttons: `Continue` (only for info steps), `Hint` (after 15 s), `Skip step` (after 30 s, small), and a `Skip tutorial` link in the footer. Info steps also dim the map slightly behind the card. Action steps do not dim, so the player can see and use the map. When a step completes, play a soft sound (reuse the existing delivery or place sound) and slide the next step in with a short tween.

### 7.7 Highlight layer

A `Node2D` over the map, plus an overlay in the HUD layer, that draws:
- A pulsing yellow outline around each cell in `highlight_cells` (scale the line width with a sine wave).
- A pulsing outline around each UI control in `highlight_ui` (read the rect from `UiRegistry`).
- A small bouncing arrow pointing at the first target.

It only draws. It never changes game state and never blocks input (`mouse_filter` ignore).

## 8. Part D: lessons

Texts below are the exact English copy. Put each in the strings table (`EN`) under keys named `TUT_<LESSON>_<STEP>` (for example `TUT_L1_S3`), with a matching `_HINT` key for action steps (write short hints in the same tone, for example "Click and drag along the row between the two buildings."). Add Russian translations to `RU` as well, or fall back to English if you do not translate them.

Lessons 1 to 3 have exact layouts. For lessons 4 to 6 and the final test, you design the layout on the 32x15 grid under the stated constraints, and each must be solvable with the stated inventory; the tests check this.

### Lesson 1: Your first road
Layout: blue factory at `(4, 7)`, blue warehouse at `(27, 7)`, a straight gap between them on row 7. Inventory: 30 roads. Tools: Road, Erase. Goal: 3 deliveries.

| # | Text | Highlight | Wait |
|---|---|---|---|
| 1 | Welcome, engineer! You never drive trucks in GridFlow. You build the system, and the system runs itself. | none | continue |
| 2 | Factories make trucks. Each truck only delivers to a warehouse of its own color: blue to blue, red to red. | factory, warehouse | continue |
| 3 | Pick the Road tool, then drag from the factory to the warehouse to connect them. | tool_road, both buildings | road_connected (blue) |
| 4 | Press 1x to start. The trucks find their own way. You can't steer them, and that is the point. | btn_speed_1 | speed_started |
| 5 | Every warehouse has a patience bar. It drains over time and refills with each delivery. If it runs out, you lose. Deliver 3 trucks. | warehouse bar, deliveries_bar | delivered_count 3 |

### Lesson 2: Junctions and jams
Layout: the blue road from lesson 1 is prebuilt on row 7. Red factory at `(15, 2)`, red warehouse at `(15, 12)`. Inventory: 15 roads. Tools: Road, Erase. Uses `force_crash`.

| # | Text | Highlight | Wait |
|---|---|---|---|
| 1 | Now a red line has to cross your blue road. Red trucks go to the red warehouse. | red buildings | continue |
| 2 | Drag a road from the red factory down to the red warehouse, crossing the blue road. | tool_road | road_connected (red) |
| 3 | Press 1x and watch what happens at the crossing. | btn_speed_1 | speed_started |
| 4 | Trucks from both roads reached the crossing at the same moment. With no signal, they block each other. | the junction | continue (game auto-paused) |
| 5 | One stuck truck makes every truck behind it wait, so a jam spreads backwards down the street. Next, let's fix it. | none | continue |

### Lesson 3: Smart traffic lights
Layout: both roads prebuilt, both factories active. Inventory: 1 light. Tools: Light. Goal: 6 deliveries.

| # | Text | Highlight | Wait |
|---|---|---|---|
| 1 | Pick the Light tool and click the crossing. | tool_light, the junction | light_placed |
| 2 | Timer: the green light switches sides every few seconds. Simple, but wasteful when one road is busier. | light_mode_timer | continue |
| 3 | Sensor: green goes to the side with the longer queue. Great when traffic is uneven. | light_mode_sensor | continue |
| 4 | Priority: urgent trucks (yellow, with a ring) always go first. | light_mode_priority | continue |
| 5 | Choose Sensor and press Apply. The slider sets how long a queue must get before the light switches. | light_mode_sensor, light_apply | light_mode_set (sensor) |
| 6 | Press 1x and watch the queue clear. Deliver 6 trucks. | btn_speed_1 | delivered_count 6 |

### Lesson 4: Bridges and sorters
Constraints for your layout: a river 2 to 3 tiles wide crosses the map. Roads on both banks are prebuilt and stop at the water. A blue factory and a red factory share one road on the near bank, which forks into two approaches to two different crossing points; the blue and red warehouses are on the far bank. Inventory: exactly the bridge tiles needed for both crossings, 1 sorter. Tools: Bridge, Sorter. Goal: 6 deliveries.

| # | Text | Highlight | Wait |
|---|---|---|---|
| 1 | Rivers block roads. Only bridges can cross water. See how both roads stop at the river? | the banks | continue |
| 2 | Pick the Bridge tool and click the water tiles to link each road across. | tool_bridge | bridge_placed (all needed) |
| 3 | Blue and red trucks share one road, then split. A Sorter sends each color its own way. | the fork | continue |
| 4 | Pick the Sorter tool and click the fork. | tool_sorter, the fork | sorter_placed |
| 5 | For each color, choose a direction. Send blue one way and red the other, then press Apply. | sorter_apply | sorter_rule_set |
| 6 | Press 1x and deliver 6 trucks. | btn_speed_1 | delivered_count 6 |

### Lesson 5: Urgent trucks
Constraints: one blue factory and warehouse, a junction with a free light slot, and room for a short bypass road. Inventory: 1 light, 8 roads. Tools: Light, Road, Erase. Uses `spawn_urgent`. Goal: 2 urgent deliveries.

| # | Text | Highlight | Wait |
|---|---|---|---|
| 1 | Yellow trucks with a ring are urgent. They re-plan their route every second, so they can use a bypass when the main road is jammed. | none | continue |
| 2 | Place a Light on the junction and set it to Priority, so urgent trucks go first. | tool_light, light_mode_priority | light_mode_set (priority) |
| 3 | Press 1x and watch the urgent trucks get through. | btn_speed_1 | urgent_delivered 2 |
| 4 | Tip: build a second road to the same warehouse, and urgent trucks will use it whenever the first one is jammed. | none | continue |

### Lesson 6: Speed, heatmap and score
Layout: reuse the lesson 3 layout with a light prebuilt in Timer mode with an 8 s period, so jams form. Inventory: none needed. Tools: all.

| # | Text | Highlight | Wait |
|---|---|---|---|
| 1 | Pause lets you build in peace. 2x and 4x stress-test your system. Press 4x. | btn_speed_4 | speed_set 4 |
| 2 | Open the Heatmap. Green is clear, yellow is busy, and red with stripes is a jam. | btn_heatmap | heatmap_toggled on |
| 3 | The red road shows where your automation is failing. Switch the heatmap off when you are done. | btn_heatmap | heatmap_toggled off |
| 4 | This light uses a slow timer. Click it and switch it to Sensor. | the light | light_mode_set (sensor) |
| 5 | Every level ends with a score and up to 3 stars. More deliveries and less time stuck in jams means a higher score. | none | continue |

### Final test
All tools unlocked. Build from scratch on a small map with both colors and a river with one crossing. Time limit 90 s, goal 6 deliveries, losing is enabled (Retry on failure). Inventory: 60 roads, 1 light, 1 sorter, 2 bridge tiles.

Intro text: `Final test! Build a network from scratch. Deliver 6 trucks in 90 seconds without a total gridlock.` (Continue button reads `Start`.) Wait: `level_won`. On `level_lost`, show the normal results screen with Retry.

### Completion screen
Title `Tutorial complete!`. Body: `You now know everything you need. Roads connect, lights and sorters decide, and the heatmap shows what is failing. Good luck, engineer!` Buttons: `Play Level 1` and `Main menu`. Mark `tutorial_done = true` here (and also when the player skips).

## 9. Part E: welcome, menu, help

**Welcome screen** (first launch only): the GridFlow title, then `Welcome to GridFlow`, body `You are a traffic automation engineer. You never drive a truck. You build a system of roads, lights and sorters, and it runs itself. The tutorial takes about 5 minutes.` A large yellow `Start tutorial` button and a small `Skip tutorial` text link. Skip opens a confirmation: `Skip the tutorial? You can replay it anytime from the main menu.` with `Skip` and `Go back`. Skipping sets `tutorial_skipped = true` and `tutorial_done = true`.

**Main menu changes:** add a `Tutorial` button that replays the tutorial from lesson 1 (it never resets or changes progress), and the language button from section 5.1. Keep Play, Levels, Sound, Quit.

**Level 1:** remove the old scripted tutorial overlay and its crash script. Level 1 is now a normal level.

**Help overlay:** a `Help` (`?`) button in the top bar and the `F1` key open a one-page overlay in every level (it pauses the simulation while open and restores the previous speed on close). Content:

- Goal: `Deliver trucks to the warehouse of the same color before time runs out. If a warehouse runs out of patience, or the whole network freezes, you lose.`
- Tools: `Road connects things. Bridge crosses water. Light controls a junction. Sorter sends each color a different way at a fork. Erase removes what you built.`
- Lights: `Timer switches every few seconds. Sensor serves the longer queue. Priority lets urgent trucks go first.`
- Urgent trucks: `Yellow trucks with a ring re-plan their route and use bypass roads.`
- Heatmap: `Green is clear, yellow is busy, red with stripes is a jam.`
- Controls: `Space: pause. 1, 2, 3: speed 1x, 2x, 4x. H: heatmap. R: retry. Esc: menu. F1: help.`
- `You never drive the trucks. Build the system and let it run.`

All of this text comes from the strings table too.

## 10. Tests

Update and extend the existing headless test script (keep its run command). Add:

1. **Strings parity:** `EN` and `RU` have identical key sets, no value is empty, and `%` placeholders match between the two languages.
2. **Missing keys:** scan all `.gd` files for `Strings.t("KEY")` and `Strings.tf("KEY", ...)` calls and fail if any key is missing from `EN`.
3. **No hardcoded UI text:** replace the old Latin-letter or Cyrillic scan with one that fails on string literals used for visible text (`.text =`, `draw_string(`, `window_title`, tooltips) outside `strings.gd`.
4. **First-run logic:** a fresh `SaveData` (no file) reports `is_first_run() == true`. After `tutorial_done` is set and saved, a new load reports false. A corrupt save file does not crash and counts as a fresh install.
5. **Lesson solvability:** for every lesson and the final test, run the lesson's `solution` actions through the real simulation and a real `tutorial_manager` (no UI), and assert the manager reaches `lesson_completed` (or `level_won` for the final test).
6. **No soft locks:** every step has a `wait` condition, and every `wait` event is one the manager implements.
7. **Tutorial cannot be lost:** in lessons 1 to 6, drive a deliberately bad network for 60 simulation seconds and assert no lose condition triggers.
8. **Existing tests:** all earlier tests (determinism, performance, no manual control, offline, and others) still pass. The "no manual control" static check must also cover the `tutorial/` folder.

## 11. Quality checklist

- A fresh install (no `user://save.cfg`) shows the Welcome screen, runs all 6 lessons and the final test, shows the completion screen, then the main menu. The next launch goes straight to the main menu.
- The whole tutorial takes about 5 to 7 minutes, and lesson 1 takes under 60 seconds for a new player.
- No Cyrillic and no leftover Russian text is visible in English mode, and no `!KEY!` marker appears anywhere.
- No tool is usable that the current lesson has not unlocked, and no lesson can be soft-locked.
- The tutorial never hides the thing the player needs to click, and never blocks input.
- The FPS is unchanged by the tutorial overlays (check with the `F3` overlay at 4x).
- Replaying the tutorial from the menu works any number of times and does not corrupt saved progress or best scores.
- All earlier hard constraints still hold (section 3).

## 12. Phases (do them in order, verify each, commit each)

**Phase 1: Inspect and report (about 20 min).** Section 2. No code changes. Report to the user before continuing.

**Phase 2: English localization (about 2 h).** Section 5, the language button, the title and window name, and test updates 1 to 3. *Done when:* the whole game, including menus, HUD, panels, and results, shows English by default; the Russian option still works; the tests pass.

**Phase 3: Save data and first-run flow (about 1 h).** Section 6 and the Welcome screen skeleton. *Done when:* test 4 passes and a fresh install shows the Welcome screen once.

**Phase 4: Tutorial framework with lesson 1 (about 4 h).** `UiRegistry`, `tutorial_manager.gd`, `tutorial_data.gd`, the coach panel, the highlight layer, tool locking, hint and skip timers, and lesson 1 end to end. *Done when:* a new player completes lesson 1 using only the coach panel.

**Phase 5: Remaining lessons (about 4 h).** Lessons 2 to 6 and the final test, the hooks `force_crash` and `spawn_urgent`, the completion screen, the menu Tutorial button, and removal of the old Level 1 overlay. Write tests 5 to 7. *Done when:* the full tutorial can be completed and every lesson's solution test passes.

**Phase 6: Help overlay and polish (about 2 h).** The Help overlay, step transition tweens and sound, the full checklist in section 11, README update (how first-run works and how to reset it with `F9` in a debug build). *Done when:* every item in section 11 is true.

If time is short, cut in this order: step transition animations, lesson 5, the Russian translation of the tutorial text. Never cut: English UI, the first-launch flow, lessons 1 to 3, the light lesson's explanation of all three modes, the heatmap explanation, or the tests for the hard constraints.

## 13. Working rules

- Read this file again at the start of each phase.
- Do not add features that are not in this file without asking.
- Keep tutorial logic in `tutorial/` and keep it free of scene-tree references (only the coach panel, highlight layer, and the two screens may touch nodes).
- Use static typing where it is simple, and no Godot 4 features.
- After each phase, report in 3 to 5 lines: what works, what you ran to verify it, and anything you could not verify.
- When something in this file seems wrong or contradictory, pick the simplest option that satisfies the constraints, note the decision in `DECISIONS.md`, and continue.
- If the existing code is structured differently from what this file assumes, adapt to the existing structure rather than rewriting it, and say what you adapted.
