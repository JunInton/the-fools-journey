extends Control
#
const CardScene = preload("res://Card.tscn")

# ------------------------------------
# @onready vars grab references to child nodes
# Like useRef in React - $ is shorthand for get_node()
# 
# ← CHANGED: All paths inside the five sections now include /VBoxContainer/
# because Part 3 added a VBoxContainer inside each section.
# Old path example: .../DiscardSection/DiscardLabel
# New path example: .../DiscardSection/VBoxContainer/DiscardLabel
# ------------------------------------
@onready var adventure_container = $MarginContainer/VBoxContainer/TopHalf/AdventureSection/VBoxContainer/AdventureContainer
@onready var discard_container = $MarginContainer/VBoxContainer/TopHalf/DiscardSection/VBoxContainer/DiscardContainer
@onready var deck_container = $MarginContainer/VBoxContainer/TopHalf/DeckSection/VBoxContainer/DeckContainer

@onready var wisdom_container = $MarginContainer/VBoxContainer/BottomHalf/WisdomSection/VBoxContainer/WisdomContainer
@onready var satchel_container = $MarginContainer/VBoxContainer/BottomHalf/SatchelSection/VBoxContainer/SatchelContainer

# Volition and Strength container paths are unchanged - they were already
# inside VBoxContainers inside FoolEquipped
@onready var volition_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/VolitionSection/VolitionContainer
@onready var strength_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/StrengthSection/StrengthContainer

# ← CHANGED: fool_name_label removed entirely - FoolNameLabel node was deleted in Part 3
# ← CHANGED: fool_vitality_label path updated - node moved to be a direct child of FoolSection
@onready var fool_vitality_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolVitalityLabel

# ← CHANGED: All label paths now include /VBoxContainer/ for the five sections
@onready var adventure_label = $MarginContainer/VBoxContainer/TopHalf/AdventureSection/VBoxContainer/AdventureLabel
@onready var discard_label = $MarginContainer/VBoxContainer/TopHalf/DiscardSection/VBoxContainer/DiscardLabel
@onready var deck_label = $MarginContainer/VBoxContainer/TopHalf/DeckSection/VBoxContainer/DeckLabel
@onready var wisdom_label = $MarginContainer/VBoxContainer/BottomHalf/WisdomSection/VBoxContainer/WisdomLabel
@onready var satchel_label = $MarginContainer/VBoxContainer/BottomHalf/SatchelSection/VBoxContainer/SatchelLabel
@onready var fool_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolLabel
@onready var volition_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/VolitionSection/VolitionLabel
@onready var strength_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/StrengthSection/StrengthLabel

func _ready():
	AudioManager.set_screen("game")
	# Set static label text for all zone headers
	adventure_label.text = "Adventure Field"
	discard_label.text = "Discard Pile"
	deck_label.text = "Deck"
	wisdom_label.text = "Wisdom"
	satchel_label.text = "Satchel"
	fool_label.text = "The Fool"
	volition_label.text = "Volition"
	strength_label.text = "Strength"
	# ← CHANGED: fool_name_label.text removed - that node no longer exists

	# Connect to GameState signals
	# Like addEventListener in JS - these fire automatically when emitted
	GameState.state_changed.connect(_on_state_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)
	
	GameState.discard_viewer_requested.connect(show_discard_viewer)

	# Connect to ThemeManager so the board recolors when theme changes
	ThemeManager.theme_changed.connect(_on_theme_changed)

	# Connect double-click on the entire DiscardSection to open the viewer
	# Using the panel rather than the label because _setup_labels() runs
	# after this and would override any mouse_filter set on the label
	var discard_section = $MarginContainer/VBoxContainer/TopHalf/DiscardSection
	discard_section.mouse_filter = Control.MOUSE_FILTER_STOP
	discard_section.gui_input.connect(_on_discard_section_input)

	_setup_colors()
	_setup_labels()
	_setup_layout()  # ← NEW: separated layout sizing into its own function
	_setup_audio_controls()

	GameState.start_game()

