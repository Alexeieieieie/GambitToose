# GridFlow (АвтоТрафик): build brief (Godot 3.x)

You are building a complete 2D game in **Godot 3.x (GDScript 1.0 syntax)** for a hackathon. Read this whole file before writing any code. Work in the phases in section 15, finish and verify one phase before starting the next, and make a git commit at the end of each phase.

**Everything in this file is Godot 3.** Do not write Godot 4 syntax. Section 3 lists the differences that most often cause mistakes; re-read it whenever a script fails to parse.

## 1. Hackathon rules (hard constraints: break one and we lose)

1. **2D only.** Use only `Node2D`, `Control`, and other 2D or UI nodes. No `Spatial`, no 3D physics, no 3D logic.
2. **Automation is the core.** The player must never control a vehicle directly. No code path may move, steer, stop, or delete a vehicle because of a player click. The player only builds roads and configures rules (traffic lights, sorters). The system then runs itself.
3. **Session length.** A full run of the main level takes 3 to 5 minutes and ends with a win or lose screen showing a score.
4. **Performance.** At least 30 FPS on a low-end laptop, load in under 30 seconds, zero crashes.
5. **Offline only.** No `HTTPRequest`, no `HTTPClient`, no sockets, no analytics, no online fonts, no update checks.
6. **Russian UI.** Every string the player sees is in Russian, and all of them live in one file (`autoload/strings.gd`).

If a task you are about to do would break any of these, stop and ask.

## 2. The game in one paragraph

The player is a traffic automation engineer. **Factories** spawn colored trucks on their own. **Warehouses** accept only trucks of their own color. Trucks find their own route over the road network the player builds. The player places **roads, bridges, smart traffic lights, and sorter filters**, and programs the lights and filters. Wrong settings create phantom traffic jams. The player can pause to build, then speed up to 2x or 4x to stress-test the system. A heatmap shows where the network is failing.

**Win:** reach the delivery goal before time runs out (Level 3: survive until time ends and maximize the score).
**Lose:** a warehouse patience bar reaches zero, or the whole network stands still for 15 simulation seconds.

## 3. Godot 3 rules you must follow

| Topic | Godot 3 (use this) | Godot 4 (never use) |
|---|---|---|
| Annotations | `export var x`, `onready var n = $Node`, `tool` | `@export`, `@onready`, `@tool` |
| Cells and grid | `Vector2` with whole numbers | `Vector2i` (does not exist) |
| Base class for data | `extends Reference` | `RefCounted` |
| Redraw | `update()` | `queue_redraw()` |
| Arrays | untyped `Array`, `PoolVector2Array`, `PoolStringArray` | `Array[Vector2i]`, `PackedVector2Array` |
| Waiting | `yield(get_tree().create_timer(1.0), "timeout")` | `await` |
| Signals | `connect("name", self, "_method")` and `emit_signal("name", arg)` | `signal.connect(callable)` |
| Math | `clamp`, `min`, `max`, `lerp`, `stepify`, `floor`, `abs` | `clampf`, `snappedf` |
| Key events | `event.scancode == KEY_SPACE` | `event.keycode` |
| Control layout | `rect_position`, `rect_size`, `rect_min_size`, `margin_left`, `anchor_left` | `position`, `size`, `offset_left` |
| Tweens | a `Tween` node: `interpolate_property(obj, "scale", from, to, 0.2)` then `start()` | `create_tween()` |
| Pathfinding | `AStar2D` (needs Godot 3.2 or newer) | |
| Ternary | `a if cond else b` works | |
| Draw text | `draw_string(font, position, text, color)` with a `DynamicFont` | |
| Rounded boxes | `StyleBoxFlat` with `set_corner_radius_all(n)`; draw with `draw_style_box(style, rect)` | |
| Rotation of drawing | `draw_set_transform(position, rotation, scale)` and reset it afterwards | |

Other rules that avoid real Godot 3 problems:

- **Do not use `class_name`.** In headless runs the global class cache may not exist, so `class_name` types can fail to resolve. Use `const C = preload("res://sim/constants.gd")` at the top of each file instead. The autoload singletons (`Strings`, `Palette`, `Sfx`, `Levels`, `Fonts`) are registered in `project.godot`, so they are fine to use by name.
- **Do not hand-write complex `.tscn` or `.tres` files.** Make each scene a single root node with a script, and let the script create its child nodes in `_ready()`. Build the Theme, fonts, and style boxes in code. This avoids broken resource files.
- **Determinism:** Godot 3 dictionaries are fine for lookups, but never let the order of dictionary iteration change simulation results. Iterate over arrays (`road_cells`, `vehicles`, `factories`) in the simulation, never over a dictionary.
- Dictionary keys may be `Vector2` cells. Always use whole-number values so keys compare equal.
- Do not use `Array.pop_back()` on arrays you are iterating.
- Check each Godot method against the Godot 3.5 documentation before using it. If you are not sure it exists in 3.x, write the logic yourself.

