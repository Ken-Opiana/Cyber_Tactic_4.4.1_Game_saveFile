extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = 1
	card_draw_effect.execute(targets)
	
	#await Events.player_card_drawn
	await Events.player_multiple_cards_drawn
	
	var return_top_deck_effect := ReturnTopDeckEffect.new()
	return_top_deck_effect.execute(targets)
