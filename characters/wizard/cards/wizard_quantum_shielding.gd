extends Card

const HELD_MANA_STATUS := preload("res://statuses/cached_energy.tres")

var held_mana_stacks := 1
var base_block := 8

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	var status_effect := StatusEffect.new()
	var held_mana := HELD_MANA_STATUS.duplicate()
	held_mana.stacks = held_mana_stacks
	status_effect.status = held_mana
	status_effect.execute(targets)
	
	var block_effect := BlockEffect.new()
	block_effect.amount = base_block
	block_effect.sound = sound
	block_effect.execute(targets)

func get_default_tooltip() -> String:
	return tooltip_text % base_block

func get_updated_tooltip(player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	var modified_block := player_modifiers.get_modified_value(base_block, Modifier.Type.BLOCK_GAINED)
	
	return tooltip_text % modified_block
