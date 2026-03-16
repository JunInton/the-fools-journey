extends Control

const CardScene = preload("res://Card.tscn")

# ------------------------------------
# ANIMATION LAYER
# A transparent Control node that sits above all zone panels.
# Cards temporarily live here while flying between zones so they
# render on top of everything and aren't constrained by container layout.
# ------------------------------------
var anim_layer: Control

# ------------------------------------
# CARD REGISTRY
# Tracks every visible card node by a unique integer ID assigned
# at game start. This allows cards to persist across state changes
# rather than being destroyed and recreated on every update,
# which is what makes smooth movement animations possible.
# ------------------------------------
var _card_nodes: Dictionary = {}          # card _id -> Card node
var _card_zones: Dictionary = {}          # card _id -> zone name string
var _card_last_positions: Dictionary = {} # card _id -> last known Vector2 position

# ------------------------------------
# ANIMATION STATE FLAGS
# These coordinate timing between GameState logic and visual animations.
# Many animations need to suppress or delay normal rendering behavior
# so visual effects don't get overwritten before they finish playing.
# ------------------------------------
var _is_reshuffling: bool = false
var _suppress_animations: bool = false
var _suppress_discard_render: bool = false
var _chance_card_id: int = -1

# Pending animation data — populated by pre-animation signals from GameState
# before state changes occur, so node positions can be captured in time.
var _pending_animations: Dictionary = {}           # card _id -> { type, target_id }
var _pending_collision_positions: Dictionary = {}  # card _id -> Vector2
var _pending_challenge_flashes: Dictionary = {}    # card _id -> true
var _pending_fool_attack: Dictionary = {}          # challenge _id -> true
var _pending_strength_bounce: Dictionary = {}      # strength _id -> challenge _id
var _delay_discard_ids: Dictionary = {}            # card _id -> delay in seconds

# ------------------------------------
# NODE REFERENCES
# @onready grabs references to child nodes once the scene is ready.
# All paths include /VBoxContainer/ inside each section because each
# zone panel wraps its label and card container in a VBoxContainer.
# ------------------------------------

# @onready grabs node references once the scene is ready — like useRef in React
# $ is shorthand for get_node()
@onready var adventure_container = $MarginContainer/VBoxContainer/TopHalf/AdventureSection/VBoxContainer/AdventureContainer
@onready var discard_container   = $MarginContainer/VBoxContainer/TopHalf/DiscardSection/VBoxContainer/DiscardContainer
@onready var deck_container      = $MarginContainer/VBoxContainer/TopHalf/DeckSection/VBoxContainer/DeckContainer
@onready var wisdom_container    = $MarginContainer/VBoxContainer/BottomHalf/WisdomSection/VBoxContainer/WisdomContainer
@onready var satchel_container   = $MarginContainer/VBoxContainer/BottomHalf/SatchelSection/VBoxContainer/SatchelContainer
@onready var volition_container  = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/VolitionSection/VolitionContainer
@onready var strength_container  = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/StrengthSection/StrengthContainer
@onready var fool_vitality_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolVitalityLabel
@onready var adventure_label     = $MarginContainer/VBoxContainer/TopHalf/AdventureSection/VBoxContainer/AdventureLabel
@onready var discard_label       = $MarginContainer/VBoxContainer/TopHalf/DiscardSection/VBoxContainer/DiscardLabel
@onready var deck_label          = $MarginContainer/VBoxContainer/TopHalf/DeckSection/VBoxContainer/DeckLabel
@onready var wisdom_label        = $MarginContainer/VBoxContainer/BottomHalf/WisdomSection/VBoxContainer/WisdomLabel
@onready var satchel_label       = $MarginContainer/VBoxContainer/BottomHalf/SatchelSection/VBoxContainer/SatchelLabel
@onready var fool_label          = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolLabel
@onready var volition_label      = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/VolitionSection/VolitionLabel
@onready var strength_label      = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/StrengthSection/StrengthLabel

