extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var card_draw_effect := CardDrawEffect.new()
	# get player hand size
	var hand := targets[0].get_tree().get_first_node_in_group("ui_layer").get_child(0)
	var draw := 6 - hand.get_child_count()
	card_draw_effect.cards_to_draw = draw
	card_draw_effect.execute(targets)
