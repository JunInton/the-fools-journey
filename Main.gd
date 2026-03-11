extends Control

const CardScene = preload("res://Card.tscn")

# ------------------------------------
# @onready vars = like useRef in React
# They grab a reference to a node in the tree
# The $ is shorthand for get_node()
# $VBoxContainer/TopHalf = document.querySelector(".TopHalf")
# ------------------------------------
@onready var adventure_container = $MarginContainer/VBoxContainer/TopHalf/AdventureSection/AdventureContainer
@onready var discard_container = $MarginContainer/VBoxContainer/TopHalf/DiscardSection/DiscardContainer
@onready var deck_container = $MarginContainer/VBoxContainer/TopHalf/DeckSection/DeckContainer

@onready var wisdom_container = $MarginContainer/VBoxContainer/BottomHalf/WisdomSection/WisdomContainer
@onready var satchel_container = $MarginContainer/VBoxContainer/BottomHalf/SatchelSection/SatchelContainer
@onready var volition_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/FoolEquipped/VolitionSection/VolitionContainer
@onready var strength_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/FoolEquipped/StrengthSection/StrengthContainer

@onready var fool_name_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/FoolEquipped/FoolCard/FoolNameLabel
@onready var fool_vitality_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/FoolEquipped/FoolCard/FoolVitalityLabel

@onready var adventure_label = $MarginContainer/VBoxContainer/TopHalf/AdventureSection/AdventureLabel
@onready var discard_label = $MarginContainer/VBoxContainer/TopHalf/DiscardSection/DiscardLabel
@onready var deck_label = $MarginContainer/VBoxContainer/TopHalf/DeckSection/DeckLabel
@onready var wisdom_label = $MarginContainer/VBoxContainer/BottomHalf/WisdomSection/WisdomLabel
@onready var satchel_label = $MarginContainer/VBoxContainer/BottomHalf/SatchelSection/SatchelLabel
@onready var fool_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/FoolLabel
@onready var volition_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/FoolEquipped/VolitionSection/VolitionLabel
@onready var strength_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/FoolEquipped/StrengthSection/StrengthLabel

func _ready():
	# Set static label text
	adventure_label.text = "Adventure Field"
	discard_label.text = "Discard Pile"
	deck_label.text = "Deck"
	wisdom_label.text = "Wisdom"
	satchel_label.text = "Satchel"
	fool_label.text = "The Fool"
	volition_label.text = "Volition"
	strength_label.text = "Strength"
	fool_name_label.text = "The Fool"

	# Connect to GameState's signal
	# This is like addEventListener in JS
	# Whenever GameState emits "state_changed", we call _on_state_changed
	GameState.state_changed.connect(_on_state_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)
	
	# Whenever Theme changes, we call _on_theme_changed
	ThemeManager.theme_changed.connect(_on_theme_changed)
	
	# Connect double-click on the entire DiscardSection panel to open the viewer
	# We use the section panel rather than just the label because _setup_labels()
	# runs after this and resets label properties, breaking the label connection.
	# The panel covers the whole zone so the player can double-click anywhere in it.
	var discard_section = $MarginContainer/VBoxContainer/TopHalf/DiscardSection
	discard_section.mouse_filter = Control.MOUSE_FILTER_STOP
	discard_section.gui_input.connect(_on_discard_section_input)
	
	_setup_colors()
	_setup_labels()

	GameState.start_game()

# ------------------------------------
# SIGNAL HANDLERS
# Like event listeners - these fire automatically
# when GameState emits the matching signal
# ------------------------------------
func _on_state_changed():
	_render_all()

func _on_game_over(reason: String):
	print("GAME OVER: ", reason)
	# Small delay before transitioning so the player can see
	# the final state of the board before the screen changes
	# get_tree().create_timer() is like setTimeout() in JS
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://LoseScreen.tscn")

func _on_game_won():
	print("YOU WIN!")
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://WinScreen.tscn")

# ------------------------------------
# RENDERING
# Like a React render/return — rebuilds
# the visual state from current game data
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

