extends Card

var base_damage := 8
var base_block := 8

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)
	
	var player := targets[0].get_tree().get_nodes_in_group("player")
	var block_effect := BlockEffect.new()
	block_effect.amount = base_block
	#block_effect.sound = sound
	block_effect.execute(player)

func get_default_tooltip() -> String:
	return tooltip_text % [base_damage, base_block]

func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var modified_damage := player_modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		modified_damage = enemy_modifiers.get_modified_value(modified_damage, Modifier.Type.DMG_TAKEN)
	
	var modified_block := player_modifiers.get_modified_value(base_block, Modifier.Type.BLOCK_GAINED)
	
	return tooltip_text % [modified_damage, modified_block]
