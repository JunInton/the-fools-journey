extends Node

# ------------------------------------
# THEME DEFINITIONS
# Each theme is a Dictionary containing all the visual and audio
# data for that theme. Adding a new theme means adding a new
# entry here - no other files need to change.
# Like a CSS theme object or a React theme context value.
# ------------------------------------

# The two available themes
const THEME_RWS = "rws"          # Rider-Waite-Smith (default)
const THEME_PERSONA3 = "persona3"  
const THEME_PERSONA5 = "persona5"

# Cycle order for the secret code
const THEME_CYCLE = [THEME_RWS, THEME_PERSONA3, THEME_PERSONA5]

# Currently active theme - starts as RWS
var current_theme: String = THEME_RWS

# Tracks where the Rules screen should return to
# Set before navigating to RulesScreen
var rules_return_scene: String = "res://MainMenu.tscn"

# Theme data - colors, names, and eventually music/image paths
# Colors are defined per suit so card rendering can read from here
var themes = {
	THEME_RWS: {
		"name": "The Fool's Journey",
		"subtitle": "A Tarot Solitaire Game\nby Desmond Meraz",
		"background": Color(0.08, 0.05, 0.15),
		"suit_colors": {
			"cups":   Color(0.2, 0.4, 0.8),   # blue
			"batons": Color(0.2, 0.6, 0.2),   # green
			"swords": Color(0.7, 0.2, 0.2),   # red
			"coins":  Color(0.7, 0.6, 0.1),   # gold
			"major":  Color(0.4, 0.1, 0.6),   # purple
		},
		"zone_colors": {
			"discard":   Color(0.15, 0.15, 0.2),
			"adventure": Color(0.1, 0.2, 0.1),
			"deck":      Color(0.15, 0.15, 0.2),
			"wisdom":    Color(0.3, 0.25, 0.05),
			"fool":      Color(0.2, 0.1, 0.3),
			"satchel":   Color(0.1, 0.2, 0.25),
		},
		"label_color": Color(0.9, 0.85, 0.6),
		"music_path": "",   # we'll fill these in when adding audio
		"sfx_path": "",
		"music": {
			"menu": "res://assets/audio/music/rws_menu.ogg",
			"game": "res://assets/audio/music/rws_game.ogg",
			"win":  "res://assets/audio/music/rws_win.ogg",
			"lose": "res://assets/audio/music/rws_lose.ogg",
		}
	},
	# Persona 3 palette: dark navy background, cyan/light blues,
	# gold accents. Based on https://www.color-hex.com/color-palette/95744
	THEME_PERSONA3: {
		"name": "Memento Mori",
		"subtitle": "\"Only those who have the power\nto face the shadows may proceed.\"",
		"background": Color8(0, 23, 54),        # #001736 - deep navy
		"suit_colors": {
			# Each suit gets a distinct color drawn from the P3 palette
			"cups":   Color8(0, 187, 250),      # #00bbfa - bright cyan
			"batons": Color8(255, 197, 74),      # #ffc54a - gold
			"swords": Color8(121, 215, 253),     # #79d7fd - light blue
			"coins":  Color8(255, 197, 74),      # #ffc54a - gold
			"major":  Color8(0, 24, 62),         # #00183e - darkest navy, lightened for visibility
		},
		"zone_colors": {
			"discard":   Color8(0, 24, 62),      # #00183e
			"adventure": Color8(0, 30, 75),      # slightly lighter navy
			"deck":      Color8(0, 24, 62),      # #00183e
			"wisdom":    Color8(40, 60, 20),     # muted gold-green
			"fool":      Color8(0, 50, 90),      # mid navy
			"satchel":   Color8(10, 40, 80),     # dark blue
		},
		"label_color": Color8(255, 197, 74),     # #ffc54a gold
		"music_path": "",
		"sfx_path": "",
		"music": {
			"menu": "res://assets/audio/music/persona3_menu.ogg",
			"game": "res://assets/audio/music/persona3_game.ogg",
			"win":  "res://assets/audio/music/persona3_win.ogg",
			"lose": "res://assets/audio/music/persona3_lose.ogg",
		}
	},
	# Persona 5 palette: near-black background, high contrast reds,
	# bright yellow accents. Based on https://www.color-hex.com/color-palette/1019867
	THEME_PERSONA5: {
		"name": "Thou Art a Rebel",
		"subtitle": "\"Welcome to the Metaverse.\"\nSteal the hearts of the corrupt.",
		"background": Color8(13, 13, 13),        # #0d0d0d - near black
		"suit_colors": {
			"cups":   Color8(115, 36, 36),       # #732424 - dark red
			"batons": Color8(217, 35, 35),       # #d92323 - bright red
			"swords": Color8(242, 232, 82),      # #f2e852 - bright yellow
			"coins":  Color8(140, 103, 35),      # #8c6723 - dark gold
			"major":  Color8(217, 35, 35),       # #d92323 - signature P5 red
		},
		"zone_colors": {
			"discard":   Color8(30, 10, 10),     # very dark red-black
			"adventure": Color8(20, 5, 5),       # near black with red tint
			"deck":      Color8(30, 10, 10),     # very dark red-black
			"wisdom":    Color8(40, 30, 5),      # dark gold-black
			"fool":      Color8(40, 5, 5),       # deep red-black
			"satchel":   Color8(15, 15, 15),     # slightly lighter black
		},
		"label_color": Color8(242, 232, 82),     # #f2e852 bright yellow
		"music_path": "",
		"sfx_path": "",
		"music": {
			"menu": "res://assets/audio/music/persona5_menu.ogg",
			"game": "res://assets/audio/music/persona5_game.ogg",
			"win":  "res://assets/audio/music/persona5_win.ogg",
			"lose": "res://assets/audio/music/persona5_lose.ogg",
		}
	}
}