## 4. Environment

- Run `godot --version` (it may be called `godot3` or be a full path). Use **3.5.x**. Run `godot --help` once and note the exact flag names your build supports for running without a window, running a script, and quitting. This file uses `--no-window`, `-s`, and `--quit`; adjust if your build differs.
- **Import pass:** after adding fonts or audio, run `godot --path . --editor --quit` once so Godot generates the `.import` data. Without it, loading those files can fail when running headless. Repeat after adding assets.
- Project name: `GridFlow`. Window 1280x720. In `project.godot` set:
  - `display/window/size/width=1280`, `display/window/size/height=720`
  - `display/window/stretch/mode="2d"`, `display/window/stretch/aspect="keep"`
  - `rendering/quality/driver/driver_name="GLES2"` (best for low-end laptops)
  - `rendering/environment/default_clear_color` set to the navy color from section 11
- **Fonts:** the user will place `Nunito-Regular.ttf` and `Nunito-Bold.ttf` (or another OFL font with Cyrillic) in `fonts/`. If the files are missing, stop and ask for them. Do not substitute a font that lacks Cyrillic.
- Python 3 (standard library only) is allowed for the sound generator in section 12.
- Add a `.gitignore` containing `.import/` and `export.cfg`.

## 5. Folder structure

```
res://
├─ project.godot
├─ CREDITS.txt
├─ autoload/
│  ├─ strings.gd        all Russian UI text
│  ├─ palette.gd        all colors
│  ├─ fonts.gd          builds DynamicFont objects in code
│  ├─ sfx.gd            sound player pool, music
│  └─ levels.gd         level data
├─ sim/                 pure logic, NO scene-tree dependencies (extends Reference)
│  ├─ constants.gd      constants and enums (accessed as C)
│  ├─ grid.gd
│  ├─ vehicle.gd
│  ├─ intersection.gd
│  ├─ sorter.gd
│  ├─ factory.gd
│  ├─ warehouse.gd
│  ├─ metrics.gd
│  ├─ pathing.gd
│  └─ sim.gd            owns everything, exposes step(dt)
├─ view/
│  ├─ game.tscn / game.gd
│  ├─ grid_view.gd
│  ├─ vehicle_layer.gd
│  ├─ building_layer.gd
│  ├─ heatmap_layer.gd
│  └─ fx_layer.gd
├─ ui/
│  ├─ main_menu.tscn / .gd
│  ├─ level_select.tscn / .gd
│  ├─ hud.gd                top bar and toolbar (builds children in code)
│  ├─ light_panel.gd
│  ├─ sorter_panel.gd
│  ├─ tutorial_overlay.gd
│  ├─ results.gd
│  └─ theme_builder.gd      builds the Theme in code
├─ audio/               generated .wav files
├─ fonts/
├─ tools/gen_sfx.py
└─ tests/run_tests.gd
```

**Architecture rule:** everything in `sim/` must run without a scene tree, so it can be tested headless. The `view/` and `ui/` scripts only read simulation state and send player build commands to it. A single node draws all vehicles in one `_draw()` call, so do **not** create one node per vehicle. The simulation reports things that happened (delivery, jam started, crash, deadlock) by pushing dictionaries onto `sim.events`; `game.gd` reads and clears that array every frame to trigger sounds and effects.

## 6. Constants (`sim/constants.gd`, used as `C`)

```gdscript
extends Reference

const TILE = 40
const MAP_W = 32
const MAP_H = 15
const STEP = 1.0 / 30.0           # fixed simulation step
const MAX_STEPS_PER_FRAME = 8
const ROAD_CAPACITY = 2           # vehicles per road tile
const JUNCTION_CAPACITY = 1       # vehicles per intersection tile
const MAX_VEHICLES = 120
const SPEED_NORMAL = 2.5          # tiles per second
const SPEED_URGENT = 3.5
const UNLOAD_TIME = 0.8
const WAREHOUSE_PATIENCE_MAX = 30.0
const WAREHOUSE_PATIENCE_GAIN = 8.0
const GRIDLOCK_SECONDS = 15.0
const GRIDLOCK_MIN_VEHICLES = 3
const REPATH_URGENT_INTERVAL = 1.0
const WEIGHT_REFRESH_INTERVAL = 0.5
const HEATMAP_REDRAW_INTERVAL = 0.25
const MIN_GREEN = 2.0
const DEFAULT_PERIOD = 5.0
const DEFAULT_THRESHOLD = 3
const DIRS = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]

enum CargoColor { BLUE, RED, URGENT }
enum Tile { EMPTY, ROAD, FACTORY, WAREHOUSE, WATER, BRIDGE, OBSTACLE }
enum Tool { NONE, ROAD, LIGHT, SORTER, BRIDGE, ERASE }
enum LightMode { TIMER, SENSOR, PRIORITY }
```

