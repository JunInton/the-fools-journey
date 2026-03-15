extends Control
#
const CardScene = preload("res://Card.tscn")

# Animation layer — cards fly through this when moving between zones
# Sits above all zone panels so animating cards render on top of everything
var anim_layer: Control

# NEW: maps card _id to its Card node and current zone
# Like a React key → component map — lets us track cards persistently
# instead of destroying and recreating nodes on every state change
var _card_nodes: Dictionary = {}   # int -> Card node
var _card_zones: Dictionary = {}   # int -> String zone name
var _card_last_positions: Dictionary = {}  # ← NEW: int -> Vector2

var _is_reshuffling: bool = false
var _suppress_animations: bool = false
var _chance_card_id: int = -1
var _suppress_discard_render: bool = false
var _delay_discard_ids: Dictionary = {}  # card_id -> delay in seconds
# Stores pending collision animations keyed by the moving card's ID
# Format: { card_id: { "type": "collision", "target_id": int } }
# Checked in _sync_zone/_sync_single when cards are being removed
var _pending_animations: Dictionary = {}
var _pending_collision_positions: Dictionary = {}  # target_id -> Vector2
var _pending_challenge_flashes: Dictionary = {}  # challenge_id -> true
var _pending_fool_attack: Dictionary = {}  # challenge_id -> true
var _pending_strength_bounce: Dictionary = {}  # strength_id -> challenge_id

# ------------------------------------
# @onready vars grab references to child nodes
# Like useRef in React - $ is shorthand for get_node()
# 
# ← CHANGED: All paths inside the five sections now include /VBoxContainer/
# because Part 3 added a VBoxContainer inside each section.
# Old path example: .../DiscardSection/DiscardLabel
# New path example: .../DiscardSection/VBoxContainer/DiscardLabel
# ------------------------------------
@onready var adventure_container = $MarginContainer/VBoxContainer/TopHalf/AdventureSection/VBoxContainer/AdventureContainer
@onready var discard_container = $MarginContainer/VBoxContainer/TopHalf/DiscardSection/VBoxContainer/DiscardContainer
@onready var deck_container = $MarginContainer/VBoxContainer/TopHalf/DeckSection/VBoxContainer/DeckContainer

@onready var wisdom_container = $MarginContainer/VBoxContainer/BottomHalf/WisdomSection/VBoxContainer/WisdomContainer
@onready var satchel_container = $MarginContainer/VBoxContainer/BottomHalf/SatchelSection/VBoxContainer/SatchelContainer

# Volition and Strength container paths are unchanged - they were already
# inside VBoxContainers inside FoolEquipped
@onready var volition_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/VolitionSection/VolitionContainer
@onready var strength_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/StrengthSection/StrengthContainer

# ← CHANGED: fool_name_label removed entirely - FoolNameLabel node was deleted in Part 3
# ← CHANGED: fool_vitality_label path updated - node moved to be a direct child of FoolSection
@onready var fool_vitality_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolVitalityLabel

# ← CHANGED: All label paths now include /VBoxContainer/ for the five sections
@onready var adventure_label = $MarginContainer/VBoxContainer/TopHalf/AdventureSection/VBoxContainer/AdventureLabel
@onready var discard_label = $MarginContainer/VBoxContainer/TopHalf/DiscardSection/VBoxContainer/DiscardLabel
@onready var deck_label = $MarginContainer/VBoxContainer/TopHalf/DeckSection/VBoxContainer/DeckLabel
@onready var wisdom_label = $MarginContainer/VBoxContainer/BottomHalf/WisdomSection/VBoxContainer/WisdomLabel
@onready var satchel_label = $MarginContainer/VBoxContainer/BottomHalf/SatchelSection/VBoxContainer/SatchelLabel
@onready var fool_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolLabel
@onready var volition_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/VolitionSection/VolitionLabel
@onready var strength_label = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/StrengthSection/StrengthLabel

