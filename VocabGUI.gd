extends Panel

const autosave_path := "user://autosave.grammar"

onready var output := $VSplitContainer/Output
onready var rule_input  := $VSplitContainer/HSplitContainer/RuleInput
onready var start_input := $VSplitContainer/HSplitContainer/VBoxContainer/StartInput
onready var words := $VSplitContainer/HSplitContainer/VBoxContainer/VBoxContainer/HBoxContainer/SpinBox

signal save_pressed
signal save_as_pressed
signal load_pressed

func _ready():
	load_file(autosave_path)

func create_generator() -> AST.VocabGenerator:
	var generator := AST.VocabGenerator.new(rule_input.text)
	return generator

func generate():
	autosave()
	var generator := create_generator()
	var output_string = ""
	for i in range(int(words.value)):
		output_string += generator.apply(start_input.text, 1000, 1000) + " "
	output.text = output_string

func autosave():
	save_file(autosave_path)

func save_file(file_path: String = "user://grammar.grammar"):
	var file := File.new()
	file.open(file_path, File.WRITE)
	var data = {
		"rules": rule_input.text,
		"start": start_input.text
	}
	file.store_line(to_json(data))
	file.close()

func load_file(file_path: String = "user://grammar.grammar"):
	var file := File.new()
	if not file.file_exists(file_path):
		return
	
	file.open(file_path, File.READ)
	var data = parse_json(file.get_line())
	if not data is Dictionary:
		return
	var dic_data: Dictionary = data
	if not (dic_data.has("rules") and dic_data.has("start")):
		return
	
	rule_input.text = dic_data["rules"]
	start_input.text = dic_data["start"]
	file.close()

func _on_save_pressed():
	emit_signal("save_pressed")

func _on_save_as_pressed():
	emit_signal("save_as_pressed")

func _on_load_pressed():
	emit_signal("load_pressed")