# ------------------------------------
# LAYOUT SETUP
# ← NEW FUNCTION: previously these settings were scattered or missing.
# Handles section proportions and container alignment.
# size_flags_stretch_ratio is like CSS flex-grow - it controls how
# much of the available space each sibling takes relative to others.
# ------------------------------------
func _setup_layout():
	var discard_section = $MarginContainer/VBoxContainer/TopHalf/DiscardSection
	var adventure_section = $MarginContainer/VBoxContainer/TopHalf/AdventureSection
	var deck_section = $MarginContainer/VBoxContainer/TopHalf/DeckSection

	# Adventure Field gets 3x the horizontal space of Discard and Deck
	# So the ratio is 1 : 3 : 1 across the top row
	discard_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_section.size_flags_stretch_ratio = 1.0
	adventure_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adventure_section.size_flags_stretch_ratio = 3.0
	deck_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_section.size_flags_stretch_ratio = 1.0

	# Tighten spacing between cards in the adventure field
	adventure_container.add_theme_constant_override("separation", 12)

	# Center cards horizontally within Wisdom and Satchel zones
	# Without this they left-align by default
	wisdom_container.alignment = BoxContainer.ALIGNMENT_CENTER
	satchel_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Center cards within Strength and Volition zones too
	strength_container.alignment = BoxContainer.ALIGNMENT_CENTER
	volition_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Center items vertically and horizontally within the Deck zone
	# Without this they left-align by default in the VBoxContainer
	deck_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Center the top discard card within the Discard zone
	discard_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Center cards horizontally in the adventure field
	adventure_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Center FoolEquipped within the Fool zone
	# SIZE_SHRINK_CENTER collapses it to its content size and centers it
	# rather than stretching it to fill the full zone height
	var fool_equipped = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped
	fool_equipped.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fool_equipped.alignment = BoxContainer.ALIGNMENT_CENTER

	# Pull the vitality label up closer to the Fool card
	# by reducing the separation on the FoolSection VBoxContainer
	var fool_vbox = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer
	fool_vbox.add_theme_constant_override("separation", 4)
	
	# ← NEW: Fix the width of Strength and Volition slots so they always
	# reserve space even when no card is equipped.
	# Without this the Fool card drifts left or right depending on what's equipped.
	# The minimum width should be wide enough to comfortably hold one card (110px card
	# + some breathing room = 130px)
	var strength_section = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/StrengthSection
	var volition_section = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/VolitionSection
	strength_section.custom_minimum_size.x = 130
	volition_section.custom_minimum_size.x = 130

	# Also center the FoolCard slot itself within its fixed-width neighbors
	var fool_card = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/FoolCard
	fool_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Add spacing between zone labels and their card containers
	# so cards appear vertically centered in the zone rather than
	# pressed up against the label at the top.
	# This targets the VBoxContainer inside each section that wraps
	# the label + card container pair.
	var sections_with_labels = [
		$MarginContainer/VBoxContainer/TopHalf/DiscardSection/VBoxContainer,
		$MarginContainer/VBoxContainer/TopHalf/AdventureSection/VBoxContainer,
		$MarginContainer/VBoxContainer/TopHalf/DeckSection/VBoxContainer,
		$MarginContainer/VBoxContainer/BottomHalf/WisdomSection/VBoxContainer,
		$MarginContainer/VBoxContainer/BottomHalf/SatchelSection/VBoxContainer,
	]
	for section_vbox in sections_with_labels:
		# separation adds space between the label child and the container child
		# 12px gives enough breathing room without pushing cards too far down
		section_vbox.add_theme_constant_override("separation", 32)

# ------------------------------------
# SIGNAL HANDLERS
# These fire automatically when GameState or ThemeManager emit signals
# ------------------------------------
func _on_state_changed():
	_render_all()

func _on_game_over(reason: String):
	print("GAME OVER: ", reason)
	# Small delay so player can see the final board state before transitioning
	# create_timer().timeout is like setTimeout() in JS
	await get_tree().create_timer(1.5).timeout
	RenderingServer.set_default_clear_color(Color.BLACK)
	get_tree().change_scene_to_file("res://LoseScreen.tscn")

func _on_game_won():
	print("YOU WIN!")
	await get_tree().create_timer(1.5).timeout
	RenderingServer.set_default_clear_color(Color.BLACK)
	get_tree().change_scene_to_file("res://WinScreen.tscn")

