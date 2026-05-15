extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	SFXPlayer.play(sound)
	
	var player := targets[0].get_tree().get_first_node_in_group("player") as Player
	var number = player.stats.spell
	
	if number > 0:
		var card_draw_effect := CardDrawEffect.new()
		card_draw_effect.cards_to_draw = number
		card_draw_effect.execute(targets)
		
		player.stats.heal(number)
		player.spend_spell(number)
