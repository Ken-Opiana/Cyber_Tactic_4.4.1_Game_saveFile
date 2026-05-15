extends ThreadPassive

@export var block = 12


func activate_thread(owner: ThreadUI):
	if GlobalTurnNumber.get_turn_number() == 2:
		var player := owner.get_tree().get_first_node_in_group("player")
		var block_effect := BlockEffect.new()
		block_effect.amount = block
		block_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
		block_effect.execute([player])
		
		owner.flash()
