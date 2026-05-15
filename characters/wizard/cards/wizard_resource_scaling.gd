extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	SFXPlayer.play(sound)
	
	var player := targets[0].get_tree().get_first_node_in_group("player") as Player
	
	# Be careful not to trigger effects reacting to increase or decrease of spell charges.
	# It should be okay, since we're setting the value directly without relying on the spend_spell function.
	player.stats.max_spell +=2
	player.stats.spell -=2
