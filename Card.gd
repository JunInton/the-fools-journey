extends PanelContainer

# ------------------------------------
# PROPERTIES
# card_data holds this card's game data - like props in React
# source_zone tracks WHERE this card currently lives so
# GameState knows which array to remove it from when used
# draggable = false on discard pile cards to prevent reuse
# ------------------------------------
var card_data: Dictionary = {}
var source_zone: String = "adventure"
var draggable: bool = true

# @onready means "get this reference once the node tree is ready"
# $ is shorthand for get_node()
# This is like storing a ref in React: const ref = useRef()
@onready var card_name_label = $VBoxContainer/CardName
@onready var card_value_label = $VBoxContainer/CardValue

func _ready():
	# Lock card to a fixed size so it never stretches to fill its container
	# SIZE_SHRINK_BEGIN = don't grow vertically, anchor to top
	custom_minimum_size = Vector2(90, 130)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# Cards sitting in equipped slots need to let drop events pass through
	# to the DropZone node underneath them. Without this, when the player
	# drags a new card onto an equipped slot, the equipped card intercepts
	# the drop instead of the DropZone handling the replacement.
	# MOUSE_FILTER_IGNORE = like pointer-events: none in CSS —
	# the node is visible but invisible to mouse events
	if source_zone in ["equipped_strength", "equipped_volition"]:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	# If set_card() was called before this node entered the scene tree,
	# card_data will already be populated - display it immediately
	if card_data.size() > 0:
		update_display()

# Called by Main.gd after instantiating this card scene
# Equivalent to passing props to a React component
func set_card(data: Dictionary):
	card_data = data
	# is_inside_tree() checks if this node is part of the active scene yet
	# If it is, update visuals immediately
	# If not, _ready() will call update_display() once the node is added
	if is_inside_tree():
		update_display()

func update_display():
	card_name_label.text = card_data.get("name", "Unknown")
	# autowrap_mode makes long names like "Wheel of Fortune" wrap to next line
	# instead of getting clipped - like CSS word-wrap: break-word
	card_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_name_label.add_theme_font_size_override("font_size", 11)
	card_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var role = card_data.get("role", "")
	var value = card_data.get("value", 0)

	# Only show numeric value for cards that have meaningful values
	# Helpers, Chance cards etc. just show their role name instead
	if role in [
		CardData.ROLE_CHALLENGE,
		CardData.ROLE_VITALITY,
		CardData.ROLE_STRENGTH,
		CardData.ROLE_VOLITION,
		CardData.ROLE_WISDOM
	]:
		var value_text = "Value: " + str(value)
		# If a Helper has doubled this card, show a marker
		# The "doubled" key is set by GameState.deploy_helper()
		if card_data.get("doubled", false):
			value_text += " x2"
		card_value_label.text = value_text
	else:
		# capitalize() turns "helper" into "Helper" etc.
		card_value_label.text = role.capitalize()

	card_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_value_label.add_theme_font_size_override("font_size", 11)
	_apply_color()

func _apply_color():
	# StyleBoxFlat is Godot's equivalent of a CSS background style
	# We create a new one each time rather than reusing, because each
	# card instance needs its own independent style object
	var stylebox = StyleBoxFlat.new()
	var suit = card_data.get("suit", "")

	# Color-code by suit so players can identify cards at a glance
	match suit:
		CardData.SUIT_CUPS:    stylebox.bg_color = Color(0.2, 0.4, 0.8)  # blue
		CardData.SUIT_BATONS:  stylebox.bg_color = Color(0.2, 0.6, 0.2)  # green
		CardData.SUIT_SWORDS:  stylebox.bg_color = Color(0.7, 0.2, 0.2)  # red
		CardData.SUIT_COINS:   stylebox.bg_color = Color(0.7, 0.6, 0.1)  # gold
		CardData.SUIT_MAJOR:   stylebox.bg_color = Color(0.4, 0.1, 0.6)  # purple
		_:                     stylebox.bg_color = Color(0.3, 0.3, 0.3)  # grey fallback

	# Rounded corners - like border-radius: 6px in CSS
	stylebox.corner_radius_top_left = 6
	stylebox.corner_radius_top_right = 6
	stylebox.corner_radius_bottom_left = 6
	stylebox.corner_radius_bottom_right = 6

	# add_theme_stylebox_override applies this style to the "panel"
	# slot of PanelContainer - like setting a CSS class on a div
	add_theme_stylebox_override("panel", stylebox)

