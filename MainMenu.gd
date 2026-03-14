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
	# Makes the root Control fill the entire viewport
	# Without this, Control has no inherent size and background nodes
	# have nothing to fill regardless of their own sizing settings
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
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
	music_btn.text = "Music ON" if AudioManager.music_enabled else "Music OFF"
	#music_btn.toggle_mode = true
	#music_btn.button_pressed = AudioManager.music_enabled
	music_btn.custom_minimum_size = Vector2(32, 32)
	music_btn.pressed.connect(func():
		AudioManager.toggle_music()
		music_btn.text = "Music ON" if AudioManager.music_enabled else "Music OFF")
	audio_controls.add_child(music_btn)

	var sfx_btn = Button.new()
	# 🔔 = sfx on, 🔕 = sfx off
	sfx_btn.text = "SFX ON" if AudioManager.sfx_enabled else "SFX OFF"
	#sfx_btn.toggle_mode = true
	sfx_btn.button_pressed = AudioManager.sfx_enabled
	sfx_btn.custom_minimum_size = Vector2(32, 32)
	sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx()
		sfx_btn.text = "SFX ON" if AudioManager.sfx_enabled else "SFX OFF")
	audio_controls.add_child(sfx_btn)
	
	rules_button.text = "Rules"
	rules_button.pressed.connect(_on_rules_pressed)
	
	_setup_fool_card()

# Holds reference to fool card display so _apply_theme can update it
var _fool_tex_rect: TextureRect = null

func _setup_fool_card():
	# NEW: creates a full-height panel on the left side of the screen
	# showing The Fool card image for the current theme.
	# Uses anchor presets so it stays positioned correctly at any resolution.
	var fool_panel = Control.new()
	fool_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fool_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fool_panel)
	# Move behind the CenterContainer so it doesn't block buttons
	fool_panel.z_index = -1

	_fool_tex_rect = TextureRect.new()
	_fool_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fool_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Position on the left third of the screen
	# CHANGED: constrain to a smaller area on the left side
	# adjust these four values to taste
	_fool_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fool_tex_rect.offset_left = 100       # distance from left edge
	_fool_tex_rect.offset_right = -1000   # how far left the right boundary sits
	_fool_tex_rect.offset_top = 100       # distance from top
	_fool_tex_rect.offset_bottom = -100   # distance from bottom
	_fool_tex_rect.modulate = Color(1, 1, 1, 0.85)  # slight transparency so it feels decorative
	fool_panel.add_child(_fool_tex_rect)

	_update_fool_image()

func _update_fool_image():
	if _fool_tex_rect == null:
		return
	# The Fool is always index 0 in CardData.all_cards
	var fool_data = CardData.all_cards[0]
	var path = CardData.get_card_image_path(fool_data)
	if path != "":
		var texture = load(path)
		if texture != null:
			_fool_tex_rect.texture = texture

func _on_rules_pressed():
	AudioManager.play_menu_click()
	ThemeManager.rules_return_scene = "res://MainMenu.tscn"
	get_tree().change_scene_to_file("res://RulesScreen.tscn")

func _apply_theme():
	# Remove any existing background node before re-applying
	# so theme cycling doesn't stack multiple backgrounds
	for child in get_children():
		if child.z_index == -1 and (child is TextureRect or child is ColorRect):
			child.queue_free()
	
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
	
	# NEW: shift the CenterContainer to the right to leave room for the Fool card
	# offset_left pushes the left edge right, giving the card visual space on the left
	$CenterContainer.offset_left = 300

	# Apply background color from theme
	# CHANGED: use shared background helper instead of flat stylebox
	# RWS: loads image from backgrounds.menu path when file exists
	# Persona 3: dark navy to black gradient
	# Persona 5: dark red to black gradient
	match ThemeManager.current_theme:
		ThemeManager.THEME_RWS:
			ThemeManager.apply_screen_background(
				self, "menu",
				Color.BLACK, Color.BLACK,  # gradient unused if image loads
				theme_data["background"])
		ThemeManager.THEME_PERSONA3:
			ThemeManager.apply_screen_background(
				self, "menu",
				Color8(0, 10, 40),    # dark navy top
				Color8(0, 0, 0),      # black bottom
				theme_data["background"])
		ThemeManager.THEME_PERSONA5:
			ThemeManager.apply_screen_background(
				self, "menu",
				Color8(40, 0, 0),     # dark red top
				Color8(0, 0, 0),      # black bottom
				theme_data["background"])
	
	_update_fool_image()

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
