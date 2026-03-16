extends Node

# ------------------------------------
# CARD ROLES
# Defines what each card does in the game.
# Roles are used throughout the codebase to route card interactions
# to the correct game logic in GameState and Card.gd.
# ------------------------------------
const ROLE_FOOL      = "fool"
const ROLE_CHALLENGE = "challenge"
const ROLE_VITALITY  = "vitality"
const ROLE_STRENGTH  = "strength"
const ROLE_VOLITION  = "volition"
const ROLE_WISDOM    = "wisdom"
const ROLE_HELPER    = "helper"
const ROLE_CHANCE    = "chance"

# ------------------------------------
# SUITS
# The five suits map to the four Minor Arcana suits plus the Major Arcana.
# ------------------------------------
const SUIT_MAJOR  = "major"
const SUIT_CUPS   = "cups"
const SUIT_BATONS = "batons"
const SUIT_SWORDS = "swords"
const SUIT_COINS  = "coins"

# The full 78-card deck built at startup.
# Each card is a Dictionary — like a JS object literal.
var all_cards: Array = []

func _ready():
	_build_deck()

func _build_deck():
	all_cards.clear()

	# The Fool is set aside at game start and never shuffled into the deck
	all_cards.append(_card("The Fool", SUIT_MAJOR, 0, ROLE_FOOL, 0))

	# Major Arcana cards 1–21 are the Challenges.
	# Each card's rank is also its combat value.
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
		var power = i + 1  # Magician = 1, The World = 21
		all_cards.append(_card(major_names[i], SUIT_MAJOR, power, ROLE_CHALLENGE, power))

	# All four Minor Arcana suits share the same structure
	_build_suit(SUIT_CUPS)
	_build_suit(SUIT_BATONS)
	_build_suit(SUIT_SWORDS)
	_build_suit(SUIT_COINS)

func _build_suit(suit: String):
	var suit_label = suit.capitalize()  # "cups" -> "Cups"

	# Ace = Chance card for all suits
	all_cards.append(_card("Ace of " + suit_label, suit, 1, ROLE_CHANCE, 0))

	# Pip cards 2–10 get their role from their suit
	for n in range(2, 11):
		var role = _pip_role(suit)
		all_cards.append(_card(str(n) + " of " + suit_label, suit, n, role, n))

	# Face cards — Page, Knight, Queen, King
	# Coins face cards are Wisdom (value 1), all other suits are Helpers
	var royals = ["Page", "Knight", "Queen", "King"]
	for royal in royals:
		var role  = _royal_role(suit)
		var value = 1 if suit == SUIT_COINS else 0
		all_cards.append(_card(royal + " of " + suit_label, suit, 0, role, value))

# ------------------------------------
# CARD FACTORY
# Builds a card Dictionary from its components.
# Like a JS object factory function — centralizes card structure
# so the format only needs to change in one place.
# ------------------------------------
func _card(card_name: String, suit: String, rank: int, role: String, value: int) -> Dictionary:
	return {
		"name":  card_name,
		"suit":  suit,
		"rank":  rank,
		"role":  role,
		"value": value
	}

func _pip_role(suit: String) -> String:
	# Each suit's pip cards map to a specific game role:
	# Cups = Vitality (healing), Batons = Strength (combat),
	# Swords = Volition (depletion), Coins = Wisdom (currency)
	match suit:  # match is GDScript's equivalent of a JS switch statement
		SUIT_CUPS:   return ROLE_VITALITY
		SUIT_BATONS: return ROLE_STRENGTH
		SUIT_SWORDS: return ROLE_VOLITION
		SUIT_COINS:  return ROLE_WISDOM
	return ""

func _royal_role(suit: String) -> String:
	# Coins face cards are Wisdom — they're spent as currency like pip Coins.
	# All other face cards are Helpers that can double a same-suit card's value.
	if suit == SUIT_COINS:
		return ROLE_WISDOM
	return ROLE_HELPER

# ------------------------------------
# IMAGE PATH RESOLVER
# Translates card data into a file path for the card's image.
# Returns an empty string if no image exists for the current theme,
# which Card.gd uses as a signal to fall back to colored rectangle display.
# ------------------------------------
func get_card_image_path(card: Dictionary) -> String:
	match ThemeManager.current_theme:
		ThemeManager.THEME_RWS:
			var filename = _get_rws_filename(card)
			if filename == "":
				return ""
			return "res://assets/cards/rws/" + filename
		ThemeManager.THEME_PERSONA3:
			# Persona 3 uses the same filename convention as RWS, different folder
			var filename = _get_rws_filename(card)
			if filename == "":
				return ""
			return "res://assets/cards/persona3/" + filename
		_:
			# Any theme without card images falls back to colored rectangles
			return ""

func _get_rws_filename(card: Dictionary) -> String:
	var suit      = card.get("suit", "")
	var rank      = card.get("rank", 0)
	var card_name = card.get("name", "")

	# Major Arcana: maj00.jpg (The Fool) through maj21.jpg (The World)
	if suit == SUIT_MAJOR:
		return "maj%02d.jpg" % rank

	# Map suit names to the filename prefix used in the asset folder
	var prefix = ""
	match suit:
		SUIT_BATONS: prefix = "wands"
		SUIT_CUPS:   prefix = "cups"
		SUIT_SWORDS: prefix = "swords"
		SUIT_COINS:  prefix = "pents"

	if prefix == "":
		return ""

	# Ace through 10 use their rank as a zero-padded two-digit number
	if rank >= 1 and rank <= 10:
		return prefix + "%02d.jpg" % rank

	# Face cards have rank 0 in the data so are identified by name instead.
	# Page=11, Knight=12, Queen=13, King=14 matches standard tarot numbering.
	if "Page"   in card_name: return prefix + "11.jpg"
	if "Knight" in card_name: return prefix + "12.jpg"
	if "Queen"  in card_name: return prefix + "13.jpg"
	if "King"   in card_name: return prefix + "14.jpg"

	return ""