func _ready():
	AudioManager.set_screen("game")

	# Create the animation layer before anything else so it's available
	# when the first state_changed signal fires after start_game()
	anim_layer = Control.new()
	anim_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim_layer.z_index = 10
	add_child(anim_layer)

	# Set static text for all zone header labels
	adventure_label.text = "Adventure Field"
	discard_label.text   = "Discard Pile"
	deck_label.text      = "Deck"
	wisdom_label.text    = "Wisdom"
	satchel_label.text   = "Satchel"
	fool_label.text      = "The Fool"
	volition_label.text  = "Volition"
	strength_label.text  = "Strength"

	# ------------------------------------
	# SIGNAL CONNECTIONS
	# GameState emits signals when game logic changes — Main.gd listens
	# and updates the visual display in response. This keeps game logic
	# and rendering cleanly separated.
	# ------------------------------------
	
	# .connect() wires signals to handler functions — like addEventListener in JS
	GameState.state_changed.connect(_on_state_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)
	GameState.discard_viewer_requested.connect(show_discard_viewer)
	ThemeManager.theme_changed.connect(_on_theme_changed)

	# Vitality damage flash fires immediately on drag-drop since there's
	# no card movement animation. On action menu the flash is triggered
	# later by animate_fool_attack() after the Fool card moves.
	GameState.sfx_vitality_damage.connect(func():
		if _suppress_animations:
			animate_vitality_damage())

	# Heal flash fires immediately on drag-drop. On action menu it fires
	# as part of the vitality card's movement animation.
	GameState.sfx_vitality_heal.connect(func():
		if _suppress_animations:
			animate_vitality_heal())

	# Track when an Ace reshuffle begins so adventure field cards animate
	# back toward the deck rather than toward the discard pile
	GameState.sfx_reshuffle_start.connect(func():
		_is_reshuffling = true
		_chance_card_id = GameState._last_chance_card_id)

	# Suppress movement animations during drag-and-drop — the drag preview
	# already provides visual feedback so flying animations would be redundant
	GameState.drag_started.connect(func(): _suppress_animations = true)
	GameState.drag_ended.connect(func(): _suppress_animations = false)

	# Pre-animation signals fire before GameState modifies its data.
	# This lets Main.gd capture card node positions before they're freed,
	# which is necessary for collision and bounce animations to know
	# where to send the attacker.
	GameState.anim_strength_vs_challenge.connect(func(str_id, chal_id):
		_pending_animations[str_id] = {"type": "collision", "target_id": chal_id}
		_delay_discard_ids[chal_id] = 0.35
		_suppress_discard_render = true)

	GameState.anim_strength_survives.connect(func(str_id, chal_id):
		_pending_strength_bounce[str_id] = chal_id
		_delay_discard_ids[chal_id] = 0.45
		_suppress_discard_render = true)

	GameState.anim_volition_vs_challenge.connect(func(vol_id, chal_id):
		_pending_animations[vol_id] = {"type": "collision", "target_id": chal_id}
		_delay_discard_ids[chal_id] = 0.35
		_suppress_discard_render = true)

	GameState.anim_fool_vs_challenge.connect(func(chal_id):
		_pending_fool_attack[chal_id] = true
		_delay_discard_ids[chal_id] = 0.45
		_suppress_discard_render = true)

	GameState.anim_challenge_damaged.connect(func(chal_id):
		_pending_challenge_flashes[chal_id] = true)

	GameState.anim_helper_deployed.connect(func(helper_id, target_id):
		_pending_animations[helper_id] = {"type": "helper", "target_id": target_id})

	GameState.anim_vitality_heal.connect(func(vitality_id):
		_pending_animations[vitality_id] = {"type": "vitality_heal", "target_id": -1})

	# Double-click on the DiscardSection panel opens the discard viewer popup.
	# Connected to the panel rather than the label so _setup_labels() doesn't
	# interfere with the mouse filter.
	var discard_section = $MarginContainer/VBoxContainer/TopHalf/DiscardSection
	discard_section.mouse_filter = Control.MOUSE_FILTER_STOP
	discard_section.gui_input.connect(_on_discard_section_input)

	_setup_colors()
	_setup_labels()
	_setup_layout()
	_setup_audio_controls()
	_clear_registry()

	GameState.start_game()
	_track_event("game_started", {"theme": ThemeManager.current_theme})

# ------------------------------------
# LAYOUT SETUP
# Configures zone proportions, card alignment, and spacing.
# size_flags_stretch_ratio works like CSS flex-grow — it controls
# how much of the available horizontal space each zone receives.
# ------------------------------------
func _setup_layout():
	var discard_section  = $MarginContainer/VBoxContainer/TopHalf/DiscardSection
	var adventure_section = $MarginContainer/VBoxContainer/TopHalf/AdventureSection
	var deck_section     = $MarginContainer/VBoxContainer/TopHalf/DeckSection

	# Top row uses a 1:3:1 ratio — Adventure Field gets 3x the space
	# of Discard and Deck since it holds the most cards simultaneously
	discard_section.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	discard_section.size_flags_stretch_ratio = 1.0 # size_flags_stretch_ratio controls how much horizontal space each zone gets relative to its siblings — like CSS flex-groww
	adventure_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adventure_section.size_flags_stretch_ratio = 3.0
	deck_section.size_flags_horizontal     = Control.SIZE_EXPAND_FILL
	deck_section.size_flags_stretch_ratio  = 1.0

	adventure_container.add_theme_constant_override("separation", 12)
	adventure_container.alignment = BoxContainer.ALIGNMENT_CENTER
	discard_container.alignment   = BoxContainer.ALIGNMENT_CENTER
	deck_container.alignment      = BoxContainer.ALIGNMENT_CENTER
	wisdom_container.alignment    = BoxContainer.ALIGNMENT_CENTER
	satchel_container.alignment   = BoxContainer.ALIGNMENT_CENTER
	strength_container.alignment  = BoxContainer.ALIGNMENT_CENTER
	volition_container.alignment  = BoxContainer.ALIGNMENT_CENTER

	# FoolEquipped shrinks to its content size and centers within the Fool zone
	var fool_equipped = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped
	fool_equipped.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fool_equipped.alignment = BoxContainer.ALIGNMENT_CENTER

	# Reduce spacing between the Fool card and the Vitality label beneath it
	var fool_vbox = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer
	fool_vbox.add_theme_constant_override("separation", 4)

	# Fixed minimum width on Strength and Volition slots prevents the Fool card
	# from shifting left or right depending on whether a card is equipped
	var strength_section = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/StrengthSection
	var volition_section = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/VolitionSection
	strength_section.custom_minimum_size.x = 130
	volition_section.custom_minimum_size.x = 130

	var fool_card = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/FoolCard
	fool_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Add vertical breathing room between zone labels and their card containers
	var sections_with_labels = [
		$MarginContainer/VBoxContainer/TopHalf/DiscardSection/VBoxContainer,
		$MarginContainer/VBoxContainer/TopHalf/AdventureSection/VBoxContainer,
		$MarginContainer/VBoxContainer/TopHalf/DeckSection/VBoxContainer,
		$MarginContainer/VBoxContainer/BottomHalf/WisdomSection/VBoxContainer,
		$MarginContainer/VBoxContainer/BottomHalf/SatchelSection/VBoxContainer,
	]
	for section_vbox in sections_with_labels:
		section_vbox.add_theme_constant_override("separation", 32)

