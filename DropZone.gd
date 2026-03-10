extends Control

# This script turns any Control node into a drop target.
# Like an HTML element with ondragover + ondrop handlers.
# Set zone_type in the Inspector after attaching this script.

enum ZoneType {
	DISCARD,
	SATCHEL,
	EQUIPPED_WISDOM,
	EQUIPPED_STRENGTH,
	EQUIPPED_VOLITION,
	FOOL
}

@export var zone_type: ZoneType = ZoneType.DISCARD

# ------------------------------------
# DRAG SOURCE (only used by FOOL zone)
# The Fool card can be dragged onto Challenges
# ------------------------------------
func _get_drag_data(at_position: Vector2):
	if zone_type == ZoneType.FOOL:
		var preview = Label.new()
		preview.text = "The Fool"
		preview.add_theme_font_size_override("font_size", 14)
		set_drag_preview(preview)
		return {
			"card": {"name": "The Fool", "role": CardData.ROLE_FOOL, "suit": CardData.SUIT_MAJOR, "value": 0},
			"source_zone": "fool",
			"card_node": self
		}
	return null

# ------------------------------------
# DROP TARGET
# Called when a card is dragged over this zone
# Returns true if the drop is valid - like ondragover
# ------------------------------------
func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false

	var card = data.get("card", {})
	var role = card.get("role", "")
	var source = data.get("source_zone", "")

	match zone_type:
		ZoneType.DISCARD:
			# Anything except Challenges and The Fool can be discarded
			return role != CardData.ROLE_CHALLENGE and role != CardData.ROLE_FOOL

		ZoneType.SATCHEL:
			# Challenges and Fool can't go in satchel
			# Cards already in satchel can't be stored again
			if role == CardData.ROLE_CHALLENGE or role == CardData.ROLE_FOOL:
				return false
			if source == "satchel":
				return false
			return GameState.satchel.size() < GameState.MAX_SATCHEL

		ZoneType.EQUIPPED_WISDOM:
			if role != CardData.ROLE_WISDOM:
				return false
			return GameState.equipped_wisdom.size() < 3

		ZoneType.EQUIPPED_STRENGTH:
			# Accept Strength from field or satchel only
			return role == CardData.ROLE_STRENGTH and source != "equipped_strength"

		ZoneType.EQUIPPED_VOLITION:
			# Accept Volition from field or satchel only
			return role == CardData.ROLE_VOLITION and source != "equipped_volition"

		ZoneType.FOOL:
			# Only Vitality (Cups) cards can heal The Fool
			return role == CardData.ROLE_VITALITY

	return false

# ------------------------------------
# Called when the card is actually dropped
# Like ondrop - this is where actions execute
# ------------------------------------
func _drop_data(at_position: Vector2, data):
	var card = data.get("card", {})
	var source = data.get("source_zone", "")
	var from_satchel = source == "satchel"

	match zone_type:
		ZoneType.DISCARD:
			GameState.discard_card(card, from_satchel)

		ZoneType.SATCHEL:
			GameState.store_in_satchel(card)

		ZoneType.EQUIPPED_WISDOM:
			GameState.equip_wisdom(card, from_satchel)

		ZoneType.EQUIPPED_STRENGTH:
			GameState.equip_strength(card, from_satchel)

		ZoneType.EQUIPPED_VOLITION:
			GameState.equip_volition(card, from_satchel)

		ZoneType.FOOL:
			GameState.replenish_vitality(card, from_satchel)