Tunable numbers (patience, speeds, intervals) live only here, so balancing is one file.

## 7. Simulation specification

### 7.1 Fixed timestep and speed

```gdscript
var speed = 1.0                  # 0 (pause), 1, 2, 4
var acc = 0.0

func _process(delta):
    if sim.finished:
        return
    acc += delta * speed
    var n = 0
    while acc >= C.STEP and n < C.MAX_STEPS_PER_FRAME:
        sim.step(C.STEP)
        acc -= C.STEP
        n += 1
    if n == C.MAX_STEPS_PER_FRAME:
        acc = 0.0                # drop the backlog so 4x never freezes the game
    _drain_events()
    vehicle_layer.update()
```

### 7.2 Grid

```gdscript
var tiles = {}          # Vector2 -> Tile enum value
var occupants = {}      # Vector2 -> Array of vehicles reserving this tile
var controllers = {}    # Vector2 -> light or sorter object
var road_cells = []     # Array of Vector2, rebuilt when the network changes
```

- A road cell with 3 or 4 road/bridge neighbors is a **junction** (capacity 1). Other road tiles hold 2.
- Roads are two-way. Two vehicles may be in the same tile (two lanes), regardless of direction.
- Bridges are road tiles that can only be placed on `WATER`. Roads cannot be placed on water.
- Whenever the player builds or erases anything, set `graph_dirty = true`. Rebuild the pathfinding graphs at the start of the next step, once.

### 7.3 Entering a tile (this creates the phantom jams)

```gdscript
func try_enter(v, from, to):
    if occupants[to].size() >= capacity(to):
        return false
    var ctrl = controllers.get(to)
    if ctrl != null and not ctrl.allows(v, from):
        return false
    occupants[to].append(v)      # reservation is immediate
    return true

func leave(cell, v):
    occupants[cell].erase(v)
```

A vehicle that cannot enter the next tile waits. The one behind it waits for the same reason. That backward chain is the shockwave jam. Do not add physics bodies, collision shapes, or per-frame distance checks.

**Uncontrolled junction rule:** first come, first served. In the tutorial level only, the first time two vehicles from different axes arrive at the same uncontrolled junction within 1 second of each other, push a `crash` event (see section 10).

### 7.4 Vehicle (`extends Reference`)

Fields: `color`, `urgent`, `path` (Array of Vector2), `idx`, `progress` (0..1 between `path[idx]` and `path[idx+1]`), `state`, `wait_time`, `unload_timer`, `pos` (world pixels), `spawn_time`, `reserved`.

States: `DRIVING`, `WAITING`, `UNLOADING`. Spawning and despawning are insert and remove on the simulation's vehicle array, not states.

```gdscript
func tick(dt, grid):
    match state:
        S.DRIVING:
            if not reserved:
                if not grid.try_enter(self, path[idx], path[idx + 1]):
                    state = S.WAITING
                    wait_time = 0.0
                    return
                reserved = true
            progress = min(progress + speed * dt, 1.0)
            pos = grid.center(path[idx]).linear_interpolate(grid.center(path[idx + 1]), progress)
            if progress >= 1.0:
                grid.leave(path[idx], self)
                idx += 1
                progress = 0.0
                reserved = false
                if idx >= path.size() - 1:
                    state = S.UNLOADING
                    unload_timer = C.UNLOAD_TIME
        S.WAITING:
            wait_time += dt
            if grid.try_enter(self, path[idx], path[idx + 1]):
                reserved = true
                state = S.DRIVING
        S.UNLOADING:
            unload_timer -= dt
            if unload_timer <= 0.0:
                sim.deliver(self)
```

(`linear_interpolate` is the Godot 3 name for vector lerp; use it, not `lerp` on vectors with the wrong argument order.) A vehicle is put into `occupants[path[0]]` when it spawns. A factory spawns only if its start tile has capacity. If `MAX_VEHICLES` is reached, factories skip that spawn.

### 7.5 Pathfinding with traffic weights

Use Godot's built-in `AStar2D`. Build **one graph per cargo color** (`BLUE`, `RED`, `URGENT`).

```gdscript
func rebuild_graphs():
    for c in [C.CargoColor.BLUE, C.CargoColor.RED, C.CargoColor.URGENT]:
        var a = AStar2D.new()
        for cell in road_cells:
            a.add_point(pid(cell), cell)
        for cell in road_cells:
            for n in exits(cell, c):               # neighbors this color may go to
                a.connect_points(pid(cell), pid(n), false)
        astar[c] = a

func pid(cell):
    return int(cell.y) * C.MAP_W + int(cell.x)
```

