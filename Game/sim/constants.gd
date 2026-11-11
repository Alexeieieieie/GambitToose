extends Reference

# All tunable numbers of the simulation live in this file.

const TILE = 40
const MAP_W = 32
const MAP_H = 15
const STEP = 1.0 / 30.0           # fixed simulation step
const MAX_STEPS_PER_FRAME = 8
const ROAD_CAPACITY = 2           # vehicles per road tile (one per lane)
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
const YELLOW_TIME = 1.0
const ALL_RED_TIME = 0.5
const DEFAULT_PERIOD = 5.0
const DEFAULT_THRESHOLD = 3
const SENSOR_RANGE = 10           # tiles a light sensor looks back along a road
const JAM_WAIT = 3.0              # a vehicle waiting longer than this is "in a jam"
const DEADLOCK_CHECK_INTERVAL = 0.5
const SPAWN_JITTER = 0.1          # +-10 percent on factory intervals
const NO_ROUTE_RETRY = 0.5
const CRASH_HOLD_MAX = 8.0        # tutorial lesson 2: how long the first truck waits for cross traffic
const LANE_OFFSET = 6.5           # pixels from the tile center to the lane center
const DIRS = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
const NO_CELL = Vector2(-99, -99)

enum CargoColor { BLUE, RED, URGENT }
enum Tile { EMPTY, ROAD, FACTORY, WAREHOUSE, WATER, BRIDGE, OBSTACLE }
enum Tool { NONE, ROAD, LIGHT, SORTER, BRIDGE, ERASE }
enum LightMode { TIMER, SENSOR, PRIORITY }