func _ready():
	AudioManager.set_screen("game")
	
	# NEW: create animation layer first so it exists before anything else
	anim_layer = Control.new()
	anim_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim_layer.z_index = 10
	add_child(anim_layer)
	print("Animation layer created. z_index: ", anim_layer.z_index)
	
	# Set static label text for all zone headers
	adventure_label.text = "Adventure Field"
	discard_label.text = "Discard Pile"
	deck_label.text = "Deck"
	wisdom_label.text = "Wisdom"
	satchel_label.text = "Satchel"
	fool_label.text = "The Fool"
	volition_label.text = "Volition"
	strength_label.text = "Strength"
	# ← CHANGED: fool_name_label.text removed - that node no longer exists

	# Connect to GameState signals
	# Like addEventListener in JS - these fire automatically when emitted
	GameState.state_changed.connect(_on_state_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)
	
	GameState.discard_viewer_requested.connect(show_discard_viewer)
	
	# CHANGED: vitality damage only fires immediately on drag-drop
	# action menu path gets it delayed via animate_fool_attack
	GameState.sfx_vitality_damage.connect(func():
		if _suppress_animations:
			animate_vitality_damage())
	GameState.sfx_vitality_heal.connect(func(): 
		# Only flash directly if animations are suppressed (drag-and-drop)
		# or if there's no pending vitality animation
		# The card animation will trigger the flash itself otherwise
		if _suppress_animations:
			animate_vitality_heal())
	
	GameState.sfx_reshuffle_start.connect(func():
		_is_reshuffling = true
		_chance_card_id = GameState._last_chance_card_id)
	
	GameState.drag_started.connect(func(): _suppress_animations = true)
	GameState.drag_ended.connect(func(): _suppress_animations = false)
	
	GameState.anim_strength_vs_challenge.connect(func(str_id, chal_id):
		_pending_animations[str_id] = {"type": "collision", "target_id": chal_id}
		# NEW: delay challenge discard so collision animation plays first
		_delay_discard_ids[chal_id] = 0.35
		# NEW: suppress discard render immediately so no copy appears
		_suppress_discard_render = true)
		
	GameState.anim_strength_survives.connect(func(str_id, chal_id):
		_pending_strength_bounce[str_id] = chal_id
		# Challenge gets delayed discard so bounce plays first
		_delay_discard_ids[chal_id] = 0.45
		_suppress_discard_render = true)

	GameState.anim_volition_vs_challenge.connect(func(vol_id, chal_id):
		_pending_animations[vol_id] = {"type": "collision", "target_id": chal_id}
		# NEW: same delay for volition collision
		_delay_discard_ids[chal_id] = 0.35
		# NEW: same suppression
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

	# Connect to ThemeManager so the board recolors when theme changes
	ThemeManager.theme_changed.connect(_on_theme_changed)

	# Connect double-click on the entire DiscardSection to open the viewer
	# Using the panel rather than the label because _setup_labels() runs
	# after this and would override any mouse_filter set on the label
	var discard_section = $MarginContainer/VBoxContainer/TopHalf/DiscardSection
	discard_section.mouse_filter = Control.MOUSE_FILTER_STOP
	discard_section.gui_input.connect(_on_discard_section_input)

	_setup_colors()
	_setup_labels()
	_setup_layout()  # ← NEW: separated layout sizing into its own function
	_setup_audio_controls()
	_clear_registry()

	GameState.start_game()
	_track_event("game_started", {"theme": ThemeManager.current_theme})

# ------------------------------------
# LAYOUT SETUP
# ← NEW FUNCTION: previously these settings were scattered or missing.
# Handles section proportions and container alignment.
# size_flags_stretch_ratio is like CSS flex-grow - it controls how
# much of the available space each sibling takes relative to others.
# ------------------------------------
func _setup_layout():
	var discard_section = $MarginContainer/VBoxContainer/TopHalf/DiscardSection
	var adventure_section = $MarginContainer/VBoxContainer/TopHalf/AdventureSection
	var deck_section = $MarginContainer/VBoxContainer/TopHalf/DeckSection

	# Adventure Field gets 3x the horizontal space of Discard and Deck
	# So the ratio is 1 : 3 : 1 across the top row
	discard_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_section.size_flags_stretch_ratio = 1.0
	adventure_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adventure_section.size_flags_stretch_ratio = 3.0
	deck_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_section.size_flags_stretch_ratio = 1.0

	# Tighten spacing between cards in the adventure field
	adventure_container.add_theme_constant_override("separation", 12)

	# Center cards horizontally within Wisdom and Satchel zones
	# Without this they left-align by default
	wisdom_container.alignment = BoxContainer.ALIGNMENT_CENTER
	satchel_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Center cards within Strength and Volition zones too
	strength_container.alignment = BoxContainer.ALIGNMENT_CENTER
	volition_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Center items vertically and horizontally within the Deck zone
	# Without this they left-align by default in the VBoxContainer
	deck_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Center the top discard card within the Discard zone
	discard_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Center cards horizontally in the adventure field
	adventure_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Center FoolEquipped within the Fool zone
	# SIZE_SHRINK_CENTER collapses it to its content size and centers it
	# rather than stretching it to fill the full zone height
	var fool_equipped = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped
	fool_equipped.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fool_equipped.alignment = BoxContainer.ALIGNMENT_CENTER

	# Pull the vitality label up closer to the Fool card
	# by reducing the separation on the FoolSection VBoxContainer
	var fool_vbox = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer
	fool_vbox.add_theme_constant_override("separation", 4)
	
	# ← NEW: Fix the width of Strength and Volition slots so they always
	# reserve space even when no card is equipped.
	# Without this the Fool card drifts left or right depending on what's equipped.
	# The minimum width should be wide enough to comfortably hold one card (110px card
	# + some breathing room = 130px)
	var strength_section = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/StrengthSection
	var volition_section = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/VolitionSection
	strength_section.custom_minimum_size.x = 130
	volition_section.custom_minimum_size.x = 130

	# Also center the FoolCard slot itself within its fixed-width neighbors
	var fool_card = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/FoolCard
	fool_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Add spacing between zone labels and their card containers
	# so cards appear vertically centered in the zone rather than
	# pressed up against the label at the top.
	# This targets the VBoxContainer inside each section that wraps
	# the label + card container pair.
	var sections_with_labels = [
		$MarginContainer/VBoxContainer/TopHalf/DiscardSection/VBoxContainer,
		$MarginContainer/VBoxContainer/TopHalf/AdventureSection/VBoxContainer,
		$MarginContainer/VBoxContainer/TopHalf/DeckSection/VBoxContainer,
		$MarginContainer/VBoxContainer/BottomHalf/WisdomSection/VBoxContainer,
		$MarginContainer/VBoxContainer/BottomHalf/SatchelSection/VBoxContainer,
	]
	for section_vbox in sections_with_labels:
		# separation adds space between the label child and the container child
		# 12px gives enough breathing room without pushing cards too far down
		section_vbox.add_theme_constant_override("separation", 32)

# ------------------------------------
# SIGNAL HANDLERS
# These fire automatically when GameState or ThemeManager emit signals
# ------------------------------------
func _on_state_changed():
	_render_all()

func _on_game_over(reason: String):
	print("GAME OVER: ", reason)
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
	# Small delay so player can see the final board state before transitioning
	# create_timer().timeout is like setTimeout() in JS
	await get_tree().create_timer(1.5).timeout
	RenderingServer.set_default_clear_color(Color.BLACK)
	get_tree().change_scene_to_file("res://LoseScreen.tscn")

func _on_game_won():
	print("YOU WIN!")
	_track_event("game_won", {
		"vitality_remaining": GameState.vitality,
		"final_challenge": GameState.last_resolved_challenge.get("name", "Unknown") \
			if GameState.last_resolved_challenge else "Unknown"
	})
	await get_tree().create_timer(1.5).timeout
	RenderingServer.set_default_clear_color(Color.BLACK)
	get_tree().change_scene_to_file("res://WinScreen.tscn")

func _on_theme_changed(_new_theme: String):
	# Re-apply zone colors and re-render cards when theme switches
	# _setup_colors handles zone backgrounds, _render_all handles card colors
	_setup_colors()
	_render_all()

# ------------------------------------
# RENDERING
# Like React's render - rebuilds the visual state from current game data.
# Called every time GameState emits state_changed.
# ------------------------------------
func _render_all():
	# CHANGED: _sync_ functions replace _render_ for persistent zones
	# _render_ functions still used for discard, deck, fool which
	# have special rendering logic not yet converted
	_sync_zone(adventure_container, GameState.adventure_field, "adventure")
	_sync_zone(satchel_container, GameState.satchel, "satchel")
	_sync_zone(wisdom_container, GameState.equipped_wisdom, "equipped_wisdom")
	_sync_single(volition_container, GameState.equipped_volition, "equipped_volition")
	_sync_single(strength_container, GameState.equipped_strength, "equipped_strength")
	if not _suppress_discard_render:
		_render_discard()
	_render_deck()
	_render_fool_stats()
	_render_fool_card()
	_is_reshuffling = false
	#_debug_print_node_ids() # TEMPORARY
	
# TEMPORARY
#func _debug_print_node_ids():
	#print("--- Node ID snapshot ---")
	#for id in _card_nodes:
		#if is_instance_valid(_card_nodes[id]):
			#var node = _card_nodes[id]
			#print("  card_id:", id, 
				#"  name:", node.card_data.get("name", "?"),
				#"  zone:", _card_zones.get(id, "?"),
				#"  node_id:", node.get_instance_id())
	#print("------------------------")
	
# ------------------------------------
# CARD REGISTRY MANAGEMENT
# Replaces the destroy/recreate render pattern with persistent nodes.
# Cards keep their node identity across state changes so they can be
# animated moving between zones rather than just appearing and disappearing.
# ------------------------------------

func _clear_registry():
	# Called on game start to ensure registry is empty
	# Also frees any lingering card nodes from a previous game
	for id in _card_nodes:
		if is_instance_valid(_card_nodes[id]):
			_card_nodes[id].queue_free()
	_card_nodes.clear()
	_card_zones.clear()

func _sync_zone(container: Node, cards: Array, zone_name: String):
	# Build set of IDs that should be in this zone
	var expected_ids: Dictionary = {}
	for card in cards:
		if card.has("_id"):
			expected_ids[card["_id"]] = card

	# Remove nodes for cards that left this zone
	for child in container.get_children():
		if child.has_method("set_card") and child.card_data.has("_id"):
			var id = child.card_data["_id"]
			if not expected_ids.has(id):
				if _card_zones.get(id, "") == zone_name:
					# Store position before freeing so destination zone
					# can animate from here instead of from deck
					_card_last_positions[id] = child.global_position
					_card_nodes.erase(id)
					_card_zones.erase(id)
					if _card_exists_in_any_zone(id):
						# Card moved to another zone — just remove node silently
						# destination sync will handle creating and animating it
						child.queue_free()
					elif _pending_animations.has(id):
						# ← NEW: collision or helper animation
						var anim_data = _pending_animations[id]
						_pending_animations.erase(id)
						if anim_data["type"] == "helper":
							animate_helper_deploy(child, anim_data["target_id"])
						elif anim_data["type"] == "vitality_heal":
							# ← NEW: vitality card slides to fool card
							animate_vitality_card_heal(child)
						else:
							animate_collision(child, anim_data["target_id"])
					elif _delay_discard_ids.has(id):
						# NEW: challenge card waits for attacker to arrive
						var delay = _delay_discard_ids[id]
						_delay_discard_ids.erase(id)
						# NEW: store position so animate_collision can find it
						# even after this node is freed
						_pending_collision_positions[id] = child.global_position
						# NEW: if fool attack pending, trigger it now
						if _pending_fool_attack.has(id):
							_pending_fool_attack.erase(id)
							animate_fool_attack(id)
						var captured = child
						get_tree().create_timer(delay).timeout.connect(func():
							if is_instance_valid(captured):
								animate_card_to_discard(captured)
							# NEW: re-enable discard render after delay
							_suppress_discard_render = false
							_render_discard())
					elif _is_reshuffling and id != _chance_card_id:
						# Field cards return to deck on reshuffle
						# but the ace itself goes to discard
						animate_card_to_deck(child)
					else:
						# Card was truly discarded
						animate_card_to_discard(child)

	# Add or update nodes for cards in this zone
	for card in cards:
		if not card.has("_id"):
			continue
		var id = card["_id"]
		if not _card_nodes.has(id) or not is_instance_valid(_card_nodes[id]):
			# Card has no node yet — create one and animate it in
			var instance = CardScene.instantiate()
			instance.source_zone = zone_name
			container.add_child(instance)
			instance.set_card(card)
			_card_nodes[id] = instance
			_card_zones[id] = zone_name
			# Use last known position as animation origin if available
			# otherwise fly in from deck
			if _card_last_positions.has(id):
				var last_pos = _card_last_positions[id]
				_card_last_positions.erase(id)
				animate_card_in_from_pos(instance, last_pos)
			else:
				animate_card_in(instance, deck_container)
		elif _card_zones.get(id, "") != zone_name:
			# Card exists but is in the wrong zone — reparent it
			var existing = _card_nodes[id]
			existing.source_zone = zone_name
			existing.get_parent().remove_child(existing)
			container.add_child(existing)
			_card_zones[id] = zone_name
		else:
			# Card is already in the correct zone — refresh its display
			# Refreshing card_data reference ensures changes like value
			# reductions from volition or helper doubling show correctly
			_card_nodes[id].card_data = card
			_card_nodes[id].update_display()
			# NEW: flash challenge value red if it was just damaged by volition
			if _pending_challenge_flashes.has(id):
				_pending_challenge_flashes.erase(id)
				animate_challenge_damaged(_card_nodes[id])

func _sync_single(container: Node, card, zone_name: String):
	# Handles single-card slots like strength and volition
	if card == null:
		# Slot is empty — remove any existing node
		for child in container.get_children():
			if child.has_method("set_card"):
				var id = child.card_data.get("_id", -999)
				# Store position before freeing
				_card_last_positions[id] = child.global_position
				_card_nodes.erase(id)
				_card_zones.erase(id)
				if _card_exists_in_any_zone(id):
					# Card moved elsewhere — remove silently
					child.queue_free()
				elif _pending_animations.has(id):
					# NEW: collision animation pending for this card
					var anim_data = _pending_animations[id]
					_pending_animations.erase(id)
					animate_collision(child, anim_data["target_id"])
				else:
					# Card was discarded — animate to discard pile
					animate_card_to_discard(child)
		return

	var id = card.get("_id", -999)
	if not _card_nodes.has(id) or not is_instance_valid(_card_nodes[id]):
		# No node yet — clear slot and create new one
		for child in container.get_children():
			if child.has_method("set_card"):
				var old_id = child.card_data.get("_id", -999)
				_card_nodes.erase(old_id)
				_card_zones.erase(old_id)
				child.queue_free()
		var instance = CardScene.instantiate()
		instance.source_zone = zone_name
		container.add_child(instance)
		instance.set_card(card)
		_card_nodes[id] = instance
		_card_zones[id] = zone_name
		# Use last known position as animation origin if available
		# otherwise fly in from adventure field
		if _card_last_positions.has(id):
			var last_pos = _card_last_positions[id]
			_card_last_positions.erase(id)
			animate_card_in_from_pos(instance, last_pos)
		else:
			animate_card_in(instance, adventure_container)
	elif _card_zones.get(id, "") != zone_name:
		# Card exists but is in wrong zone — reparent it
		var existing = _card_nodes[id]
		existing.source_zone = zone_name
		existing.get_parent().remove_child(existing)
		container.add_child(existing)
		_card_zones[id] = zone_name
	else:
		# Card is already in correct zone — refresh its display
		# Same card_data refresh as _sync_zone for consistency
		_card_nodes[id].card_data = card
		_card_nodes[id].update_display()
		# NEW: trigger strength bounce if pending
		if _pending_strength_bounce.has(id):
			var chal_id = _pending_strength_bounce[id]
			_pending_strength_bounce.erase(id)
			animate_strength_bounce(_card_nodes[id], chal_id, container)
		# existing challenge flash check
		if _pending_challenge_flashes.has(id):
			_pending_challenge_flashes.erase(id)
			animate_challenge_damaged(_card_nodes[id])
		
func _card_exists_in_any_zone(card_id: int) -> bool:
	# Returns true if the card is still present in any active game zone
	# Used to distinguish "card moved zones" from "card was discarded"
	for card in GameState.adventure_field:
		if card.get("_id", -999) == card_id:
			return true
	for card in GameState.satchel:
		if card.get("_id", -999) == card_id:
			return true
	for card in GameState.equipped_wisdom:
		if card.get("_id", -999) == card_id:
			return true
	if GameState.equipped_strength != null:
		if GameState.equipped_strength.get("_id", -999) == card_id:
			return true
	if GameState.equipped_volition != null:
		if GameState.equipped_volition.get("_id", -999) == card_id:
			return true
	return false
		
# ------------------------------------
# ANIMATIONS
# Cards animate using Godot's Tween system — like CSS transitions.
# create_tween() creates a one-shot animation sequence.
# tween_property(node, "property", target_value, duration) is the
# core method — like CSS transition: property duration.
# ------------------------------------

func animate_card_in(card_node: Control, from_node: Control = null):
	if _suppress_animations:
		return
	# Wait one frame so both source and destination positions are settled
	await get_tree().process_frame
	var dest = card_node.global_position
	# CHANGED: read from_node position after await so layout is settled
	# Previously from_position was captured before await giving wrong coords
	var from_pos = from_node.global_position if from_node != null else dest
	# Skip animation if card is already at destination
	if from_pos.distance_to(dest) < 10:
		return
	# ← CHANGED: use a duplicate on anim_layer instead of moving the real node
	# Moving a HBoxContainer child's global_position directly causes the container
	# to recalculate layout incorrectly, creating gaps between cards.
	# The duplicate flies in visually while the real card stays invisible at
	# its correct layout position — no layout conflict possible.
	var preview = card_node.duplicate()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.size = card_node.size
	anim_layer.add_child(preview)
	preview.global_position = from_pos
	card_node.modulate.a = 0  # hide real card during animation
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
	# Same as animate_card_in but uses a captured position
	# rather than reading from a container node
	await get_tree().process_frame
	var dest = card_node.global_position
	# Skip animation if card is already at destination
	if from_pos.distance_to(dest) < 10:
		return
	# ← CHANGED: same duplicate approach as animate_card_in
	# prevents layout gaps when cards animate into HBoxContainers
	var preview = card_node.duplicate()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.size = card_node.size
	anim_layer.add_child(preview)
	preview.global_position = from_pos
	card_node.modulate.a = 0  # hide real card during animation
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
		# Just free immediately with no animation
		card_node.queue_free()
		return
	# Card flies toward the discard pile then disappears
	# Card node gets freed after animation completes
	var src_pos = card_node.global_position
	card_node.reparent(anim_layer, true)
	card_node.global_position = src_pos
	var dest = discard_container.global_position
	var tween = card_node.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card_node, "global_position", dest, 0.25)
	tween.parallel().tween_property(card_node, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): card_node.queue_free())

