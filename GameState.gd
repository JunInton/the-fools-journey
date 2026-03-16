extends Node

# ------------------------------------
# SIGNALS
# GameState communicates with the rest of the game exclusively through
# signals. Other nodes connect to these and react when they fire —
# this keeps game logic cleanly separated from rendering and audio.
# ------------------------------------

# Core game flow
signal state_changed   # fires after any game state update
signal game_over(reason: String)
signal game_won

# Fired when the player double-clicks the discard pile area
@warning_ignore("unused_signal")
signal discard_viewer_requested

# Fired just before the adventure field is cleared by an Ace reshuffle,
# giving Main.gd time to set animation flags before nodes are removed
signal sfx_reshuffle_start

# Drag-and-drop lifecycle — used by Main.gd to suppress movement animations
# while the player is dragging a card (the drag preview handles visual feedback)
signal drag_started
signal drag_ended

# ------------------------------------
# PRE-ANIMATION SIGNALS
# These fire immediately before the corresponding state change occurs.
# Main.gd connects to them to capture card node positions and queue
# animations before those nodes are freed by the next state_changed render.
# ------------------------------------
signal anim_strength_vs_challenge(strength_id: int, challenge_id: int)
signal anim_strength_survives(strength_id: int, challenge_id: int)
signal anim_volition_vs_challenge(volition_id: int, challenge_id: int)
signal anim_fool_vs_challenge(challenge_id: int)
signal anim_challenge_damaged(challenge_id: int)
signal anim_helper_deployed(helper_id: int, target_id: int)
signal anim_vitality_heal(vitality_id: int)

# ------------------------------------
# AUDIO SIGNALS
# One signal per meaningful game audio moment.
# AudioManager connects to these and plays the appropriate sound effect.
# ------------------------------------
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
# All mutable game data lives here as Autoload-accessible variables.
# Main.gd reads these on every state_changed to rebuild the display.
# ------------------------------------

var deck: Array = []            # draw pile — array of card Dictionaries
var adventure_field: Array = [] # the 4 cards currently in play
var satchel: Array = []         # player's storage bag, max 3 cards
var discard_pile: Array = []    # all used and discarded cards

var vitality: int = 25
const MAX_VITALITY = 25
const MAX_SATCHEL = 3
const ADVENTURE_FIELD_SIZE = 4

var equipped_wisdom: Array = []  # up to 3 Pentacles cards
var equipped_strength = null     # one Wands pip card or null
var equipped_volition = null     # one Swords pip card or null

# Counts how many cards have left the adventure field this round.
# When this reaches 3, the adventure ends and 3 new cards are dealt.
var cards_resolved_this_adventure: int = 0

# The one card that carries over to the next adventure when a round ends
var carried_over_card = null

# Guards against double-dealing when use_chance() cancels a pending
# _end_adventure() timer that was already counting down
var _adventure_end_pending: bool = false

# Stored at game end so win/lose screens can display the final card
var last_resolved_challenge = null  # last challenge successfully overcome
var last_fatal_challenge = null     # challenge that drained the last Vitality

# Incremented each time start_game() assigns IDs so every card across
# every game gets a unique integer identity
var _next_card_id: int = 0

# Stored when an Ace is used so Main.gd can exclude it from the
# reshuffle animation (the Ace itself goes to discard, not back to the deck)
var _last_chance_card_id: int = -1

# ------------------------------------
# SETUP
# ------------------------------------
func _ready():
	pass  # start_game() is called explicitly by Main.gd after the scene is ready

func start_game():
	# Build a fresh 77-card deck from CardData, excluding The Fool
	deck = []
	for card in CardData.all_cards:
		if card.role != CardData.ROLE_FOOL:
			deck.append(card.duplicate()) # .duplicate() is like JS spread {...card} — creates a fresh copy so cards don't share references

	_shuffle_deck()

	# Assign a unique integer _id to every card so Main.gd can maintain
	# a persistent node registry across state changes and zone transitions
	_next_card_id = 0
	for card in deck:
		card["_id"] = _next_card_id
		_next_card_id += 1

	# The Fool lives outside the deck permanently and gets a fixed ID of -1
	CardData.all_cards[0]["_id"] = -1

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