# ------------------------------------
# SIGNAL HANDLERS
# ------------------------------------
func _on_state_changed():
	_render_all()

func _on_game_over(_reason: String):
	# Count challenges still remaining to include in analytics
	var challenges_remaining = 0
	for card in GameState.adventure_field:
		if card.role == CardData.ROLE_CHALLENGE:
			challenges_remaining += 1
	for card in GameState.deck:
		if card.role == CardData.ROLE_CHALLENGE:
			challenges_remaining += 1
	_track_event("game_lost", {
		"challenges_remaining": challenges_remaining,
		"fatal_challenge": GameState.last_fatal_challenge.get("name", "Unknown") \
			if GameState.last_fatal_challenge else "Unknown"
	})
	# Brief delay so the player can see the final board state before the scene changes
	await get_tree().create_timer(1.5).timeout # create_timer() is non-blocking — like setTimeout() in JS
	RenderingServer.set_default_clear_color(Color.BLACK)
	get_tree().change_scene_to_file("res://LoseScreen.tscn")

func _on_game_won():
	_track_event("game_won", {
		"vitality_remaining": GameState.vitality,
		"final_challenge": GameState.last_resolved_challenge.get("name", "Unknown") \
			if GameState.last_resolved_challenge else "Unknown"
	})
	await get_tree().create_timer(1.5).timeout
	RenderingServer.set_default_clear_color(Color.BLACK)
	get_tree().change_scene_to_file("res://WinScreen.tscn")

func _on_theme_changed(_new_theme: String):
	# Re-apply zone colors and re-render all cards when the theme changes
	_setup_colors()
	_render_all()

# ------------------------------------
# RENDERING
# _render_all() is called every time GameState emits state_changed.
# It delegates to _sync_zone() and _sync_single() for zones where cards
# move in and out, and to dedicated render functions for zones with
# special display logic (discard pile, deck, Fool card).
# ------------------------------------

# Rebuilds the visual state from current game data on every state_changed signal
# Like React's render — describes what the screen should look like given the current state
func _render_all():
	_sync_zone(adventure_container, GameState.adventure_field, "adventure")
	_sync_zone(satchel_container,   GameState.satchel,         "satchel")
	_sync_zone(wisdom_container,    GameState.equipped_wisdom,  "equipped_wisdom")
	_sync_single(volition_container, GameState.equipped_volition, "equipped_volition")
	_sync_single(strength_container, GameState.equipped_strength, "equipped_strength")
	if not _suppress_discard_render:
		_render_discard()
	_render_deck()
	_render_fool_stats()
	_render_fool_card()
	_is_reshuffling = false

# ------------------------------------
# CARD REGISTRY MANAGEMENT
# _sync_zone() and _sync_single() maintain a persistent mapping from
# card ID to Card node. Rather than destroying and recreating nodes on
# every state change, they diff the expected card set against what's
# currently displayed and only add, remove, or move nodes that changed.
# This is what enables smooth movement animations between zones.
# ------------------------------------

func _clear_registry():
	# Called at game start to free any card nodes from a previous game
	# and reset all tracking dictionaries to a clean state
	for id in _card_nodes:
		if is_instance_valid(_card_nodes[id]):
			_card_nodes[id].queue_free()
	_card_nodes.clear()
	_card_zones.clear()

