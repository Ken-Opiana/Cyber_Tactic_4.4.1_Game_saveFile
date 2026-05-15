extends ThreadPassive

@export var block := 2

func activate_thread(owner: ThreadUI):
	var player := owner.get_tree().get_nodes_in_group("player")
	var charges = player[0].stats.spell
	
	if charges > 0:
		var block_effect := BlockEffect.new()
		block_effect.amount = charges*block
		block_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
		block_effect.execute(player)
		
		owner.flash()
