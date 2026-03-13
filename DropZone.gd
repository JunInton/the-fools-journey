extends Control

# ------------------------------------
# ZONE TYPES
# An enum defines a fixed set of named values - like a JS enum or union type
# This tells each zone instance what kind of drop it accepts
# Set via the @export property in the Inspector after attaching this script
# ------------------------------------
enum ZoneType {
	DISCARD,
	SATCHEL,
	EQUIPPED_WISDOM,
	EQUIPPED_STRENGTH,
	EQUIPPED_VOLITION,
	FOOL
}

# @export makes this property visible and editable in the Godot Inspector
# Like a prop with a default value in React
@export var zone_type: ZoneType = ZoneType.DISCARD

func _ready():
	# MOUSE_FILTER_STOP means this node catches mouse events and
	# doesn't pass them through to nodes behind it
	# This is critical for drop zones - without it, cards sitting inside
	# the zone can intercept the drop event before the zone gets it
	# Like CSS pointer-events: all on the zone container
	mouse_filter = Control.MOUSE_FILTER_STOP

# ------------------------------------
# FOOL ZONE DRAG SOURCE
# The Fool section doubles as a drag source
# The Fool card can be dragged onto Challenges to resolve them directly
# This only applies to the FOOL zone type - all others return null
# ------------------------------------
func _get_drag_data(_at_position: Vector2):
	if zone_type == ZoneType.FOOL:
		var preview = Label.new()
		preview.text = "The Fool"
		preview.add_theme_font_size_override("font_size", 14)
		set_drag_preview(preview)
		# Build a minimal card dictionary representing The Fool
		# role = ROLE_FOOL lets Card.gd identify this as a direct challenge attempt
		return {
			"card": {
				"name": "The Fool",
				"role": CardData.ROLE_FOOL,
				"suit": CardData.SUIT_MAJOR,
				"value": 0
			},
			"source_zone": "fool",
			"card_node": self
		}
	return null

# ------------------------------------
# DROP VALIDATION
# Called continuously while a card is dragged over this zone
# Returns true to allow the drop, false to reject it
# Godot shows a visual indicator based on this return value
# Like the HTML5 ondragover event - you must return true to allow dropping
# ------------------------------------
func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false

	var card = data.get("card", {})
	var role = card.get("role", "")
	var source = data.get("source_zone", "")

	match zone_type:
		ZoneType.DISCARD:
			# Anything can be discarded except Challenges (must be resolved)
			# and The Fool (not a real card in the deck)
			# Equipped cards can be dragged here to unequip them
			if role == CardData.ROLE_CHALLENGE or role == CardData.ROLE_FOOL:
				return false
			return true

		ZoneType.SATCHEL:
			# Challenges and Fool can't be stored
			if role == CardData.ROLE_CHALLENGE or role == CardData.ROLE_FOOL:
				return false
			# Cards already in the satchel can't be stored again
			if source == "satchel":
				return false
			# Equipped cards cannot be stored in satchel
			# They can only go to challenges or discard
			if source in ["equipped_strength", "equipped_volition", "equipped_wisdom"]:
				return false
			# Respect the 3-card satchel limit
			return GameState.satchel.size() < GameState.MAX_SATCHEL

		ZoneType.EQUIPPED_WISDOM:
			if role != CardData.ROLE_WISDOM:
				return false
			# Max 3 wisdom cards equipped at once
			return GameState.equipped_wisdom.size() < 3

		ZoneType.EQUIPPED_STRENGTH:
			# Accept any Strength card not already in the equipped slot
			# source != "equipped_strength" prevents dragging the card
			# onto its own slot which would be a no-op
			return role == CardData.ROLE_STRENGTH and source != "equipped_strength"

		ZoneType.EQUIPPED_VOLITION:
			return role == CardData.ROLE_VOLITION and source != "equipped_volition"

		ZoneType.FOOL:
			# Only Vitality (Cups) cards can heal The Fool
			return role == CardData.ROLE_VITALITY

	return false

# ------------------------------------
# DROP EXECUTION
# Called once when the player releases the card over this zone
# This is where we actually execute the game action
# Like the HTML5 ondrop event
# ------------------------------------
func _drop_data(_at_position: Vector2, data):
	var card = data.get("card", {})
	var source = data.get("source_zone", "")
	var from_satchel = source == "satchel"

	match zone_type:
		ZoneType.DISCARD:
			# Handle equipped cards from being unequipped to discard
			# These need special handling rather than normal discard
			if source == "equipped_strength":
				GameState.unequip_strength_to_discard()
			elif source == "equipped_volition":
				GameState.unequip_volition_to_discard()
			else:
				GameState.discard_card(card, from_satchel)

		ZoneType.SATCHEL:
			GameState.store_in_satchel(card)

		ZoneType.EQUIPPED_WISDOM:
			GameState.equip_wisdom(card, from_satchel)

		ZoneType.EQUIPPED_STRENGTH:
			# Replacing an equipped card discards the old one
			# This is a destructive action so we confirm with the player first
			if GameState.equipped_strength != null:
				_confirm_replace(
					"Replace equipped Strength card?",
					func(): GameState.equip_strength(card, from_satchel)
				)
			else:
				# Empty slot - equip immediately
				GameState.equip_strength(card, from_satchel)

		ZoneType.EQUIPPED_VOLITION:
			if GameState.equipped_volition != null:
				_confirm_replace(
					"Replace equipped Volition card?",
					func(): GameState.equip_volition(card, from_satchel)
				)
			else:
				GameState.equip_volition(card, from_satchel)

		ZoneType.FOOL:
			# Healing at full health wastes the card - confirm before allowing it
			if GameState.vitality == GameState.MAX_VITALITY:
				_confirm_replace(
					"Vitality is already full. Discard this card anyway?",
					func(): GameState.replenish_vitality(card, from_satchel)
				)
			else:
				GameState.replenish_vitality(card, from_satchel)

# ------------------------------------
# CONFIRMATION DIALOG
# Identical pattern to the one in Card.gd
# Extracted here so DropZone can show confirmations independently
# of Card.gd without duplicating the dialog creation code
# In a larger project this would live in a shared utility autoload
# ------------------------------------
func _confirm_replace(message: String, callback: Callable):
	# CHANGED: was ConfirmationDialog which uses OS-native styling
	# Now matches the PopupPanel pattern used everywhere else in the game
	var popup = PopupPanel.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var label = Label.new()
	label.text = message
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
		callback.call())
	btn_row.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): popup.queue_free())
	btn_row.add_child(cancel_btn)

	vbox.add_child(btn_row)
	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	popup.popup_centered()
