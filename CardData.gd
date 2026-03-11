extends Node

# ------------------------------------
# ROLES - what each card does in game
# ------------------------------------
const ROLE_FOOL = "fool"
const ROLE_CHALLENGE = "challenge"
const ROLE_VITALITY = "vitality"
const ROLE_STRENGTH = "strength"
const ROLE_VOLITION = "volition"
const ROLE_WISDOM = "wisdom"
const ROLE_HELPER = "helper"
const ROLE_CHANCE = "chance"

# ------------------------------------
# SUITS
# ------------------------------------
const SUIT_MAJOR = "major"
const SUIT_CUPS = "cups"
const SUIT_BATONS = "batons"
const SUIT_SWORDS = "swords"
const SUIT_COINS = "coins"

# ------------------------------------
# The full 78-card deck definition
# Each card is a Dictionary - like a JS object
# ------------------------------------
var all_cards: Array = []

func _ready():
	_build_deck()
	print("Deck built! Total cards: ", all_cards.size())

func _build_deck():
	all_cards.clear()

	# --- THE FOOL (set aside at game start) ---
	all_cards.append(_card("The Fool", SUIT_MAJOR, 0, ROLE_FOOL, 0))

	# --- MAJOR ARCANA (Trumps 1-21) = Challenges ---
	var major_names = [
		"The Magician", "The High Priestess", "The Empress",
		"The Emperor", "The Hierophant", "The Lovers",
		"The Chariot", "Strength", "The Hermit",
		"Wheel of Fortune", "Justice", "The Hanged Man",
		"Death", "Temperance", "The Devil",
		"The Tower", "The Star", "The Moon",
		"The Sun", "Judgement", "The World"
	]
	for i in range(major_names.size()):
		var power = i + 1  # Magician=1, World=21
		all_cards.append(_card(major_names[i], SUIT_MAJOR, power, ROLE_CHALLENGE, power))

	# --- MINOR ARCANA ---
	# We'll build each suit using a helper loop
	_build_suit(SUIT_CUPS)
	_build_suit(SUIT_BATONS)
	_build_suit(SUIT_SWORDS)
	_build_suit(SUIT_COINS)

func _build_suit(suit: String):
	var suit_label = suit.capitalize()  # "cups" -> "Cups"

	# Ace = Chance for all suits
	all_cards.append(_card("Ace of " + suit_label, suit, 1, ROLE_CHANCE, 0))

	# Pip cards 2-10
	for n in range(2, 11):
		var role = _pip_role(suit)
		all_cards.append(_card(str(n) + " of " + suit_label, suit, n, role, n))

	# Royal cards - Page, Knight, Queen, King
	var royals = ["Page", "Knight", "Queen", "King"]
	for royal in royals:
		var role = _royal_role(suit)
		# Coins royals are Wisdom (value 1), others are Helpers
		var value = 1 if suit == SUIT_COINS else 0
		all_cards.append(_card(royal + " of " + suit_label, suit, 0, role, value))

# ------------------------------------
# Helper functions
# ------------------------------------

# Builds a card dictionary - like a JS object factory function
func _card(card_name: String, suit: String, rank: int, role: String, value: int) -> Dictionary:
	return {
		"name": card_name,
		"suit": suit,
		"rank": rank,
		"role": role,
		"value": value
	}

# Returns the pip role based on suit
func _pip_role(suit: String) -> String:
	match suit:  # match = JS switch statement
		SUIT_CUPS:    return ROLE_VITALITY
		SUIT_BATONS:  return ROLE_STRENGTH
		SUIT_SWORDS:  return ROLE_VOLITION
		SUIT_COINS:   return ROLE_WISDOM
	return ""

# Royal cards: Coins = Wisdom, all others = Helper
func _royal_role(suit: String) -> String:
	if suit == SUIT_COINS:
		return ROLE_WISDOM
	return ROLE_HELPER

# ------------------------------------
# IMAGE PATH RESOLVER
# Translates card data into a file path for the card's image.
# Returns empty string if no image exists for the current theme,
# which Card.gd uses to fall back to colored rectangle display.
# ------------------------------------
func get_card_image_path(card: Dictionary) -> String:
	# Only RWS theme has images currently
	# Persona themes fall back to colored rectangles until
	# their own image sets are added later
	if ThemeManager.current_theme != ThemeManager.THEME_RWS:
		return ""
	return "res://assets/cards/rws/" + _get_rws_filename(card)

func _get_rws_filename(card: Dictionary) -> String:
	var suit = card.get("suit", "")
	var rank = card.get("rank", 0)
	var card_name = card.get("name", "")

	# Major Arcana: maj00.jpg through maj21.jpg
	if suit == SUIT_MAJOR:
		return "maj%02d.jpg" % rank

	# Minor Arcana prefix per suit
	var prefix = ""
	match suit:
		SUIT_BATONS: prefix = "wands"
		SUIT_CUPS:   prefix = "cups"
		SUIT_SWORDS: prefix = "swords"
		SUIT_COINS:  prefix = "pents"

	if prefix == "":
		return ""

	# Ace through 10 use rank directly as two digit number
	if rank >= 1 and rank <= 10:
		return prefix + "%02d.jpg" % rank

	# Royal cards have rank 0 in our data so we identify by name
	if "Page" in card_name:   return prefix + "11.jpg"
	if "Knight" in card_name: return prefix + "12.jpg"
	if "Queen" in card_name:  return prefix + "13.jpg"
	if "King" in card_name:   return prefix + "14.jpg"

	return ""
