extends Card

var base_block := 11

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var player := targets[0].get_tree().get_nodes_in_group("player")[0] as Player
	if player.stats.block == 0:
		var block_effect := BlockEffect.new()
		block_effect.amount = base_block
		block_effect.sound = sound
		block_effect.execute(targets)

func get_default_tooltip() -> String:
	return tooltip_text % base_block

func get_updated_tooltip(player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	var modified_block := player_modifiers.get_modified_value(base_block, Modifier.Type.BLOCK_GAINED)
	
	return tooltip_text % modified_block
