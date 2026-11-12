extends Node


var _nodes = {}


func register(a: String, b: Control) -> void:
	_nodes[a] = b


func get_rect(a: String) -> Rect2:
	var b = _nodes.get(a)
	if b == null or not is_instance_valid(b) or not b.is_inside_tree():
		return Rect2()
	if not b.is_visible_in_tree():
		return Rect2()
	return b.get_global_rect()


func is_shown(a: String) -> bool:
	return get_rect(a).size.x > 0.0
