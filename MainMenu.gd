extends Control

@onready var title_label    = $CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label = $CenterContainer/VBoxContainer/SubtitleLabel
@onready var start_button   = $CenterContainer/VBoxContainer/StartButton
@onready var rules_button   = $CenterContainer/VBoxContainer/RulesButton
@onready var credits_button = $CenterContainer/VBoxContainer/CreditsButton

# ------------------------------------
# SECRET CODE
# A buffer tracks the last N keypresses and is checked against
# the target sequence after every keypress — like tracking input
# history in JS with a sliding window array.
# ------------------------------------
const SECRET_CODE = [
	KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN,
	KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT,
	KEY_B, KEY_A
]
var input_buffer: Array = []

# Holds the Fool card image TextureRect so _apply_theme() can update it
# when the theme changes without rebuilding the whole panel
var _fool_tex_rect: TextureRect = null

func _ready():
	# Fill the entire viewport — without this, Control has no inherent size
	# and background nodes have nothing to fill regardless of their own sizing
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	AudioManager.set_screen("menu")
	_apply_theme()

	start_button.pressed.connect(_on_start_pressed)
	rules_button.text = "Rules"
	rules_button.pressed.connect(_on_rules_pressed)
	credits_button.text = "Credits"
	credits_button.pressed.connect(_on_credits_pressed)

	ThemeManager.theme_changed.connect(_on_theme_changed)

	_setup_audio_controls()
	_setup_fool_card()

func _setup_audio_controls():
	# Audio toggle buttons pinned to the top-left corner of the screen
	var audio_controls = HBoxContainer.new()
	audio_controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	audio_controls.position = Vector2(8, 8)
	audio_controls.add_theme_constant_override("separation", 4)
	add_child(audio_controls)

	var music_btn = Button.new()
	music_btn.text = "Music ON" if AudioManager.music_enabled else "Music OFF"
	music_btn.custom_minimum_size = Vector2(32, 32)
	music_btn.pressed.connect(func():
		AudioManager.toggle_music()
		music_btn.text = "Music ON" if AudioManager.music_enabled else "Music OFF")
	audio_controls.add_child(music_btn)

	var sfx_btn = Button.new()
	sfx_btn.text = "SFX ON" if AudioManager.sfx_enabled else "SFX OFF"
	sfx_btn.custom_minimum_size = Vector2(32, 32)
	sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx()
		sfx_btn.text = "SFX ON" if AudioManager.sfx_enabled else "SFX OFF")
	audio_controls.add_child(sfx_btn)

func _setup_fool_card():
	# Decorative Fool card image displayed on the left side of the menu.
	# Lives on its own panel at z_index -1 so it sits behind the buttons.
	var fool_panel = Control.new()
	fool_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fool_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fool_panel.z_index = -1
	add_child(fool_panel)

	_fool_tex_rect = TextureRect.new()
	_fool_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fool_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fool_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fool_tex_rect.offset_left   =  100
	_fool_tex_rect.offset_right  = -1000
	_fool_tex_rect.offset_top    =  100
	_fool_tex_rect.offset_bottom = -100
	# Slight transparency so the image reads as decorative rather than functional
	_fool_tex_rect.modulate = Color(1, 1, 1, 0.85)
	fool_panel.add_child(_fool_tex_rect)

	_update_fool_image()

func _update_fool_image():
	if _fool_tex_rect == null:
		return
	var fool_data = CardData.all_cards[0]
	var path = CardData.get_card_image_path(fool_data)
	if path != "":
		var texture = load(path)
		if texture != null:
			_fool_tex_rect.texture = texture

func _apply_theme():
	# Remove any existing background node before re-applying so theme
	# cycling doesn't stack multiple background nodes on top of each other
	for child in get_children():
		if child.z_index == -1 and (child is TextureRect or child is ColorRect):
			child.queue_free()

	# Use theme_data rather than 'theme' to avoid shadowing Control's
	# built-in 'theme' property
	var theme_data = ThemeManager.get_current()

	title_label.text = theme_data["name"]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", theme_data["label_color"])

	subtitle_label.text = theme_data["subtitle"]
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.9))

	start_button.text = "Begin the Journey"
	$CenterContainer/VBoxContainer.add_theme_constant_override("separation", 24)

	# Shift the CenterContainer right to leave visual space for the Fool card
	$CenterContainer.offset_left = 300

	# Apply background — each theme uses a different approach:
	# RWS loads a background image if one exists at the configured path,
	# others fall back to a vertical gradient defined here
	match ThemeManager.current_theme:
		ThemeManager.THEME_RWS:
			ThemeManager.apply_screen_background(
				self, "menu",
				Color.BLACK, Color.BLACK,
				theme_data["background"])
		ThemeManager.THEME_PERSONA3:
			ThemeManager.apply_screen_background(
				self, "menu",
				Color8(0, 10, 40),
				Color8(0, 0, 0),
				theme_data["background"])
		ThemeManager.THEME_PERSONA5:
			ThemeManager.apply_screen_background(
				self, "menu",
				Color8(40, 0, 0),
				Color8(0, 0, 0),
				theme_data["background"])

	_update_fool_image()

func _on_theme_changed(_new_theme: String):
	_apply_theme()

func _on_start_pressed():
	AudioManager.play_menu_click()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_rules_pressed():
	AudioManager.play_menu_click()
	ThemeManager.rules_return_scene = "res://MainMenu.tscn"
	get_tree().change_scene_to_file("res://RulesScreen.tscn")

func _on_credits_pressed():
	AudioManager.play_menu_click()
	get_tree().change_scene_to_file("res://CreditsScreen.tscn")

# ------------------------------------
# SECRET CODE INPUT
# _input fires for every input event. We only care about key presses,
# not releases or echoes (repeated events from holding a key).
# The buffer acts like a sliding window — only the last N keypresses
# are kept, like using JS .slice(-N) on an array.
# ------------------------------------
func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		input_buffer.append(event.keycode)
		# Trim to the length of the target sequence
		# pop_front() removes the oldest entry — like JS .shift()
		if input_buffer.size() > SECRET_CODE.size():
			input_buffer.pop_front()
		if input_buffer == SECRET_CODE:
			input_buffer.clear()
			_on_secret_activated()

func _on_secret_activated():
	ThemeManager.cycle_theme()
	AudioManager.play_sfx("ping")
	# Track theme switches in analytics to see how many players find the secret
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"typeof gtag !== 'undefined' && gtag('event', 'theme_switched', {'new_theme': '"
			+ ThemeManager.current_theme + "'})")
	# Flash the subtitle as visual confirmation the code was accepted
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	await get_tree().create_timer(0.3).timeout
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.9))
	await get_tree().create_timer(0.3).timeout
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	await get_tree().create_timer(0.3).timeout
	_apply_theme()
