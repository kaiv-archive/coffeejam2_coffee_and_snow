extends HBoxContainer

const cnv_mul = 100
@export var bus: String
@export var label_text: String

@onready var slider = $VBoxContainer/HSlider
@onready var line_edit = $LineEdit
@onready var label = $VBoxContainer/Label

func _ready() -> void:
	label.text = label_text
	var volume_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
	var linear = db_to_linear(volume_db)
	var value = linear * 100.0
	slider.value = value
	line_edit.text = str(int(value))


func _on_line_edit_text_changed(new_text: String) -> void:
	var sanitized = ""
	for c in new_text:
		if c >= "0" and c <= "9":
			sanitized += c

	if sanitized == "":
		return

	var value = float(sanitized)
	value = clamp(value, 0.0, 200.0)

	slider.value = value
	line_edit.text = str(int(value))
	set_bus_volume(value)


func _on_line_edit_text_submitted(new_text: String) -> void:
	_on_line_edit_text_changed(new_text)


func _on_h_slider_value_changed(value: float) -> void:
	var t = str(int(value))
	if value >= 100: t = str(int(value))
	line_edit.text = t
	set_bus_volume(value)

func set_bus_volume(linear_value: float) -> void:
	var db = linear_to_db(linear_value / cnv_mul)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), db)