func _on_theme_changed(_new_theme: String):
	# Re-apply zone colors and re-render cards when theme switches
	# _setup_colors handles zone backgrounds, _render_all handles card colors
	_setup_colors()
	_render_all()

# ------------------------------------
# RENDERING
# Like React's render - rebuilds the visual state from current game data.
# Called every time GameState emits state_changed.
# ------------------------------------
func _render_all():
	_render_zone(adventure_container, GameState.adventure_field, "adventure")
	_render_zone(satchel_container, GameState.satchel, "satchel")
	_render_zone(wisdom_container, GameState.equipped_wisdom, "equipped_wisdom")
	_render_equipped_single(volition_container, GameState.equipped_volition, "equipped_volition")
	_render_equipped_single(strength_container, GameState.equipped_strength, "equipped_strength")
	_render_discard()
	_render_deck()
	_render_fool_stats()
	_render_fool_card()

# Renders an array of cards into a container
# Like mapping over an array in JSX: cards.map(card => <Card data={card} />)
func _render_zone(container: Node, cards: Array, zone_name: String):
	# Clear existing children - like clearing innerHTML before re-rendering
	for child in container.get_children():
		child.queue_free()

	for card in cards:
		var instance = CardScene.instantiate()
		# IMPORTANT: source_zone must be set BEFORE add_child()
		# add_child() triggers _ready() on the instance, which reads source_zone
		# to set mouse_filter. Setting it after means _ready() fires with the wrong default.
		instance.source_zone = zone_name
		container.add_child(instance)
		instance.set_card(card)

# Renders a single equipped card slot (Strength or Volition)
func _render_equipped_single(container: Node, card, zone_name: String):
	for child in container.get_children():
		child.queue_free()

	if card != null:
		var instance = CardScene.instantiate()
		instance.source_zone = zone_name
		container.add_child(instance)
		instance.set_card(card)

# Discard pile shows only the top card, non-interactive
func _render_discard():
	for child in discard_container.get_children():
		child.queue_free()

	if GameState.discard_pile.size() > 0:
		var top_card = GameState.discard_pile.back()
		var instance = CardScene.instantiate()
		instance.source_zone = "discard"
		discard_container.add_child(instance)
		# draggable = false prevents players from recycling discarded cards
		instance.draggable = false
		instance.set_card(top_card)

	discard_label.text = "Discard Pile (" + str(GameState.discard_pile.size()) + ")"

# Shows a scrollable popup of all discarded cards, most recent first
# Triggered by double-clicking anywhere in the DiscardSection panel
func show_discard_viewer():
	if GameState.discard_pile.size() == 0:
		return

	var popup = PopupPanel.new()
	popup.title = "Discard Pile — " + str(GameState.discard_pile.size()) + " cards"

	var vbox = VBoxContainer.new()

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 200)
	# Horizontal scroll keeps all cards in one row instead of wrapping
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 6)

	# duplicate().reverse() = like [...arr].reverse() in JS
	var cards_reversed = GameState.discard_pile.duplicate()
	cards_reversed.reverse()

	for card in cards_reversed:
		var instance = CardScene.instantiate()
		instance.source_zone = "discard"
		card_row.add_child(instance)
		instance.draggable = false
		instance.set_card(card)

	scroll.add_child(card_row)
	vbox.add_child(scroll)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(close_btn)

	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	popup.popup_centered()

# Deck shows a card back image plus count label
# Uses the Card scene for the back image so sizing matches all other cards
func _render_deck():
	for child in deck_container.get_children():
		child.queue_free()

	# Render the card back as a Card scene instance
	# This reuses the same sizing constraints as every other card
	if GameState.deck.size() > 0:
		var instance = CardScene.instantiate()
		instance.source_zone = "deck"
		instance.draggable = false
		deck_container.add_child(instance)
		instance.show_card_back()

	var challenge_count = 0
	for card in GameState.deck:
		if card.role == CardData.ROLE_CHALLENGE:
			challenge_count += 1

	var label = Label.new()
	label.text = str(GameState.deck.size()) + " cards\n" + str(challenge_count) + " challenges remaining"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	# ← NEW: Shrink label to its content width and center it horizontally
	# Without this the label fills the container width and appears left-anchored
	# even though its text is centered within it
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	deck_container.add_child(label)

