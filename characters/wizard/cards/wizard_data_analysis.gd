extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = 1
	card_draw_effect.execute(targets)
	
	var gain_spell_effect := GainSpellEffect.new()
	gain_spell_effect.amount = 1
	gain_spell_effect.execute(targets)
