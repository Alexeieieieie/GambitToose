extends Reference

var deliveries = 0
var urgent_deliveries = 0
var time_left = 0.0
var roads_used = 0
var min_patience_ratio = 1.0
var total_delivery_time = 0.0
var jam_seconds = 0.0
var jam_cells = {}
var jam_cell_order = []


func avg_delivery_time() -> float:
	if deliveries == 0:
		return 0.0
	return total_delivery_time / deliveries


func score() -> int:
	return deliveries * 100 - int(avg_delivery_time() * 2) - int(jam_seconds * 10)


func add_jam_cell(a: Vector2, dt: float) -> void:
	if not jam_cells.has(a):
		jam_cells[a] = 0.0
		jam_cell_order.append(a)
	jam_cells[a] += dt


func worst_jam_cell():
	var a = null
	var b = 0.0
	for c in jam_cell_order:
		if jam_cells[c] > b:
			b = jam_cells[c]
			a = c
	return a