func animate_vitality_damage():
	# Red flash and scale pulse on vitality label
	var tween = fool_vitality_label.create_tween()
	tween.tween_property(fool_vitality_label, "scale", Vector2(1.5, 1.5), 0.1)
	tween.parallel().tween_property(fool_vitality_label, "modulate",
		Color(1.0, 0.1, 0.1), 0.1)
	tween.tween_interval(0.08)
	tween.tween_property(fool_vitality_label, "scale", Vector2(1.0, 1.0), 0.25)
	tween.parallel().tween_property(fool_vitality_label, "modulate",
		Color(1.0, 1.0, 1.0), 0.25)
	
func animate_vitality_heal():
	# Green flash and scale pulse on vitality label — mirrors animate_card_boosted
	var tween = fool_vitality_label.create_tween()
	tween.tween_property(fool_vitality_label, "scale", Vector2(1.5, 1.5), 0.12)
	tween.parallel().tween_property(fool_vitality_label, "modulate",
		Color(0.2, 1.0, 0.2), 0.12)
	tween.tween_interval(0.1)
	tween.tween_property(fool_vitality_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(fool_vitality_label, "modulate",
		Color(1.0, 1.0, 1.0), 0.2)

func animate_card_to_deck(card_node: Control):
	if _suppress_animations:
		card_node.queue_free()
		return
	# Card flies back toward the deck — used when reshuffling
	var src_pos = card_node.global_position
	card_node.reparent(anim_layer, true)
	card_node.global_position = src_pos
	var tween = card_node.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card_node, "global_position", 
		deck_container.global_position, 0.25)
	tween.parallel().tween_property(card_node, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): card_node.queue_free())
	