func _sync_zone(container: Node, cards: Array, zone_name: String):
	# Build the set of card IDs that should currently be in this zone
	var expected_ids: Dictionary = {}
	for card in cards:
		if card.has("_id"):
			expected_ids[card["_id"]] = card

	# Remove nodes for cards that are no longer in this zone
	for child in container.get_children():
		if child.has_method("set_card") and child.card_data.has("_id"):
			var id = child.card_data["_id"]
			if not expected_ids.has(id):
				if _card_zones.get(id, "") == zone_name:
					# Capture screen position before the node is removed so
					# the destination zone can use it as an animation origin
					_card_last_positions[id] = child.global_position
					_card_nodes.erase(id)
					_card_zones.erase(id)
					if _card_exists_in_any_zone(id):
						# Card moved to another zone — remove silently here,
						# the destination zone's sync will animate it arriving
						child.queue_free()
					elif _pending_animations.has(id):
						# A special animation is queued for this card
						var anim_data = _pending_animations[id]
						_pending_animations.erase(id)
						if anim_data["type"] == "helper":
							animate_helper_deploy(child, anim_data["target_id"])
						elif anim_data["type"] == "vitality_heal":
							animate_vitality_card_heal(child)
						else:
							animate_collision(child, anim_data["target_id"])
					elif _delay_discard_ids.has(id):
						# This card's discard is delayed so an attacking card
						# can reach it first before both fly to the discard pile
						var delay = _delay_discard_ids[id]
						_delay_discard_ids.erase(id)
						_pending_collision_positions[id] = child.global_position
						if _pending_fool_attack.has(id):
							_pending_fool_attack.erase(id)
							animate_fool_attack(id)
						var captured = child
						get_tree().create_timer(delay).timeout.connect(func():
							if is_instance_valid(captured):
								animate_card_to_discard(captured)
							_suppress_discard_render = false
							_render_discard())
					elif _is_reshuffling and id != _chance_card_id:
						# Cards reshuffled by an Ace fly back toward the deck
						animate_card_to_deck(child)
					else:
						animate_card_to_discard(child)

	# Add or update nodes for cards that belong in this zone
	for card in cards:
		if not card.has("_id"):
			continue
		var id = card["_id"]
		if not _card_nodes.has(id) or not is_instance_valid(_card_nodes[id]):
			# No node exists yet — instantiate one and animate it arriving
			var instance = CardScene.instantiate()
			instance.source_zone = zone_name
			container.add_child(instance)
			instance.set_card(card)
			_card_nodes[id] = instance
			_card_zones[id] = zone_name
			if _card_last_positions.has(id):
				# Card moved from another zone — fly from its last known position
				var last_pos = _card_last_positions[id]
				_card_last_positions.erase(id)
				animate_card_in_from_pos(instance, last_pos)
			else:
				# Brand new card dealt from the deck
				animate_card_in(instance, deck_container)
		elif _card_zones.get(id, "") != zone_name:
			# Node exists but belongs to a different zone — reparent it
			var existing = _card_nodes[id]
			existing.source_zone = zone_name
			existing.get_parent().remove_child(existing)
			container.add_child(existing)
			_card_zones[id] = zone_name
		else:
			# Card is already in the correct zone — refresh its visual display.
			# Reassigning card_data ensures value changes (e.g. volition depletion,
			# helper doubling) are reflected on the node immediately.
			_card_nodes[id].card_data = card
			_card_nodes[id].update_display()
			if _pending_challenge_flashes.has(id):
				_pending_challenge_flashes.erase(id)
				animate_challenge_damaged(_card_nodes[id])

func _sync_single(container: Node, card, zone_name: String):
	# Handles single-card equipped slots (Strength and Volition)
	if card == null:
		# Slot is now empty — remove any existing card node
		for child in container.get_children():
			if child.has_method("set_card"):
				var id = child.card_data.get("_id", -999)
				_card_last_positions[id] = child.global_position
				_card_nodes.erase(id)
				_card_zones.erase(id)
				if _card_exists_in_any_zone(id):
					child.queue_free()
				elif _pending_animations.has(id):
					var anim_data = _pending_animations[id]
					_pending_animations.erase(id)
					animate_collision(child, anim_data["target_id"])
				else:
					animate_card_to_discard(child)
		return

	var id = card.get("_id", -999)
	if not _card_nodes.has(id) or not is_instance_valid(_card_nodes[id]):
		# No node yet — clear the slot and create a new one.
		# If the outgoing card was discarded (replaced by a new equip),
		# animate it flying to the discard pile instead of freeing it instantly.
		for child in container.get_children():
			if child.has_method("set_card"):
				var old_id = child.card_data.get("_id", -999)
				_card_last_positions[old_id] = child.global_position
				_card_nodes.erase(old_id)
				_card_zones.erase(old_id)
				if _card_exists_in_any_zone(old_id):
					child.queue_free()
				else:
					animate_card_to_discard(child)
		var instance = CardScene.instantiate()
		instance.source_zone = zone_name
		container.add_child(instance)
		instance.set_card(card)
		_card_nodes[id] = instance
		_card_zones[id] = zone_name
		if _card_last_positions.has(id):
			var last_pos = _card_last_positions[id]
			_card_last_positions.erase(id)
			animate_card_in_from_pos(instance, last_pos)
		else:
			animate_card_in(instance, adventure_container)
	elif _card_zones.get(id, "") != zone_name:
		# Card exists but is in the wrong container — reparent it
		var existing = _card_nodes[id]
		existing.source_zone = zone_name
		existing.get_parent().remove_child(existing)
		container.add_child(existing)
		_card_zones[id] = zone_name
	else:
		# Card is already in the correct slot — refresh display and check
		# for any pending animation effects triggered by recent game actions
		_card_nodes[id].card_data = card
		_card_nodes[id].update_display()
		if _pending_strength_bounce.has(id):
			var chal_id = _pending_strength_bounce[id]
			_pending_strength_bounce.erase(id)
			animate_strength_bounce(_card_nodes[id], chal_id, container)
		if _pending_challenge_flashes.has(id):
			_pending_challenge_flashes.erase(id)
			animate_challenge_damaged(_card_nodes[id])

