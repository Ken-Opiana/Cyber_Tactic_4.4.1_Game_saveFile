extends Card

var base_block := 0

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var player := targets[0].get_tree().get_nodes_in_group("player")[0] as Player
	base_block = player.stats.block
	var block_effect := BlockEffect.new()
	block_effect.amount = base_block
	block_effect.sound = sound
	block_effect.execute(targets)
