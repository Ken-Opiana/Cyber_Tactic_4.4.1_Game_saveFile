extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var hand := targets[0].get_tree().get_first_node_in_group("ui_layer").get_child(0)
	
	var number = 0
	for card_in_hand in hand.get_child_count():
		number += 1
	
	var discard_random_effect := DiscardRandomEffect.new()
	discard_random_effect.amount = number
	discard_random_effect.execute(targets)
	
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = number
	card_draw_effect.execute(targets)