func _card_exists_in_any_zone(card_id: int) -> bool:
	# Returns true if the card is still present in any active game zone.
	# Used to distinguish a card that moved zones (should animate to destination)
	# from a card that was discarded (should animate to the discard pile).
	for card in GameState.adventure_field:
		if card.get("_id", -999) == card_id: return true
	for card in GameState.satchel:
		if card.get("_id", -999) == card_id: return true
	for card in GameState.equipped_wisdom:
		if card.get("_id", -999) == card_id: return true
	if GameState.equipped_strength != null:
		if GameState.equipped_strength.get("_id", -999) == card_id: return true
	if GameState.equipped_volition != null:
		if GameState.equipped_volition.get("_id", -999) == card_id: return true
	return false

# ------------------------------------
# ANIMATIONS
# All animations use Godot's Tween system. create_tween() produces a
# one-shot sequence. tween_property() interpolates a node property
# from its current value to a target over a given duration in seconds.
# EASE_OUT feels like a card decelerating as it arrives.
# EASE_IN feels like a card accelerating as it leaves.
# ------------------------------------

func animate_card_in(card_node: Control, from_node: Control = null):
	if _suppress_animations:
		return
	# Wait one frame so the container has finished laying out the card
	# and global_position reflects its true destination
	await get_tree().process_frame
	var dest = card_node.global_position
	var from_pos = from_node.global_position if from_node != null else dest
	if from_pos.distance_to(dest) < 10:
		return
	# A visual duplicate flies in on the animation layer while the real card
	# stays invisible at its layout position. This prevents HBoxContainer from
	# recalculating spacing mid-animation and causing gaps between cards.
	var preview = card_node.duplicate()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.size = card_node.size
	anim_layer.add_child(preview)
	preview.global_position = from_pos
	card_node.modulate.a = 0
	var tween = preview.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(preview, "global_position", dest, 0.3)
	tween.tween_callback(func():
		if is_instance_valid(card_node):
			card_node.modulate.a = 1.0
		preview.queue_free())

func animate_card_in_from_pos(card_node: Control, from_pos: Vector2):
	if _suppress_animations:
		return
	# Same as animate_card_in but accepts a pre-captured Vector2 position
	# rather than reading from a container node reference
	await get_tree().process_frame
	var dest = card_node.global_position
	if from_pos.distance_to(dest) < 10:
		return
	var preview = card_node.duplicate()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.size = card_node.size
	anim_layer.add_child(preview)
	preview.global_position = from_pos
	card_node.modulate.a = 0
	var tween = preview.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(preview, "global_position", dest, 0.3)
	tween.tween_callback(func():
		if is_instance_valid(card_node):
			card_node.modulate.a = 1.0
		preview.queue_free())

func animate_card_to_discard(card_node: Control):
	if _suppress_animations:
		card_node.queue_free()
		return
	# Reparent to anim_layer so the card floats freely above all zones
	# while it flies toward the discard pile
	var src_pos = card_node.global_position
	card_node.reparent(anim_layer, true)
	card_node.global_position = src_pos
	var tween = card_node.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card_node, "global_position", discard_container.global_position, 0.25)
	tween.parallel().tween_property(card_node, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): card_node.queue_free())

func animate_card_to_deck(card_node: Control):
	if _suppress_animations:
		card_node.queue_free()
		return
	# Used when an Ace reshuffles the adventure field — cards fly back to the deck
	var src_pos = card_node.global_position
	card_node.reparent(anim_layer, true)
	card_node.global_position = src_pos
	var tween = card_node.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card_node, "global_position", deck_container.global_position, 0.25)
	tween.parallel().tween_property(card_node, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): card_node.queue_free())

func animate_vitality_damage():
	# Red flash and scale pulse on the Vitality label when the Fool takes damage
	var tween = fool_vitality_label.create_tween()
	tween.tween_property(fool_vitality_label, "scale", Vector2(1.5, 1.5), 0.1)
	tween.parallel().tween_property(fool_vitality_label, "modulate", Color(1.0, 0.1, 0.1), 0.1)
	tween.tween_interval(0.08)
	tween.tween_property(fool_vitality_label, "scale", Vector2(1.0, 1.0), 0.25)
	tween.parallel().tween_property(fool_vitality_label, "modulate", Color(1.0, 1.0, 1.0), 0.25)