# ------------------------------------
# DRAG SOURCE
# Godot calls _get_drag_data automatically when the player
# starts dragging this node. Returning null cancels the drag.
# Returning a value starts the drag with that value as the payload.
# This is like the HTML5 ondragstart event.
# ------------------------------------
func _get_drag_data(_at_position: Vector2):
	# Non-draggable cards (discard pile) silently cancel drag
	if not draggable:
		return null
	# Challenges are never draggable - player can only resolve them
	if card_data.get("role", "") == CardData.ROLE_CHALLENGE:
		return null

	# The drag preview is a lightweight node that follows the cursor
	# We use a simple Label rather than a full card to keep it lightweight
	var preview = Label.new()
	preview.text = card_data.get("name", "Card")
	preview.add_theme_font_size_override("font_size", 12)
	preview.add_theme_color_override("font_color", Color.WHITE)
	set_drag_preview(preview)

	# The Dictionary returned here is the drag "payload"
	# It gets passed to _can_drop_data and _drop_data on the target
	# source_zone is critical - it tells GameState which array to remove from
	return {
		"card": card_data,
		"source_zone": source_zone,
		"card_node": self
	}

# ------------------------------------
# DROP TARGET - card-on-card drops only
# This handles two cases:
# 1. Helper dragged onto a pip card to double its value
# 2. Equipped Strength/Volition/Fool dragged onto a Challenge
#
# DropZone.gd handles drops onto zone areas (empty or not).
# Card.gd handles drops onto specific individual cards.
# ------------------------------------
func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false

	var dragged_card = data.get("card", {})
	var dragged_role = dragged_card.get("role", "")
	var dragged_suit = dragged_card.get("suit", "")
	var my_role = card_data.get("role", "")
	var my_suit = card_data.get("suit", "")
	var source = data.get("source_zone", "")

	# HELPER RULE: Helper can only land on a card if:
	# - Same suit (Cups helper on Cups pip etc.)
	# - Target is a Strength, Volition, or Vitality card
	# - Target hasn't already been doubled
	# - Player has at least one Wisdom card equipped to pay the cost
	if dragged_role == CardData.ROLE_HELPER:
		if dragged_suit == my_suit:
			if my_role in [CardData.ROLE_STRENGTH, CardData.ROLE_VOLITION, CardData.ROLE_VITALITY]:
				if not card_data.get("doubled", false):
					return GameState.equipped_wisdom.size() > 0

	# CHALLENGE RESOLUTION: Only already-equipped cards can attack challenges
	# source_zone must be "equipped_volition" not just "adventure"
	# to prevent accidentally dragging an unequipped sword at a challenge
	if dragged_role == CardData.ROLE_VOLITION and source == "equipped_volition":
		return my_role == CardData.ROLE_CHALLENGE

	if dragged_role == CardData.ROLE_STRENGTH and source == "equipped_strength":
		return my_role == CardData.ROLE_CHALLENGE

	# The Fool can be dragged to any challenge to resolve it directly
	# at the cost of the challenge's full value in vitality
	if dragged_role == CardData.ROLE_FOOL:
		return my_role == CardData.ROLE_CHALLENGE

	return false

