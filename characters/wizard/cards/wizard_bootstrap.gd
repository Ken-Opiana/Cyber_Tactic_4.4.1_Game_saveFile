extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = 1
	card_draw_effect.execute(targets)
	
	targets[0].stats.mana += 1 #targets[0] should be the player
