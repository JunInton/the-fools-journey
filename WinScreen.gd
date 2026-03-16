extends Control

@onready var title_label    = $CenterContainer/VBoxContainer/TitleLabel
@onready var stats_label    = $CenterContainer/VBoxContainer/StatsLabel
@onready var play_again_btn = $CenterContainer/VBoxContainer/PlayAgainBtn

# ------------------------------------
# WIN TEXT
# Theme-specific copy for the win screen.
# Keyed by theme constant so the correct text is selected in _ready().
# ------------------------------------
const WIN_TEXT = {
	ThemeManager.THEME_RWS: {
		"title":        "The Fool Completes His Journey!",
		"title_color":  Color(0.9, 0.85, 0.6),
		"stats_color":  Color(0.7, 0.9, 0.7),
		"button":       "Journey Again",
		"stats_suffix": " vitality remaining."
	},
	ThemeManager.THEME_PERSONA3: {
		"title":        "The Journey of the Fool is Complete.",
		"title_color":  Color8(255, 197, 74),
		"stats_color":  Color8(121, 215, 253),
		"button":       "Face destiny again",
		"stats_suffix": " resolve remaining.\n\"The power of the Wild Card is yours.\""
	},
	ThemeManager.THEME_PERSONA5: {
		"title":        "Thou hast stolen the heart of fate itself.",
		"title_color":  Color8(242, 232, 82),
		"stats_color":  Color8(217, 35, 35),
		"button":       "Take another target",
		"stats_suffix": " resolve remaining.\n\"The Phantom Thieves never lose.\""
	}
}

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.set_screen("win")

	var text = WIN_TEXT[ThemeManager.current_theme]

	ThemeManager.apply_screen_background(
		self, "win",
		Color.BLACK, Color.BLACK,
		Color.BLACK)

	title_label.text = text["title"]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.add_theme_color_override("font_color", text["title_color"])

	stats_label.text = "The Fool survived with " + str(GameState.vitality) + text["stats_suffix"]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 20)
	stats_label.add_theme_color_override("font_color", text["stats_color"])

	_add_final_card_display(GameState.last_resolved_challenge, "Final Challenge Overcome:", text["title_color"])

	play_again_btn.text = text["button"]
	play_again_btn.pressed.connect(_on_play_again_pressed)
	$CenterContainer/VBoxContainer.add_theme_constant_override("separation", 24)

func _add_final_card_display(challenge, label_text: String, accent_color: Color):
	if challenge == null:
		return

	var vbox = $CenterContainer/VBoxContainer

	var section_label = Label.new()
	section_label.text = label_text
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_label.add_theme_font_size_override("font_size", 16)
	section_label.add_theme_color_override("font_color", accent_color)
	vbox.add_child(section_label)
	vbox.move_child(section_label, play_again_btn.get_index())

	# RWS card images include the card name printed on the image itself,
	# so a separate name label is only needed for other themes
	if ThemeManager.current_theme != ThemeManager.THEME_RWS:
		var card_label = Label.new()
		card_label.text = challenge.get("name", "Unknown")
		card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_label.add_theme_font_size_override("font_size", 18)
		card_label.add_theme_color_override("font_color", Color.WHITE)
		vbox.add_child(card_label)
		vbox.move_child(card_label, play_again_btn.get_index())

	var image_path = CardData.get_card_image_path(challenge)
	if image_path != "":
		var texture = load(image_path)
		if texture != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = texture
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(120, 200)
			tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vbox.add_child(tex_rect)
			vbox.move_child(tex_rect, play_again_btn.get_index())

func _on_play_again_pressed():
	AudioManager.play_menu_click()
	get_tree().change_scene_to_file("res://MainMenu.tscn")