func _drop_data(_at_position: Vector2, data):
	var dragged_card = data.get("card", {})
	var dragged_role = dragged_card.get("role", "")
	var source = data.get("source_zone", "")
	var from_satchel = source == "satchel"

	if dragged_role == CardData.ROLE_HELPER:
		# deploy_helper handles: spending wisdom, doubling value, discarding helper
		GameState.deploy_helper(dragged_card, card_data, from_satchel)

	elif dragged_role == CardData.ROLE_VOLITION and source == "equipped_volition":
		# resolve_with_volition: subtracts volition from challenge value
		# if challenge hits 0 both are discarded, otherwise volition is discarded
		# and challenge remains with reduced value
		GameState.resolve_with_volition(card_data)

	elif dragged_role == CardData.ROLE_STRENGTH and source == "equipped_strength":
		# resolve_with_strength: subtracts challenge from strength value
		# strength wins if it has more value, otherwise fool takes damage
		GameState.resolve_with_strength(card_data)

	elif dragged_role == CardData.ROLE_FOOL:
		# resolve_directly: subtracts challenge value straight from vitality
		GameState.resolve_directly(card_data)

# ------------------------------------
# DOUBLE CLICK SHORTCUTS AND CHALLENGE DIALOG
# _gui_input receives ALL input events on this node
# We filter down to just double-click left mouse button
# These are convenience shortcuts - drag and drop still works too
# ------------------------------------
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:

			# Non-draggable cards (discard pile) should not respond to
			# double-click either - same restriction as drag
			if not draggable:
				return

			var role = card_data.get("role", "")
			var from_satchel = source_zone == "satchel"

			match role:
				CardData.ROLE_CHANCE:
					# Reshuffle is destructive and irreversible - always confirm
					_confirm_action(
						"Use Chance card to reshuffle the Adventure Field?",
						func(): GameState.use_chance(card_data, from_satchel)
					)

				CardData.ROLE_WISDOM:
					# Guard: skip if this card is already in the equipped slot
					# Without this, double-clicking an equipped wisdom card would
					# try to re-equip it, adding a duplicate to the array
					if source_zone == "equipped_wisdom":
						return
					# Auto-equip if there's space - no confirmation needed
					# since equipping wisdom is always safe and reversible
					if GameState.equipped_wisdom.size() < 3:
						GameState.equip_wisdom(card_data, from_satchel)
					else:
						print("Wisdom slots full!")

				CardData.ROLE_STRENGTH:
					# Guard: skip if this IS the currently equipped strength card
					# Prevents the already-equipped card from showing a
					# "replace yourself?" dialog when double-clicked
					if source_zone == "equipped_strength":
						return
					if GameState.equipped_strength == null:
						# Empty slot - equip immediately, no confirmation needed
						GameState.equip_strength(card_data, from_satchel)
					else:
						# Replacing discards the old card - confirm first
						_confirm_action(
							"Replace equipped Strength card?",
							func(): GameState.equip_strength(card_data, from_satchel)
						)

				CardData.ROLE_VOLITION:
					# Same guard pattern as Strength above
					if source_zone == "equipped_volition":
						return
					if GameState.equipped_volition == null:
						GameState.equip_volition(card_data, from_satchel)
					else:
						_confirm_action(
							"Replace equipped Volition card?",
							func(): GameState.equip_volition(card_data, from_satchel)
						)

				CardData.ROLE_VITALITY:
					if GameState.vitality == GameState.MAX_VITALITY:
						# Healing at full health wastes the card - confirm first
						_confirm_action(
							"Vitality is already full. Discard this card anyway?",
							func(): GameState.replenish_vitality(card_data, from_satchel)
						)
					else:
						# Safe heal - no confirmation needed
						GameState.replenish_vitality(card_data, from_satchel)

				CardData.ROLE_CHALLENGE:
					# Challenges can't be dragged so double-click is the
					# primary way to interact with them besides drag-and-drop
					# from equipped cards. Opens a multi-option dialog.
					_show_challenge_dialog()