# Signal fires when theme changes so all active scenes can re-render
# Like a React context update that triggers re-renders in consumers
signal theme_changed(new_theme: String)

func get_current() -> Dictionary:
	return themes[current_theme]

func get_suit_color(suit: String) -> Color:
	return themes[current_theme]["suit_colors"].get(suit, Color(0.3, 0.3, 0.3))

func get_zone_color(zone: String) -> Color:
	return themes[current_theme]["zone_colors"].get(zone, Color(0.2, 0.2, 0.2))

func switch_theme(theme_name: String):
	if theme_name not in themes:
		return
	current_theme = theme_name
	print("Theme switched to: ", themes[theme_name]["name"])
	emit_signal("theme_changed", theme_name)

# Cycles through THEME_CYCLE order: RWS → Persona3 → Persona5 → RWS → ...
func cycle_theme():
	var current_index = THEME_CYCLE.find(current_theme)
	# find() returns -1 if not found - wrap to 0 as a fallback
	var next_index = (current_index + 1) % THEME_CYCLE.size()
	switch_theme(THEME_CYCLE[next_index])
	
func get_music_path(screen: String) -> String:
	# Returns the music path for the current theme and screen context
	# Falls back to empty string if the file doesn't exist yet
	var path = themes[current_theme]["music"].get(screen, "")
	if path == "" or not FileAccess.file_exists(path):
		# Try falling back to RWS if current theme has no music yet
		path = themes[THEME_RWS]["music"].get(screen, "")
	if not FileAccess.file_exists(path):
		return ""
	return path

func get_rules_text() -> String:
	return \
"""OVERVIEW
The Fool embarks on a journey, acquiring wisdom and overcoming challenges. Begin with 25 Vitality. The deck contains 77 cards (the full tarot minus The Fool). Deal 4 cards to the Adventure Field to begin.

OBJECTIVE
Overcome every Major Arcana challenge and reach the end of the deck with at least 1 Vitality remaining.

------------------------------
THE CARDS
------------------------------

Major Arcana — Challenges
The 21 numbered Major Arcana are Challenges. Each has a value equal to its number. Challenges cannot be simply discarded — they must be overcome.

Pentacles — Wisdom
Equip up to 3 Pentacles cards (including face cards). Spend one Wisdom card to deploy a Helper onto a same-suit card.

Wands — Strength
Equip up to 1 Wands pip card (face cards cannot be equipped as Strength). Reusable — the Strength card stays equipped unless the challenge value exceeds your Strength, in which case both are discarded and you take the difference as damage.

Swords — Volition
Equip up to 1 Swords pip card (face cards cannot be equipped as Volition). Single use — always discarded after being used to overcome a Challenge.

Cups — Vitality
Discard to restore Vitality equal to the card's value, up to a maximum of 25. The Fool can never exceed 25 Vitality.

Aces — Chance
Discard from the Adventure Field or Satchel to reshuffle all current Adventure Field cards back into the deck and deal 4 new cards.

Face Cards — Helpers
Spend 1 Wisdom card to place a face card under a same-suit card in the Adventure Field, Satchel, or equipped Strength/Volition slot. Doubles the target card's current value. Each card can only have one Helper at a time. Helpers attached to Healing cards in the Satchel do not count toward the 3-card Satchel limit.

------------------------------
ACTIONS
------------------------------
Each turn you may take any number of actions in any order.

  Discard        Send any non-Challenge card to the discard pile.
                 Any Helper attached to it is also discarded.

  Store          Place a Minor Arcana card in the Satchel (max 3 cards).

  Equip          Place a Wisdom, Strength, or Volition card in its slot.
                 Only 1 Strength and 1 Volition can be equipped at a time.
                 Up to 3 Wisdom cards can be equipped at a time.

  Deploy Helper  Spend 1 Wisdom card to double a same-suit card's value.

  Heal           Discard a Cups card to restore Vitality.

  Take a Chance  Discard an Ace to reshuffle the Adventure Field.

  Overcome       Use Strength, Volition, or raw Vitality against a Challenge.

------------------------------
OVERCOMING CHALLENGES
------------------------------

Using Strength
  Equal or Greater:  Both the Strength card and Challenge are discarded.
  Less:              Both cards are discarded. The Fool loses Vitality
                     equal to the difference between the two values.

Using Volition
  Equal:    Both the Volition card and Challenge are discarded.
  Greater:  Volition is discarded. The Challenge remains in the field
            with its value permanently reduced by the Volition's value.
  Less:     Both cards are discarded. The Fool loses Vitality equal to
            the difference between the Challenge and Volition values.

Using Vitality
  Subtract the Challenge's value directly from the Fool's Vitality.
  The Challenge is then discarded.

------------------------------
ADVENTURE ROUNDS
------------------------------
When only 1 card remains in the Adventure Field, deal 3 more cards to begin a new Adventure round.

------------------------------
WINNING AND LOSING
------------------------------
  Loss  Vitality reaches 0 or below.
  Win   All Challenges overcome and the deck is exhausted.
  Tie   If Vitality hits 0 on the very final Challenge, consider the
		story created by the journey to decide the outcome."""
