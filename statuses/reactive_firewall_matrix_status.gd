class_name ReactiveFirewallMatrix
extends Status

func initialize_status(target) -> void:
	Events.player_gain_block.connect(_on_player_gain_block.bind(target))

func _on_player_gain_block(target):
	var enemies = target.get_tree().get_nodes_in_group("enemies")
	var random_target = RNG.array_pick_random(enemies)
	var damage_effect := DamageEffect.new()
	damage_effect.amount = stacks
	# The damage is not affected by modifiers such as Exposed.
	damage_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	damage_effect.execute([random_target])

func get_tooltip() -> String:
	return tooltip % stacks