func animate_collision(attacker_node: Control, target_id: int):
	if _suppress_animations:
		attacker_node.queue_free()
		return
		
	# NEW: suppress discard pile update until animation completes
	_suppress_discard_render = true
	
	# Attacker slides to the target card's position, pauses briefly,
	# then both fly to the discard pile
	# target_node may still exist briefly since challenge removal
	# is handled by _sync_zone after _sync_single
	var target_node = _card_nodes.get(target_id, null)
	var dest = discard_container.global_position
	if target_node != null and is_instance_valid(target_node):
		# Target node still exists — use its live position
		dest = target_node.global_position
	elif _pending_collision_positions.has(target_id):
		# ← NEW: target node already freed but position was captured
		dest = _pending_collision_positions[target_id]
		_pending_collision_positions.erase(target_id)

	var src_pos = attacker_node.global_position
	attacker_node.reparent(anim_layer, true)
	attacker_node.global_position = src_pos

	var tween = attacker_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	# Slide to target
	tween.tween_property(attacker_node, "global_position", dest, 0.2)
	# Brief pause at target position
	tween.tween_interval(0.1)
	# Then fly to discard
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(attacker_node, "global_position",
		discard_container.global_position, 0.2)
	tween.parallel().tween_property(attacker_node, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		attacker_node.queue_free()
		# NEW: re-enable discard render and update it now
		_suppress_discard_render = false
		_render_discard())

