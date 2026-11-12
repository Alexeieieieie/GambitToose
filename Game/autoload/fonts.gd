extends Node


const REGULAR_PATH = "res://fonts/Nunito-Regular.ttf"
const BOLD_PATH = "res://fonts/Nunito-Bold.ttf"

var _data_regular
var _data_bold
var _cache = {}


func _ready() -> void:
	_data_regular = load(REGULAR_PATH)
	_data_bold = load(BOLD_PATH)


func make(a: int, b: bool = false) -> DynamicFont:
	var c = a * 2 + (1 if b else 0)
	if _cache.has(c):
		return _cache[c]
	if _data_regular == null:
		_ready()
	var f = DynamicFont.new()
	f.font_data = _data_bold if b else _data_regular
	f.size = a
	f.use_filter = true
	_cache[c] = f
	return f
