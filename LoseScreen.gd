extends Control

@onready var title_label = $CenterContainer/VBoxContainer/TitleLabel
@onready var stats_label = $CenterContainer/VBoxContainer/StatsLabel
@onready var play_again_btn = $CenterContainer/VBoxContainer/PlayAgainBtn

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

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = ThemeManager.get_current()["background"]
	add_theme_stylebox_override("panel", stylebox)

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

	# ← NEW: show the challenge that ended the run
	_add_fatal_card_display(text["title_color"])

	play_again_btn.text = text["button"]
	play_again_btn.pressed.connect(_on_play_again_pressed)
	$CenterContainer/VBoxContainer.add_theme_constant_override("separation", 24)

func _add_fatal_card_display(accent_color: Color):
	# Prefer the fatal challenge (caused direct damage) over last resolved
	var challenge = GameState.last_fatal_challenge
	if challenge == null:
		challenge = GameState.last_resolved_challenge
	if challenge == null:
		return

	var vbox = $CenterContainer/VBoxContainer

	var section_label = Label.new()
	section_label.text = "Defeated by:"
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_label.add_theme_font_size_override("font_size", 16)
	section_label.add_theme_color_override("font_color", accent_color)
	vbox.add_child(section_label)
	vbox.move_child(section_label, play_again_btn.get_index())

	# ← CHANGED: only show card name text for themes where cards
	# don't display their own name on the image (e.g. Persona 3)
	# RWS cards already have the name printed on the card image itself
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