- `exits(cell, color)`: adjacent road, bridge, and building cells. If `cell` holds a **sorter**, return only the exit that the sorter's rule chooses for that color. This is how sorters work; there is no special movement code.
- **Weights:** every `WEIGHT_REFRESH_INTERVAL` seconds, call `a.set_point_weight_scale(pid, 1.0 + 3.0 * smoothed_density[cell])` on every graph.
- Normal trucks compute their path once at spawn. **Urgent trucks recompute every `REPATH_URGENT_INTERVAL` seconds** while driving, so only they take bypass roads. This difference must be visible in play.
- Handle an empty path: a vehicle with no route does not spawn and the factory shows a small warning icon.
- The destination is the nearest warehouse of the matching color by path length. `get_point_path` returns a `PoolVector2Array`; convert it to a normal `Array` of cells.

### 7.6 Traffic light (`intersection.gd`)

Phases: `GREEN`, `YELLOW`, `ALL_RED`, then flip axis. Axis 0 is horizontal, axis 1 is vertical.

```gdscript
func tick(dt):
    t += dt
    match phase:
        Phase.GREEN:
            if t >= C.MIN_GREEN and _wants_switch():
                _set(Phase.YELLOW)
        Phase.YELLOW:
            if t >= 1.0:
                _set(Phase.ALL_RED)
        Phase.ALL_RED:
            if t >= 0.5:
                green_axis = 1 - green_axis
                _set(Phase.GREEN)

func _wants_switch():
    var other = 1 - green_axis
    match mode:
        C.LightMode.TIMER:
            return t >= period
        C.LightMode.SENSOR:
            return waiting[other] > threshold or (waiting[green_axis] == 0 and waiting[other] > 0)
        C.LightMode.PRIORITY:
            return urgent_waiting[other] and not urgent_waiting[green_axis]
    return false

func allows(v, from):
    var axis = 0 if from.y == cell.y else 1
    return phase == Phase.GREEN and axis == green_axis
```

Defaults: `period = C.DEFAULT_PERIOD`, `threshold = C.DEFAULT_THRESHOLD`. Vehicles register in `waiting[axis]` and `urgent_waiting[axis]` when they enter `WAITING` for a tile controlled by this light, and unregister when they leave `WAITING`.

### 7.7 Sorter (`sorter.gd`)

A sorter sits on a junction cell. It holds `rules`, a dictionary from cargo color to a direction `Vector2`. A direction is valid only if the neighbor in that direction is a road. The UI shows only valid directions. When a rule changes, set `graph_dirty = true`. Vehicles already driving keep their path until the next repath (urgent) or arrival (normal); that is acceptable.

### 7.8 Warehouses, win and lose

- Each warehouse has `patience` starting at `WAREHOUSE_PATIENCE_MAX`. It drains 1.0 per simulation second and gains `WAREHOUSE_PATIENCE_GAIN` per delivery (capped at the max).
- If any warehouse reaches 0, the run is lost with reason `patience`.
- **Gridlock:** every step, if there are at least `GRIDLOCK_MIN_VEHICLES` vehicles and none has moved for `GRIDLOCK_SECONDS`, the run is lost with reason `gridlock`.
- **Win:** `deliveries >= goal` before time ends. Level 3 uses `mode: "score"`: no goal, the run ends when time ends and always shows the results screen, unless a lose condition triggered.

### 7.9 Deadlock detection (technical showcase)

Every 0.5 s, build a wait-for map: for each vehicle in `WAITING`, find the vehicle in the tile it wants to enter. Run a depth-first search for cycles. Push a `deadlock_cycle` event with the cells so the FX layer can flash those tiles red. The gridlock timer is still the actual lose rule; cycle detection is the diagnostic that explains why.

### 7.10 Metrics and score

Track `deliveries`, `total_delivery_time`, `jam_seconds` (simulation seconds in which at least one vehicle has `wait_time > 3`), and `score`.

```
score = deliveries * 100 - int(avg_delivery_time * 2) - int(jam_seconds * 10)
```

Stars: 1 star for winning, 2 stars if also `jam_seconds < 20`, 3 stars if also `jam_seconds < 5`. Save best score and stars per level with a `ConfigFile` at `user://save.cfg` (a local file only).

### 7.11 Heatmap

`density(cell) = occupants[cell].size() / capacity`. Smooth it with `d = lerp(d, now, 0.2)` at each weight refresh. The heatmap layer redraws every `HEATMAP_REDRAW_INTERVAL` seconds, not every frame. Colors: below 0.4 green, below 0.8 yellow, otherwise red **with diagonal hatching** so color-blind players can read it. `draw_line` cannot dash, so draw hatching and dashed lines as many short `draw_line` segments.

### 7.12 Determinism

Each level has a `seed`. The simulation uses one `RandomNumberGenerator` with `rng.seed = level.seed`. Never call the global `randi()` or `randomize()` in `sim/`. The same build actions and the same seed must always give the same result.

## 8. Levels (`autoload/levels.gd`)

