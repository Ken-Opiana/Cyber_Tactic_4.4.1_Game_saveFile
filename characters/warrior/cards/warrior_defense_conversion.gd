extends Card

var base_damage := 0

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var player := targets[0].get_tree().get_nodes_in_group("player")[0] as Player
	base_damage = player.stats.block
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)
