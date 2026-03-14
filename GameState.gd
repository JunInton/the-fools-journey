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

# Specific audio signals so AudioManager knows exactly what happened
# One signal per meaningful audio moment - keeps sounds from stacking up
signal sfx_card_deal
signal sfx_card_discard
signal sfx_card_equip
signal sfx_challenge_resolved
signal sfx_vitality_heal
signal sfx_vitality_damage
signal sfx_shuffle
signal sfx_sword_hit
signal sfx_wisdom_equip

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

# Guard flag for Chance interaction quirks
var _adventure_end_pending: bool = false

# Tracks the last challenge involved in ending the game
# Read by WinScreen and LoseScreen to display the final card
var last_resolved_challenge = null  # last challenge successfully overcome
var last_fatal_challenge = null     # challenge that drained final vitality

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

	# Carry-over card goes in first, in the leftmost position
	if carried_over_card != null:
		adventure_field.append(carried_over_card)
		carried_over_card = null

	# Fill remaining slots from the deck
	# pop_back() takes from the end of the array - like JS .pop()
	while adventure_field.size() < ADVENTURE_FIELD_SIZE and deck.size() > 0:
		adventure_field.append(deck.pop_back())
		emit_signal("sfx_card_deal")

	print("Adventure dealt. Field: ", adventure_field.size(), 
		" cards. Deck remaining: ", deck.size())

# ------------------------------------
# ACTIONS
# These are the things the player can DO.
# Each returns true/false for success.
# ------------------------------------

# Move a card from adventure field into the satchel
# Now uses _remove_from_source so storing a card correctly
# counts toward the 3 needed to end the adventure
func store_in_satchel(card: Dictionary) -> bool:
	if satchel.size() >= MAX_SATCHEL:
		print("Satchel is full!")
		return false
	if card.role == CardData.ROLE_CHALLENGE:
		print("Cannot store a Challenge card!")
		return false

	# _remove_from_source handles adventure field tracking
	# previously this was adventure_field.erase(card) directly
	# which bypassed _on_card_resolved entirely
	_remove_from_source(card, false)
	satchel.append(card)
	emit_signal("sfx_card_equip")
	emit_signal("state_changed")
	print("Stored in satchel: ", card.name)
	return true

