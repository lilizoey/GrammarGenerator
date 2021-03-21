extends Panel

const autosave_path := "user://autosave.grammar"

onready var output := $VSplitContainer/Output
onready var rule_input  := $VSplitContainer/HSplitContainer/RuleInput
onready var start_input := $VSplitContainer/HSplitContainer/VBoxContainer/StartInput
onready var words := $VSplitContainer/HSplitContainer/VBoxContainer/VBoxContainer/HBoxContainer/SpinBox

signal save_pressed
signal save_as_pressed
signal load_pressed

export var font_size := 16
export var font_size_increments := 4

func _ready():
	load_file(autosave_path)

func create_ast() -> AST.Statement:
	var parser := ASTParser.Statement.get_parser().parse(rule_input.text)
	return AST.Statement.create_statement(parser.get_result())

var ast: AST.Statement
var output_string := ""
var step_initialized := false

func generate():
	autosave()
	step_initialized = false
	ast = create_ast()
	if not ast:
		output.text = "{{ERROR}}"
		return
	if ast is AST.EmptyStatement:
		output.text = "{{EMPTY}}"
		return
		
	output_string = ""
	for i in range(int(words.value)):
		output_string += ast.evaluate_all(start_input.text, 1000, 1000) + " "
	output.text = output_string

func step():
	autosave()
	if not step_initialized:
		step_initialized = true
		ast = create_ast()
		for i in range(int(words.value)):
			output_string += start_input.text + " "
		output.text = output_string
		return
	
	output_string = ast.evaluate_all(output_string, 1, 1)
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

func set_font_size(size: int):
	var font = rule_input.get_font("font")
	font.size = size

func font_size_increase():
	font_size += font_size_increments
	font_size = int(clamp(font_size, 4, 120))
	set_font_size(font_size)

func font_size_decrease():
	font_size -= font_size_increments
	font_size = int(clamp(font_size, 0, 120))
	set_font_size(font_size)
