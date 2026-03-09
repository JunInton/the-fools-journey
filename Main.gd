extends Node2D

# Preload is like import in JS
# It loads the Card scene so we can create instances of it
const CardScene = preload("res://Card.tscn")

func _ready():
	GameState.start_game()
	_render_adventure_field()

func _render_adventure_field():
	# Remove any existing cards first (like clearing a div's innerHTML)
	for child in get_children():
		child.queue_free()  # queue_free() = safe way to delete a node

	# Create a card node for each card in the adventure field
	for i in range(GameState.adventure_field.size()):
		var card_instance = CardScene.instantiate()  # like <CardScene /> in JSX
		add_child(card_instance)
		card_instance.set_card(GameState.adventure_field[i])
		# Space them out horizontally - like flexbox with a gap
		card_instance.position = Vector2(i * 120, 50)
