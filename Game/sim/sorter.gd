extends Reference

# A sorter filter. It only changes the pathfinding graph (see pathing.gd).

const C = preload("res://sim/constants.gd")

var is_sorter = true
var cell = Vector2()
# Cargo color -> direction. Vector2(0, 0) means "any direction".
var rules = {
	C.CargoColor.BLUE: Vector2(),
	C.CargoColor.RED: Vector2(),
	C.CargoColor.URGENT: Vector2(),
}


func allows(_v, _from: Vector2) -> bool:
	return true
