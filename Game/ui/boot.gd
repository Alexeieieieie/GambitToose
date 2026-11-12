extends Node



func _ready() -> void:
	call_deferred("_go")


func _go() -> void:
	if SaveData.is_first_run():
		get_tree().change_scene("res://tutorial/welcome_screen.tscn")
	else:
		get_tree().change_scene("res://ui/main_menu.tscn")
