# Decisions

Places where the brief (`promts/GRIDFLOW_BUILD_GODOT3.md`) was unclear, contradictory, or
did not work as written, and what was done instead.

## Engine
- **Godot 3.6.3 instead of 3.5.x.** It is the version installed on the build machine. Only
  features that also exist in 3.5 are used.
- **`_set` renamed to `_enter` in `intersection.gd`.** `_set` is a built-in Object method in
  Godot 3 and the brief's signature does not parse.
- **`Vector2.sign()` is not used.** In Godot 3 it returns 1 for 0, which made line helpers loop
  forever. The scalar `sign()` is used instead.

## Simulation
- **One vehicle per lane, not two per tile "regardless of direction".** A road tile still holds
  2 vehicles, but at most one per lane, where a lane is the side it was entered from. With the
  brief's rule, two opposite streams on one road lock head-on forever, which would be a crash-like
  dead end for the player. Lanes also let trucks be drawn on the right-hand side of the road.
- **Light sensors count the whole queue.** The brief registers only vehicles waiting directly at
  the light, which can never exceed the default threshold of 3. The simulation counts consecutive
  waiting vehicles along each approach (up to `SENSOR_RANGE` tiles).
- **Priority mode = Sensor + urgent override.** The brief's Priority rule only switches for urgent
  trucks, so a junction with no urgent traffic would never change. The toggle "Срочные грузовики
  без очереди" adds the same override to Timer and Sensor modes.
- **Urgent trucks keep the cargo color of their factory.** They are routed and sorted as the
  URGENT class but unload at the warehouse of their factory's color (shown as a colored stripe).
- **Buildings are end points.** Nothing drives through a factory or a warehouse.
- **Warehouse patience only drains while a factory of its color is active.** Otherwise the red
  warehouse of Level 1 would lose before the first red truck could reach it.
- **Vehicles whose road was erased under their route** re-plan; if no route exists they stop and
  wait (state `STRANDED`) and re-plan at the next network change.
- **Running out of time in a goal level is a loss** with reason `time` ("Время вышло").

## Levels
- **Level 1 has a pre-built red road**, goal 14 and the red factory starts at 12 s (brief: goal 8,
  25 s). With the brief's numbers the level was won 3 seconds after the scripted crash, before
  the light mattered.
- **Level 2 goal is 70, not 20.** Goal 20 ends in about a minute; hackathon rule 3 needs a 3 to 5
  minute run. The intended solution wins at about 3:08.
- **Level 2 river narrows.** The river is 3 tiles wide but the inventory has 2 bridges, so at
  columns 11 and 22 (cells K and V) the river is 1 tile wide; bridges go there.
- **Level 3 shows future building sites** as dashed plots that cannot be built on, so a later
  factory can never land on a player road.

## UI and tests
- Stars use the brief's thresholds. Light and sorter panels pause the simulation while open.
- The strings test checks text assignments and text-drawing calls for Latin literals, and
  forbids any Cyrillic literal in `view/` and `ui/`. Level names stay in `autoload/levels.gd`
  next to the level data, as in the brief's own example.
- `tests/smoke.tscn` is an extra end-to-end run (real scenes, mouse and keyboard input,
  screenshots). It is not one of the 11 required tests.

## English and tutorial update (promts/eng_tutorial.md)

### Localization
- **Existing key names were kept** (for example `LIGHT_TITLE`, `THRESHOLD`, `LEVEL_N`) instead of renaming them to
  the names in the brief's table, because the brief says to map to the keys that exist. The English texts follow the table.
- **`HINT_PATIENCE` has no location now**, as in the brief's English text. The Russian text was changed to match.
- **Level names** moved out of `autoload/levels.gd` into the string tables (`name_key`).
- **The title is `GridFlow` in both languages** (the old Russian title was a different name).
- **Autoload order** is `SaveData, Strings, Palette, Fonts, Levels, Sfx, UiRegistry`. `SaveData` reaches `Strings` and `Sfx`
  by node path because autoloads that read it cannot also be referenced from it (parse cycle).

### Tutorial
- **Lesson 2, step 3 waits for the crash, not for the 1x press.** The explanation in step 4 is only true once the
  trucks have met, so the manager shows it then. Pressing 1x is still highlighted.
- **The scripted crash is guaranteed.** In lesson 2 only, the first truck to reach the uncontrolled crossing waits
  (at most 8 s) until a truck from the other road is also there. Everything else about junctions is unchanged.
- **Lesson levels never end by themselves** (`lesson: true`), have no time limit and cannot be lost: patience bars refill
  and gridlock does not end the run. The top bar shows `--:--` and a delivery count instead of a timer.
- **Lessons 3 and 4 keep a panel open** (`needs_panel`) while they explain it; closing it with Cancel reopens it.
  In the tutorial the light and sorter panels sit on the right so the coach card on the left never covers them.
- **Lesson 4 layout:** a vertical 2-tile river, two prebuilt crossings approaches, a fork at (8, 7). Each crossing ends
  next to a warehouse of both colors, so any split of the colors works. The rule check also requires that both
  factories still have a route, so pointing a color back the way it came does not count.
- **Lesson 5:** the first two trucks are urgent (a hook arms the first one, the factory makes every second truck urgent).
  A dead-end stub makes the crossing a junction so a light can go there.
- **Lesson 6** has a prebuilt Timer light (8 s) and fast factories so jams form.
- **Final test:** 90 s, goal 6, losing enabled; a second step explains what to do after the Start button.
- **Reset lesson** is offered when the network stands still for 8 s, and `R` always restarts the lesson.
- **Progress dots** show the steps of the current lesson; the tag shows the lesson number.
- The Help overlay pauses with a silent speed change, so closing it never counts as pressing a speed button.

### Sound
- Sounds were rebuilt (marimba and bell tones, filtered noise, reverb). Short effects are 44.1 kHz, long ones and
  the 30 s music loop 22.05 kHz; the total is about 1.9 MB. New sounds: bridge, step, lesson, fanfare, deny, speed.
- Delivery dings climb a major pentatonic ladder instead of a linear pitch ramp. The music is ducked under the results.
- I cannot listen to audio here. The files were checked numerically (no clipping, no DC offset, seamless loop ends).