func animate_helper_deploy(helper_node: Control, target_id: int):
	if _suppress_animations:
		helper_node.queue_free()
		# CHANGED: skip movement but still flash boosted value on target
		var target_node = _card_nodes.get(target_id, null)
		if target_node != null and is_instance_valid(target_node):
			animate_card_boosted(target_node)
		return
	# Helper slides to target card, triggers value flash on target,
	# then flies to discard
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
	# CHANGED: brief pause before triggering boost so it feels like impact
	tween.tween_interval(0.08)
	# On arrival, flash the target card's value
	tween.tween_callback(func():
		if target_node != null and is_instance_valid(target_node):
			animate_card_boosted(target_node))
	# Brief pause then fly to discard
	tween.tween_interval(0.15)
	tween.tween_property(helper_node, "global_position",
		discard_container.global_position, 0.2)
	tween.parallel().tween_property(helper_node, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): helper_node.queue_free())

func animate_card_boosted(card_node: Control):
	# Brief gold flash and scale pulse on the value label
	# to draw attention to the doubled value
	var value_label = card_node.get_node_or_null("VBoxContainer/CardValue")
	if value_label == null:
		return
	var tween = value_label.create_tween()
	# Scale up
	# CHANGED: bigger scale and longer duration for visibility
	tween.tween_property(value_label, "scale", Vector2(1.8, 1.8), 0.15)
	# Flash gold
	tween.parallel().tween_property(value_label, "modulate",
		Color(1.0, 0.85, 0.2), 0.15)
	tween.tween_interval(0.1)
	# Scale back down
	tween.tween_property(value_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(value_label, "modulate",
		Color(1.0, 1.0, 1.0), 0.2)
		
func animate_vitality_card_heal(vitality_node: Control):
	if _suppress_animations:
		vitality_node.queue_free()
		return

	# Get the Fool card node position as the target
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
	# Slide to Fool card
	tween.tween_property(vitality_node, "global_position", target_pos, 0.25)
	# Brief pause then trigger heal flash on vitality label
	tween.tween_interval(0.08)
	tween.tween_callback(func(): animate_vitality_heal())
	# Then fly to discard
	tween.tween_interval(0.1)
	tween.tween_property(vitality_node, "global_position",
		discard_container.global_position, 0.2)
	tween.parallel().tween_property(vitality_node, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): vitality_node.queue_free())
	
