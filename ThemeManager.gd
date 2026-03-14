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
const THEME_CYCLE = [THEME_RWS, THEME_PERSONA3]

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
		"subtitle": "A Tarot Solitaire Game",
		"background": Color(0, 0, 0),
		"rules_text_color": Color(1, 1, 1),
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
		},
		"backgrounds": {
			"menu": "res://assets/backgrounds/rws_menu.jpg",
			"win": "res://assets/backgrounds/rws_win.jpg"
		}
	},
	# Persona 3 palette: dark navy background, cyan/light blues,
	# gold accents. Based on https://www.color-hex.com/color-palette/95744
	THEME_PERSONA3: {
		"name": "The Fool's Journey",
		"subtitle": "\"Only those who have the power\nto face the shadows may proceed.\"",
		"background": Color8(153, 153, 153),        # #001736 - deep navy
		"rules_text_color": Color(0, 0, 0),
		"suit_colors": {
			# Each suit gets a distinct color drawn from the P3 palette
			"cups":   Color8(0, 187, 250),      # #00bbfa - bright cyan
			"batons": Color(0.2, 0.6, 0.2),    # green
			"swords": Color(0.7, 0.2, 0.2),     # 121, 215, 253 #79d7fd - light blue
			"coins":  Color8(255, 197, 74),      # #ffc54a - gold
			"major":  Color8(255, 255, 255),         # #00183e - darkest navy, lightened for visibility
		},
		"zone_colors": {
			"discard":   Color8(0, 24, 62),      # #00183e
			"adventure": Color8(0, 30, 75),      # slightly lighter navy
			"deck":      Color8(0, 24, 62),      # #00183e
			"wisdom":    Color8(0, 23, 54),        # black
			"fool":      Color8(0, 50, 90),      # mid navy
			"satchel":   Color8(0, 23, 54),     # dark blue
		},
		"label_color": Color8(255, 197, 74),     # #ffc54a gold
		"music_path": "",
		"sfx_path": "",
		"music": {
			"menu": "res://assets/audio/music/persona3_menu.ogg",
			"game": "res://assets/audio/music/persona3_game.ogg",
			"win":  "res://assets/audio/music/persona3_win.ogg",
			"lose": "res://assets/audio/music/persona3_lose.ogg",
		},
		"backgrounds": {
			"menu": "",
			"win": "res://assets/backgrounds/persona3_win.jpg"
		}
	},
	# Persona 5 palette: near-black background, high contrast reds,
	# bright yellow accents. Based on https://www.color-hex.com/color-palette/1019867
	THEME_PERSONA5: {
		"name": "The Fool's Journey",
		"subtitle": "\"this theme is incomplete,\"\nplease switch to another.",
		"background": Color8(255, 255, 255),        # #0d0d0d - near black
		"suit_colors": {
			"cups":   Color(0.2, 0.4, 0.8),       # #732424 - dark red
			"batons": Color(0.2, 0.6, 0.2),       # #d92323 - bright red
			"swords": Color8(217, 35, 35),      # #f2e852 - bright yellow
			"coins":  Color8(242, 232, 82),      # #8c6723 - dark gold
			"major":  Color8(255, 255, 255),       # #d92323 - signature P5 red
		},
		"zone_colors": {
			"discard":   Color8(30, 10, 10),     # very dark red-black
			"adventure": Color8(20, 5, 5),       # near black with red tint
			"deck":      Color8(30, 10, 10),     # very dark red-black
			"wisdom":    Color8(140, 103, 35),      # dark gold-black
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
		},
		"backgrounds": {
			"menu": "",
			"win": ""
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
	# CHANGED: removed FileAccess.file_exists() checks - unreliable in web exports
	# Just return the path directly and let the caller handle a failed load
	var path = themes[current_theme]["music"].get(screen, "")
	if path == "":
		# Fall back to RWS if current theme has no music for this screen
		path = themes[THEME_RWS]["music"].get(screen, "")
	return path
	
func get_background_path(screen: String) -> String:
	return themes[current_theme]["backgrounds"].get(screen, "")
	
# Call this from any screen's _ready() to apply the appropriate background.
# Handles three cases in priority order:
# 1. Image file exists at the path → show image
# 2. No image but gradient colors provided → draw gradient
# 3. Neither → fall back to flat color
func apply_screen_background(node: Control, screen: String,
		gradient_top: Color = Color.BLACK,
		gradient_bottom: Color = Color.BLACK,
		fallback_color: Color = Color.BLACK):
			
	var w = ProjectSettings.get_setting("display/window/size/viewport_width")
	var h = ProjectSettings.get_setting("display/window/size/viewport_height")

	var path = get_background_path(screen)

	# Case 1 — image
	if path != "":
		print("Background path found: ", path)
		var texture = load(path)
		print("Texture loaded: ", texture)
		if texture != null:
			var bg = TextureRect.new()
			bg.texture = texture
			bg.stretch_mode = TextureRect.STRETCH_SCALE
			bg.z_index = -1
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg.position = Vector2.ZERO
			bg.size = Vector2(w, h)
			node.add_child(bg)
			node.move_child(bg, 0)
			return

	# Case 2 — gradient
	if gradient_top != gradient_bottom:
		var g = Gradient.new()
		g.set_color(0, gradient_top)
		g.set_color(1, gradient_bottom)
		var gradient = GradientTexture2D.new()
		gradient.gradient = g
		gradient.fill_from = Vector2(0.5, 0)
		gradient.fill_to = Vector2(0.5, 1)

		var grad_rect = TextureRect.new()
		grad_rect.texture = gradient
		grad_rect.stretch_mode = TextureRect.STRETCH_SCALE
		grad_rect.z_index = -1
		grad_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grad_rect.position = Vector2.ZERO
		grad_rect.size = Vector2(w, h)
		node.add_child(grad_rect)
		node.move_child(grad_rect, 0)
		return

	# Case 3 — flat color fallback
	# CHANGED: was add_theme_stylebox_override which only works on PanelContainer
	# ColorRect works on any Control node
	var color_rect = ColorRect.new()
	color_rect.color = fallback_color
	color_rect.z_index = -1
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.position = Vector2.ZERO
	color_rect.size = Vector2(w, h)
	node.add_child(color_rect)
	node.move_child(color_rect, 0)

func get_rules_text() -> String:
	return \
"""OVERVIEW
The Fool embarks on a journey, acquiring wisdom and overcoming challenges. You begin with 25 Vitality. The deck contains 77 cards — the full tarot minus The Fool himself. Four cards are dealt to the Adventure Field to begin each round.

OBJECTIVE
Overcome every Major Arcana challenge and exhaust the deck with at least 1 Vitality remaining.

------------------------------
CONTROLS
------------------------------
Double-click any card to open its action menu. From there you can equip it, store it in the Satchel, heal with it, deploy it as a Helper, or discard it.

Drag and drop cards as an alternative to the action menu:
  - Drag a card to the Discard Pile zone to discard it.
  - Drag a card to the Wisdom, Strength, or Volition slots to equip it.
  - Drag a card to the Satchel zone to store it.
  - Drag a Vitality card onto the Fool card to heal.
  - Drag an equipped Strength or Volition card onto a Challenge to resolve it.
  - Drag the Fool card onto a Challenge to resolve it directly with Vitality.
  - Drag a Helper card onto a same-suit card to deploy it (costs 1 Wisdom).

Double-click the Discard Pile zone to view all discarded cards.

------------------------------
THE CARDS
------------------------------

Major Arcana — Challenges
The 21 numbered Major Arcana are Challenges. Each card's number is its value. Challenges cannot be discarded — they must be overcome using Strength, Volition, Vitality, or a combination of these.

Pentacles — Wisdom
Equip up to 3 Pentacles cards (including face cards) to the Wisdom slot. Each equipped Wisdom card can be spent to deploy one Helper card.

Wands — Strength
Equip one Wands pip card (not face cards) to the Strength slot. Strength is reusable — it stays equipped as long as its value exceeds the Challenge it faces. If it does not, both cards are discarded and the Fool takes the difference as damage.

Swords — Volition
Equip one Swords pip card (not face cards) to the Volition slot. Volition is single-use — it is always discarded after overcoming a Challenge.

Cups — Vitality
Double-click or drag to the Fool card to heal Vitality equal to the card's value, up to a maximum of 25.

Aces — Chance
Double-click or drag to discard an Ace and reshuffle all Adventure Field cards back into the deck, then deal 4 new cards.

Face Cards — Helpers
Spend 1 Wisdom card to double the current value of a same-suit card in the Adventure Field, Satchel, or an equipped slot. Each card can only have one Helper at a time. Helpers deployed on cards in the Satchel do not count toward the 3-card Satchel limit.

------------------------------
OVERCOMING CHALLENGES
------------------------------

Using Strength (drag equipped Strength onto a Challenge, or use the Challenge's action menu)
  Strength >= Challenge:  Challenge is discarded. Strength's value is reduced by the Challenge's value and stays equipped.
  Strength < Challenge:   Both cards are discarded. The Fool loses Vitality equal to the difference.

Using Volition (drag equipped Volition onto a Challenge, or use the Challenge's action menu)
  Volition >= Challenge:   Both cards are discarded.
  Volition < Challenge:   Volition is discarded. The Challenge remains with its value permanently reduced by Volition's value.

Using Vitality directly (drag the Fool onto a Challenge, or use the Challenge's action menu)
  The Challenge's current value is subtracted from the Fool's Vitality. The Challenge is then discarded.

------------------------------
ADVENTURE ROUNDS
------------------------------
When only 1 card remains in the Adventure Field, 3 more cards are dealt automatically to begin a new Adventure round. The remaining card carries over to the new field.

------------------------------
WINNING AND LOSING
------------------------------
  Win   All 21 Challenges overcome and the deck is exhausted.
  Loss  The Fool's Vitality reaches 0."""
