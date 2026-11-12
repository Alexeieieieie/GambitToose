extends Reference

var deliveries = 0
var urgent_deliveries = 0
var time_left = 0.0
var roads_used = 0
var min_patience_ratio = 1.0     # the lowest patience ratio any active warehouse reached
var total_delivery_time = 0.0
var jam_seconds = 0.0
var jam_cells = {}               # Vector2 -> seconds a jammed vehicle stood there
var jam_cell_order = []          # keys of jam_cells in first-seen order


func avg_delivery_time() -> float:
	if deliveries == 0:
		return 0.0
	return total_delivery_time / deliveries


func score() -> int:
	return deliveries * 100 - int(avg_delivery_time() * 2) - int(jam_seconds * 10)


func add_jam_cell(cell: Vector2, dt: float) -> void:
	if not jam_cells.has(cell):
		jam_cells[cell] = 0.0
		jam_cell_order.append(cell)
	jam_cells[cell] += dt


func worst_jam_cell():
	var best = null
	var best_t = 0.0
	for cell in jam_cell_order:
		if jam_cells[cell] > best_t:
			best_t = jam_cells[cell]
			best = cell
	return best
