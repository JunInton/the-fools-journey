extends PanelContainer

var card_data: Dictionary = {}
var source_zone: String = "adventure"
var draggable: bool = true

# ------------------------------------
# NODE REFERENCES
# @onready grabs references to child nodes once the scene is ready
# Like useRef in React - they let us access specific nodes by path
# ------------------------------------
@onready var card_name_label = $VBoxContainer/CardName
@onready var card_border      = $VBoxContainer/CardBorder
@onready var card_image       = $VBoxContainer/CardBorder/CardImage
@onready var card_value_label = $VBoxContainer/CardValue

func _ready():
	custom_minimum_size = Vector2(130, 0)

	# Transparent outer panel — the visible colored border is on card_border,
	# not the outer container, so the suit color only wraps the image
	var outer_style = StyleBoxFlat.new()
	outer_style.bg_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("panel", outer_style)

	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical   = Control.SIZE_SHRINK_CENTER

	# CardBorder shrinks to hug the image's natural width rather than
	# stretching to fill the full card width, keeping the color frame tight
	card_border.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Equipped cards sit directly on top of a DropZone node.
	# MOUSE_FILTER_PASS receives mouse events and also passes them through
	# to the DropZone beneath, so both double-click and drop interactions work.
	# MOUSE_FILTER_IGNORE would block double-clicks entirely.
	if source_zone in ["equipped_strength", "equipped_volition"]:
		mouse_filter = Control.MOUSE_FILTER_PASS

	# CardBorder and CardImage must pass mouse events up to the parent Card node.
	# Without this, CardBorder (being a PanelContainer) consumes all clicks and
	# drags before they reach _gui_input and _get_drag_data on the Card.
	# This is like CSS pointer-events: none on inner elements.
	card_border.mouse_filter = Control.MOUSE_FILTER_PASS
	card_image.mouse_filter  = Control.MOUSE_FILTER_PASS

	if card_data.size() > 0:
		update_display()

# ------------------------------------
# SET CARD
# Called by Main.gd after instantiating a Card scene to assign data.
# Like passing props to a React component — the card re-renders based
# on whatever data is passed in.
# ------------------------------------
func set_card(data: Dictionary):
	card_data = data
	# is_node_ready() checks if _ready() has already fired.
	# If not, _ready() will call update_display() itself when it runs.
	if is_node_ready():
		update_display()

# ------------------------------------
# UPDATE DISPLAY
# Rebuilds the visual state of this card from card_data.
# Like the render/return of a React component — describes what the
# card should look like given its current data.
# ------------------------------------
func update_display():
	# Name label sits above the colored border
	card_name_label.text = card_data.get("name", "Unknown")
	card_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_name_label.max_lines_visible = 2
	card_name_label.add_theme_font_size_override("font_size", 13)
	card_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Reserve space for exactly 2 lines even when the name only needs 1.
	# Without this, single-line names make the card shorter than two-line names,
	# causing vertical misalignment when multiple cards share a container.
	card_name_label.custom_minimum_size.y = 30

	_load_card_image()

	# Value label sits below the colored border
	var role  = card_data.get("role", "")
	var value = card_data.get("value", 0)

	if role in [CardData.ROLE_CHALLENGE, CardData.ROLE_VITALITY,
				CardData.ROLE_STRENGTH, CardData.ROLE_VOLITION]:
		if card_data.get("doubled", false):
			card_value_label.text = "** " + str(value) + " **"
		else:
			card_value_label.text = "Value: " + str(value)
		card_value_label.visible = true

	elif role == CardData.ROLE_WISDOM:
		# Wisdom cards don't show a value — they're spent as currency,
		# not compared numerically. The label is kept visible but blank
		# so all cards remain the same height regardless of role.
		card_value_label.text = ""
		card_value_label.visible = true

	else:
		# Helpers, Chance, and any other roles show their role name
		card_value_label.text = role.capitalize()
		card_value_label.visible = true

	card_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_value_label.add_theme_font_size_override("font_size", 13)

	_apply_color()