# ------------------------------------
# DECK MANAGEMENT
# ------------------------------------
func _shuffle_deck():
	deck.shuffle() # Godot's built-in shuffle, like JS array sort hack but actually random

func _deal_adventure():
	adventure_field = []
	cards_resolved_this_adventure = 0

	# The carry-over card from the previous round goes in position 0
	if carried_over_card != null:
		adventure_field.append(carried_over_card)
		carried_over_card = null

	# Fill remaining slots by drawing from the top of the deck
	while adventure_field.size() < ADVENTURE_FIELD_SIZE and deck.size() > 0:
		adventure_field.append(deck.pop_back()) # pop_back() removes and returns the last element — like JS .pop()
		emit_signal("sfx_card_deal")

# ------------------------------------
# PLAYER ACTIONS
# Each action function validates the move, updates state, emits the
# appropriate signals, and returns true/false for success.
# ------------------------------------

func store_in_satchel(card: Dictionary) -> bool:
	if satchel.size() >= MAX_SATCHEL:
		return false
	if card.role == CardData.ROLE_CHALLENGE:
		return false
	# Routes through _remove_from_source so the adventure field's
	# resolved card count is tracked correctly
	_remove_from_source(card, false)
	satchel.append(card)
	emit_signal("sfx_card_equip")
	emit_signal("state_changed")
	return true

