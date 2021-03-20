extends Panel

onready var save_dialog := $SaveDialog
onready var load_dialog := $LoadDialog
onready var generator_gui := $VBoxContainer/MarginContainer/GeneratorGUI

var last_file_path := ""

func _input(_event):
	if Input.is_action_just_pressed("save"):
		_on_save_pressed()
	if Input.is_action_just_pressed("save_as"):
		_on_save_as_pressed()
	if Input.is_action_just_pressed("load"):
		_on_load_pressed()

func _on_save_pressed():
	if not last_file_path:
		_on_save_as_pressed()
	else:
		save_file(last_file_path)

func _on_save_as_pressed():
	save_dialog.popup_centered_ratio(0.75)

func _on_load_pressed():
	load_dialog.popup_centered_ratio(0.75)

func save_file(file_path: String):
	generator_gui.save_file(file_path)

func load_file(file_path: String):
	generator_gui.load_file(file_path)

func _on_SaveDialog_file_selected(path):
	last_file_path = path
	save_file(path)


func _on_LoadDialog_file_selected(path):
	last_file_path = path
	load_file(path)