# ------------------------------------
# THE FOOL CARD RENDERING
# ← CHANGED: The Fool card now hides its name and value labels.
# The zone label ("The Fool") and the vitality label below handle
# all the information the player needs about this zone.
# The card only renders once - we check for the named node to avoid
# re-creating it on every state_changed signal.
# ------------------------------------
func _render_fool_card():
	var fool_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/FoolCard
	if fool_container.has_node("FoolCardDisplay"):
		return

	# The Fool is always index 0 in CardData.all_cards
	var fool_data = CardData.all_cards[0]
	var instance = CardScene.instantiate()
	instance.name = "FoolCardDisplay"
	instance.source_zone = "fool"
	fool_container.add_child(instance)
	instance.set_card(fool_data)

	# CHANGED: was visible = false which removes nodes from layout,
	# making the Fool card shorter than equipped cards and causing the
	# vitality label to shift down when a strength/volition card is equipped.
	# modulate = Color(0,0,0,0) makes labels fully transparent while keeping
	# them in the layout, so the Fool card stays the same height as equipped cards.
	instance.get_node("VBoxContainer/CardName").modulate = Color(0, 0, 0, 0)
	instance.get_node("VBoxContainer/CardValue").modulate = Color(0, 0, 0, 0)

# ------------------------------------
# FOOL STATS
# ← CHANGED: fool_vitality_label is now a direct child of FoolSection
# (moved in Part 3), so it sits below the entire FoolEquipped row.
# Centering it makes it read as a caption under the Fool card area.
# ------------------------------------
func _render_fool_stats():
	fool_vitality_label.text = "Vitality: " + str(GameState.vitality) + " / 25"
	fool_vitality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# ------------------------------------
# ZONE COLORS
# Reads colors from ThemeManager instead of hardcoded values
# so switching themes recolors all zones automatically.
# Like a CSS variable that updates everywhere it's used.
# ------------------------------------
func _setup_colors():
	var zone_map = {
		$MarginContainer/VBoxContainer/TopHalf/DiscardSection: "discard",
		$MarginContainer/VBoxContainer/TopHalf/AdventureSection: "adventure",
		$MarginContainer/VBoxContainer/TopHalf/DeckSection: "deck",
		$MarginContainer/VBoxContainer/BottomHalf/WisdomSection: "wisdom",
		$MarginContainer/VBoxContainer/BottomHalf/FoolSection: "fool",
		$MarginContainer/VBoxContainer/BottomHalf/SatchelSection: "satchel",
	}
	for node in zone_map:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = ThemeManager.get_zone_color(zone_map[node])
		stylebox.corner_radius_top_left = 8
		stylebox.corner_radius_top_right = 8
		stylebox.corner_radius_bottom_left = 8
		stylebox.corner_radius_bottom_right = 8
		# ← CHANGED: increased content margins from 8 to 16
		# This gives cards more breathing room from zone edges
		stylebox.content_margin_left = 16
		stylebox.content_margin_right = 16
		stylebox.content_margin_top = 16
		stylebox.content_margin_bottom = 16
		node.add_theme_stylebox_override("panel", stylebox)
		
	# NEW: set the background clear color to match the current theme
	# This colors the area behind all zone panels rather than showing
	# Godot's default gray
	RenderingServer.set_default_clear_color(ThemeManager.get_current()["background"])

# ------------------------------------
# LABEL STYLING
# Centers all labels and sets font sizes.
# ← CHANGED: fool_name_label removed from both lists since that node
# was deleted in Part 3. It's no longer needed.
# ------------------------------------
func _setup_labels():
	var all_labels = [
		adventure_label, discard_label, deck_label,
		wisdom_label, satchel_label, fool_label,
		volition_label, strength_label,
		fool_vitality_label
		# ← CHANGED: fool_name_label removed
	]
	for label in all_labels:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)

	var header_labels = [
		adventure_label, discard_label, deck_label,
		wisdom_label, satchel_label, fool_label
	]
	for label in header_labels:
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))

