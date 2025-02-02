@tool
extends EditorPlugin
class_name Elementum

var panel

func _enter_tree():
	panel = preload("res://addons/Elementum/Panel.tscn").instantiate()
	add_control_to_bottom_panel(panel, "Elementum")
	panel.hide()
	E_ElementManger.new().on()

func _exit_tree():
	E_ElementManger.new().off()
	remove_control_from_bottom_panel(panel)
