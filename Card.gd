extends PanelContainer

var card_data: Dictionary = {}
var source_zone: String = "adventure"
var draggable: bool = true

# ------------------------------------
# @onready vars grab references to child nodes once the scene is ready
# Like useRef in React - they let us access specific nodes by path
# ------------------------------------
@onready var card_name_label = $VBoxContainer/CardName
@onready var card_border = $VBoxContainer/CardBorder         # ← NEW: inner colored panel
@onready var card_image = $VBoxContainer/CardBorder/CardImage  # ← CHANGED: now nested inside CardBorder
@onready var card_value_label = $VBoxContainer/CardValue

func _ready():
	custom_minimum_size = Vector2(110, 0)

	var outer_style = StyleBoxFlat.new()
	outer_style.bg_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("panel", outer_style)

	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# ← NEW: CardBorder shrinks to hug the image's natural width
	# instead of stretching to fill the full 110px card width.
	# This means the suit color only appears directly around the image,
	# with no wide color bands on the sides.
	card_border.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Equipped cards sit on top of a DropZone - we ignore mouse events
	# so clicks pass through to the DropZone beneath them
	if source_zone in ["equipped_strength", "equipped_volition"]:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	# CardBorder and CardImage must pass mouse events up to the parent Card node.
	# Without MOUSE_FILTER_PASS, CardBorder (being a PanelContainer) consumes all
	# clicks and drags before they reach _gui_input and _get_drag_data on the Card.
	# This is like CSS pointer-events: none on the inner elements.
	card_border.mouse_filter = Control.MOUSE_FILTER_PASS
	card_image.mouse_filter = Control.MOUSE_FILTER_PASS

	if card_data.size() > 0:
		update_display()

# ------------------------------------
# SET CARD
# Called by Main.gd after instantiating a Card scene
# Like passing props to a React component
# ------------------------------------
func set_card(data: Dictionary):
	card_data = data
	# is_node_ready() checks if _ready() has already fired
	# If the node isn't ready yet, _ready() will call update_display() itself
	if is_node_ready():
		update_display()

# ------------------------------------
# UPDATE DISPLAY
# Rebuilds the visual state of this card from card_data
# Like the render/return of a React component
# ------------------------------------
func update_display():
	# Name label sits ABOVE the colored border
	card_name_label.text = card_data.get("name", "Unknown")
	card_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_name_label.max_lines_visible = 2
	card_name_label.add_theme_font_size_override("font_size", 11)
	card_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Reserve space for exactly 2 lines always, even if the name
	# only needs 1 line. Without this, single-line names make cards shorter
	# than two-line names, causing vertical misalignment in shared containers.
	card_name_label.custom_minimum_size.y = 30

	# Load the card image into the CardBorder's TextureRect
	_load_card_image()

	# Value label sits BELOW the colored border
	var role = card_data.get("role", "")
	var value = card_data.get("value", 0)

	if role in [CardData.ROLE_CHALLENGE, CardData.ROLE_VITALITY,
				CardData.ROLE_STRENGTH, CardData.ROLE_VOLITION]:
		if card_data.get("doubled", false):
			# Highlight the doubled value with unicode sparkles
			card_value_label.text = "** " + str(value) + " **"
		else:
			card_value_label.text = "Value: " + str(value)
		card_value_label.visible = true

	elif role == CardData.ROLE_WISDOM:
		# Wisdom cards no longer show a value label
		# Wisdom cards are spent as currency, their individual value
		# is not meaningful to display
		# Instead of hiding the label (which removes it from layout
		# and makes wisdom cards shorter than other cards, causing misalignment),
		# we keep it visible but blank. It still occupies the same vertical space
		# so all cards remain the same height regardless of role.
		card_value_label.text = ""
		card_value_label.visible = true

	else:
		# Helpers, Chance, etc show their role name
		card_value_label.text = role.capitalize()
		card_value_label.visible = true

	card_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_value_label.add_theme_font_size_override("font_size", 11)

	_apply_color()

# ------------------------------------
# IMAGE LOADING
# Tries to load the card's image for the current theme.
# Falls back gracefully if the image doesn't exist.
# ------------------------------------
func _load_card_image():
	var path = CardData.get_card_image_path(card_data)

	if path == "":
		card_image.visible = false
		return
	# CHANGED: removed FileAccess.file_exists() check - unreliable in web exports
	# Just attempt the load directly and check for null instead
	var texture = load(path)
	if texture != null:
		card_image.texture = texture
		card_image.visible = true
	else:
		card_image.visible = false

