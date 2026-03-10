extends Node

# ------------------------------------
# SIGNALS
# Signals are Godot's version of events/callbacks.
# Like an EventEmitter in JS — other nodes can
# "listen" to these and react when they fire.
# ------------------------------------
signal state_changed  # fires whenever anything updates
signal game_over(reason: String)
signal game_won

# ------------------------------------
# GAME STATE
# ------------------------------------

# The draw pile - array of card Dictionaries
var deck: Array = []

# The 4 cards currently in play
var adventure_field: Array = []

# Player's bag - max 3 cards
var satchel: Array = []

# Cards that have been used/discarded
var discard_pile: Array = []

# Fool's stats
var vitality: int = 25
const MAX_VITALITY = 25
const MAX_SATCHEL = 3
const ADVENTURE_FIELD_SIZE = 4

# Equipped cards - only one of each type at a time
var equipped_wisdom: Array = []   # up to 3 wisdom cards
var equipped_strength = null      # one card or null
var equipped_volition = null      # one card or null

# Tracks how many cards in the adventure field
# have been resolved this round (need 3 of 4)
var cards_resolved_this_adventure: int = 0

# The carry-over card from previous adventure
var carried_over_card = null

# ------------------------------------
# SETUP
# ------------------------------------
func _ready():
	pass  # we won't auto-start, Main scene will call start_game()

func start_game():
	print("Starting new game...")

	# Build a fresh deck from CardData, excluding The Fool
	deck = []
	for card in CardData.all_cards:
		if card.role != CardData.ROLE_FOOL:
			deck.append(card.duplicate())  # .duplicate() is like JS spread {...card}

	_shuffle_deck()
	vitality = MAX_VITALITY
	satchel = []
	discard_pile = []
	adventure_field = []
	equipped_wisdom = []
	equipped_strength = null
	equipped_volition = null
	cards_resolved_this_adventure = 0
	carried_over_card = null

	_deal_adventure()
	emit_signal("state_changed")
	print("Game started! Deck size: ", deck.size())

# ------------------------------------
# DECK MANAGEMENT
# ------------------------------------
func _shuffle_deck():
	deck.shuffle()  # Godot's built-in shuffle, like JS array sort hack but actually random
	print("Deck shuffled.")

func _deal_adventure():
	adventure_field = []
	cards_resolved_this_adventure = 0

	# If there's a carried over card, place it first
	if carried_over_card != null:
		adventure_field.append(carried_over_card)
		carried_over_card = null

	# Fill the rest from the deck
	while adventure_field.size() < ADVENTURE_FIELD_SIZE and deck.size() > 0:
		adventure_field.append(deck.pop_back())  # pop_back = JS .pop()

	print("Adventure dealt. Field: ", adventure_field.size(), " cards. Deck remaining: ", deck.size())

# ------------------------------------
# ACTIONS
# These are the things the player can DO.
# Each returns true/false for success.
# ------------------------------------

# Move a card from adventure field into the satchel
func store_in_satchel(card: Dictionary) -> bool:
	if satchel.size() >= MAX_SATCHEL:
		print("Satchel is full!")
		return false
	if card.role == CardData.ROLE_CHALLENGE:
		print("Cannot store a Challenge card!")
		return false

	adventure_field.erase(card)
	satchel.append(card)
	emit_signal("state_changed")
	print("Stored in satchel: ", card.name)
	return true

