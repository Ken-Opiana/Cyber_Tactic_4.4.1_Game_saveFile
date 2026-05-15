extends Card

var base_damage := 4

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var player := targets[0].get_tree().get_first_node_in_group("player")
	for i in player.stats.spell:
		var damage_effect := DamageEffect.new()
		damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
		damage_effect.sound = sound
		damage_effect.execute(targets)
		await player.get_tree().create_timer(0.35).timeout

func get_default_tooltip() -> String:
	return tooltip_text % base_damage

func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var modified_damage := player_modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		modified_damage = enemy_modifiers.get_modified_value(modified_damage, Modifier.Type.DMG_TAKEN)
	
	return tooltip_text % modified_damage
