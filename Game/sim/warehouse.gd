extends Reference

const C = preload("res://sim/constants.gd")

var cell = Vector2()
var color = 0
var patience = C.WAREHOUSE_PATIENCE_MAX
var received = 0
var low_flags = {}               # threshold percent -> already announced (observation only)


func ratio() -> float:
	return patience / C.WAREHOUSE_PATIENCE_MAX


func drain(dt: float) -> void:
	patience = max(patience - dt, 0.0)


func deliver() -> void:
	received += 1
	patience = min(patience + C.WAREHOUSE_PATIENCE_GAIN, C.WAREHOUSE_PATIENCE_MAX)
