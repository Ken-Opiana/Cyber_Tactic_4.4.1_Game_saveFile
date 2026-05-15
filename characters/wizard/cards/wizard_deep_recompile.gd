extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var player_handler := targets[0].get_tree().get_first_node_in_group("player_handler") as PlayerHandler
	var hand := targets[0].get_tree().get_first_node_in_group("ui_layer").get_child(0)
	
	var number = 0
	for card_in_hand in hand.get_child_count():
		number += 1
	
	var return_random_effect := ReturnTopDeckRandomEffect.new()
	return_random_effect.amount = number
	return_random_effect.execute(targets)
	print("return hand to top of deck")
	
	player_handler.force_reshuffle()
	
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = 4
	card_draw_effect.execute(targets)
