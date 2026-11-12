extends Reference


const C = preload("res://sim/constants.gd")

const BLUE = C.CargoColor.BLUE
const RED = C.CargoColor.RED


static func _line(a: Vector2, b: Vector2) -> Dictionary:
	return {"type": "road_line", "from": a, "to": b}


static func _step(id: String, c: Dictionary, d: Dictionary = {}) -> Dictionary:
	var s = {"id": id, "text_key": "TUT_" + id.to_upper(), "wait": c}
	for e in d.keys():
		s[e] = d[e]
	if c["event"] != "continue":
		s["hint_key"] = s["text_key"] + "_HINT"
	return s


static func _cont() -> Dictionary:
	return {"event": "continue"}


static func _all_tools() -> Array:
	return [C.Tool.ROAD, C.Tool.BRIDGE, C.Tool.LIGHT, C.Tool.SORTER, C.Tool.ERASE]


static func lesson_count() -> int:
	return 7


static func get_lesson(c: int) -> Dictionary:
	return get_lessons()[c]


static func get_lessons() -> Array:
	return [_l1(), _l2(), _l3(), _l4(), _l5(), _l6(), _final()]


static func _blue_row_level(id: int, c: int) -> Dictionary:
	return {
		"id": id, "seed": c, "time": 0, "goal": 0, "mode": "score",
		"lesson": true, "lose_enabled": false,
		"factories": [{"cell": Vector2(4, 7), "color": BLUE, "interval": 4.0, "start_at": 0.0}],
		"warehouses": [{"cell": Vector2(27, 7), "color": BLUE}],
		"water": [], "obstacles": [], "roads": [], "prebuilt": [],
		"inventory": {"road": 0, "light": 0, "sorter": 0, "bridge": 0},
	}


static func _l1() -> Dictionary:
	var lv = _blue_row_level(101, 101)
	lv["name_key"] = "TUT_L1_TITLE"
	lv["goal"] = 3
	lv["inventory"]["road"] = 30
	lv["allowed_tools"] = [C.Tool.ROAD, C.Tool.ERASE]
	var c = [Vector2(4, 7), Vector2(27, 7)]
	return {
		"id": "l1", "title_key": "TUT_L1_TITLE", "level": lv,
		"steps": [
			_step("l1_s1", _cont()),
			_step("l1_s2", _cont(), {"highlight_cells": c}),
			_step("l1_s3", {"event": "road_connected", "color": BLUE},
					{"highlight_cells": c, "highlight_ui": ["tool_road"]}),
			_step("l1_s4", {"event": "speed_started"}, {"highlight_ui": ["btn_speed_1"]}),
			_step("l1_s5", {"event": "delivered_count", "n": 3},
					{"highlight_cells": [Vector2(27, 7)], "highlight_ui": ["deliveries_bar"]}),
		],
		"solution": [
			{"do": "continue"}, {"do": "continue"},
			{"do": "action", "action": _line(Vector2(5, 7), Vector2(26, 7))},
			{"do": "speed", "value": 1.0},
			{"do": "run"},
		],
	}


static func _l2() -> Dictionary:
	var lv = _blue_row_level(102, 102)
	lv["name_key"] = "TUT_L2_TITLE"
	lv["force_crash"] = true
	lv["prebuilt"] = [_line(Vector2(5, 7), Vector2(26, 7))]
	lv["factories"].append({"cell": Vector2(15, 2), "color": RED, "interval": 5.0, "start_at": 0.0})
	lv["warehouses"].append({"cell": Vector2(15, 12), "color": RED})
	lv["inventory"]["road"] = 15
	lv["allowed_tools"] = [C.Tool.ROAD, C.Tool.ERASE]
	var c = [Vector2(15, 2), Vector2(15, 12)]
	return {
		"id": "l2", "title_key": "TUT_L2_TITLE", "level": lv,
		"steps": [
			_step("l2_s1", _cont(), {"highlight_cells": c}),
			_step("l2_s2", {"event": "road_connected", "color": RED},
					{"highlight_cells": c, "highlight_ui": ["tool_road"]}),
			_step("l2_s3", {"event": "crash"}, {"highlight_ui": ["btn_speed_1"]}),
			_step("l2_s4", _cont(), {"highlight_cells": [Vector2(15, 7)], "pause_sim": true}),
			_step("l2_s5", _cont(), {"pause_sim": true}),
		],
		"solution": [
			{"do": "continue"},
			{"do": "action", "action": _line(Vector2(15, 3), Vector2(15, 11))},
			{"do": "speed", "value": 1.0},
			{"do": "run"},
			{"do": "continue"}, {"do": "continue"},
		],
	}