func animate_fool_attack(target_id: int):
	if _suppress_animations:
		return
	# Fool card moves to challenge position then returns to original spot
	var fool_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/FoolCard
	var fool_card = fool_container.get_node_or_null("FoolCardDisplay")
	if fool_card == null or not is_instance_valid(fool_card):
		return

	var origin = fool_card.global_position
	var dest = _pending_collision_positions.get(target_id, origin)

	var tween = fool_card.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	# Move toward challenge
	tween.tween_property(fool_card, "global_position", dest, 0.2)
	# Brief pause at impact
	tween.tween_interval(0.05)
	# Trigger damage flash at impact point
	tween.tween_callback(func(): animate_vitality_damage())
	# Return to original position
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fool_card, "global_position", origin, 0.2)

func animate_challenge_damaged(card_node: Control):
	# Red flash and scale pulse on challenge value label
	# shows the challenge took damage from volition depletion
	var value_label = card_node.get_node_or_null("VBoxContainer/CardValue")
	if value_label == null:
		return
	var tween = value_label.create_tween()
	tween.tween_property(value_label, "scale", Vector2(1.6, 1.6), 0.12)
	tween.parallel().tween_property(value_label, "modulate",
		Color(1.0, 0.2, 0.2), 0.12)
	tween.tween_interval(0.1)
	tween.tween_property(value_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(value_label, "modulate",
		Color(1.0, 1.0, 1.0), 0.2)

func animate_strength_bounce(strength_node: Control, challenge_id: int, container: Node):
	if _suppress_animations:
		# CHANGED: skip movement but still flash depleted value
		# player needs to see the result even without the animation
		animate_strength_depleted(strength_node)
		return
	# Capture origin before reparenting
	var origin = strength_node.global_position
	var dest = _pending_collision_positions.get(challenge_id, origin)
	_pending_collision_positions.erase(challenge_id)

	# Reparent to anim_layer so container doesn't override position during tween
	strength_node.reparent(anim_layer, true)
	strength_node.global_position = origin

	var tween = strength_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	# Slide to challenge position
	tween.tween_property(strength_node, "global_position", dest, 0.2)
	tween.tween_interval(0.05)
	# Bounce back to equipped slot
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(strength_node, "global_position", origin, 0.2)
	tween.tween_callback(func():
		# Return to container and flash depleted value
		strength_node.reparent(container, false)
		animate_strength_depleted(strength_node))

func animate_strength_depleted(card_node: Control):
	# Red flash and scale pulse on the strength value label
	# shows the strength card took damage from overcoming the challenge
	var value_label = card_node.get_node_or_null("VBoxContainer/CardValue")
	if value_label == null:
		return
	var tween = value_label.create_tween()
	tween.tween_property(value_label, "scale", Vector2(1.6, 1.6), 0.12)
	tween.parallel().tween_property(value_label, "modulate",
		Color(1.0, 0.2, 0.2), 0.12)
	tween.tween_interval(0.1)
	tween.tween_property(value_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(value_label, "modulate",
		Color(1.0, 1.0, 1.0), 0.2)

# ------------------------------------
# RENDERING
# ------------------------------------

# Renders an array of cards into a container
# Like mapping over an array in JSX: cards.map(card => <Card data={card} />)
func _render_zone(container: Node, cards: Array, zone_name: String):
	# Clear existing children - like clearing innerHTML before re-rendering
	for child in container.get_children():
		child.queue_free()

	for card in cards:
		var instance = CardScene.instantiate()
		# IMPORTANT: source_zone must be set BEFORE add_child()
		# add_child() triggers _ready() on the instance, which reads source_zone
		# to set mouse_filter. Setting it after means _ready() fires with the wrong default.
		instance.source_zone = zone_name
		container.add_child(instance)
		instance.set_card(card)

# Renders a single equipped card slot (Strength or Volition)
func _render_equipped_single(container: Node, card, zone_name: String):
	for child in container.get_children():
		child.queue_free()

	if card != null:
		var instance = CardScene.instantiate()
		instance.source_zone = zone_name
		container.add_child(instance)
		instance.set_card(card)

# Discard pile shows only the top card, non-interactive
func _render_discard():
	for child in discard_container.get_children():
		child.queue_free()

	if GameState.discard_pile.size() > 0:
		var top_card = GameState.discard_pile.back()
		var instance = CardScene.instantiate()
		instance.source_zone = "discard"
		discard_container.add_child(instance)
		# draggable = false prevents players from recycling discarded cards
		instance.draggable = false
		instance.set_card(top_card)

	discard_label.text = "Discard Pile (" + str(GameState.discard_pile.size()) + ")"

# Shows a scrollable popup of all discarded cards, most recent first
# Triggered by double-clicking anywhere in the DiscardSection panel
func show_discard_viewer():
	if GameState.discard_pile.size() == 0:
		return

	var popup = PopupPanel.new()
	popup.title = "Discard Pile — " + str(GameState.discard_pile.size()) + " cards"

	var vbox = VBoxContainer.new()

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 200)
	# Horizontal scroll keeps all cards in one row instead of wrapping
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 6)

	# duplicate().reverse() = like [...arr].reverse() in JS
	var cards_reversed = GameState.discard_pile.duplicate()
	cards_reversed.reverse()

	for card in cards_reversed:
		var instance = CardScene.instantiate()
		instance.source_zone = "discard"
		card_row.add_child(instance)
		instance.draggable = false
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