# ------------------------------------
# IMAGE LOADING
# Attempts to load the card's image for the current theme.
# Falls back gracefully by hiding the image if it can't be loaded.
# ------------------------------------
func _load_card_image():
	var path = CardData.get_card_image_path(card_data)
	if path == "":
		card_image.visible = false
		return
	# Attempt the load directly and check for null rather than checking
	# file existence first — FileAccess.file_exists() is unreliable in web exports
	var texture = load(path)
	if texture != null:
		card_image.texture = texture
		card_image.visible = true
	else:
		card_image.visible = false

# ------------------------------------
# COLOR APPLICATION
# Suit color is applied to card_border (the inner PanelContainer)
# rather than the outer card container. This means the color only
# covers the image area — name and value labels are unaffected.
# ------------------------------------
func _apply_color():
	var suit = card_data.get("suit", "")
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = ThemeManager.get_suit_color(suit)
	if card_data.get("doubled", false):
		# Lightened background makes doubled cards visually distinct
		stylebox.bg_color = stylebox.bg_color.lightened(0.25)
	stylebox.corner_radius_top_left    = 6
	stylebox.corner_radius_top_right   = 6
	stylebox.corner_radius_bottom_left = 6
	stylebox.corner_radius_bottom_right = 6
	# Small margins let the suit color peek out as a thin frame around the image
	stylebox.content_margin_left   = 3
	stylebox.content_margin_right  = 3
	stylebox.content_margin_top    = 3
	stylebox.content_margin_bottom = 3
	card_border.add_theme_stylebox_override("panel", stylebox)

# ------------------------------------
# CARD BACK DISPLAY
# Used by the deck zone to show a face-down card.
# Hides name and value labels and loads the card back image.
# ------------------------------------
func show_card_back():
	card_name_label.visible = false
	card_value_label.visible = false

	# Each theme has its own card back image
	var back_path = "res://assets/cards/rws/card_back.jpg"
	if ThemeManager.current_theme == ThemeManager.THEME_PERSONA3:
		back_path = "res://assets/cards/persona3/card_back.jpg"

	var texture = load(back_path)
	if texture != null:
		card_image.texture = texture
		card_image.visible = true

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.3, 0.3, 0.4)
	stylebox.corner_radius_top_left    = 6
	stylebox.corner_radius_top_right   = 6
	stylebox.corner_radius_bottom_left = 6
	stylebox.corner_radius_bottom_right = 6
	stylebox.content_margin_left   = 3
	stylebox.content_margin_right  = 3
	stylebox.content_margin_top    = 3
	stylebox.content_margin_bottom = 3
	card_border.add_theme_stylebox_override("panel", stylebox)

# ------------------------------------
# DRAG AND DROP — SOURCE
# _get_drag_data fires when the player starts dragging this card.
# Returns null to cancel the drag, or a Dictionary to begin it.
# Godot's drag system works like HTML5 draggable — returning data
# starts the drag, and the engine passes that data to _can_drop_data
# and _drop_data on any node the card is dragged over.
# ------------------------------------
func _get_drag_data(_at_position: Vector2):
	if not draggable:
		return null
	# Challenges can never be dragged — they must be resolved in place
	if card_data.get("role", "") == CardData.ROLE_CHALLENGE:
		return null
	# Signal Main.gd that a drag has started so movement animations
	# are suppressed — the drag preview handles visual feedback instead
	GameState.emit_signal("drag_started")
	# duplicate() creates a visual copy to use as the drag preview
	var preview = duplicate()
	set_drag_preview(preview)
	return { "card": card_data, "source_zone": source_zone, "card_node": self }

func _notification(what: int):
	# NOTIFICATION_DRAG_END fires when any drag initiated by this node ends,
	# whether it landed on a valid target or was cancelled mid-drag.
	# This is more reliable than _drop_data which only fires on valid drops —
	# using _drop_data would leave _suppress_animations permanently true
	# after any cancelled or invalid drag.
	if what == NOTIFICATION_DRAG_END:
		GameState.emit_signal("drag_ended")