Levels are plain dictionaries inside `var LEVELS = [...]`, so adding or fixing a level never means touching simulation code. Cells are `Vector2`. (Use `var`, not `const`, if Godot rejects the enum references inside a constant.) Every level must be validated by the headless tests (section 13): each color must have a path when the intended solution is built.

```gdscript
var LEVELS = [
  {
    "id": 1, "name": "Первые дороги", "time": 90, "goal": 8, "mode": "goal", "seed": 1337,
    "factories": [
      {"cell": Vector2(2, 7),  "color": C.CargoColor.BLUE, "interval": 4.0, "start_at": 0.0},
      {"cell": Vector2(15, 1), "color": C.CargoColor.RED,  "interval": 5.0, "start_at": 25.0},
    ],
    "warehouses": [
      {"cell": Vector2(29, 7),  "color": C.CargoColor.BLUE},
      {"cell": Vector2(15, 13), "color": C.CargoColor.RED},
    ],
    "water": [], "obstacles": [],
    "inventory": {"road": 80, "light": 1, "sorter": 0, "bridge": 0},
    "tutorial": true,
    "solution": []        # build actions of the intended solution, used by tests
  },
]
```

**Level 1 (tutorial, 60 to 90 s).** One blue line, then a red line that crosses it at 25 s. The first conflict triggers the scripted crash and the hint to place a light. The goal is easy to reach once a Sensor light is placed.

**Level 2 (main run, 4 minutes, goal 20).** Layout matches the concept art:
- Blue factory top-left `(2, 4)`, red factory bottom-left `(2, 10)`, red warehouse top-right `(29, 4)`, blue warehouse bottom-right `(29, 10)`.
- A river across the full width on rows 6 to 8 (the `water` list). Two narrow crossings are available where the player may place **bridges** (inventory: 2). Trucks must cross the river, so the bridge count is the bottleneck.
- Three cargo types: BLUE, RED, and URGENT (urgent trucks come from the blue factory on every 6th spawn).
- Inventory: `road 70, light 2, sorter 2, bridge 2`.
- Intended solution: one bridge for each direction of traffic, a Sensor light at the shared junction, and a Sorter that sends blue trucks and red trucks onto different bridges.

**Level 3 (high score, 4 minutes, `mode: "score"`).** Open map with a few `obstacles`. It uses `spawn_events` so new factories and warehouses appear over time (for example at 30, 70, 110 and 150 seconds). Inventory is larger. Place spawn cells so the map never becomes unsolvable; the tests must check reachability.

## 9. Player tools and input

| Tool | Behavior |
|---|---|
| Road | Click or drag to paint road tiles on empty cells. Costs 1 road from the inventory. |
| Bridge | Click water cells to place a bridge tile. Costs 1 bridge. |
| Light | Click a junction cell to place a light and open its panel. Costs 1 light. |
| Sorter | Click a junction cell to place a sorter and open its panel. Costs 1 sorter. |
| Erase | Click any player-built tile to remove it and refund the inventory. Vehicles on a removed tile are removed too (the road disappeared; that is not manual control). |

- Clicking an existing light or sorter reopens its panel.
- Building is allowed at any time, including while running; pausing is the intended way to build.
- Handle map clicks in `_unhandled_input`, so UI controls (the toolbar and panels, with `mouse_filter` set to stop) get the click first and the map never builds underneath them.
- Convert the mouse to a cell with `(get_local_mouse_position() / C.TILE).floor()` on the grid view node, which sits at `Vector2(0, 56)`.
- Keyboard (check `event.scancode`): `Space` pause or resume, `1`/`2`/`3` for 1x/2x/4x, `H` heatmap, `Esc` menu, `R` restart level, `F3` FPS overlay. Each also has an on-screen button.
- Tools never let the player target a vehicle. There is no hover or click handling on vehicles at all.

## 10. Tutorial script (Level 1)

`tutorial_overlay.gd` holds an array of steps. Each step has a Russian text, a list of cells to highlight (pulsing outline), and a completion condition:

1. `road_connected`: blue factory and blue warehouse are connected. Text: `Проложи дорогу от фабрики к складу`
2. `speed_started`: the player pressed play. Text: `Нажми «Играть», и машины поедут сами`
3. `crash_detected`: the scripted conflict at the first uncontrolled junction. On this event, **pause the game**, flash the junction red, and show the next step.
4. `light_placed`: Text: `Поставь умный светофор на перекрёсток`
5. `light_mode_sensor`: Text: `Выбери режим «Датчик»`
6. The tutorial overlay hides and the level continues.

The tutorial must teach a new player in under 60 seconds. If the player does something unexpected (for example builds a light early), skip the steps that are already satisfied.

## 11. UI and drawing specification

Base layout at 1280x720: top bar 0 to 56 px, map 56 to 656 px (32x15 tiles of 40 px), toolbar 656 to 720 px.