# Deck shows a card back image plus count label
# Uses the Card scene for the back image so sizing matches all other cards
func _render_deck():
	for child in deck_container.get_children():
		child.queue_free()

	# Render the card back as a Card scene instance
	# This reuses the same sizing constraints as every other card
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
	# ← NEW: Shrink label to its content width and center it horizontally
	# Without this the label fills the container width and appears left-anchored
	# even though its text is centered within it
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	deck_container.add_child(label)

# ------------------------------------
# THE FOOL CARD RENDERING
# ← CHANGED: The Fool card now hides its name and value labels.
# The zone label ("The Fool") and the vitality label below handle
# all the information the player needs about this zone.
# The card only renders once - we check for the named node to avoid
# re-creating it on every state_changed signal.
# ------------------------------------
func _render_fool_card():
	var fool_container = $MarginContainer/VBoxContainer/BottomHalf/FoolSection/VBoxContainer/FoolEquipped/FoolCard
	if fool_container.has_node("FoolCardDisplay"):
		return

	# The Fool is always index 0 in CardData.all_cards
	var fool_data = CardData.all_cards[0]
	var instance = CardScene.instantiate()
	instance.name = "FoolCardDisplay"
	instance.source_zone = "fool"
	fool_container.add_child(instance)
	instance.set_card(fool_data)

	# CHANGED: was visible = false which removes nodes from layout,
	# making the Fool card shorter than equipped cards and causing the
	# vitality label to shift down when a strength/volition card is equipped.
	# modulate = Color(0,0,0,0) makes labels fully transparent while keeping
	# them in the layout, so the Fool card stays the same height as equipped cards.
	instance.get_node("VBoxContainer/CardName").modulate = Color(0, 0, 0, 0)
	instance.get_node("VBoxContainer/CardValue").modulate = Color(0, 0, 0, 0)

# ------------------------------------
# FOOL STATS
# ← CHANGED: fool_vitality_label is now a direct child of FoolSection
# (moved in Part 3), so it sits below the entire FoolEquipped row.
# Centering it makes it read as a caption under the Fool card area.
# ------------------------------------
func _render_fool_stats():
	fool_vitality_label.text = "Vitality: " + str(GameState.vitality) + " / 25"
	fool_vitality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# ------------------------------------
