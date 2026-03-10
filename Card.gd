extends PanelContainer

# This is our card's data - like props in React
var card_data: Dictionary = {}

#source_zone tells drag/drop logic where this card came from
# Like a data-source attribute on an HTML element
var source_zone: String = "adventure"

# These get filled in _ready once the node tree is built
@onready var card_name_label = $VBoxContainer/CardName
@onready var card_value_label = $VBoxContainer/CardValue

func _ready():
	#Lock the card to a fixed size - prevent it from strecthing
	custom_minimum_size = Vector2(90, 130)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	# If card_data was set before this node was added to the scene
	# we update the display immediately
	if card_data.size() > 0:
		update_display()

# Call this to give the card its data - like passing props
func set_card(data: Dictionary):
	card_data = data
	# If the node is already in the scene tree, update right away
	# otherwise _ready() will handle it
	if is_inside_tree():
		update_display()

func update_display():
	card_name_label.text = card_data.get("name", "Unknown")
	card_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_name_label.add_theme_font_size_override("font_size", 11)
	card_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Only show value for cards that have meaningful values
	var role = card_data.get("role", "")
	var value = card_data.get("value", 0)
	if role in [
		CardData.ROLE_CHALLENGE,
		CardData.ROLE_VITALITY,
		CardData.ROLE_STRENGTH,
		CardData.ROLE_VOLITION,
		CardData.ROLE_WISDOM
	]:
		var value_text = "Value: " + str(value)
		# Show a marker if this card has been doubled by a Helper
		if card_data.get("doubled", false):
			value_text += " ×2"
		card_value_label.text = value_text
	else:
		card_value_label.text = role.capitalize()

	# Color the card based on suit - like conditional CSS classes
	_apply_color()

func _apply_color():
	var stylebox = StyleBoxFlat.new()
	var suit = card_data.get("suit", "")

	match suit:
		CardData.SUIT_CUPS:    stylebox.bg_color = Color(0.2, 0.4, 0.8)   # blue
		CardData.SUIT_BATONS:  stylebox.bg_color = Color(0.2, 0.6, 0.2)   # green
		CardData.SUIT_SWORDS:  stylebox.bg_color = Color(0.7, 0.2, 0.2)   # red
		CardData.SUIT_COINS:   stylebox.bg_color = Color(0.7, 0.6, 0.1)   # gold
		CardData.SUIT_MAJOR:   stylebox.bg_color = Color(0.4, 0.1, 0.6)   # purple
		_:                     stylebox.bg_color = Color(0.3, 0.3, 0.3)   # grey

	stylebox.corner_radius_top_left = 6
	stylebox.corner_radius_top_right = 6
	stylebox.corner_radius_bottom_left = 6
	stylebox.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", stylebox)

# ------------------------------------
# DRAG AND DROP - DRAG SOURCE
# _get_drag_data fires when the player
# starts dragging this card
# ------------------------------------
func _get_drag_data(_at_position: Vector2):
	# Challenges can never be dragged
	if card_data.get("role", "") == CardData.ROLE_CHALLENGE:
		return null

	# Build a simple text preview that follows the cursor
	var preview = Label.new()
	preview.text = card_data.get("name", "Card")
	preview.add_theme_font_size_override("font_size", 12)
	preview.add_theme_color_override("font_color", Color.WHITE)
	set_drag_preview(preview)

	return {
		"card": card_data,
		"source_zone": source_zone,
		"card_node": self
	}

# ------------------------------------
# DRAG AND DROP - DROP TARGET
# Cards themselves can be drop targets
# for Helpers and Challenge resolution
# ------------------------------------
func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false

	var dragged_card = data.get("card", {})
	var dragged_role = dragged_card.get("role", "")
	var dragged_suit = dragged_card.get("suit", "")
	var my_role = card_data.get("role", "")
	var my_suit = card_data.get("suit", "")
	var source = data.get("source_zone", "")

	# Helper dropped onto a same-suit Strength, Volition, or Vitality card
	if dragged_role == CardData.ROLE_HELPER:
		if dragged_suit == my_suit:
			if my_role in [CardData.ROLE_STRENGTH, CardData.ROLE_VOLITION, CardData.ROLE_VITALITY]:
				if not card_data.get("doubled", false):
					# Must have at least one Wisdom equipped to pay the cost
					return GameState.equipped_wisdom.size() > 0

	# Equipped Volition dragged onto a Challenge
	if dragged_role == CardData.ROLE_VOLITION and source == "equipped_volition":
		return my_role == CardData.ROLE_CHALLENGE

	# Equipped Strength dragged onto a Challenge
	if dragged_role == CardData.ROLE_STRENGTH and source == "equipped_strength":
		return my_role == CardData.ROLE_CHALLENGE

	# The Fool dragged onto a Challenge
	if dragged_role == CardData.ROLE_FOOL:
		return my_role == CardData.ROLE_CHALLENGE

	return false

func _drop_data(_at_position: Vector2, data):
	var dragged_card = data.get("card", {})
	var dragged_role = dragged_card.get("role", "")
	var source = data.get("source_zone", "")
	var from_satchel = source == "satchel"

	if dragged_role == CardData.ROLE_HELPER:
		GameState.deploy_helper(dragged_card, card_data, from_satchel)

	elif dragged_role == CardData.ROLE_VOLITION and source == "equipped_volition":
		GameState.resolve_with_volition(card_data)

	elif dragged_role == CardData.ROLE_STRENGTH and source == "equipped_strength":
		GameState.resolve_with_strength(card_data)

	elif dragged_role == CardData.ROLE_FOOL:
		GameState.resolve_directly(card_data)

# ------------------------------------
# DOUBLE CLICK - Chance (Ace) cards only
# Double clicking an Ace triggers reshuffle
# ------------------------------------
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			if card_data.get("role", "") == CardData.ROLE_CHANCE:
				var from_satchel = source_zone == "satchel"
				GameState.use_chance(card_data, from_satchel)