**Palette (`autoload/palette.gd`, build colors with `Color("#RRGGBB")`):**

| Name | Hex |
|---|---|
| navy (UI bars, panels) | `#1F2340` |
| navy_light (buttons) | `#3B4070` |
| navy_mid (cards) | `#2E3463` |
| accent yellow | `#FACC15` (dark text `#1F2340` on it) |
| grass | `#9AD16F`, grid line `#8CC463` |
| tree | `#3F9B3A` |
| water | `#5BB8F0`, wave `#A5DDFF` |
| asphalt | `#4A4E69`, lane dash `#F8F4E3` |
| bridge deck | `#C89B5E`, rail `#7A4B22` |
| blue truck / building | `#3B82F6`, dark `#1D4ED8` |
| red truck / building | `#EF4444`, dark `#B91C1C` |
| urgent truck | `#FACC15`, dark `#CA8A04`, ring `#F59E0B` |
| sorter | `#A855F7`, dark `#7E22CE` |
| ok / free | `#22C55E` |
| busy | `#FACC15` |
| jam | `#EF4444` |
| heatmap button | `#F97316` |

**Fonts (`autoload/fonts.gd`):** build `DynamicFont` objects in code from the TTF files (`font_data = load("res://fonts/Nunito-Regular.ttf")`, set `size`) for sizes 12, 14, 18, 24, and 46, plus a bold variant. Use them for `draw_string` calls and set the default font in the Theme.

**Top bar:** level name in a yellow pill (left), deliveries progress bar with `12 / 20` text, timer in a rounded pill with larger text, pause and `1x 2x 4x` buttons (active speed in yellow), sound toggle, menu button.

**Toolbar:** one button per tool with a colored icon dot, the Russian label, and the remaining count (`Светофор ×2`), the active tool outlined in yellow, and the `Тепловая карта` button on the right in orange.

**World drawing (all with `_draw()`, no image files):**
- Grass base with grid lines, and a few trees on empty cells chosen deterministically from the level seed.
- Water as flat blue with a few wave arcs. Bridges as a wooden deck wider than the road, with side rails.
- Roads as 26 px wide asphalt strips with a dashed center line. Junction tiles are just the overlap of the strips.
- Factory: colored box with a darker roof strip, a chimney, and two windows. Warehouse: colored box with a pitched roof and a door. A small patience bar floats above each warehouse (green, yellow below 50 percent, red below 25 percent).
- Trucks: a rounded rect with a lighter cab at the front, rotated to face the direction of travel using `draw_set_transform`. Reset the transform after drawing each truck. Urgent trucks have a dashed ring and two speed lines, so they are not identified by color alone.
- Lights: a small dark box with three dots showing the current phase. Sorters: a purple diamond with a white arrow showing the direction for the selected color.
- A jam ring (dashed red rectangle with light red fill) appears around any run of waiting vehicles longer than 3 tiles.

**Light panel:** a modal over a dimmed map. Title `Светофор, перекрёсток B3` (use the cell label from the grid: column letter and row number). Three mode cards (Таймер, Датчик, Приоритет), the selected one outlined in yellow. A threshold slider (1 to 10) for sensor mode and a period slider (2 to 15 s) for timer mode. A toggle `Срочные грузовики без очереди`. A small live preview of the junction. Buttons `Отмена` and `Применить`.

**Sorter panel:** a modal with one row per cargo color and a choice of valid directions (arrow buttons). `Применить` and `Отмена`.

**Results screen:** a bright card with a title (`Уровень пройден!` or `Система остановилась`), up to 3 stars drawn as polygons with `_draw()`, three stat cards (delivered, average delivery time, time in jams), one hint line, and buttons `Заново` and `Следующий уровень`. The hint must name the location of the longest jam (cell label) and suggest one concrete action based on the biggest problem (a sensor light, a second bridge, a sorter). The lose reason (`patience` or `gridlock`) changes the title and the hint.

**Menus:** the main menu shows the title `АвтоТрафик` with a yellow shadow, a subtitle, buttons `Играть`, `Уровни`, `Звук: вкл`, `Выход`, and a decorative road with moving trucks (drawn, no assets). The level select shows three cards with the best stars and score.

**Accessibility:** never use color as the only cue. Jams are hatched, urgent trucks have a ring, all text is at least 12 px. Keep 30 percent extra width in every button, since Russian labels are longer.

## 12. Localization and audio

### Strings (`autoload/strings.gd`)

Every visible string is a constant in this file, referenced as `Strings.PLAY`. Include at least:

