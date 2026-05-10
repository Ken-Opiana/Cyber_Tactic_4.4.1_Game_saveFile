extends Card

var base_damage := 4

func apply_effects(targets: Array[Node], modifiers: ModifierHandler):
	var player := targets[0].get_tree().get_nodes_in_group("player")
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)
	# Card being a Resource and not a Node, we must declare the timer on the player node.
	await player[0].get_tree().create_timer(0.35).timeout
	damage_effect.execute(targets)
	

func get_default_tooltip() -> String:
	return tooltip_text % base_damage

func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var modified_damage := player_modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		modified_damage = enemy_modifiers.get_modified_value(modified_damage, Modifier.Type.DMG_TAKEN)
	
	return tooltip_text % modified_damage
