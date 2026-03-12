extends PanelContainer

@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var scroll_container = $MarginContainer/VBoxContainer/ScrollContainer
@onready var rules_label = $MarginContainer/VBoxContainer/ScrollContainer/RulesLabel
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

var return_scene: String = "res://MainMenu.tscn"

func _ready():
	# Ensure the root fills the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	AudioManager.set_screen("menu")
	return_scene = ThemeManager.rules_return_scene

	var theme_data = ThemeManager.get_current()

	# Apply background
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = theme_data["background"]
	add_theme_stylebox_override("panel", stylebox)

	# Title
	title_label.text = "The Fool's Journey — Rules"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", theme_data["label_color"])

	# Rules text
	rules_label.text = _get_rules_text()
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.custom_minimum_size.x = 600

	# Back button
	back_button.text = "← Back"
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	AudioManager.play_menu_click()
	get_tree().change_scene_to_file(return_scene)

func _get_rules_text() -> String:
	return ThemeManager.get_rules_text()