```gdscript
extends Node

const PLAY = "Играть"
const LEVELS = "Уровни"
const SOUND_ON = "Звук: вкл"
const SOUND_OFF = "Звук: выкл"
const EXIT = "Выход"
const PAUSE = "Пауза"
const HEATMAP = "Тепловая карта"
const HEATMAP_ON = "Включена"
const FREE = "Свободно"
const BUSY = "Загружено"
const JAM = "Затор"
const DELIVERED = "Доставлено"
const LEVEL = "Уровень"
const ROAD = "Дорога"
const LIGHT = "Светофор"
const SORTER = "Фильтр"
const BRIDGE = "Мост"
const ERASE = "Стереть"
const MODE_TIMER = "Таймер"
const MODE_SENSOR = "Датчик"
const MODE_PRIORITY = "Приоритет"
const URGENT_FIRST = "Срочные грузовики без очереди"
const APPLY = "Применить"
const CANCEL = "Отмена"
const RESTART = "Заново"
const NEXT_LEVEL = "Следующий уровень"
const WIN_TITLE = "Уровень пройден!"
const LOSE_PATIENCE = "Склад не дождался груза"
const LOSE_GRIDLOCK = "Система остановилась"
const AVG_DELIVERY = "Средняя доставка"
const TIME_IN_JAMS = "Время в заторах"
```

Add everything else the same way (tutorial text, hints, level names, tool tooltips). Add a test that scans all `.gd` files for string literals containing Latin letters in UI calls (`.text =`, `Label`, `Button`) outside `strings.gd`, and fails if it finds any.

### Audio (no downloads, no network)

Write `tools/gen_sfx.py` using only the Python standard library (`wave`, `math`, `struct`, `random`). It generates 16-bit mono 22050 Hz WAV files into `audio/`:

| File | Description |
|---|---|
| `deliver.wav` | Bright two-note "ding": sine 880 Hz then 1320 Hz, about 0.25 s, fast decay |
| `place.wav` | Soft pop: sine 300 Hz, 0.08 s, fast decay |
| `erase.wav` | Short downward blip: 400 to 200 Hz, 0.1 s |
| `tick.wav` | Light switch: tiny noise burst, 0.03 s |
| `warn.wav` | Jam warning: low saw sweeping 140 to 220 Hz, 0.6 s |
| `crash.wav` | Noise burst with a low sine thump, 0.35 s |
| `win.wav` | Arpeggio C5 E5 G5 C6, 0.8 s |
| `lose.wav` | Falling tone 400 to 150 Hz, 0.8 s |
| `siren.wav` | Soft looping sweep 600 to 900 Hz, 0.8 s, quiet |
| `click.wav` | UI click, 0.04 s |
| `music.wav` | About 20 s loop: 100 BPM, pentatonic arpeggio over a soft bass, quiet, seamless |

Rules for `autoload/sfx.gd`:
- Two audio buses, `Music` and `SFX`, created in code with `AudioServer.add_bus()` if they do not exist. The sound toggle mutes both.
- A pool of 6 `AudioStreamPlayer` nodes for effects, so rapid sounds do not cut each other off. Never create a player per sound.
- The `deliver` sound raises `pitch_scale` slightly with each delivery in a row without a jam, and resets after a jam.
- The `warn` sound plays once when a jam first appears (limited to once per 5 s).
- Music `pitch_scale` goes up slightly with speed (1.0, 1.05, 1.1 for 1x, 2x, 4x).
- **Looping WAV in Godot 3:** after `load()`, set `stream.loop_mode = AudioStreamSample.LOOP_FORWARD`, `stream.loop_begin = 0`, and `stream.loop_end = stream.data.size() / 2` (16-bit mono: two bytes per frame). Do this for `music.wav` and `siren.wav`.
- Keep all audio files under about 2 MB in total.

Run the generator once, commit the output, and run the import pass from section 4, so the project works without Python.

## 13. Tests (`tests/run_tests.gd`)

Write the tests as a script that `extends SceneTree` and does its work in `_init()`. Load simulation classes with `preload`, never with `class_name`. Run them with:

```
godot --no-window --path . -s tests/run_tests.gd
```

Print one clear line per test, and finish with `quit(1)` on failure and `quit()` on success. (If your 3.5 build ignores the exit code, also print a final line `TESTS FAILED` or `TESTS PASSED`.) Required tests:

1. **Pathfinding:** a straight road delivers a truck from factory to warehouse. A sorter changes which of two routes a color takes.
2. **Capacity jam:** a red light with vehicles arriving makes a queue that grows backward tile by tile.
3. **Light modes:** Timer switches on its period. Sensor switches when the other axis exceeds the threshold. Priority switches for an urgent truck.
4. **Gridlock lose:** a deliberately closed network triggers the lose condition at 15 s.
5. **Patience lose:** a warehouse with no route reaches zero and loses.
6. **Determinism:** the same level, seed, and build actions give identical `deliveries` after 3600 steps, run twice.
7. **Level validity:** for each level, apply the intended solution (the `solution` build actions in the level data), then assert that every color has a path and that the goal is reachable within the time limit.
8. **Performance:** simulate 120 vehicles for 60 simulation seconds at 4x (8 steps per frame equivalent) and assert that the average step time, measured with `OS.get_ticks_usec()`, stays below 2 ms.
9. **No manual control:** a static check that searches `view/` and `ui/` for any code that changes a vehicle's `path`, `state`, or `pos`, or removes a vehicle, in response to input events; the test fails if it finds one.
10. **Offline:** a static check that fails on `HTTPRequest`, `HTTPClient`, `StreamPeerTCP`, `PacketPeerUDP`, `WebSocketClient`, `WebSocketServer`, `NetworkedMultiplayerENet`, or `OS.shell_open` anywhere in the project.
11. **Strings:** the Latin-letter scan from section 12.

