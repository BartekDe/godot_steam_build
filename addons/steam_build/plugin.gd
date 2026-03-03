@tool
extends EditorPlugin

var panel: Control


func _enter_tree() -> void:
	panel = load("res://addons/steam_build/steam_build_panel.gd").new()
	add_control_to_bottom_panel(panel, "Steam Publisher")


func _exit_tree() -> void:
	remove_control_from_bottom_panel(panel)
	panel.queue_free()