# ------------------------------------
# COLOR APPLICATION
# ← CHANGED: Color is now applied to card_border (the inner PanelContainer)
# instead of the outer card container.
# This means the suit color only covers the image area,
# and the name/value labels above and below are unaffected by the border size.
# ------------------------------------
func _apply_color():
	var suit = card_data.get("suit", "")
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = ThemeManager.get_suit_color(suit)
	if card_data.get("doubled", false):
		stylebox.bg_color = stylebox.bg_color.lightened(0.25)
	stylebox.corner_radius_top_left = 6
	stylebox.corner_radius_top_right = 6
	stylebox.corner_radius_bottom_left = 6
	stylebox.corner_radius_bottom_right = 6
	# draw_center = true so suit color fills behind the image
	# Small margins so the color peeks out as a thin frame on all sides equally
	stylebox.content_margin_left = 3
	stylebox.content_margin_right = 3
	stylebox.content_margin_top = 3
	stylebox.content_margin_bottom = 3
	card_border.add_theme_stylebox_override("panel", stylebox)

# ------------------------------------
# CARD BACK DISPLAY
# Used by the deck zone to show a face-down card.
# Hides name/value labels and shows the card back image instead.
# ← CHANGED: now applies stylebox to card_border, not self
# ------------------------------------
func show_card_back():
	card_name_label.visible = false
	card_value_label.visible = false

	# CHANGED: load directly without FileAccess check
	var texture = load("res://assets/cards/rws/card_back.jpg")
	if texture != null:
		card_image.texture = texture
		card_image.visible = true

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.3, 0.3, 0.4)
	stylebox.corner_radius_top_left = 6
	stylebox.corner_radius_top_right = 6
	stylebox.corner_radius_bottom_left = 6
	stylebox.corner_radius_bottom_right = 6
	stylebox.content_margin_left = 3
	stylebox.content_margin_right = 3
	stylebox.content_margin_top = 3
	stylebox.content_margin_bottom = 3
	card_border.add_theme_stylebox_override("panel", stylebox)

# ------------------------------------
# DRAG AND DROP - SOURCE
# _get_drag_data fires when the player starts dragging this card.
# Returns null to cancel the drag, or a Dictionary with card info.
# Godot's drag system is like HTML5 draggable - return data to start,
# the engine passes it to _can_drop_data and _drop_data on targets.
# ------------------------------------
func _get_drag_data(_at_position: Vector2):
	if not draggable:
		return null
	# Challenges can never be dragged - they must be resolved in place
	if card_data.get("role", "") == CardData.ROLE_CHALLENGE:
		return null
	# Use duplicate() as the drag preview so it looks like the card
	var preview = duplicate()
	set_drag_preview(preview)
	return { "card": card_data, "source_zone": source_zone, "card_node": self }

# ------------------------------------
# DRAG AND DROP - TARGET (card on card)
# Checks if an incoming drag can be dropped onto THIS card.
# Only a few card-on-card interactions are valid:
# Helper on same-suit pip, Equipped Volition/Strength on Challenge, Fool on Challenge.
# ------------------------------------
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var card = data.get("card", {})
	var source = data.get("source_zone", "")
	var role = card.get("role", "")
	var my_role = card_data.get("role", "")
	var my_suit = card_data.get("suit", "")

	# Helper dropped onto a same-suit pip card to double its value
	# Requires: same suit, target not already doubled, wisdom available
	if role == CardData.ROLE_HELPER:
		if my_role in [CardData.ROLE_STRENGTH, CardData.ROLE_VOLITION, CardData.ROLE_VITALITY]:
			if card.get("suit", "") == my_suit:
				if not card_data.get("doubled", false):
					if GameState.equipped_wisdom.size() > 0:
						return true
						
	# NEW: Vitality card dropped onto the Fool card to heal
	if my_role == CardData.ROLE_FOOL and role == CardData.ROLE_VITALITY:
		return true

	# Equipped volition resolves a challenge
	if source == "equipped_volition" and my_role == CardData.ROLE_CHALLENGE:
		return GameState.equipped_volition != null

	# Equipped strength resolves a challenge
	if source == "equipped_strength" and my_role == CardData.ROLE_CHALLENGE:
		return GameState.equipped_strength != null

	# The Fool resolves a challenge directly (takes damage)
	if source == "fool" and my_role == CardData.ROLE_CHALLENGE:
		return true

	return false

