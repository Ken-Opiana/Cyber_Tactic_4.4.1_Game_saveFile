extends ThreadPassive

@export var damage = 2


func activate_thread(owner: ThreadUI) -> void:
	var enemies := owner.get_tree().get_nodes_in_group("enemies")
	var damage_effect := DamageEffect.new()
	damage_effect.amount = damage
	# The damage is not affected by modifiers such as Exposed.
	damage_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	damage_effect.execute(enemies)
	
	owner.flash()
	