static func _crossing_level(id: int, c: int) -> Dictionary:
	var lv = _blue_row_level(id, c)
	lv["prebuilt"] = [_line(Vector2(5, 7), Vector2(26, 7)), _line(Vector2(15, 3), Vector2(15, 11))]
	lv["factories"] = [
		{"cell": Vector2(4, 7), "color": BLUE, "interval": 2.5, "start_at": 0.0},
		{"cell": Vector2(15, 2), "color": RED, "interval": 3.0, "start_at": 0.0},
	]
	lv["warehouses"] = [{"cell": Vector2(27, 7), "color": BLUE}, {"cell": Vector2(15, 12), "color": RED}]
	return lv


static func _l3() -> Dictionary:
	var lv = _crossing_level(103, 103)
	lv["name_key"] = "TUT_L3_TITLE"
	lv["goal"] = 6
	lv["inventory"]["light"] = 1
	lv["allowed_tools"] = [C.Tool.LIGHT]
	var jn = [Vector2(15, 7)]
	return {
		"id": "l3", "title_key": "TUT_L3_TITLE", "level": lv,
		"steps": [
			_step("l3_s1", {"event": "light_placed"}, {"highlight_cells": jn, "highlight_ui": ["tool_light"]}),
			_step("l3_s2", _cont(), {"highlight_ui": ["light_mode_timer"], "needs_panel": "light"}),
			_step("l3_s3", _cont(), {"highlight_ui": ["light_mode_sensor"], "needs_panel": "light"}),
			_step("l3_s4", _cont(), {"highlight_ui": ["light_mode_priority"], "needs_panel": "light"}),
			_step("l3_s5", {"event": "light_mode_set", "mode": C.LightMode.SENSOR},
					{"highlight_ui": ["light_mode_sensor", "light_apply"], "needs_panel": "light"}),
			_step("l3_s6", {"event": "delivered_count", "n": 6}, {"highlight_ui": ["btn_speed_1"]}),
		],
		"solution": [
			{"do": "action", "action": {"type": "light", "cell": Vector2(15, 7), "mode": C.LightMode.TIMER}},
			{"do": "continue"}, {"do": "continue"}, {"do": "continue"},
			{"do": "action", "action": {"type": "configure_light", "cell": Vector2(15, 7), "mode": C.LightMode.SENSOR}},
			{"do": "speed", "value": 1.0},
			{"do": "run"},
		],
	}


