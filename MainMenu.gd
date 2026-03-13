extends Control

@onready var title_label = $CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label = $CenterContainer/VBoxContainer/SubtitleLabel
@onready var start_button = $CenterContainer/VBoxContainer/StartButton
@onready var rules_button = $CenterContainer/VBoxContainer/RulesButton

# ------------------------------------
# SECRET CODE
# We keep a buffer of the last N keypresses and check if they
# match the sequence. This is like tracking input history in JS.
# ------------------------------------
const SECRET_CODE = [
	KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN,
	KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT,
	KEY_B, KEY_A
]
# Stores the player's recent keypresses - like a sliding window
var input_buffer: Array = []

func _ready():
	AudioManager.set_screen("menu")
	_apply_theme()
	start_button.pressed.connect(_on_start_pressed)

	# Listen for theme changes in case player switches mid-menu
	# (unlikely but keeps the menu reactive)
	ThemeManager.theme_changed.connect(_on_theme_changed)
	
	# Audio toggle buttons on the menu screen
	var audio_controls = HBoxContainer.new()
	audio_controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# Offset slightly from the corner so it's not right on the edge
	audio_controls.position = Vector2(8, 8)
	audio_controls.add_theme_constant_override("separation", 4)
	add_child(audio_controls)

	var music_btn = Button.new()
	# 🔊 = music on, 🔇 = music off
	music_btn.text = "Music ON"
	music_btn.toggle_mode = true
	music_btn.button_pressed = AudioManager.music_enabled
	music_btn.custom_minimum_size = Vector2(32, 32)
	music_btn.pressed.connect(func():
		AudioManager.toggle_music()
		music_btn.text = "Music ON" if AudioManager.music_enabled else "Music OFF")
	audio_controls.add_child(music_btn)

	var sfx_btn = Button.new()
	# 🔔 = sfx on, 🔕 = sfx off
	sfx_btn.text = "SFX ON"
	sfx_btn.toggle_mode = true
	sfx_btn.button_pressed = AudioManager.sfx_enabled
	sfx_btn.custom_minimum_size = Vector2(32, 32)
	sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx()
		sfx_btn.text = "SFX ON" if AudioManager.sfx_enabled else "SFX OFF")
	audio_controls.add_child(sfx_btn)
	
	rules_button.text = "Rules"
	rules_button.pressed.connect(_on_rules_pressed)

func _on_rules_pressed():
	AudioManager.play_menu_click()
	ThemeManager.rules_return_scene = "res://MainMenu.tscn"
	get_tree().change_scene_to_file("res://RulesScreen.tscn")

func _apply_theme():
	# Renamed from 'theme' to 'theme_data' to avoid shadowing
	# Control's built-in 'theme' property
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

	# Apply background color from theme
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = theme_data["background"]
	add_theme_stylebox_override("panel", stylebox)

func _on_theme_changed(_new_theme: String):
	# Re-apply visuals when theme switches
	_apply_theme()

func _on_start_pressed():
	AudioManager.play_menu_click()
	get_tree().change_scene_to_file("res://main.tscn")

# ------------------------------------
# SECRET CODE INPUT HANDLER
# _input fires for every input event in the game
# We only care about key presses, not releases
# ------------------------------------
func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		# Add this keycode to the buffer
		input_buffer.append(event.keycode)

		# Keep the buffer trimmed to the length of the code
		# Like a sliding window - we only need the last N presses
		# This prevents the buffer growing forever
		if input_buffer.size() > SECRET_CODE.size():
			input_buffer.pop_front()  # remove oldest entry, like JS shift()

		# Check if the buffer matches the Secret code exactly
		if input_buffer == SECRET_CODE:
			input_buffer.clear()
			_on_secret_activated()

func _on_secret_activated():
	ThemeManager.cycle_theme()
	# Visual and audio feedback so the player knows it worked
	AudioManager.play_sfx("ping")
	print("Secret code activated! Theme: ", ThemeManager.current_theme)
	# Flash the subtitle as confirmation
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	await get_tree().create_timer(0.3).timeout
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.9))
	await get_tree().create_timer(0.3).timeout
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	await get_tree().create_timer(0.3).timeout
	_apply_theme()