# ------------------------------------
# DRAG AND DROP - TARGET (receive drop)
# Routes the dropped card to the appropriate GameState function.
# GameState handles all the logic; this just identifies what happened.
# ------------------------------------
func _drop_data(_at_position: Vector2, data: Variant):
	var card = data.get("card", {})
	var source = data.get("source_zone", "")
	
	# NEW: Vitality dropped onto Fool card — same logic as double-click heal
	if card_data.get("role", "") == CardData.ROLE_FOOL and card.get("role", "") == CardData.ROLE_VITALITY:
		var heal_amount = card.get("value", 0)
		var current_vitality = GameState.vitality
		var max_vitality = GameState.MAX_VITALITY
		if current_vitality >= max_vitality:
			_confirm_action("Vitality is full. Discard this card?", func():
				GameState.discard_card(card, source == "satchel"))
		elif current_vitality + heal_amount > max_vitality:
			var actual_heal = max_vitality - current_vitality
			var wasted = heal_amount - actual_heal
			_confirm_action(
				"Healing " + str(heal_amount) + " would overheal.\n" +
				"You will only recover " + str(actual_heal) + " vitality (" +
				str(wasted) + " wasted).\nProceed?",
				func(): GameState.replenish_vitality(card, source == "satchel"))
		else:
			GameState.replenish_vitality(card, source == "satchel")
		return

	if card.get("role", "") == CardData.ROLE_HELPER:
		GameState.deploy_helper(card, card_data, source == "satchel")
		return

	if source == "equipped_volition":
		GameState.resolve_with_volition(card_data)
		return

	if source == "equipped_strength":
		GameState.resolve_with_strength(card_data)
		return

	if source == "fool":
		GameState.resolve_directly(card_data)

# ------------------------------------
# INPUT HANDLING
# Double-click opens context-appropriate dialogs.
# Single clicks are handled by Godot's drag system automatically.
# ------------------------------------
func _gui_input(event: InputEvent):
	if not draggable:
		return
	if event is InputEventMouseButton:
		if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_double_click()

func _handle_double_click():
	var role = card_data.get("role", "")
	match role:
		CardData.ROLE_CHANCE:
			_confirm_action("Reshuffle the adventure field into the deck?", func():
				GameState.use_chance(card_data, source_zone == "satchel"))

		CardData.ROLE_WISDOM:
			if source_zone == "equipped_wisdom":
				return
			GameState.equip_wisdom(card_data, source_zone == "satchel")

		CardData.ROLE_STRENGTH:
			if source_zone == "equipped_strength":
				return
			if GameState.equipped_strength != null:
				_confirm_action("Replace equipped Strength card?", func():
					GameState.equip_strength(card_data, source_zone == "satchel"))
			else:
				GameState.equip_strength(card_data, source_zone == "satchel")

		CardData.ROLE_VOLITION:
			if source_zone == "equipped_volition":
				return
			if GameState.equipped_volition != null:
				_confirm_action("Replace equipped Volition card?", func():
					GameState.equip_volition(card_data, source_zone == "satchel"))
			else:
				GameState.equip_volition(card_data, source_zone == "satchel")

		CardData.ROLE_VITALITY:
			var heal_amount = card_data.get("value", 0)
			var current_vitality = GameState.vitality
			var max_vitality = GameState.MAX_VITALITY

			if current_vitality >= max_vitality:
				# Already at full - offer to discard instead
				_confirm_action("Vitality is full. Discard this card?", func():
					GameState.discard_card(card_data, source_zone == "satchel"))

			elif current_vitality + heal_amount > max_vitality:
				# ← NEW: healing would exceed maximum - show overheal warning
				# so the player can make an informed decision rather than
				# accidentally wasting part of the card's value
				var actual_heal = max_vitality - current_vitality
				var wasted = heal_amount - actual_heal
				_confirm_action(
					"Healing " + str(heal_amount) + " would overheal.\n" +
					"You will only recover " + str(actual_heal) + " vitality (" +
					str(wasted) + " wasted).\nProceed?",
					func(): GameState.replenish_vitality(card_data, source_zone == "satchel"))
			else:
				# Clean heal with no waste - no confirmation needed
				GameState.replenish_vitality(card_data, source_zone == "satchel")

		CardData.ROLE_CHALLENGE:
			_show_challenge_dialog()

		CardData.ROLE_HELPER:
			if GameState.equipped_wisdom.size() == 0:
				return
			var targets = _find_helper_targets()
			if targets.is_empty():
				return
			_show_helper_dialog(targets)

