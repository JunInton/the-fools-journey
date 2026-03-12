extends Control

@onready var title_label = $CenterContainer/VBoxContainer/TitleLabel
@onready var stats_label = $CenterContainer/VBoxContainer/StatsLabel
@onready var play_again_btn = $CenterContainer/VBoxContainer/PlayAgainBtn

# Lose screen text varies by theme
const LOSE_TEXT = {
	ThemeManager.THEME_RWS: {
		"title": "The Fool's Journey Ends Here",
		"title_color": Color(0.9, 0.3, 0.3),
		"stats_color": Color(0.8, 0.6, 0.6),
		"button": "Try Again",
		"flavor": "Perhaps the next journey will fare better."
	},
	ThemeManager.THEME_PERSONA3: {
		"title": "You could not overcome the Dark Hour.",
		"title_color": Color8(0, 187, 250),
		"stats_color": Color8(121, 215, 253),
		"button": "Return to the Dark Hour",
		"flavor": "\"Memento Mori. Remember, you will die.\""
	},
	ThemeManager.THEME_PERSONA5: {
		"title": "Game Over\nThe Metaverse has claimed you.",
		"title_color": Color8(217, 35, 35),
		"stats_color": Color8(140, 103, 35),
		"button": "Back to the hideout",
		"flavor": "\"A true Phantom Thief never gives up.\""
	}
}

func _ready():
	AudioManager.set_screen("lose")
	var text = LOSE_TEXT[ThemeManager.current_theme]

	# Show which challenge drained the last vitality
	# by counting how many challenges were left unresolved
	var challenges_remaining = 0
	for card in GameState.adventure_field:
		if card.role == CardData.ROLE_CHALLENGE:
			challenges_remaining += 1
	for card in GameState.deck:
		if card.role == CardData.ROLE_CHALLENGE:
			challenges_remaining += 1

	title_label.text = text["title"]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.add_theme_color_override("font_color", text["title_color"])

	stats_label.text = (
		str(challenges_remaining) + " challenges left unresolved.\n"
		+ text["flavor"]
	)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", text["stats_color"])

	play_again_btn.text = text["button"]
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