Read files for the static checks with the `File` and `Directory` classes (Godot 3). After each phase, also run `godot --no-window --path . --quit` to make sure the project loads without script errors, and fix every warning that points to a real bug.

## 14. Quality bar before calling it done

- The game reaches the main menu in under 5 seconds on a normal laptop, and a full cold start is under 30 seconds.
- The FPS stays above 30 at 4x speed with 120 vehicles. The `F3` overlay shows `Engine.get_frames_per_second()`.
- Starting, finishing, and restarting a level 5 times in a row produces no errors and no memory growth (check `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)` and the vehicle array size at restart).
- No script error is printed during a full play of all three levels.
- A new player can finish Level 1 in under 60 seconds without outside help.
- Every sound exists and the mute button works.
- Every player-facing string is Russian.

## 15. Phases (do them in order, verify each, commit each)

**Phase 0: Project skeleton (about 30 min).**
Create the project and settings from section 4, the folders, `constants.gd`, `palette.gd`, `strings.gd`, `fonts.gd`, the import pass, and an empty main menu that opens an empty game scene. *Done when:* `godot --no-window --path . --quit` runs with no errors and the window opens at 1280x720 with Cyrillic text rendering correctly.

**Phase 1: Grid and drawing (about 2 h).**
`grid.gd`, `grid_view.gd`, `building_layer.gd`, level loading from `levels.gd`, mouse painting of roads and bridges, and the erase tool with inventory counts. *Done when:* Level 1 shows the map with factories and warehouses, and the player can draw and erase roads and see the toolbar counts change.

**Phase 2: Movement and jams (about 4 h).**
`pathing.gd`, `vehicle.gd`, `factory.gd`, `warehouse.gd`, `sim.gd`, the fixed timestep with speed controls, and `vehicle_layer.gd`. Write tests 1, 2, 5, 6 and 8 now. *Done when:* trucks deliver along the player's road, queues form at a crossing with no light, and the tests pass.

**Phase 3: Automation (about 4 h).**
`intersection.gd` with the three modes, the light panel, `sorter.gd` with its panel, gridlock detection, the wait-for cycle detection, and the jam ring effect. Write tests 3 and 4. *Done when:* a Sensor light measurably clears the Level 1 jam.

**Phase 4: Game feel and flow (about 3 h).**
Top bar and toolbar polish, heatmap, metrics and score, the results screen with the hint, the tutorial script, `sfx.gd` and `tools/gen_sfx.py`, main menu and level select, and the save file for best scores. *Done when:* the full loop menu to Level 1 to results to Level 2 works with sound.

**Phase 5: Levels and polish (about 4 h).**
Level 2 and Level 3 data with `solution` actions, spawn events, balancing of the constants, tweens for juice (scale pop when building, flash on delivery, pulse on jams) using `Tween` nodes, the localization pass, tests 7, 9, 10 and 11, the performance pass, and the Windows export preset. *Done when:* every item in section 14 is true.

If time runs short, cut in this order: Level 3 spawn events, then the wait-for cycle detection visual, then music. Never cut the Sensor light, the sorter, the heatmap, the speed controls, the Russian UI, or the tests for the hard constraints.

## 16. Working rules

- Read this file again at the start of each phase.
- Keep all simulation logic in `sim/` and free of scene-tree references.
- Do not add features that are not in this file without asking, in particular no 3D, no networking, no manual vehicle control, no procedural world generation, no addons.
- Use static typing where it is simple (`var x: int`, `func f(a: Vector2) -> bool`). Do not use typed arrays, `class_name`, or any Godot 4 feature.
- After each phase, report in 3 to 5 lines: what works, what you ran to verify it, and anything you could not verify (for example, if the `godot` command is missing).
- If you are unsure whether a Godot method exists in 3.5, check the Godot 3.5 documentation or test it in a tiny script before building on it.
- When something in this file seems wrong or contradictory, pick the simplest option that still meets the hard constraints in section 1, write down your decision in `DECISIONS.md`, and continue.
- Do not export the final build yourself unless the Godot 3.5 export templates are installed. Prepare the Windows Desktop preset and write the exact steps for the user in `README.md`.
