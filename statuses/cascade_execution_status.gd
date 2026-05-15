class_name CascadeExecution
extends Status

func initialize_status(target) -> void:
	Events.player_gain_spell.connect(_on_player_gain_spell.bind(target))

func _on_player_gain_spell(target):
	# Deal raw damage to a random enemy equal to stacks
	var enemies = target.get_tree().get_nodes_in_group("enemies")
	var random_target = RNG.array_pick_random(enemies)
	var damage_effect := DamageEffect.new()
	damage_effect.amount = stacks
	# The damage is not affected by modifiers such as Exposed.
	damage_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	damage_effect.execute([random_target])
	
func get_tooltip() -> String:
	return tooltip % stacks