func animate_vitality_heal():
	# Green flash and scale pulse on the Vitality label when the Fool heals
	var tween = fool_vitality_label.create_tween()
	tween.tween_property(fool_vitality_label, "scale", Vector2(1.5, 1.5), 0.12)
	tween.parallel().tween_property(fool_vitality_label, "modulate", Color(0.2, 1.0, 0.2), 0.12)
	tween.tween_interval(0.1)
	tween.tween_property(fool_vitality_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(fool_vitality_label, "modulate", Color(1.0, 1.0, 1.0), 0.2)

func animate_collision(attacker_node: Control, target_id: int):
	if _suppress_animations:
		attacker_node.queue_free()
		return
	# Prevent the discard pile from updating while the animation plays
	# so the card doesn't appear in the discard pile before it arrives there
	_suppress_discard_render = true
	# Use the target node's live position if it still exists, otherwise fall back
	# to the position captured before the node was freed
	var target_node = _card_nodes.get(target_id, null)
	var dest = discard_container.global_position
	if target_node != null and is_instance_valid(target_node):
		dest = target_node.global_position
	elif _pending_collision_positions.has(target_id):
		dest = _pending_collision_positions[target_id]
		_pending_collision_positions.erase(target_id)
	var src_pos = attacker_node.global_position
	attacker_node.reparent(anim_layer, true)
	attacker_node.global_position = src_pos
	var tween = attacker_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(attacker_node, "global_position", dest, 0.2)
	tween.tween_interval(0.1)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(attacker_node, "global_position", discard_container.global_position, 0.2)
	tween.parallel().tween_property(attacker_node, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		attacker_node.queue_free()
		_suppress_discard_render = false
		_render_discard())

func animate_helper_deploy(helper_node: Control, target_id: int):
	if _suppress_animations:
		# No movement but still flash the target card's boosted value
		helper_node.queue_free()
		var target_node = _card_nodes.get(target_id, null)
		if target_node != null and is_instance_valid(target_node):
			animate_card_boosted(target_node)
		return
	var target_node = _card_nodes.get(target_id, null)
	var target_pos = discard_container.global_position
	if target_node != null and is_instance_valid(target_node):
		target_pos = target_node.global_position
	var src_pos = helper_node.global_position
	helper_node.reparent(anim_layer, true)
	helper_node.global_position = src_pos
	var tween = helper_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(helper_node, "global_position", target_pos, 0.25)
	tween.tween_interval(0.08)
	tween.tween_callback(func():
		if target_node != null and is_instance_valid(target_node):
			animate_card_boosted(target_node))
	tween.tween_interval(0.15)
	tween.tween_property(helper_node, "global_position", discard_container.global_position, 0.2)
	tween.parallel().tween_property(helper_node, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): helper_node.queue_free())

func animate_card_boosted(card_node: Control):
	# Gold flash and scale pulse on the value label to highlight a doubled value
	var value_label = card_node.get_node_or_null("VBoxContainer/CardValue")
	if value_label == null:
		return
	var tween = value_label.create_tween()
	tween.tween_property(value_label, "scale", Vector2(1.8, 1.8), 0.15)
	tween.parallel().tween_property(value_label, "modulate", Color(1.0, 0.85, 0.2), 0.15)
	tween.tween_interval(0.1)
	tween.tween_property(value_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(value_label, "modulate", Color(1.0, 1.0, 1.0), 0.2)

func animate_vitality_card_heal(vitality_node: Control):
	if _suppress_animations:
		vitality_node.queue_free()
		return
	# Vitality card slides to the Fool card position, triggers the heal flash,
	# then continues to the discard pile
	var fool_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/FoolCard
	var fool_card = fool_container.get_node_or_null("FoolCardDisplay")
	var target_pos = fool_vitality_label.global_position
	if fool_card != null and is_instance_valid(fool_card):
		target_pos = fool_card.global_position
	var src_pos = vitality_node.global_position
	vitality_node.reparent(anim_layer, true)
	vitality_node.global_position = src_pos
	var tween = vitality_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(vitality_node, "global_position", target_pos, 0.25)
	tween.tween_interval(0.08)
	tween.tween_callback(func(): animate_vitality_heal())
	tween.tween_interval(0.1)
	tween.tween_property(vitality_node, "global_position", discard_container.global_position, 0.2)
	tween.parallel().tween_property(vitality_node, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): vitality_node.queue_free())

func animate_fool_attack(target_id: int):
	if _suppress_animations:
		return
	# The Fool card lunges toward the challenge position then returns,
	# with the vitality damage flash firing at the moment of impact
	var fool_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/FoolCard
	var fool_card = fool_container.get_node_or_null("FoolCardDisplay")
	if fool_card == null or not is_instance_valid(fool_card):
		return
	var origin = fool_card.global_position
	var dest = _pending_collision_positions.get(target_id, origin)
	var tween = fool_card.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fool_card, "global_position", dest, 0.2)
	tween.tween_interval(0.05)
	tween.tween_callback(func(): animate_vitality_damage())
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fool_card, "global_position", origin, 0.2)