static func _l4() -> Dictionary:
	var c = []
	for y in range(C.MAP_H):
		c.append(Vector2(14, y))
		c.append(Vector2(15, y))
	var d = [
		_line(Vector2(3, 6), Vector2(3, 8)), _line(Vector2(4, 7), Vector2(8, 7)),
		_line(Vector2(8, 3), Vector2(8, 6)), _line(Vector2(8, 8), Vector2(8, 11)),
		_line(Vector2(9, 3), Vector2(13, 3)), _line(Vector2(9, 11), Vector2(13, 11)),
		_line(Vector2(16, 3), Vector2(27, 3)), _line(Vector2(16, 11), Vector2(27, 11)),
	]
	var lv = {
		"id": 104, "name_key": "TUT_L4_TITLE", "seed": 104, "time": 0, "goal": 6, "mode": "score",
		"lesson": true, "lose_enabled": false,
		"factories": [
			{"cell": Vector2(2, 6), "color": BLUE, "interval": 4.0, "start_at": 0.0},
			{"cell": Vector2(2, 8), "color": RED, "interval": 4.0, "start_at": 0.0},
		],
		"warehouses": [
			{"cell": Vector2(28, 3), "color": BLUE}, {"cell": Vector2(27, 2), "color": RED},
			{"cell": Vector2(28, 11), "color": RED}, {"cell": Vector2(27, 12), "color": BLUE},
		],
		"water": c, "obstacles": [], "roads": [], "prebuilt": d,
		"inventory": {"road": 0, "light": 0, "sorter": 1, "bridge": 4},
		"allowed_tools": [C.Tool.BRIDGE, C.Tool.SORTER],
	}
	var e = [Vector2(13, 3), Vector2(16, 3), Vector2(13, 11), Vector2(16, 11)]
	var up = [Vector2(14, 3), Vector2(15, 3)]
	var f = [Vector2(14, 11), Vector2(15, 11)]
	var g = [Vector2(8, 7)]
	return {
		"id": "l4", "title_key": "TUT_L4_TITLE", "level": lv,
		"steps": [
			_step("l4_s1", _cont(), {"highlight_cells": e}),
			_step("l4_s2", {"event": "bridge_placed", "count": 4},
					{"highlight_cells": up + f, "highlight_ui": ["tool_bridge"],
					"checklist": [
						{"key": "TUT_CK_UP", "cond": {"event": "bridge_placed", "cells": up}},
						{"key": "TUT_CK_DOWN", "cond": {"event": "bridge_placed", "cells": f}},
					]}),
			_step("l4_s3", _cont(), {"highlight_cells": g}),
			_step("l4_s4", {"event": "sorter_placed"}, {"highlight_cells": g, "highlight_ui": ["tool_sorter"]}),
			_step("l4_s5", {"event": "sorter_rule_set"}, {"highlight_ui": ["sorter_apply"], "needs_panel": "sorter"}),
			_step("l4_s6", {"event": "delivered_count", "n": 6}, {"highlight_ui": ["btn_speed_1"]}),
		],
		"solution": [
			{"do": "continue"},
			{"do": "action", "action": {"type": "bridge", "cell": Vector2(14, 3)}},
			{"do": "action", "action": {"type": "bridge", "cell": Vector2(15, 3)}},
			{"do": "action", "action": {"type": "bridge", "cell": Vector2(14, 11)}},
			{"do": "action", "action": {"type": "bridge", "cell": Vector2(15, 11)}},
			{"do": "continue"},
			{"do": "action", "action": {"type": "sorter", "cell": Vector2(8, 7),
					"rules": {BLUE: Vector2(0, -1), RED: Vector2(0, 1)}}},
			{"do": "speed", "value": 1.0},
			{"do": "run"},
		],
	}


static func _l5() -> Dictionary:
	var lv = _blue_row_level(105, 105)
	lv["name_key"] = "TUT_L5_TITLE"
	lv["prebuilt"] = [_line(Vector2(5, 7), Vector2(26, 7)), _line(Vector2(15, 6), Vector2(15, 6))]
	lv["factories"] = [{"cell": Vector2(4, 7), "color": BLUE, "interval": 3.5, "start_at": 0.0, "urgent_every": 2}]
	lv["inventory"] = {"road": 8, "light": 1, "sorter": 0, "bridge": 0}
	lv["allowed_tools"] = [C.Tool.LIGHT, C.Tool.ROAD, C.Tool.ERASE]
	return {
		"id": "l5", "title_key": "TUT_L5_TITLE", "level": lv,
		"steps": [
			_step("l5_s1", _cont(), {"on_enter": [{"hook": "spawn_urgent", "color": BLUE}]}),
			_step("l5_s2", {"event": "light_mode_set", "mode": C.LightMode.PRIORITY},
					{"highlight_cells": [Vector2(15, 7)], "highlight_ui": ["tool_light", "light_mode_priority"]}),
			_step("l5_s3", {"event": "urgent_delivered", "n": 2},
					{"highlight_ui": ["btn_speed_1"], "on_enter": [{"hook": "spawn_urgent", "color": BLUE}]}),
			_step("l5_s4", _cont()),
		],
		"solution": [
			{"do": "continue"},
			{"do": "action", "action": {"type": "light", "cell": Vector2(15, 7), "mode": C.LightMode.PRIORITY}},
			{"do": "speed", "value": 1.0},
			{"do": "run"},
			{"do": "continue"},
		],
	}


