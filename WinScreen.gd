extends Control

@onready var title_label = $CenterContainer/VBoxContainer/TitleLabel
@onready var stats_label = $CenterContainer/VBoxContainer/StatsLabel
@onready var play_again_btn = $CenterContainer/VBoxContainer/PlayAgainBtn

# Win screen text varies by theme
const WIN_TEXT = {
	ThemeManager.THEME_RWS: {
		"title": "The Fool Completes His Journey!",
		"title_color": Color(0.9, 0.85, 0.6),
		"stats_color": Color(0.7, 0.9, 0.7),
		"button": "Journey Again",
		"stats_suffix": " vitality remaining."
	},
	ThemeManager.THEME_PERSONA3: {
		"title": "The Journey of the Fool is Complete.",
		"title_color": Color8(255, 197, 74),
		"stats_color": Color8(121, 215, 253),
		"button": "Face destiny again",
		"stats_suffix": " resolve remaining.\n\"The power of the Wild Card is yours.\""
	},
	ThemeManager.THEME_PERSONA5: {
		"title": "Thou hast stolen the heart of fate itself.",
		"title_color": Color8(242, 232, 82),
		"stats_color": Color8(217, 35, 35),
		"button": "Take another target",
		"stats_suffix": " resolve remaining.\n\"The Phantom Thieves never lose.\""
	}
}

func _ready():
	AudioManager.set_screen("win")
	var text = WIN_TEXT[ThemeManager.current_theme]
	
	title_label.text = text["title"]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.add_theme_color_override("font_color", text["title_color"])

	# Show final vitality as the player's score
	# GameState persists through scene changes so we can read it here
	stats_label.text = "The Fool survived with " + str(GameState.vitality) + text["stats_suffix"]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 20)
	stats_label.add_theme_color_override("font_color", text["stats_color"])

	play_again_btn.text = "Journey Again"
	play_again_btn.pressed.connect(_on_play_again_pressed)

	$CenterContainer/VBoxContainer.add_theme_constant_override("separation", 24)
	
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = ThemeManager.get_current()["background"]
	add_theme_stylebox_override("panel", stylebox)

func _on_play_again_pressed():
	# Return to main menu rather than restarting directly
	# This lets the player trigger the Konami code theme switch
	# before starting a new run, and is cleaner UX overall
	AudioManager.play_menu_click()
	get_tree().change_scene_to_file("res://MainMenu.tscn")
