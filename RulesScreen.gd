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
	title_label.text = "How to Play"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", theme_data["rules_text_color"])

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(margin)

	var rules_label = Label.new()
	rules_label.text = _get_rules_text()
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.custom_minimum_size.x = 560
	rules_label.add_theme_color_override("font_color", 
		ThemeManager.get_current()["rules_text_color"])
	margin.add_child(rules_label)

	# Back button
	back_button.text = "Back"
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	AudioManager.play_menu_click()
	get_tree().change_scene_to_file(return_scene)

func _get_rules_text() -> String:
	return ThemeManager.get_rules_text()