func discard_card(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role == CardData.ROLE_CHALLENGE:
		return false
	_remove_from_source(card, from_satchel)
	discard_pile.append(card)
	emit_signal("sfx_card_discard")
	emit_signal("state_changed")
	return true

func equip_wisdom(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_WISDOM:
		return false
	if equipped_wisdom.size() >= 3:
		return false
	_remove_from_source(card, from_satchel)
	equipped_wisdom.append(card)
	emit_signal("sfx_wisdom_equip")
	emit_signal("state_changed")
	return true

func equip_strength(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_STRENGTH:
		return false
	# If a Strength card is already equipped, discard it first
	if equipped_strength != null:
		discard_pile.append(equipped_strength)
	_remove_from_source(card, from_satchel)
	equipped_strength = card
	emit_signal("sfx_card_equip")
	emit_signal("state_changed")
	return true

func equip_volition(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_VOLITION:
		return false
	# If a Volition card is already equipped, discard it first
	if equipped_volition != null:
		discard_pile.append(equipped_volition)
	_remove_from_source(card, from_satchel)
	equipped_volition = card
	emit_signal("sfx_card_equip")
	emit_signal("state_changed")
	return true

func use_chance(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_CHANCE:
		return false

	# Cancel any pending _end_adventure() timer — use_chance() handles
	# its own deal, so letting the timer fire would cause a double deal
	_adventure_end_pending = false

	# Erase directly rather than through _remove_from_source() to avoid
	# triggering _on_card_resolved(), which would also queue _end_adventure()
	if from_satchel:
		satchel.erase(card)
	else:
		adventure_field.erase(card)
	discard_pile.append(card)

	# Store the Ace's ID and emit the reshuffle signal before clearing the
	# adventure field so Main.gd can set its animation flags in time
	_last_chance_card_id = card.get("_id", -1)
	emit_signal("sfx_reshuffle_start")

	# Return all adventure field cards to the deck and reshuffle
	for field_card in adventure_field:
		deck.append(field_card)
	adventure_field = []

	# Also return the carry-over card if one is waiting — otherwise it would
	# appear in the new field as if it was never reshuffled
	if carried_over_card != null:
		deck.append(carried_over_card)
		carried_over_card = null

	_shuffle_deck()
	_deal_adventure()
	emit_signal("sfx_shuffle")
	emit_signal("state_changed")
	return true

func resolve_with_volition(challenge: Dictionary) -> bool:
	if equipped_volition == null:
		return false
	if challenge.role != CardData.ROLE_CHALLENGE:
		return false

	var vol_value = equipped_volition.value
	var challenge_value = challenge.value

	# Emit pre-animation signal before any state changes so Main.gd can
	# capture node positions for the collision animation
	emit_signal("anim_volition_vs_challenge",
		equipped_volition.get("_id", -1),
		challenge.get("_id", -1))

	if vol_value >= challenge_value:
		# Volition meets or exceeds challenge — both cards are discarded
		last_resolved_challenge = challenge
		discard_pile.append(equipped_volition)
		discard_pile.append(challenge)
		equipped_volition = null
		_remove_from_source(challenge, false)
		emit_signal("sfx_challenge_resolved")
	else:
		# Volition falls short — challenge value is reduced and survives,
		# Volition card is still discarded
		challenge.value -= vol_value
		discard_pile.append(equipped_volition)
		equipped_volition = null
		# Emit after the value is reduced so the damage flash shows the new value
		emit_signal("anim_challenge_damaged", challenge.get("_id", -1))
		emit_signal("sfx_sword_hit")

	emit_signal("state_changed")
	return true

func resolve_with_strength(challenge: Dictionary) -> bool:
	if equipped_strength == null:
		return false
	if challenge.role != CardData.ROLE_CHALLENGE:
		return false

	var str_value = equipped_strength.value
	var challenge_value = challenge.value

	if str_value == challenge_value:
		# Exact match — both cards are discarded
		emit_signal("anim_strength_vs_challenge",
			equipped_strength.get("_id", -1), challenge.get("_id", -1))
		last_resolved_challenge = challenge
		discard_pile.append(equipped_strength)
		discard_pile.append(challenge)
		equipped_strength = null
		_remove_from_source(challenge, false)
		emit_signal("sfx_challenge_resolved")

	elif str_value > challenge_value:
		# Strength exceeds challenge — challenge is discarded, Strength stays
		# equipped with its value reduced by the challenge's value.
		# Uses a different animation signal so Main.gd plays a bounce-back
		# animation instead of a discard animation for the Strength card.
		emit_signal("anim_strength_survives",
			equipped_strength.get("_id", -1), challenge.get("_id", -1))
		last_resolved_challenge = challenge
		equipped_strength.value -= challenge_value
		discard_pile.append(challenge)
		_remove_from_source(challenge, false)
		emit_signal("sfx_challenge_resolved")

	else:
		# Challenge exceeds Strength — both are discarded and the Fool
		# takes Vitality damage equal to the difference
		emit_signal("anim_strength_vs_challenge",
			equipped_strength.get("_id", -1), challenge.get("_id", -1))
		var damage = challenge_value - str_value
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

func resolve_directly(challenge: Dictionary) -> bool:
	# The Fool takes full Vitality damage equal to the challenge's current value
	if challenge.role != CardData.ROLE_CHALLENGE:
		return false

	vitality -= challenge.value
	emit_signal("sfx_vitality_damage")
	last_fatal_challenge = challenge
	last_resolved_challenge = challenge
	discard_pile.append(challenge)

	# Emit before removing so Main.gd can capture the challenge node's position
	# for the Fool lunge animation
	emit_signal("anim_fool_vs_challenge", challenge.get("_id", -1))

	_remove_from_source(challenge, false)
	_check_vitality()
	emit_signal("state_changed")
	return true

func replenish_vitality(card: Dictionary, from_satchel: bool = false) -> bool:
	if card.role != CardData.ROLE_VITALITY:
		return false

	# Clamp healing so Vitality never exceeds the maximum
	var healed = min(card.value, MAX_VITALITY - vitality)
	vitality += healed
	emit_signal("sfx_vitality_heal")

	# Emit before removing so Main.gd can animate the card sliding to the Fool
	emit_signal("anim_vitality_heal", card.get("_id", -1))

	_remove_from_source(card, from_satchel)
	discard_pile.append(card)
	emit_signal("state_changed")
	return true

func deploy_helper(helper_card: Dictionary, target_card: Dictionary, helper_from_satchel: bool = false) -> bool:
	if helper_card.role != CardData.ROLE_HELPER:
		return false
	if helper_card.suit != target_card.suit:
		return false
	if target_card.get("doubled", false):
		return false
	if equipped_wisdom.size() == 0:
		return false

	# Spend one equipped Wisdom card as the deployment cost
	var wisdom_card = equipped_wisdom[0]
	equipped_wisdom.remove_at(0)
	discard_pile.append(wisdom_card)

	# Double the target card's value and mark it so it can't be doubled again
	target_card["value"] = target_card["value"] * 2
	target_card["doubled"] = true

	# Emit before removing the helper so Main.gd can animate it sliding
	# to the target card before flying to the discard pile
	emit_signal("anim_helper_deployed",
		helper_card.get("_id", -1),
		target_card.get("_id", -1))

	_remove_from_source(helper_card, helper_from_satchel)
	discard_pile.append(helper_card)

	emit_signal("sfx_card_discard")
	emit_signal("state_changed")
	return true

func unequip_strength_to_discard() -> bool:
	if equipped_strength == null:
		return false
	discard_pile.append(equipped_strength)
	equipped_strength = null
	emit_signal("sfx_card_discard")
	emit_signal("state_changed")
	return true

func unequip_volition_to_discard() -> bool:
	if equipped_volition == null:
		return false
	discard_pile.append(equipped_volition)
	equipped_volition = null
	emit_signal("sfx_card_discard")
	emit_signal("state_changed")
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

# ------------------------------------
# INTERNAL HELPERS
# ------------------------------------

func _remove_from_source(card: Dictionary, from_satchel: bool):
	# Central removal function for all card zone transitions.
	# Routes through here so adventure field removals are always counted,
	# which is what triggers adventure completion checks.
	if from_satchel:
		satchel.erase(card)
	else:
		var was_in_field = adventure_field.has(card)
		adventure_field.erase(card)
		if was_in_field:
			_on_card_resolved()

func _on_card_resolved():
	# Called whenever a card leaves the adventure field.
	# Checks for win conditions and triggers a new adventure deal
	# once 3 of the 4 field cards have been resolved.

	# Guard against dealing new cards when the game is already lost.
	# resolve_directly() removes the card before checking vitality,
	# so this function could otherwise fire after a fatal hit.
	if vitality <= 0:
		return

	cards_resolved_this_adventure += 1

	# Check if all Major Arcana challenges have been cleared —
	# the win condition doesn't require the full deck to be exhausted,
	# only that no challenges remain anywhere
	var challenges_in_deck = 0
	for c in deck:
		if c.role == CardData.ROLE_CHALLENGE:
			challenges_in_deck += 1

	var challenges_in_field = 0
	for c in adventure_field:
		if c.role == CardData.ROLE_CHALLENGE:
			challenges_in_field += 1

	if challenges_in_deck == 0 and challenges_in_field == 0:
		emit_signal("game_won")
		return

	# After 3 of 4 cards are resolved, wait briefly then end the adventure.
	# The delay gives SFX time to finish playing before the new deal fires.
	if cards_resolved_this_adventure >= 3:
		_adventure_end_pending = true
		await get_tree().create_timer(0.4).timeout # create_timer() is non-blocking — like setTimeout() in JS
		if _adventure_end_pending:
			_adventure_end_pending = false
			_end_adventure()

func _end_adventure():
	# The one remaining unresolved card carries over as the first card
	# of the next adventure field
	if adventure_field.size() == 1:
		carried_over_card = adventure_field[0]
		adventure_field = []
	elif adventure_field.size() == 0:
		carried_over_card = null

	# Final win check — deck exhausted with no carry-over remaining
	if deck.size() == 0 and adventure_field.size() == 0 and carried_over_card == null:
		emit_signal("game_won")
		return

	_deal_adventure()
	emit_signal("state_changed")

func _check_vitality():
	if vitality <= 0:
		vitality = 0
		emit_signal("game_over", "The Fool's journey has ended.")
