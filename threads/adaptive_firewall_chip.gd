extends ThreadPassive

@export var block = 3


func initialize_thread(owner: ThreadUI) -> void:
	var player := owner.get_tree().get_nodes_in_group("player")
	var block_effect := BlockEffect.new()
	block_effect.amount = block
	block_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	block_effect.execute(player)
	
	owner.flash()
