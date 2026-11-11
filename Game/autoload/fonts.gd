extends Node

# Builds DynamicFont objects in code from the bundled Nunito files.

const REGULAR_PATH = "res://fonts/Nunito-Regular.ttf"
const BOLD_PATH = "res://fonts/Nunito-Bold.ttf"

var _data_regular
var _data_bold
var _cache = {}


func _ready() -> void:
	_data_regular = load(REGULAR_PATH)
	_data_bold = load(BOLD_PATH)


func make(size: int, bold: bool = false) -> DynamicFont:
	var key = size * 2 + (1 if bold else 0)
	if _cache.has(key):
		return _cache[key]
	if _data_regular == null:
		_ready()
	var f = DynamicFont.new()
	f.font_data = _data_bold if bold else _data_regular
	f.size = size
	f.use_filter = true
	_cache[key] = f
	return f
