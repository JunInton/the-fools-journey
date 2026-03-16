extends PanelContainer

@onready var title_label   = $MarginContainer/VBoxContainer/TitleLabel
@onready var credits_label = $MarginContainer/VBoxContainer/ScrollContainer/CreditsLabel
@onready var back_button   = $MarginContainer/VBoxContainer/BackButton

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.set_screen("menu")

	var theme_data = ThemeManager.get_current()

	# Apply the theme's background color to the panel
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = theme_data["background"]
	add_theme_stylebox_override("panel", stylebox)

	title_label.text = "Credits"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", theme_data["label_color"])

	# Wrap credits label in a MarginContainer to add left/right padding
	# so text doesn't sit flush against the scroll container edges
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",  40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Reparent credits_label into the margin container
	credits_label.get_parent().remove_child(credits_label)
	var scroll = $MarginContainer/VBoxContainer/ScrollContainer
	scroll.add_child(margin)
	margin.add_child(credits_label)

	credits_label.text = _get_credits_text()
	credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_label.custom_minimum_size.x = 560
	credits_label.add_theme_color_override("font_color",
		theme_data.get("rules_text_color", Color.WHITE))

	back_button.text = "Back"
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	AudioManager.play_menu_click()
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _get_credits_text() -> String:
	return \
"""GAME DESIGN & RULES
  Desmond Meraz

DEVELOPMENT
  Jun Inton

------------------------------

CARD ARTWORK
  Rider-Waite-Smith Tarot (1909)
  Illustrated by Pamela Colman Smith
  Public Domain

MUSIC
  "Immersed", "On the Passing of Time"
  Kevin MacLeod (incompetech.com)
  Licensed under Creative Commons: By Attribution 4.0
  creativecommons.org/licenses/by/4.0

SOUND EFFECTS
  Public Domain (CC0) via Freesound.org

BACKGROUND IMAGES
  Public Domain (CC0) via Unsplash

------------------------------

ANALYTICS
  This game uses cookieless Google Analytics
  to collect anonymous gameplay statistics.
  No personal data or cookies are stored.

------------------------------

Built with Godot Engine 4
godotengine.org"""