# Discard a non-challenge card from field or satchel
func discard_card(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role == CardData.ROLE_CHALLENGE:
		print("Cannot discard a Challenge card!")
		return false

	if from_satchel:
		satchel.erase(card)
	else:
		adventure_field.erase(card)

	discard_pile.append(card)
	emit_signal("state_changed")
	print("Discarded: ", card.name)
	return true

# Equip a Wisdom card (from field or satchel)
func equip_wisdom(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_WISDOM:
		return false
	if equipped_wisdom.size() >= 3:
		print("Already have 3 Wisdom cards equipped!")
		return false

	_remove_from_source(card, from_satchel)
	equipped_wisdom.append(card)
	emit_signal("state_changed")
	print("Equipped wisdom: ", card.name)
	return true

# Equip a Strength card
func equip_strength(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_STRENGTH:
		return false
	# If already equipped, discard the old one first
	if equipped_strength != null:
		discard_pile.append(equipped_strength)
		print("Old Strength discarded.")
	_remove_from_source(card, from_satchel)
	equipped_strength = card
	emit_signal("state_changed")
	print("Equipped strength: ", card.name)
	return true

# Equip a Volition card
func equip_volition(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_VOLITION:
		return false
	#If already equipped, discard the old one first
	if equipped_volition != null:
		discard_pile.append(equipped_volition)
		print("Old Volition discarded.")
	_remove_from_source(card, from_satchel)
	equipped_volition = card
	emit_signal("state_changed")
	print("Equipped volition: ", card.name)
	return true

# Use an Ace (Chance) - reshuffle adventure field into deck
func use_chance(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_CHANCE:
		return false

	_remove_from_source(card, from_satchel)
	discard_pile.append(card)

	# Shuffle adventure field back into deck
	for field_card in adventure_field:
		deck.append(field_card)
	adventure_field = []
	_shuffle_deck()
	_deal_adventure()
	emit_signal("state_changed")
	print("Chance used! Adventure reshuffled.")
	return true

# Resolve a challenge using Volition (overcome)
func resolve_with_volition(challenge: Dictionary) -> bool:
	if equipped_volition == null:
		print("No Volition equipped!")
		return false
	if challenge.role != CardData.ROLE_CHALLENGE:
		return false

	var vol_value = equipped_volition.value
	var challenge_value = challenge.value

	if vol_value >= challenge_value:
		# Overcome! Discard both
		print("Challenge OVERCOME with Volition!")
		discard_pile.append(equipped_volition)
		discard_pile.append(challenge)
		equipped_volition = null
		adventure_field.erase(challenge)
		_on_card_resolved()
	else:
		# Deplete the challenge
		print("Volition depletes challenge by ", vol_value)
		challenge.value -= vol_value
		discard_pile.append(equipped_volition)
		equipped_volition = null

	emit_signal("state_changed")
	return true

# Resolve a challenge using Strength (endure)
func resolve_with_strength(challenge: Dictionary) -> bool:
	if equipped_strength == null:
		print("No Strength equipped!")
		return false
	if challenge.role != CardData.ROLE_CHALLENGE:
		return false

	var str_value = equipped_strength.value
	var challenge_value = challenge.value

	if str_value == challenge_value:
		# Exactly matched - both discarded
		print("Challenge ENDURED exactly!")
		discard_pile.append(equipped_strength)
		discard_pile.append(challenge)
		equipped_strength = null
		adventure_field.erase(challenge)
		_on_card_resolved()
	elif str_value > challenge_value:
		# Strength wins - challenge discarded, strength depleted
		print("Challenge ENDURED, Strength depleted by ", challenge_value)
		equipped_strength.value -= challenge_value
		discard_pile.append(challenge)
		adventure_field.erase(challenge)
		_on_card_resolved()
	else:
		# Challenge wins - both discarded, Fool takes damage
		var damage = challenge_value - str_value
		print("Challenge ENDURED at cost! Fool takes ", damage, " damage")
		vitality -= damage
		discard_pile.append(equipped_strength)
		discard_pile.append(challenge)
		equipped_strength = null
		adventure_field.erase(challenge)
		_on_card_resolved()
		_check_vitality()

	emit_signal("state_changed")
	return true

# Resolve a challenge directly (pay vitality)
func resolve_directly(challenge: Dictionary) -> bool:
	if challenge.role != CardData.ROLE_CHALLENGE:
		return false

	vitality -= challenge.value
	print("Challenge resolved directly! Vitality cost: ", challenge.value)
	discard_pile.append(challenge)
	adventure_field.erase(challenge)
	_on_card_resolved()
	_check_vitality()
	emit_signal("state_changed")
	return true

# Replenish vitality using a Cups card
func replenish_vitality(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_VITALITY:
		return false

	var healed = min(card.value, MAX_VITALITY - vitality)  # can't exceed 25
	vitality += healed
	print("Vitality replenished by ", healed, ". Now at: ", vitality)
	_remove_from_source(card, from_satchel)
	discard_pile.append(card)
	emit_signal("state_changed")
	return true

# ------------------------------------
# INTERNAL HELPERS
# ------------------------------------
func _remove_from_source(card: Dictionary, from_satchel: bool):
	if from_satchel:
		satchel.erase(card)
	else:
		adventure_field.erase(card)

func _on_card_resolved():
	cards_resolved_this_adventure += 1
	print("Cards resolved this adventure: ", cards_resolved_this_adventure)

	# Need to resolve 3 of 4 before moving on
	if cards_resolved_this_adventure >= 3:
		_end_adventure()

func _end_adventure():
	print("Adventure complete!")

	# One remaining card carries over
	if adventure_field.size() == 1:
		carried_over_card = adventure_field[0]
		adventure_field = []

	if deck.size() == 0 and adventure_field.size() == 0:
		print("YOU WIN!")
		emit_signal("game_won")
		return

	_deal_adventure()

func _check_vitality():
	if vitality <= 0:
		vitality = 0
		print("GAME OVER - Vitality depleted!")
		emit_signal("game_over", "The Fool's journey has ended.")
		
func deploy_helper(helper_card: Dictionary, target_card: Dictionary, helper_from_satchel: bool = false) -> bool:
	if helper_card.role != CardData.ROLE_HELPER:
		return false
	if helper_card.suit != target_card.suit:
		print("Helper suit doesn't match target!")
		return false
	if target_card.get("doubled", false):
		print("Card already doubled!")
		return false
	if equipped_wisdom.size() == 0:
		print("Need at least one Wisdom card to deploy a Helper!")
		return false

	# Pay cost - discard one equipped wisdom card
	var wisdom_card = equipped_wisdom[0]
	equipped_wisdom.remove_at(0)
	discard_pile.append(wisdom_card)
	print("Wisdom spent: ", wisdom_card.name)

	# Double the target card's value and flag it
	target_card["value"] = target_card["value"] * 2
	target_card["doubled"] = true

	# Discard the helper
	_remove_from_source(helper_card, helper_from_satchel)
	discard_pile.append(helper_card)

	emit_signal("state_changed")
	print("Helper deployed! ", target_card.name, " value doubled to ", target_card.value)
	return true
