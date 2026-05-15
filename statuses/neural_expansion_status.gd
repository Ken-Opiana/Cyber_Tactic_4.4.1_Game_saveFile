extends Status

func initialize_status(target) -> void:
	Events.player_hand_drawn.connect(_on_player_hand_drawn.bind(target))

func _on_player_hand_drawn(target: Player) -> void:
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = stacks
	card_draw_effect.execute([target])
	

func get_tooltip() -> String:
	return tooltip % stacks
