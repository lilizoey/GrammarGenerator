extends MenuButton


signal save_pressed
signal save_as_pressed
signal load_pressed

func _ready():
	var popup := get_popup()
	popup.connect("id_pressed", self, "on_popup_id_pressed")

func on_popup_id_pressed(id: int):
	match id:
		0:
			emit_signal("save_pressed")
		1:
			emit_signal("save_as_pressed")
		2:
			emit_signal("load_pressed")