# ZONE COLORS
# Reads colors from ThemeManager instead of hardcoded values
# so switching themes recolors all zones automatically.
# Like a CSS variable that updates everywhere it's used.
# ------------------------------------
func _setup_colors():
	var zone_map = {
		$MarginContainer/VBoxContainer/TopHalf/DiscardSection: "discard",
		$MarginContainer/VBoxContainer/TopHalf/AdventureSection: "adventure",
		$MarginContainer/VBoxContainer/TopHalf/DeckSection: "deck",
		$MarginContainer/VBoxContainer/BottomHalf/WisdomSection: "wisdom",
		$MarginContainer/VBoxContainer/BottomHalf/FoolSection: "fool",
		$MarginContainer/VBoxContainer/BottomHalf/SatchelSection: "satchel",
	}
	for node in zone_map:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = ThemeManager.get_zone_color(zone_map[node])
		stylebox.corner_radius_top_left = 8
		stylebox.corner_radius_top_right = 8
		stylebox.corner_radius_bottom_left = 8
		stylebox.corner_radius_bottom_right = 8
		# ← CHANGED: increased content margins from 8 to 16
		# This gives cards more breathing room from zone edges
		stylebox.content_margin_left = 16
		stylebox.content_margin_right = 16
		stylebox.content_margin_top = 16
		stylebox.content_margin_bottom = 16
		node.add_theme_stylebox_override("panel", stylebox)
		
	# NEW: set the background clear color to match the current theme
	# This colors the area behind all zone panels rather than showing
	# Godot's default gray
	RenderingServer.set_default_clear_color(ThemeManager.get_current()["background"])

# ------------------------------------
# LABEL STYLING
# Centers all labels and sets font sizes.
# ← CHANGED: fool_name_label removed from both lists since that node
# was deleted in Part 3. It's no longer needed.
# ------------------------------------
func _setup_labels():
	var all_labels = [
		adventure_label, discard_label, deck_label,
		wisdom_label, satchel_label, fool_label,
		volition_label, strength_label,
		fool_vitality_label
		# ← CHANGED: fool_name_label removed
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

func _on_discard_section_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			show_discard_viewer()
			
# Settings and Rules
func _setup_audio_controls():
	# Invisible full-screen backdrop - sits behind the panel but above the game
	# Clicking anywhere on it closes the panel, like clicking outside a dropdown
	var backdrop = Button.new()
	backdrop.flat = true  # no visible button styling
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.visible = false
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.z_index = 1 # above game, below controls
	add_child(backdrop)
	
	# Gear button that toggles the settings panel open/closed
	var gear_btn = Button.new()
	gear_btn.text = "Options"
	gear_btn.custom_minimum_size = Vector2(32, 32)
	gear_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	gear_btn.position = Vector2(8, 8)
	gear_btn.z_index = 2 # above backdrop
	add_child(gear_btn)

	# Settings panel — hidden by default, shown when gear is clicked
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(8, 48)
	panel.visible = false
	panel.z_index = 2 # above backdrop
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var music_btn = Button.new()
	music_btn.text = "Music ON" if AudioManager.music_enabled else "Music OFF"
	# REMOVED: music_btn.toggle_mode = true — was causing inconsistent hover appearance
	# State is tracked manually via text change instead
	#music_btn.button_pressed = AudioManager.music_enabled
	music_btn.pressed.connect(func():
		AudioManager.toggle_music()
		music_btn.text = "Music ON" if AudioManager.music_enabled else "Music OFF")
	vbox.add_child(music_btn)

	var sfx_btn = Button.new()
	sfx_btn.text = "SFX ON" if AudioManager.sfx_enabled else "SFX OFF"
	#sfx_btn.toggle_mode = true
	sfx_btn.button_pressed = AudioManager.sfx_enabled
	sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx()
		sfx_btn.text = "SFX ON" if AudioManager.sfx_enabled else "SFX OFF")
	vbox.add_child(sfx_btn)

	var rules_btn = Button.new()
	rules_btn.text = "Rules"
	rules_btn.pressed.connect(func():
		AudioManager.play_menu_click()
		# ← CHANGED: show rules as overlay instead of changing scenes
		# This keeps the game scene alive so nothing resets
		_show_rules_overlay())
	vbox.add_child(rules_btn)
	
	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.pressed.connect(func():
		AudioManager.play_menu_click()
		_confirm_return_to_menu())
	vbox.add_child(menu_btn)

	# Toggle both panel and backdrop together
	gear_btn.pressed.connect(func():
		var opening = not panel.visible
		panel.visible = opening
		backdrop.visible = opening)

	backdrop.pressed.connect(func():
		panel.visible = false
		backdrop.visible = false)

func _show_rules_overlay():
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 100
	panel.offset_right = -100
	panel.offset_top = 60
	panel.offset_bottom = -60
	overlay.add_child(panel)

	# FIXED: single MarginContainer directly inside panel
	# previously had both an empty vbox and a margin as siblings which caused confusion
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(inner_vbox)

	var title = Label.new()
	title.text = "The Fool's Journey — Rules"
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
	# Same rules text as RulesScreen which calls from ThemeManager
	return ThemeManager.get_rules_text()
	
func _confirm_return_to_menu():
	# ← Confirm before leaving since returning to menu resets the game
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

# Google Analytics
func _track_event(event_name: String, params: Dictionary = {}):
	# Only runs in web exports — JavaScriptBridge doesn't exist on desktop
	if not OS.has_feature("web"):
		return
	var js_params = JSON.stringify(params)
	JavaScriptBridge.eval(
		"typeof gtag !== 'undefined' && gtag('event', '" 
		+ event_name + "', " + js_params + ")")
