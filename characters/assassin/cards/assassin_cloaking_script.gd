extends Card

const WEAKENED_STATUS := preload("res://statuses/weakened.tres")

var base_block := 10
var weakened_duration := 2

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	var player := targets[0].get_tree().get_nodes_in_group("player")
	var block_effect := BlockEffect.new()
	block_effect.amount = base_block
	block_effect.sound = sound
	block_effect.execute(player)
	
	var status_effect := StatusEffect.new()
	var weak := WEAKENED_STATUS.duplicate()
	weak.duration = weakened_duration
	status_effect.status = weak
	status_effect.execute(targets)
	
	
func get_default_tooltip() -> String:
	return tooltip_text % base_block

func get_updated_tooltip(player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	var modified_block := player_modifiers.get_modified_value(base_block, Modifier.Type.BLOCK_GAINED)
	
	return tooltip_text % modified_block
