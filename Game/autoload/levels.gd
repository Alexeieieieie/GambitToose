extends Node

# Level data, the selected level, and the local save file with best results.

const C = preload("res://sim/constants.gd")

var current = 0                  # index into LEVELS
var mode = "level"               # "level" or "tutorial"
var tutorial_index = 0           # lesson 0..5, and 6 is the final test

var LEVELS = [
	{
		"id": 1, "name_key": "LEVEL_1", "time": 90, "goal": 14, "mode": "goal", "seed": 1337,
		"factories": [
			{"cell": Vector2(2, 7), "color": C.CargoColor.BLUE, "interval": 4.0, "start_at": 0.0},
			{"cell": Vector2(15, 1), "color": C.CargoColor.RED, "interval": 5.0, "start_at": 12.0},
		],
		"warehouses": [
			{"cell": Vector2(29, 7), "color": C.CargoColor.BLUE},
			{"cell": Vector2(15, 13), "color": C.CargoColor.RED},
		],
		"water": [], "obstacles": [],
		"roads": _line(Vector2(15, 2), Vector2(15, 12)),
		"inventory": {"road": 80, "light": 1, "sorter": 0, "bridge": 0},
		"solution": [
			{"type": "road_line", "from": Vector2(3, 7), "to": Vector2(28, 7)},
			{"type": "light", "cell": Vector2(15, 7), "mode": C.LightMode.SENSOR},
		]
	},
	{
		"id": 2, "name_key": "LEVEL_2", "time": 240, "goal": 70, "mode": "goal", "seed": 2024,
		"factories": [
			{"cell": Vector2(2, 4), "color": C.CargoColor.BLUE, "interval": 5.0, "start_at": 0.0, "urgent_every": 6},
			{"cell": Vector2(2, 10), "color": C.CargoColor.RED, "interval": 5.0, "start_at": 0.0},
		],
		"warehouses": [
			{"cell": Vector2(29, 4), "color": C.CargoColor.RED},
			{"cell": Vector2(29, 10), "color": C.CargoColor.BLUE},
		],
		"water": _river([10, 21]),
		"obstacles": [Vector2(6, 1), Vector2(7, 1), Vector2(16, 2), Vector2(25, 1),
				Vector2(5, 13), Vector2(15, 12), Vector2(16, 12), Vector2(26, 13)],
		"roads": [],
		"inventory": {"road": 70, "light": 2, "sorter": 2, "bridge": 2},
		"solution": [
			{"type": "road_line", "from": Vector2(3, 4), "to": Vector2(10, 4)},
			{"type": "road_line", "from": Vector2(10, 5), "to": Vector2(10, 6)},
			{"type": "bridge", "cell": Vector2(10, 7)},
			{"type": "road_line", "from": Vector2(10, 8), "to": Vector2(10, 9)},
			{"type": "road_line", "from": Vector2(3, 10), "to": Vector2(28, 10)},
			{"type": "road_line", "from": Vector2(21, 9), "to": Vector2(21, 8)},
			{"type": "bridge", "cell": Vector2(21, 7)},
			{"type": "road_line", "from": Vector2(21, 6), "to": Vector2(21, 4)},
			{"type": "road_line", "from": Vector2(22, 4), "to": Vector2(28, 4)},
			{"type": "light", "cell": Vector2(10, 10), "mode": C.LightMode.SENSOR},
			{"type": "sorter", "cell": Vector2(21, 10), "rules": {
				C.CargoColor.BLUE: Vector2(1, 0),
				C.CargoColor.URGENT: Vector2(1, 0),
				C.CargoColor.RED: Vector2(0, -1),
			}},
		]
	},
	{
		"id": 3, "name_key": "LEVEL_3", "time": 240, "goal": 0, "mode": "score", "seed": 777,
		"factories": [
			{"cell": Vector2(2, 3), "color": C.CargoColor.BLUE, "interval": 5.0, "start_at": 0.0},
		],
		"warehouses": [
			{"cell": Vector2(29, 11), "color": C.CargoColor.BLUE},
		],
		"spawn_events": [
			{"at": 30.0,
				"factories": [{"cell": Vector2(2, 11), "color": C.CargoColor.RED, "interval": 5.0}],
				"warehouses": [{"cell": Vector2(29, 3), "color": C.CargoColor.RED}]},
			{"at": 70.0,
				"factories": [{"cell": Vector2(15, 1), "color": C.CargoColor.BLUE, "interval": 6.0, "urgent_every": 3}]},
			{"at": 110.0,
				"factories": [{"cell": Vector2(15, 13), "color": C.CargoColor.RED, "interval": 6.0}]},
			{"at": 150.0,
				"factories": [{"cell": Vector2(22, 1), "color": C.CargoColor.RED, "interval": 6.0}]},
		],
		"water": [],
		"obstacles": [Vector2(7, 6), Vector2(8, 6), Vector2(7, 7), Vector2(8, 7),
				Vector2(12, 8), Vector2(13, 8), Vector2(19, 6), Vector2(19, 7), Vector2(20, 7),
				Vector2(5, 13), Vector2(6, 13), Vector2(10, 1), Vector2(11, 1), Vector2(27, 7)],
		"roads": [],
		"inventory": {"road": 140, "light": 4, "sorter": 3, "bridge": 0},
		"solution": [
			{"type": "road_line", "from": Vector2(3, 3), "to": Vector2(28, 3)},
			{"type": "road_line", "from": Vector2(3, 11), "to": Vector2(28, 11)},
			{"type": "road_line", "from": Vector2(23, 4), "to": Vector2(23, 10)},
			{"type": "road_line", "from": Vector2(26, 4), "to": Vector2(26, 10)},
			{"type": "road", "cell": Vector2(15, 2)},
			{"type": "road", "cell": Vector2(15, 12)},
			{"type": "road", "cell": Vector2(22, 2)},
			{"type": "sorter", "cell": Vector2(23, 3), "rules": {
				C.CargoColor.BLUE: Vector2(0, 1),
				C.CargoColor.URGENT: Vector2(0, 1),
				C.CargoColor.RED: Vector2(1, 0),
			}},
			{"type": "sorter", "cell": Vector2(23, 11), "rules": {
				C.CargoColor.BLUE: Vector2(1, 0),
				C.CargoColor.URGENT: Vector2(1, 0),
				C.CargoColor.RED: Vector2(1, 0),
			}},
			{"type": "sorter", "cell": Vector2(26, 11), "rules": {
				C.CargoColor.BLUE: Vector2(1, 0),
				C.CargoColor.URGENT: Vector2(1, 0),
				C.CargoColor.RED: Vector2(0, -1),
			}},
			{"type": "light", "cell": Vector2(26, 3), "mode": C.LightMode.SENSOR},
			{"type": "light", "cell": Vector2(15, 3), "mode": C.LightMode.SENSOR},
			{"type": "light", "cell": Vector2(15, 11), "mode": C.LightMode.SENSOR},
		]
	},
]


static func _line(from: Vector2, to: Vector2) -> Array:
	var out = []
	var d = Vector2(sign(to.x - from.x), sign(to.y - from.y))
	var cell = from
	while true:
		out.append(cell)
		if cell == to:
			break
		cell += d
	return out


static func _river(narrow_columns: Array) -> Array:
	# A river on rows 6 to 8. At the narrow columns it is one tile wide (row 7).
	var out = []
	for x in range(C.MAP_W):
		for y in [6, 7, 8]:
			if y != 7 and narrow_columns.has(x):
				continue
			out.append(Vector2(x, y))
	return out


func level() -> Dictionary:
	return LEVELS[current]


func has_next() -> bool:
	return current + 1 < LEVELS.size()