static func _l6() -> Dictionary:
	var lv = _crossing_level(106, 106)
	lv["name_key"] = "TUT_L6_TITLE"
	lv["prebuilt"].append({"type": "light", "cell": Vector2(15, 7), "mode": C.LightMode.TIMER, "period": 8.0})
	lv["inventory"] = {"road": 10, "light": 1, "sorter": 1, "bridge": 0}
	lv["allowed_tools"] = _all_tools()
	return {
		"id": "l6", "title_key": "TUT_L6_TITLE", "level": lv,
		"steps": [
			_step("l6_s1", {"event": "speed_set", "value": 4.0}, {"highlight_ui": ["btn_speed_4"]}),
			_step("l6_s2", {"event": "heatmap_toggled", "on": true}, {"highlight_ui": ["btn_heatmap"]}),
			_step("l6_s3", {"event": "heatmap_toggled", "on": false}, {"highlight_ui": ["btn_heatmap"]}),
			_step("l6_s4", {"event": "light_mode_set", "mode": C.LightMode.SENSOR},
					{"highlight_cells": [Vector2(15, 7)]}),
			_step("l6_s5", _cont()),
		],
		"solution": [
			{"do": "speed", "value": 4.0},
			{"do": "run_for", "seconds": 20.0},
			{"do": "heatmap", "on": true},
			{"do": "heatmap", "on": false},
			{"do": "action", "action": {"type": "configure_light", "cell": Vector2(15, 7), "mode": C.LightMode.SENSOR}},
			{"do": "continue"},
		],
	}


static func _final() -> Dictionary:
	var c = []
	for y in range(C.MAP_H):
		c.append(Vector2(14, y))
		c.append(Vector2(15, y))
	var lv = {
		"id": 107, "name_key": "TUT_FINAL_TITLE", "seed": 202, "time": 90, "goal": 6, "mode": "goal",
		"final_test": true,
		"factories": [
			{"cell": Vector2(3, 4), "color": BLUE, "interval": 5.0, "start_at": 0.0},
			{"cell": Vector2(3, 10), "color": RED, "interval": 5.0, "start_at": 0.0},
		],
		"warehouses": [{"cell": Vector2(28, 10), "color": BLUE}, {"cell": Vector2(28, 4), "color": RED}],
		"water": c, "obstacles": [], "roads": [], "prebuilt": [],
		"inventory": {"road": 60, "light": 1, "sorter": 1, "bridge": 2},
		"allowed_tools": _all_tools(),
	}
	return {
		"id": "final", "title_key": "TUT_FINAL_TITLE", "final": true, "level": lv,
		"steps": [
			_step("final_s1", _cont(), {"button_key": "TUT_START"}),
			_step("final_s2", {"event": "level_won"}),
		],
		"solution": [
			{"do": "continue"},
			{"do": "action", "action": _line(Vector2(4, 4), Vector2(8, 4))},
			{"do": "action", "action": _line(Vector2(8, 5), Vector2(8, 6))},
			{"do": "action", "action": _line(Vector2(4, 10), Vector2(8, 10))},
			{"do": "action", "action": _line(Vector2(8, 9), Vector2(8, 8))},
			{"do": "action", "action": {"type": "road", "cell": Vector2(8, 7)}},
			{"do": "action", "action": _line(Vector2(9, 7), Vector2(13, 7))},
			{"do": "action", "action": {"type": "bridge", "cell": Vector2(14, 7)}},
			{"do": "action", "action": {"type": "bridge", "cell": Vector2(15, 7)}},
			{"do": "action", "action": _line(Vector2(16, 7), Vector2(21, 7))},
			{"do": "action", "action": {"type": "road", "cell": Vector2(22, 7)}},
			{"do": "action", "action": _line(Vector2(22, 6), Vector2(22, 4))},
			{"do": "action", "action": _line(Vector2(23, 4), Vector2(27, 4))},
			{"do": "action", "action": _line(Vector2(22, 8), Vector2(22, 10))},
			{"do": "action", "action": _line(Vector2(23, 10), Vector2(27, 10))},
			{"do": "action", "action": {"type": "light", "cell": Vector2(8, 7), "mode": C.LightMode.SENSOR}},
			{"do": "action", "action": {"type": "sorter", "cell": Vector2(22, 7),
					"rules": {BLUE: Vector2(0, 1), RED: Vector2(0, -1)}}},
			{"do": "speed", "value": 1.0},
			{"do": "run"},
		],
	}
