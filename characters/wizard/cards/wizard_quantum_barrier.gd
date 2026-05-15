extends Card

var base_block := 7

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var block_effect := BlockEffect.new()
	block_effect.amount = base_block
	block_effect.sound = sound
	block_effect.execute(targets)
	
	var gain_spell_effect := GainSpellEffect.new()
	gain_spell_effect.amount = 2
	gain_spell_effect.execute(targets)

func get_default_tooltip() -> String:
	return tooltip_text % base_block

func get_updated_tooltip(player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	var modified_block := player_modifiers.get_modified_value(base_block, Modifier.Type.BLOCK_GAINED)
	
	return tooltip_text % modified_block