func animate_challenge_damaged(card_node: Control):
	# Red flash and scale pulse on a challenge's value label after
	# it takes partial damage from a Volition card
	var value_label = card_node.get_node_or_null("VBoxContainer/CardValue")
	if value_label == null:
		return
	var tween = value_label.create_tween()
	tween.tween_property(value_label, "scale", Vector2(1.6, 1.6), 0.12)
	tween.parallel().tween_property(value_label, "modulate", Color(1.0, 0.2, 0.2), 0.12)
	tween.tween_interval(0.1)
	tween.tween_property(value_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(value_label, "modulate", Color(1.0, 1.0, 1.0), 0.2)

func animate_strength_bounce(strength_node: Control, challenge_id: int, container: Node):
	if _suppress_animations:
		# No movement animation but still show the depleted value flash
		animate_strength_depleted(strength_node)
		return
	# Strength card slides to the challenge position, pauses briefly,
	# then bounces back to its equipped slot with a value depletion flash
	var origin = strength_node.global_position
	var dest = _pending_collision_positions.get(challenge_id, origin)
	_pending_collision_positions.erase(challenge_id)
	strength_node.reparent(anim_layer, true)
	strength_node.global_position = origin
	var tween = strength_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(strength_node, "global_position", dest, 0.2)
	tween.tween_interval(0.05)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(strength_node, "global_position", origin, 0.2)
	tween.tween_callback(func():
		strength_node.reparent(container, false)
		animate_strength_depleted(strength_node))

func animate_strength_depleted(card_node: Control):
	# Red flash and scale pulse on the Strength value label after
	# the card survives a challenge with reduced value
	var value_label = card_node.get_node_or_null("VBoxContainer/CardValue")
	if value_label == null:
		return
	var tween = value_label.create_tween()
	tween.tween_property(value_label, "scale", Vector2(1.6, 1.6), 0.12)
	tween.parallel().tween_property(value_label, "modulate", Color(1.0, 0.2, 0.2), 0.12)
	tween.tween_interval(0.1)
	tween.tween_property(value_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(value_label, "modulate", Color(1.0, 1.0, 1.0), 0.2)

# ------------------------------------
# ZONE RENDER FUNCTIONS
# These handle zones with special display logic that doesn't fit
# the persistent card registry pattern.
# ------------------------------------

func _render_discard():
	# Shows only the top card of the discard pile, non-interactive.
	# Recreated fresh each time since only one card is ever visible.
	for child in discard_container.get_children():
		child.queue_free()
	if GameState.discard_pile.size() > 0:
		var top_card = GameState.discard_pile.back()
		var instance = CardScene.instantiate()
		instance.source_zone = "discard"
		instance.draggable = false
		discard_container.add_child(instance)
		instance.set_card(top_card)
	discard_label.text = "Discard Pile (" + str(GameState.discard_pile.size()) + ")"

func show_discard_viewer():
	# Opens a scrollable popup showing all discarded cards in reverse order.
	# Triggered by double-clicking the DiscardSection panel or its top card.
	if GameState.discard_pile.size() == 0:
		return
	var popup = PopupPanel.new()
	popup.title = "Discard Pile — " + str(GameState.discard_pile.size()) + " cards"
	var vbox = VBoxContainer.new()
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 6)
	var cards_reversed = GameState.discard_pile.duplicate()
	cards_reversed.reverse() # duplicate().reverse() creates a reversed copy without mutating the original like [...arr].reverse() in JS
	for card in cards_reversed:
		var instance = CardScene.instantiate()
		instance.source_zone = "discard"
		instance.draggable = false
		card_row.add_child(instance)
		instance.set_card(card)
	scroll.add_child(card_row)
	vbox.add_child(scroll)
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(close_btn)
	popup.add_child(vbox)
	get_tree().root.add_child(popup)
	popup.popup_centered()

func _render_deck():
	# Shows a face-down card back image and the remaining card/challenge counts.
	# Recreated on every state change since the counts update frequently.
	for child in deck_container.get_children():
		child.queue_free()
	if GameState.deck.size() > 0:
		var instance = CardScene.instantiate()
		instance.source_zone = "deck"
		instance.draggable = false
		deck_container.add_child(instance)
		instance.show_card_back()
	var challenge_count = 0
	for card in GameState.deck:
		if card.role == CardData.ROLE_CHALLENGE:
			challenge_count += 1
	var label = Label.new()
	label.text = str(GameState.deck.size()) + " cards\n" + str(challenge_count) + " challenges remaining"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	deck_container.add_child(label)

func _render_fool_card():
	# Creates the Fool card display once and never recreates it.
	# The name and value labels are made transparent since The Fool's
	# identity is shown by the zone label and vitality display instead.
	var fool_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/FoolCard
	if fool_container.has_node("FoolCardDisplay"):
		return
	var fool_data = CardData.all_cards[0]
	var instance = CardScene.instantiate()
	instance.name = "FoolCardDisplay"
	instance.source_zone = "fool"
	fool_container.add_child(instance)
	instance.set_card(fool_data)
	instance.get_node("VBoxContainer/CardName").modulate = Color(0, 0, 0, 0)
	instance.get_node("VBoxContainer/CardValue").modulate = Color(0, 0, 0, 0)

func _render_fool_stats():
	# Updates the Vitality label below the Fool card on every state change
	fool_vitality_label.text = "Vitality: " + str(GameState.vitality) + " / 25"
	fool_vitality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# ------------------------------------
# VISUAL STYLING
# ------------------------------------

func _setup_colors():
	# Apply background colors to each zone panel from the current theme.
	# Also sets the viewport clear color to match, covering the area
	# behind all panels with the theme's background color.
	var zone_map = {
		$MarginContainer/VBoxContainer/TopHalf/DiscardSection:   "discard",
		$MarginContainer/VBoxContainer/TopHalf/AdventureSection: "adventure",
		$MarginContainer/VBoxContainer/TopHalf/DeckSection:      "deck",
		$MarginContainer/VBoxContainer/BottomHalf/WisdomSection: "wisdom",
		$MarginContainer/VBoxContainer/BottomHalf/FoolSection:   "fool",
		$MarginContainer/VBoxContainer/BottomHalf/SatchelSection:"satchel",
	}
	for node in zone_map:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = ThemeManager.get_zone_color(zone_map[node])
		stylebox.corner_radius_top_left    = 8
		stylebox.corner_radius_top_right   = 8
		stylebox.corner_radius_bottom_left = 8
		stylebox.corner_radius_bottom_right = 8
		stylebox.content_margin_left   = 16
		stylebox.content_margin_right  = 16
		stylebox.content_margin_top    = 16
		stylebox.content_margin_bottom = 16
		node.add_theme_stylebox_override("panel", stylebox)
	RenderingServer.set_default_clear_color(ThemeManager.get_current()["background"])

func _setup_labels():
	# Center all zone labels and set font sizes.
	# Header labels (zone titles) are slightly larger than sub-labels.
	var all_labels = [
		adventure_label, discard_label, deck_label,
		wisdom_label, satchel_label, fool_label,
		volition_label, strength_label, fool_vitality_label
	]
	for label in all_labels:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
	var header_labels = [
		adventure_label, discard_label, deck_label,
		wisdom_label, satchel_label, fool_label
	]
	for label in header_labels:
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))

