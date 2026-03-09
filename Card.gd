extends PanelContainer

# This is our card's data - like props in React
var card_data: Dictionary = {}

# These get filled in _ready once the node tree is built
@onready var card_name_label = $VBoxContainer/CardName
@onready var card_value_label = $VBoxContainer/CardValue

func _ready():
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
		card_value_label.text = "Value: " + str(value)
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