# ------------------------------------
# DRAG AND DROP — TARGET (card on card)
# _can_drop_data checks whether an incoming drag is valid for this card.
# Valid card-on-card interactions: Helper on same-suit pip,
# equipped Volition/Strength on Challenge, Fool card on Challenge,
# Vitality on Fool, Wisdom on Wisdom, any card on satchel card.
# ------------------------------------
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var card    = data.get("card", {})
	var source  = data.get("source_zone", "")
	var role    = card.get("role", "")
	var my_role = card_data.get("role", "")
	var my_suit = card_data.get("suit", "")

	# Cards in the discard pile only accept drag-to-discard.
	# Challenge and Fool drags are blocked here to prevent accidental
	# challenge resolution by dropping onto the discard pile's top card.
	if source_zone == "discard":
		if role != CardData.ROLE_CHALLENGE and role != CardData.ROLE_FOOL:
			return true
		return false

	# Helper dropped onto a same-suit pip card to double its value.
	# Requires matching suit, target not already doubled, and at least one Wisdom equipped.
	if role == CardData.ROLE_HELPER:
		if my_role in [CardData.ROLE_STRENGTH, CardData.ROLE_VOLITION, CardData.ROLE_VITALITY]:
			if card.get("suit", "") == my_suit:
				if not card_data.get("doubled", false):
					if GameState.equipped_wisdom.size() > 0:
						return true

	# Vitality card dropped onto the Fool card to heal
	if my_role == CardData.ROLE_FOOL and role == CardData.ROLE_VITALITY:
		return true

	# Equipped Volition or Strength resolves a challenge
	if source == "equipped_volition" and my_role == CardData.ROLE_CHALLENGE:
		return GameState.equipped_volition != null
	if source == "equipped_strength" and my_role == CardData.ROLE_CHALLENGE:
		return GameState.equipped_strength != null

	# The Fool resolves a challenge directly at the cost of Vitality
	if source == "fool" and my_role == CardData.ROLE_CHALLENGE:
		return true

	# Wisdom card dropped onto an equipped Wisdom card to equip it
	if my_role == CardData.ROLE_WISDOM and role == CardData.ROLE_WISDOM:
		if source != "equipped_wisdom":
			return GameState.equipped_wisdom.size() < 3

	# Any non-challenge card dropped onto a satchel card stores it in the satchel
	if source_zone == "satchel" and role != CardData.ROLE_CHALLENGE and role != CardData.ROLE_FOOL:
		if source != "satchel":
			return GameState.satchel.size() < GameState.MAX_SATCHEL

	return false

# ------------------------------------
# DRAG AND DROP — TARGET (receive drop)
# Routes the dropped card to the correct GameState action function.
# GameState handles all logic — this function only identifies the interaction.
# ------------------------------------
func _drop_data(_at_position: Vector2, data: Variant):
	var card   = data.get("card", {})
	var source = data.get("source_zone", "")

	# Card dropped onto the discard pile's top card
	if source_zone == "discard":
		if source == "equipped_strength":
			GameState.unequip_strength_to_discard()
		elif source == "equipped_volition":
			GameState.unequip_volition_to_discard()
		elif source == "equipped_wisdom":
			GameState.unequip_wisdom_to_discard(card)
		else:
			if card.get("role", "") == CardData.ROLE_CHANCE:
				_show_ace_drop_menu(card, source == "satchel")
			else:
				GameState.discard_card(card, source == "satchel")
		return

	# Vitality card dropped onto the Fool card
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

	# Wisdom card dropped onto an equipped Wisdom card
	if card_data.get("role", "") == CardData.ROLE_WISDOM and card.get("role", "") == CardData.ROLE_WISDOM:
		GameState.equip_wisdom(card, source == "satchel")
		return

	# Any card dropped onto a satchel card stores it
	if source_zone == "satchel" and card.get("role", "") != CardData.ROLE_CHALLENGE:
		if source != "satchel":
			GameState.store_in_satchel(card)
		return

	if source == "equipped_volition":
		GameState.resolve_with_volition(card_data)
		return
	if source == "equipped_strength":
		GameState.resolve_with_strength(card_data)
		return
	if source == "fool":
		GameState.resolve_directly(card_data)
		return

# ------------------------------------
# INPUT HANDLING
# Double-click opens a context-sensitive dialog depending on the card's
# role and current zone. Single clicks are handled by Godot's drag system.
# ------------------------------------
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			# Double-click is always handled regardless of draggable state —
			# non-draggable discard pile cards still need to open the discard viewer
			_handle_double_click()