# Discard a non-challenge card from field or satchel
# Same fix - now routes through _remove_from_source
# so field discards correctly count toward adventure completion
func discard_card(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role == CardData.ROLE_CHALLENGE:
		print("Cannot discard a Challenge card!")
		return false

	# _remove_from_source handles both satchel and field removal
	# and triggers _on_card_resolved when card leaves the field
	_remove_from_source(card, from_satchel)
	discard_pile.append(card)
	emit_signal("sfx_card_discard")
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
	emit_signal("sfx_wisdom_equip")
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
	emit_signal("sfx_card_equip")
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
	emit_signal("sfx_card_equip")
	emit_signal("state_changed")
	print("Equipped volition: ", card.name)
	return true

# Use an Ace (Chance) - reshuffle adventure field into deck
func use_chance(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_CHANCE:
		return false
	
	# ← Cancel any deferred _end_adventure() from a recent card resolution
	# Without this, the timer fires after use_chance() already dealt new cards
	# resulting in a double deal
	_adventure_end_pending = false
	
	# ← CHANGED: erase directly instead of _remove_from_source()
	# _remove_from_source() would trigger _on_card_resolved() which
	# queues _end_adventure() — but use_chance() handles its own deal,
	# so we skip that path entirely to prevent a double deal
	if from_satchel:
		satchel.erase(card)
	else:
		adventure_field.erase(card)
	discard_pile.append(card)

	# Shuffle adventure field back into deck
	for field_card in adventure_field:
		deck.append(field_card)
	adventure_field = []
	
	# ← NEW: clear any carried over card back into the deck too
	# If a carried_over_card was set from the previous adventure,
	# _deal_adventure() would place it at position 0 of the new field
	# making it look like a card never got reshuffled.
	# Taking a Chance should reshuffle everything including this card.
	if carried_over_card != null:
		deck.append(carried_over_card)
		carried_over_card = null
	
	_shuffle_deck()
	_deal_adventure()
	emit_signal("sfx_shuffle")
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
		last_resolved_challenge = challenge
		discard_pile.append(equipped_volition)
		discard_pile.append(challenge)
		equipped_volition = null
		_remove_from_source(challenge, false)
		emit_signal("sfx_challenge_resolved")
	else:
		# Deplete the challenge
		print("Volition depletes challenge by ", vol_value)
		challenge.value -= vol_value
		discard_pile.append(equipped_volition)
		equipped_volition = null
		emit_signal("sfx_sword_hit")
	
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
		last_resolved_challenge = challenge
		discard_pile.append(equipped_strength)
		discard_pile.append(challenge)
		equipped_strength = null
		_remove_from_source(challenge, false)
		emit_signal("sfx_challenge_resolved")
	elif str_value > challenge_value:
		# Strength wins - challenge discarded, strength depleted
		print("Challenge ENDURED, Strength depleted by ", challenge_value)
		last_resolved_challenge = challenge
		equipped_strength.value -= challenge_value
		discard_pile.append(challenge)
		_remove_from_source(challenge, false)
		emit_signal("sfx_challenge_resolved")
	else:
		# Challenge wins - both discarded, Fool takes damage
		var damage = challenge_value - str_value
		print("Challenge ENDURED at cost! Fool takes ", damage, " damage")
		last_resolved_challenge = challenge
		last_fatal_challenge = challenge
		vitality -= damage
		discard_pile.append(equipped_strength)
		discard_pile.append(challenge)
		equipped_strength = null
		_remove_from_source(challenge, false)
		_check_vitality()
		emit_signal("sfx_vitality_damage")

	emit_signal("state_changed")
	return true

# Resolve a challenge directly (pay vitality)
# Now uses _remove_from_source like all other resolution functions
func resolve_directly(challenge: Dictionary) -> bool:
	if challenge.role != CardData.ROLE_CHALLENGE:
		return false

	vitality -= challenge.value
	emit_signal("sfx_vitality_damage")
	print("Challenge resolved directly! Vitality cost: ", challenge.value)
	last_fatal_challenge = challenge
	last_resolved_challenge = challenge
	discard_pile.append(challenge)
	# _remove_from_source replaces the old adventure_field.erase() + _on_card_resolved()
	# pattern - one call handles both removal and adventure completion check
	_remove_from_source(challenge, false)
	_check_vitality()
	emit_signal("state_changed")
	return true

# Replenish vitality using a Cups card
func replenish_vitality(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_VITALITY:
		return false

	var healed = min(card.value, MAX_VITALITY - vitality)  # can't exceed 25
	vitality += healed
	emit_signal("sfx_vitality_heal")
	print("Vitality replenished by ", healed, ". Now at: ", vitality)
	_remove_from_source(card, from_satchel)
	discard_pile.append(card)
	emit_signal("state_changed")
	return true

# ------------------------------------
# INTERNAL HELPERS
# ------------------------------------
# Central removal function called whenever a card leaves a zone
# Now tracks adventure field removals to trigger adventure completion
# Previously only challenge resolution counted - this was the bug
func _remove_from_source(card: Dictionary, from_satchel: bool):
	if from_satchel:
		satchel.erase(card)
	else:
		# Card is leaving the adventure field - count it
		# erase() returns true if the card was found and removed
		var was_in_field = adventure_field.has(card)
		adventure_field.erase(card)
		if was_in_field:
			_on_card_resolved()

func _on_card_resolved():
	# NEW: Don't deal a new adventure if the game is already lost
	# resolve_directly() removes the card (triggering this function) before
	# checking vitality, so we could end up dealing new cards and showing
	# the lose screen at the same time. Bail out early if vitality is gone.
	if vitality <= 0:
		return
	
	cards_resolved_this_adventure += 1
	print("Cards resolved this adventure: ", cards_resolved_this_adventure)

	# Count remaining challenges across deck and adventure field
	# The player wins as soon as the last challenge is resolved —
	# no need to clear leftover non-challenge cards from the field
	var challenges_in_deck = 0
	for c in deck:
		if c.role == CardData.ROLE_CHALLENGE:
			challenges_in_deck += 1

	var challenges_in_field = 0
	for c in adventure_field:
		if c.role == CardData.ROLE_CHALLENGE:
			challenges_in_field += 1

	if challenges_in_deck == 0 and challenges_in_field == 0:
		print("YOU WIN! All challenges resolved!")
		emit_signal("game_won")
		return

	# Need 3 of 4 cards resolved before dealing the next adventure
	if cards_resolved_this_adventure >= 3:
		_adventure_end_pending = true # flag that a deal is incoming
		# Delay _end_adventure() slightly so challenge_resolved
		# SFX has time to play before card_deal fires on the new deal.
		# create_timer() is non-blocking - like setTimeout() in JS.
		await get_tree().create_timer(0.4).timeout
		if _adventure_end_pending:
			_adventure_end_pending = false
			_end_adventure()

func _end_adventure():
	print("Adventure complete!")

	# The one unresolved card carries over to the next adventure
	# Per the rules, exactly one card remains when 3 of 4 are resolved
	if adventure_field.size() == 1:
		carried_over_card = adventure_field[0]
		adventure_field = []
	elif adventure_field.size() == 0:
		carried_over_card = null

	# Check win condition - deck empty and no cards left to resolve
	if deck.size() == 0 and adventure_field.size() == 0 and carried_over_card == null:
		print("YOU WIN!")
		emit_signal("game_won")
		return

	# Deal the next adventure
	_deal_adventure()
	emit_signal("state_changed")

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

	emit_signal("sfx_card_discard")
	emit_signal("state_changed")
	print("Helper deployed! ", target_card.name, " value doubled to ", target_card.value)
	return true
	
# Called when player drags an equipped card to the discard pile
# Unequips the card and discards it cleanly
func unequip_strength_to_discard() -> bool:
	if equipped_strength == null:
		return false
	discard_pile.append(equipped_strength)
	equipped_strength = null
	emit_signal("sfx_card_discard")
	emit_signal("state_changed")
	print("Strength unequipped and discarded.")
	return true

func unequip_volition_to_discard() -> bool:
	if equipped_volition == null:
		return false
	discard_pile.append(equipped_volition)
	equipped_volition = null
	emit_signal("sfx_card_discard")
	emit_signal("state_changed")
	print("Volition unequipped and discarded.")
	return true
	
func unequip_wisdom_to_discard(card: Dictionary) -> bool:
	if equipped_wisdom.is_empty():
		return false
	if not equipped_wisdom.has(card):
		return false
	equipped_wisdom.erase(card)
	discard_pile.append(card)
	emit_signal("sfx_card_discard")
	emit_signal("state_changed")
	return true