# ------------------------------------
# CHALLENGE RESOLUTION DIALOG
# Shows a popup with all available resolution options.
# Each button previews the outcome so the player can make an informed choice.
# ------------------------------------
func _show_challenge_dialog():
	var popup = PopupPanel.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title = Label.new()
	title.text = "Resolve: " + card_data.get("name", "") + " (Value: " + str(card_data.get("value", 0)) + ")"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Volition option - only shows if a volition card is equipped
	if GameState.equipped_volition != null:
		var vol = GameState.equipped_volition
		var diff = card_data.get("value", 0) - vol.get("value", 0)
		var label = "Use Volition (" + str(vol.get("value", 0)) + ")"
		if diff > 0:
			label += " — Challenge reduced to " + str(diff)
		else:
			label += " — Challenge resolved!"
		var btn = Button.new()
		btn.text = label
		btn.pressed.connect(func():
			popup.queue_free()
			GameState.resolve_with_volition(card_data))
		vbox.add_child(btn)

	# Strength option - only shows if a strength card is equipped
	if GameState.equipped_strength != null:
		var str_card = GameState.equipped_strength
		var sv = str_card.get("value", 0)
		var cv = card_data.get("value", 0)
		var outcome = "Use Strength (" + str(sv) + ")"
		if sv == cv:
			outcome += " — Both discarded"
		elif sv > cv:
			outcome += " — Challenge discarded, Strength depleted to " + str(sv - cv)
		else:
			outcome += " — Both discarded, Fool takes " + str(cv - sv) + " damage"
		var btn = Button.new()
		btn.text = outcome
		btn.pressed.connect(func():
			popup.queue_free()
			GameState.resolve_with_strength(card_data))
		vbox.add_child(btn)

	# Direct resolution is always available - Fool takes full damage
	var direct_btn = Button.new()
	direct_btn.text = "Resolve Directly — Fool takes " + str(card_data.get("value", 0)) + " damage"
	direct_btn.pressed.connect(func():
		popup.queue_free()
		GameState.resolve_directly(card_data))
	vbox.add_child(direct_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(cancel_btn)

	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	popup.popup_centered()

# ------------------------------------
# CONFIRMATION DIALOG
# Generic reusable confirm popup - like window.confirm() in JS
# but non-blocking. Takes a message and a callback to run on confirm.
# ------------------------------------
func _confirm_action(message: String, callback: Callable):
	# ← CHANGED: was ConfirmationDialog which uses OS-native styling
	# Now uses PopupPanel like all other dialogs in the game,
	# giving it the same transparent appearance
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

# ------------------------------------
# HELPER TARGET FINDER
# Searches all zones for valid cards this Helper can double.
# Returns an array of Dictionaries describing each valid target.
# ------------------------------------
func _find_helper_targets() -> Array:
	var targets = []
	var my_suit = card_data.get("suit", "")

	for card in GameState.adventure_field:
		if _is_valid_helper_target(card, my_suit):
			targets.append({"card": card, "zone": "adventure",
				"label": card.name + " (Adventure Field) — Value: " + str(card.value)})

	for card in GameState.satchel:
		if _is_valid_helper_target(card, my_suit):
			targets.append({"card": card, "zone": "satchel",
				"label": card.name + " (Satchel) — Value: " + str(card.value)})

	if GameState.equipped_strength != null:
		var s = GameState.equipped_strength
		if _is_valid_helper_target(s, my_suit):
			targets.append({"card": s, "zone": "equipped_strength",
				"label": s.name + " (Equipped Strength) — Value: " + str(s.value)})

	if GameState.equipped_volition != null:
		var v = GameState.equipped_volition
		if _is_valid_helper_target(v, my_suit):
			targets.append({"card": v, "zone": "equipped_volition",
				"label": v.name + " (Equipped Volition) — Value: " + str(v.value)})

	return targets

func _is_valid_helper_target(card: Dictionary, required_suit: String) -> bool:
	return (
		card.get("suit", "") == required_suit and
		card.get("role", "") in [CardData.ROLE_STRENGTH, CardData.ROLE_VOLITION, CardData.ROLE_VITALITY] and
		not card.get("doubled", false)
	)

# ------------------------------------
# HELPER DEPLOYMENT DIALOG
# Shows valid targets for this Helper card to double.
# Each button shows card name, zone, and current value.
# ------------------------------------
func _show_helper_dialog(targets: Array):
	var popup = PopupPanel.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title_label = Label.new()
	title_label.text = "Choose a card to double its value:\n(costs 1 Wisdom)"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	for target in targets:
		var btn = Button.new()
		btn.text = target.label
		# Capture target in a local var to avoid closure-over-loop-variable bug
		# Without this, all buttons would reference the last value of 'target'
		var captured = target
		btn.pressed.connect(func():
			popup.queue_free()
			GameState.deploy_helper(card_data, captured.card, source_zone == "satchel"))
		vbox.add_child(btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(cancel_btn)

	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	# ← CHANGED: was popup_centered(Vector2(360, 220)) hardcoded
	# popup_centered() with no argument lets the popup size itself
	# to fit its content - fewer targets = smaller box automatically
	popup.popup_centered()

# Preloaded here for the drag preview duplicate()
# Must be at the bottom to avoid circular reference issues
const CardScene = preload("res://Card.tscn")