# Renders an array of cards into a container
# Like mapping over an array in JSX
func _render_zone(container: Node, cards: Array, zone_name: String):
	# Clear existing children first - like clearing innerHTML
	for child in container.get_children():
		child.queue_free()

	for card in cards:
		var instance = CardScene.instantiate()
		# IMPORTANT: source_zone must be set BEFORE add_child()
		# add_child() triggers _ready() on the instance, which reads source_zone
		# to set mouse_filter. If we set source_zone after, _ready() has already
		# fired with the wrong default value and mouse_filter never gets set.
		instance.source_zone = zone_name
		container.add_child(instance)
		instance.set_card(card)

# Renders a single equipped card slot (or empty)
func _render_equipped_single(container: Node, card, zone_name: String):
	for child in container.get_children():
		child.queue_free()

	if card != null:
		var instance = CardScene.instantiate()
		# Same reason as above - source_zone before add_child
		instance.source_zone = zone_name
		container.add_child(instance)
		instance.set_card(card)

# Discard pile shows only the top card face-up
# but tracks draggable = false so it can't be reused
func _render_discard():
	for child in discard_container.get_children():
		child.queue_free()

	if GameState.discard_pile.size() > 0:
		var top_card = GameState.discard_pile.back()
		var instance = CardScene.instantiate()
		instance.source_zone = "discard"
		discard_container.add_child(instance)
		# Discard pile cards must not be draggable
		# Without this flag, players could recycle discarded cards
		instance.draggable = false
		instance.set_card(top_card)

	# Show the discard count on the section label
	discard_label.text = "Discard Pile (" + str(GameState.discard_pile.size()) + ")"

# Opens a read-only popup showing all discarded cards
# Called from the DiscardSection node on double-click
# Player can only view - no interactions allowed
func show_discard_viewer():
	if GameState.discard_pile.size() == 0:
		return

	# PopupPanel with a scrollable list of all discarded cards
	var popup = PopupPanel.new()
	popup.title = "Discard Pile — " + str(GameState.discard_pile.size()) + " cards"

	var vbox = VBoxContainer.new()

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 320)
	# Allow horizontal scrolling so cards stay in one row
	# rather than wrapping to new lines
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	# HBoxContainer keeps all cards in a single horizontal row
	# HFlowContainer was wrapping to new lines - HBoxContainer won't
	var card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 6)

	# Show all discarded cards, most recent first
	# Array.duplicate().reverse() = like [...arr].reverse() in JS

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

	# Close button at the bottom
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(close_btn)

	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	popup.popup_centered(Vector2(440, 380))

# Deck shows a count - no need to show actual cards
# Challenge count helps the player plan ahead
func _render_deck():
	for child in deck_container.get_children():
		child.queue_free()
		
	# Count how many challenges remain in the draw pile
	var challenge_count = 0
	for card in GameState.deck:
		if card.role == CardData.ROLE_CHALLENGE:
			challenge_count += 1

	var label = Label.new()
	label.text = str(GameState.deck.size()) + " cards\n" + str(challenge_count) + " challenges remaining"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	deck_container.add_child(label)

# Update the Fool's vitality display
func _render_fool_stats():
	fool_vitality_label.text = "Vitality: " + str(GameState.vitality) + " / 25"

func _setup_colors():
	# Read zone colors from ThemeManager so themes apply globally
	# Previously these were hardcoded Colors - now they're data-driven
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
		stylebox.content_margin_left = 8
		stylebox.content_margin_right = 8
		stylebox.content_margin_top = 8
		stylebox.content_margin_bottom = 8
		node.add_theme_stylebox_override("panel", stylebox)

func _setup_labels():
	# Center all labels and set font sizes
	# Like text-align: center in CSS
	var all_labels = [
		adventure_label, discard_label, deck_label,
		wisdom_label, satchel_label, fool_label,
		volition_label, strength_label, fool_name_label,
		fool_vitality_label
	]
	for label in all_labels:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)

	# Make section headers slightly bigger
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
			
func _on_theme_changed(_new_theme: String):
	# Re-apply colors when theme changes
	# _render_all handles cards, _setup_colors handles zones
	_setup_colors()
	_render_all()