func _handle_double_click():
	var role = card_data.get("role", "")

	if role == CardData.ROLE_CHALLENGE:
		_show_challenge_dialog()
		return

	if role == CardData.ROLE_FOOL:
		return

	if source_zone == "discard":
		GameState.emit_signal("discard_viewer_requested")
		return

	# Equipped cards only offer a discard option — they can't be re-equipped
	# to a different slot from their current position
	if source_zone in ["equipped_strength", "equipped_volition"]:
		_show_equipped_discard_menu()
		return

	_show_action_menu()

# ------------------------------------
# ACTION MENU
# Shows a role-appropriate set of actions for this card.
# The available options depend on the card's role and current zone.
# ------------------------------------
func _show_action_menu():
	var role = card_data.get("role", "")
	var popup = PopupPanel.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title = Label.new()
	title.text = card_data.get("name", "")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	match role:
		CardData.ROLE_VITALITY:
			var heal_amount = card_data.get("value", 0)
			var current_vitality = GameState.vitality
			var max_vitality = GameState.MAX_VITALITY
			var heal_btn = Button.new()
			if current_vitality >= max_vitality:
				heal_btn.text = "Heal — Vitality already full"
				heal_btn.disabled = true
			elif current_vitality + heal_amount > max_vitality:
				var actual = max_vitality - current_vitality
				var wasted = heal_amount - actual
				heal_btn.text = "Heal " + str(heal_amount) + " (only " + str(actual) + " effective)"
				heal_btn.pressed.connect(func():
					popup.queue_free()
					_confirm_action(
						"Healing " + str(heal_amount) + " would overheal.\n" +
						"You will only recover " + str(actual) + " vitality (" +
						str(wasted) + " wasted).\nProceed?",
						func(): GameState.replenish_vitality(card_data, source_zone == "satchel")))
			else:
				heal_btn.text = "Heal " + str(heal_amount) + " Vitality"
				heal_btn.pressed.connect(func():
					popup.queue_free()
					GameState.replenish_vitality(card_data, source_zone == "satchel"))
			vbox.add_child(heal_btn)

		CardData.ROLE_WISDOM:
			if source_zone != "equipped_wisdom":
				var equip_btn = Button.new()
				equip_btn.text = "Equip as Wisdom"
				equip_btn.pressed.connect(func():
					popup.queue_free()
					GameState.equip_wisdom(card_data, source_zone == "satchel"))
				vbox.add_child(equip_btn)

		CardData.ROLE_STRENGTH:
			if source_zone != "equipped_strength":
				var equip_btn = Button.new()
				if GameState.equipped_strength != null:
					# Show exactly what will happen so the player can make an informed choice
					equip_btn.text = "Replace " + GameState.equipped_strength.get("name", "Strength") + " with " + card_data.get("name", "")
				else:
					equip_btn.text = "Equip as Strength"
				equip_btn.pressed.connect(func():
					popup.queue_free()
					GameState.equip_strength(card_data, source_zone == "satchel"))
				vbox.add_child(equip_btn)

		CardData.ROLE_VOLITION:
			if source_zone != "equipped_volition":
				var equip_btn = Button.new()
				if GameState.equipped_volition != null:
					equip_btn.text = "Replace " + GameState.equipped_volition.get("name", "Volition") + " with " + card_data.get("name", "")
				else:
					equip_btn.text = "Equip as Volition"
				equip_btn.pressed.connect(func():
					popup.queue_free()
					GameState.equip_volition(card_data, source_zone == "satchel"))
				vbox.add_child(equip_btn)

		CardData.ROLE_CHANCE:
			var chance_btn = Button.new()
			chance_btn.text = "Take a Chance — reshuffle Adventure"
			chance_btn.pressed.connect(func():
				popup.queue_free()
				GameState.use_chance(card_data, source_zone == "satchel"))
			vbox.add_child(chance_btn)

		CardData.ROLE_HELPER:
			# List valid deployment targets directly in this menu rather than
			# opening a second dialog — one fewer click to deploy
			if GameState.equipped_wisdom.size() > 0:
				var targets = _find_helper_targets()
				if targets.is_empty():
					var no_targets = Label.new()
					no_targets.text = "No valid targets to deploy to"
					no_targets.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					vbox.add_child(no_targets)
				else:
					var deploy_label = Label.new()
					deploy_label.text = "Deploy Helper (costs 1 Wisdom) to:"
					deploy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					vbox.add_child(deploy_label)
					for target in targets:
						var btn = Button.new()
						btn.text = target.label
						# Capture target in a local variable to avoid the closure-over-loop
						# variable bug — without this, all buttons would reference the
						# final value of 'target' after the loop finishes
						var captured = target
						btn.pressed.connect(func():
							popup.queue_free()
							GameState.deploy_helper(card_data, captured.card, source_zone == "satchel"))
						vbox.add_child(btn)
			else:
				var no_wisdom = Label.new()
				no_wisdom.text = "No Wisdom equipped to deploy Helper"
				no_wisdom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(no_wisdom)

	# Store in Satchel is available for any adventure field card except Aces
	if source_zone == "adventure" and role != CardData.ROLE_CHANCE:
		if GameState.satchel.size() < GameState.MAX_SATCHEL:
			var store_btn = Button.new()
			store_btn.text = "Store in Satchel"
			store_btn.pressed.connect(func():
				popup.queue_free()
				GameState.store_in_satchel(card_data))
			vbox.add_child(store_btn)

	# Discard is available from all zones except equipped strength/volition slots
	# (those have their own minimal menu via _show_equipped_discard_menu)
	if source_zone not in ["equipped_strength", "equipped_volition"]:
		var discard_btn = Button.new()
		discard_btn.text = "Discard"
		discard_btn.pressed.connect(func():
			popup.queue_free()
			if source_zone == "equipped_wisdom":
				GameState.unequip_wisdom_to_discard(card_data)
			else:
				GameState.discard_card(card_data, source_zone == "satchel"))
		vbox.add_child(discard_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(cancel_btn)

	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	popup.popup_centered()

func _show_equipped_discard_menu():
	# Minimal menu for equipped Strength and Volition cards —
	# the only available action from an equipped slot is to discard
	var popup = PopupPanel.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title = Label.new()
	title.text = card_data.get("name", "") + " (Equipped)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var discard_btn = Button.new()
	discard_btn.text = "Discard"
	discard_btn.pressed.connect(func():
		popup.queue_free()
		if source_zone == "equipped_strength":
			GameState.unequip_strength_to_discard()
		elif source_zone == "equipped_volition":
			GameState.unequip_volition_to_discard())
	vbox.add_child(discard_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(cancel_btn)

	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	popup.popup_centered()

# ------------------------------------
# CHALLENGE RESOLUTION DIALOG
# Shows all available resolution options with outcome previews
# so the player can make an informed decision before committing.
# ------------------------------------
func _show_challenge_dialog():
	var popup = PopupPanel.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title = Label.new()
	title.text = "Resolve: " + card_data.get("name", "") + " (Value: " + str(card_data.get("value", 0)) + ")"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Volition option — only shown if a Volition card is equipped
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

	# Strength option — only shown if a Strength card is equipped
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

	# Direct resolution is always available — Fool takes full damage
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
# Generic reusable confirm popup — like window.confirm() in JS but
# non-blocking. Accepts a message string and a Callable to run on confirm.
# ------------------------------------
func _confirm_action(message: String, callback: Callable):
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
# Searches all active zones for cards this Helper can double.
# Returns an array of Dictionaries, each describing a valid target
# with its card data, zone name, and a display label for the action menu.
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

func _show_ace_drop_menu(card: Dictionary, from_satchel: bool):
	# Shown when an Ace is dragged to the discard zone — offers the choice
	# between taking a Chance (reshuffling) or simply discarding
	var popup = PopupPanel.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title = Label.new()
	title.text = card.get("name", "Ace")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var chance_btn = Button.new()
	chance_btn.text = "Take a Chance — reshuffle Adventure"
	chance_btn.pressed.connect(func():
		popup.queue_free()
		GameState.use_chance(card, from_satchel))
	vbox.add_child(chance_btn)

	var discard_btn = Button.new()
	discard_btn.text = "Discard"
	discard_btn.pressed.connect(func():
		popup.queue_free()
		GameState.discard_card(card, from_satchel))
	vbox.add_child(discard_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(cancel_btn)

	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	popup.popup_centered()

# Preloaded at the bottom to avoid circular reference issues —
# Card.gd needs CardScene for the drag preview duplicate
const CardScene = preload("res://Card.tscn")
