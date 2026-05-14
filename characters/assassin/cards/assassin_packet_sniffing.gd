extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = 1
	card_draw_effect.execute(targets)
	
	await Events.player_card_drawn
	
	var discard_effect := DiscardEffect.new()
	discard_effect.execute(targets)