# ------------------------------------
# CHALLENGE RESOLUTION DIALOG
# Shows multiple resolution options for a challenge card.
# We build this manually with a PopupPanel + VBoxContainer because
# Godot's built-in ConfirmationDialog only supports two buttons (OK/Cancel).
# This is like building a custom modal in React.
# ------------------------------------
func _show_challenge_dialog():
	var challenge_value = card_data.get("value", 0)
	var challenge_name = card_data.get("name", "Challenge")

	# PopupPanel is a bare popup window we can fill with any nodes we want
	# Like a <dialog> element in HTML
	var popup = PopupPanel.new()
	popup.title = "Resolve " + challenge_name + " (Value: " + str(challenge_value) + ")"

	# VBoxContainer stacks buttons vertically inside the popup
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title_label = Label.new()
	title_label.text = "How do you resolve this challenge?"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# Only show Volition option if a Volition card is actually equipped
	# The button text previews the outcome so the player can make
	# an informed decision before committing
	if GameState.equipped_volition != null:
		var vol_value = GameState.equipped_volition.value
		var btn = Button.new()
		btn.text = "Use Volition (" + str(vol_value) + ") — " + (
			"Overcomes challenge" if vol_value >= challenge_value
			else "Depletes challenge by " + str(vol_value)
		)
		# The lambda captures popup and card_data from the outer scope
		# Like a closure in JS: () => { popup.close(); resolve(); }
		btn.pressed.connect(func():
			popup.queue_free()
			GameState.resolve_with_volition(card_data)
		)
		vbox.add_child(btn)

	# Only show Strength option if a Strength card is equipped
	if GameState.equipped_strength != null:
		var str_value = GameState.equipped_strength.value
		var damage = max(0, challenge_value - str_value)
		var btn = Button.new()
		btn.text = "Use Strength (" + str(str_value) + ") — " + (
			"Endures fully" if str_value >= challenge_value
			else "Takes " + str(damage) + " damage"
		)
		btn.pressed.connect(func():
			popup.queue_free()
			GameState.resolve_with_strength(card_data)
		)
		vbox.add_child(btn)

	# Direct resolution is always available regardless of equipped cards
	# Shows the exact vitality cost upfront so there are no surprises
	var direct_btn = Button.new()
	direct_btn.text = "Resolve Directly — costs " + str(challenge_value) + " vitality"
	direct_btn.pressed.connect(func():
		popup.queue_free()
		GameState.resolve_directly(card_data)
	)
	vbox.add_child(direct_btn)

	# Cancel button dismisses the dialog without taking any action
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(cancel_btn)

	# Add vbox into popup, add popup to root scene so it renders on top
	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	# popup_centered takes a suggested minimum size as a Vector2
	popup.popup_centered(Vector2(320, 200))

# ------------------------------------
# CONFIRMATION DIALOG HELPER
# Reusable function that creates a popup with confirm/cancel buttons
# message = the question shown to the player
# callback = the function to run if they confirm
#
# Callable is GDScript's way of passing a function as a value
# func(): GameState.do_something() is like () => gameState.doSomething() in JS
# ------------------------------------
func _confirm_action(message: String, callback: Callable):
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.title = "Confirm"

	# Add to root so the dialog renders on top of all game UI
	# Like appending a modal to document.body in JS
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

	# Connect the confirmed signal to the callback
	# CONNECT_ONE_SHOT means this connection auto-removes after firing once
	# Prevents the same action firing multiple times if dialog is reused
	# Like addEventListener with { once: true } in JS
	dialog.confirmed.connect(callback, CONNECT_ONE_SHOT)

	# Clean up the dialog node after it closes regardless of the player's choice
	# We check !dialog.visible because visibility_changed fires on both
	# show and hide - we only want to clean up on hide
	var cleanup = func():
		if not dialog.visible:
			dialog.queue_free()
	dialog.visibility_changed.connect(cleanup, CONNECT_ONE_SHOT)
