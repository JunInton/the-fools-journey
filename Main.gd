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
	# We'll add a proper screen for this later

func _on_game_won():
	print("YOU WIN!")
	# We'll add a proper screen for this later

# ------------------------------------
# RENDERING
# Like a React render/return — rebuilds
# the visual state from current game data
# ------------------------------------
func _render_all():
	_render_zone(adventure_container, GameState.adventure_field)
	_render_zone(satchel_container, GameState.satchel)
	_render_zone(wisdom_container, GameState.equipped_wisdom)
	_render_equipped_single(volition_container, GameState.equipped_volition)
	_render_equipped_single(strength_container, GameState.equipped_strength)
	_render_discard()
	_render_deck()
	_render_fool_stats()

# Renders an array of cards into a container
# Like mapping over an array in JSX
func _render_zone(container: Node, cards: Array):
	# Clear existing children first - like clearing innerHTML
	for child in container.get_children():
		child.queue_free()

	for card in cards:
		var instance = CardScene.instantiate()
		container.add_child(instance)
		instance.set_card(card)

# Renders a single equipped card slot (or empty)
func _render_equipped_single(container: Node, card):
	for child in container.get_children():
		child.queue_free()

	if card != null:
		var instance = CardScene.instantiate()
		container.add_child(instance)
		instance.set_card(card)

# Discard pile just shows the top card
func _render_discard():
	for child in discard_container.get_children():
		child.queue_free()

	if GameState.discard_pile.size() > 0:
		var top_card = GameState.discard_pile.back()
		var instance = CardScene.instantiate()
		discard_container.add_child(instance)
		instance.set_card(top_card)

# Deck shows a count - no need to show actual cards
func _render_deck():
	for child in deck_container.get_children():
		child.queue_free()

	var count = GameState.deck.size()
	var label = Label.new()
	label.text = str(count) + " cards remaining"
	deck_container.add_child(label)

# Update the Fool's vitality display
func _render_fool_stats():
	fool_vitality_label.text = "Vitality: " + str(GameState.vitality) + " / 25"

func _setup_colors():
	# Helper that creats a colored background panel for any Control node
	# Like setting a background color in CSS
	var sections = {
		$MarginContainer/VBoxContainer/TopHalf/DiscardSection: Color(0.15, 0.15, 0.2),
		$MarginContainer/VBoxContainer/TopHalf/AdventureSection: Color(0.1, 0.2, 0.1),
		$MarginContainer/VBoxContainer/TopHalf/DeckSection: Color(0.15, 0.15, 0.2),
		$MarginContainer/VBoxContainer/BottomHalf/WisdomSection: Color(0.3, 0.25, 0.05),
		$MarginContainer/VBoxContainer/BottomHalf/FoolSection: Color(0.2, 0.1, 0.3),
		$MarginContainer/VBoxContainer/BottomHalf/SatchelSection: Color(0.1, 0.2, 0.25),
	}
	for node in sections:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = sections[node]
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
