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
