extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var player := targets[0].get_tree().get_first_node_in_group("player")
	if player is Player:
		var number = player.stats.discard.cards.size()
		
		var block_effect := BlockEffect.new()
		block_effect.amount = number
		block_effect.sound = sound
		block_effect.execute(targets)