func _on_discard_section_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			show_discard_viewer()
			
# Settings and Rules
func _setup_audio_controls():
	# Invisible full-screen backdrop - sits behind the panel but above the game
	# Clicking anywhere on it closes the panel, like clicking outside a dropdown
	var backdrop = Button.new()
	backdrop.flat = true  # no visible button styling
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.visible = false
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.z_index = 1 # above game, below controls
	add_child(backdrop)
	
	# Gear button that toggles the settings panel open/closed
	var gear_btn = Button.new()
	gear_btn.text = "Options"
	gear_btn.custom_minimum_size = Vector2(32, 32)
	gear_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	gear_btn.position = Vector2(8, 8)
	gear_btn.z_index = 2 # above backdrop
	add_child(gear_btn)

	# Settings panel — hidden by default, shown when gear is clicked
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(8, 48)
	panel.visible = false
	panel.z_index = 2 # above backdrop
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var music_btn = Button.new()
	music_btn.text = "Music ON" if AudioManager.music_enabled else "Music OFF"
	# REMOVED: music_btn.toggle_mode = true — was causing inconsistent hover appearance
	# State is tracked manually via text change instead
	#music_btn.button_pressed = AudioManager.music_enabled
	music_btn.pressed.connect(func():
		AudioManager.toggle_music()
		music_btn.text = "Music ON" if AudioManager.music_enabled else "Music OFF")
	vbox.add_child(music_btn)

	var sfx_btn = Button.new()
	sfx_btn.text = "SFX ON" if AudioManager.sfx_enabled else "SFX OFF"
	#sfx_btn.toggle_mode = true
	sfx_btn.button_pressed = AudioManager.sfx_enabled
	sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx()
		sfx_btn.text = "SFX ON" if AudioManager.sfx_enabled else "SFX OFF")
	vbox.add_child(sfx_btn)

	var rules_btn = Button.new()
	rules_btn.text = "Rules"
	rules_btn.pressed.connect(func():
		AudioManager.play_menu_click()
		# ← CHANGED: show rules as overlay instead of changing scenes
		# This keeps the game scene alive so nothing resets
		_show_rules_overlay())
	vbox.add_child(rules_btn)
	
	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.pressed.connect(func():
		AudioManager.play_menu_click()
		_confirm_return_to_menu())
	vbox.add_child(menu_btn)

	# Toggle both panel and backdrop together
	gear_btn.pressed.connect(func():
		var opening = not panel.visible
		panel.visible = opening
		backdrop.visible = opening)

	backdrop.pressed.connect(func():
		panel.visible = false
		backdrop.visible = false)

func _show_rules_overlay():
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 100
	panel.offset_right = -100
	panel.offset_top = 60
	panel.offset_bottom = -60
	overlay.add_child(panel)

	# FIXED: single MarginContainer directly inside panel
	# previously had both an empty vbox and a margin as siblings which caused confusion
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(inner_vbox)

	var title = Label.new()
	title.text = "The Fool's Journey — Rules"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ThemeManager.get_current()["label_color"])
	inner_vbox.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(scroll)

	var rules_label = Label.new()
	rules_label.text = _get_rules_text()
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.custom_minimum_size.x = 580
	scroll.add_child(rules_label)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func():
		AudioManager.play_menu_click()
		overlay.queue_free())
	inner_vbox.add_child(close_btn)

func _get_rules_text() -> String:
	# Same rules text as RulesScreen which calls from ThemeManager
	return ThemeManager.get_rules_text()
	
func _confirm_return_to_menu():
	# ← Confirm before leaving since returning to menu resets the game
	var popup = PopupPanel.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var label = Label.new()
	label.text = "Return to Main Menu?\nYour current game will be lost."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 260
	vbox.add_child(label)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 8)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.pressed.connect(func():
		popup.queue_free()
		get_tree().change_scene_to_file("res://MainMenu.tscn"))
	btn_row.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): popup.queue_free())
	btn_row.add_child(cancel_btn)

	vbox.add_child(btn_row)
	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	popup.popup_centered()