# ------------------------------------
# INPUT HANDLERS
# ------------------------------------

func _on_discard_section_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			show_discard_viewer()

# ------------------------------------
# OPTIONS PANEL
# The Options button opens a small panel with audio toggles, a Rules
# overlay, and a Main Menu button. A full-screen transparent backdrop
# sits behind the panel so clicking anywhere outside closes it.
# ------------------------------------
func _setup_audio_controls():
	var backdrop = Button.new()
	backdrop.flat = true
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.visible = false
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.z_index = 1
	add_child(backdrop)

	var gear_btn = Button.new()
	gear_btn.text = "Options"
	gear_btn.custom_minimum_size = Vector2(32, 32)
	gear_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	gear_btn.position = Vector2(8, 8)
	gear_btn.z_index = 2
	add_child(gear_btn)

	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(8, 48)
	panel.visible = false
	panel.z_index = 2
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var music_btn = Button.new()
	music_btn.text = "Music ON" if AudioManager.music_enabled else "Music OFF"
	music_btn.pressed.connect(func():
		AudioManager.toggle_music()
		music_btn.text = "Music ON" if AudioManager.music_enabled else "Music OFF")
	vbox.add_child(music_btn)

	var sfx_btn = Button.new()
	sfx_btn.text = "SFX ON" if AudioManager.sfx_enabled else "SFX OFF"
	sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx()
		sfx_btn.text = "SFX ON" if AudioManager.sfx_enabled else "SFX OFF")
	vbox.add_child(sfx_btn)

	var rules_btn = Button.new()
	rules_btn.text = "Rules"
	rules_btn.pressed.connect(func():
		AudioManager.play_menu_click()
		_show_rules_overlay())
	vbox.add_child(rules_btn)

	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.pressed.connect(func():
		AudioManager.play_menu_click()
		_confirm_return_to_menu())
	vbox.add_child(menu_btn)

	gear_btn.pressed.connect(func():
		var opening = not panel.visible
		panel.visible = opening
		backdrop.visible = opening)

	backdrop.pressed.connect(func():
		panel.visible = false
		backdrop.visible = false)

func _show_rules_overlay():
	# Displays the rules as a full-screen overlay so the game scene
	# stays loaded in the background — no state is lost
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left   =  200
	panel.offset_right  = -200
	panel.offset_top    =   60
	panel.offset_bottom =  -60
	overlay.add_child(panel)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   140)
	margin.add_theme_constant_override("margin_right",  200)
	margin.add_theme_constant_override("margin_top",    16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(inner_vbox)
	var title = Label.new()
	title.text = "How to Play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ThemeManager.get_current()["label_color"])
	inner_vbox.add_child(title)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(scroll)
	var rules_label = Label.new()
	rules_label.text = _get_rules_text()
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.custom_minimum_size.x = 580
	scroll.add_child(rules_label)
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func():
		AudioManager.play_menu_click()
		overlay.queue_free())
	inner_vbox.add_child(close_btn)

func _get_rules_text() -> String:
	return ThemeManager.get_rules_text()

func _confirm_return_to_menu():
	# Asks for confirmation before leaving since returning to the menu
	# will end the current game and all progress will be lost
	var popup = PopupPanel.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	var label = Label.new()
	label.text = "Return to Main Menu?\nYour current game will be lost."
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
		get_tree().change_scene_to_file("res://MainMenu.tscn"))
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
# ANALYTICS
# Sends gameplay events to Google Analytics using the browser's
# gtag function via JavaScriptBridge. Only runs in web exports —
# the JavaScriptBridge singleton does not exist on desktop builds.
# ------------------------------------
func _track_event(event_name: String, params: Dictionary = {}):
	if not OS.has_feature("web"):
		return
	var js_params = JSON.stringify(params)
	JavaScriptBridge.eval(
		"typeof gtag !== 'undefined' && gtag('event', '"
		+ event_name + "', " + js_params + ")")
