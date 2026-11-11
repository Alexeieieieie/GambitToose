extends Node

# Name -> Control lookup, so the tutorial can highlight a button without knowing the layout.

var _nodes = {}


func register(key: String, node: Control) -> void:
	_nodes[key] = node


func get_rect(key: String) -> Rect2:
	# An empty rectangle means: not on screen right now.
	var node = _nodes.get(key)
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return Rect2()
	if not node.is_visible_in_tree():
		return Rect2()
	return node.get_global_rect()


func is_shown(key: String) -> bool:
	return get_rect(key).size.x > 0.0
