extends Reference


const C = preload("res://sim/constants.gd")

var is_sorter = true
var cell = Vector2()
var rules = {
	C.CargoColor.BLUE: Vector2(),
	C.CargoColor.RED: Vector2(),
	C.CargoColor.URGENT: Vector2(),
}


func allows(_v, a: Vector2) -> bool:
	return true
