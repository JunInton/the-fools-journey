extends Control

# ------------------------------------
# ZONE TYPES
# An enum defines a fixed set of named values — like a union type in JS.
# Each DropZone instance is assigned one of these in the Inspector,
# which determines what kinds of cards it accepts.
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
@export var zone_type: ZoneType = ZoneType.DISCARD

func _ready():
	# MOUSE_FILTER_STOP catches mouse events and prevents them from passing
	# through to nodes behind this one. Without it, cards sitting inside the
	# zone can intercept the drop event before the zone receives it.
	mouse_filter = Control.MOUSE_FILTER_STOP

# ------------------------------------
# FOOL ZONE DRAG SOURCE
# The Fool zone doubles as a drag source so the player can drag
# The Fool card onto Challenges to resolve them directly.
# All other zone types return null from this function.
# ------------------------------------
func _get_drag_data(_at_position: Vector2):
	if zone_type == ZoneType.FOOL:
		var preview = Label.new()
		preview.text = "The Fool"
		preview.add_theme_font_size_override("font_size", 14)
		set_drag_preview(preview)
		# Minimal card dictionary representing The Fool —
		# ROLE_FOOL lets Card.gd identify this as a direct challenge resolution
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
# Called continuously while a card is dragged over this zone.
# Returns true to allow the drop, false to reject it.
# Godot shows a visual highlight on the zone based on this return value.
# Like the HTML5 ondragover event — you must return true to allow dropping.
# ------------------------------------
func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false

	var card   = data.get("card", {})
	var role   = card.get("role", "")
	var source = data.get("source_zone", "")

	match zone_type:
		ZoneType.DISCARD:
			# Challenges must be resolved, not discarded.
			# The Fool is not a real deck card and cannot be discarded.
			if role == CardData.ROLE_CHALLENGE or role == CardData.ROLE_FOOL:
				return false
			return true

		ZoneType.SATCHEL:
			if role == CardData.ROLE_CHALLENGE or role == CardData.ROLE_FOOL:
				return false
			# Cards already in the satchel cannot be re-stored
			if source == "satchel":
				return false
			# Equipped cards can only go to challenges or discard, not the satchel
			if source in ["equipped_strength", "equipped_volition", "equipped_wisdom"]:
				return false
			return GameState.satchel.size() < GameState.MAX_SATCHEL

		ZoneType.EQUIPPED_WISDOM:
			if role != CardData.ROLE_WISDOM:
				return false
			return GameState.equipped_wisdom.size() < 3

		ZoneType.EQUIPPED_STRENGTH:
			# source != "equipped_strength" prevents dropping the card onto its own slot
			return role == CardData.ROLE_STRENGTH and source != "equipped_strength"

		ZoneType.EQUIPPED_VOLITION:
			return role == CardData.ROLE_VOLITION and source != "equipped_volition"

		ZoneType.FOOL:
			# Only Vitality (Cups) cards can be used to heal The Fool
			return role == CardData.ROLE_VITALITY

	return false

# ------------------------------------
# DROP EXECUTION
# Called once when the player releases a card over this zone.
# Routes the drop to the appropriate GameState action function.
# Like the HTML5 ondrop event.
# ------------------------------------
func _drop_data(_at_position: Vector2, data):
	var card         = data.get("card", {})
	var source       = data.get("source_zone", "")
	var from_satchel = source == "satchel"

	match zone_type:
		ZoneType.DISCARD:
			if source == "equipped_strength":
				GameState.unequip_strength_to_discard()
			elif source == "equipped_volition":
				GameState.unequip_volition_to_discard()
			elif source == "equipped_wisdom":
				GameState.unequip_wisdom_to_discard(card)
			else:
				# Aces dropped on the discard zone offer the Chance option
				# rather than silently discarding — matches double-click behavior
				if card.get("role", "") == CardData.ROLE_CHANCE:
					_show_ace_drop_menu(card, from_satchel)
				else:
					GameState.discard_card(card, from_satchel)

		ZoneType.SATCHEL:
			GameState.store_in_satchel(card)

		ZoneType.EQUIPPED_WISDOM:
			GameState.equip_wisdom(card, from_satchel)

		ZoneType.EQUIPPED_STRENGTH:
			# Replacing an equipped card is destructive — confirm before acting
			if GameState.equipped_strength != null:
				_confirm_replace(
					"Replace equipped Strength card?",
					func(): GameState.equip_strength(card, from_satchel))
			else:
				GameState.equip_strength(card, from_satchel)

		ZoneType.EQUIPPED_VOLITION:
			if GameState.equipped_volition != null:
				_confirm_replace(
					"Replace equipped Volition card?",
					func(): GameState.equip_volition(card, from_satchel))
			else:
				GameState.equip_volition(card, from_satchel)

		ZoneType.FOOL:
			# Healing at full Vitality wastes the card — confirm first
			if GameState.vitality == GameState.MAX_VITALITY:
				_confirm_replace(
					"Vitality is already full. Discard this card anyway?",
					func(): GameState.replenish_vitality(card, from_satchel))
			else:
				GameState.replenish_vitality(card, from_satchel)

func _show_ace_drop_menu(card: Dictionary, from_satchel: bool):
	var popup = PopupPanel.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title = Label.new()
	title.text = card.get("name", "Ace")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var chance_btn = Button.new()
	chance_btn.text = "Take a Chance — reshuffle Adventure Field back into the Deck"
	chance_btn.pressed.connect(func():
		popup.queue_free()
		GameState.use_chance(card, from_satchel))
	vbox.add_child(chance_btn)

	var discard_btn = Button.new()
	discard_btn.text = "Discard"
	discard_btn.pressed.connect(func():
		popup.queue_free()
		GameState.discard_card(card, from_satchel))
	vbox.add_child(discard_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(cancel_btn)

	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	popup.popup_centered()

# ------------------------------------
# CONFIRMATION DIALOG
# Reusable confirm popup — same pattern as Card.gd's _confirm_action().
# Kept here so DropZone can show confirmations independently without
# coupling to Card.gd. In a larger project this would live in a
# shared utility Autoload.
# ------------------------------------
func _confirm_replace(message: String, callback: Callable):
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
