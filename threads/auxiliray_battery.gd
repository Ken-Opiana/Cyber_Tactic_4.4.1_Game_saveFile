extends ThreadPassive


func activate_thread(owner: ThreadUI) -> void:
	# The CONNECT_ONE_SHOT argument has the connected function called once, then disconnects it.
	Events.player_hand_drawn.connect(_add_mana.bind(owner), CONNECT_ONE_SHOT)

func _add_mana(owner: ThreadUI) -> void:
	owner.flash()
	var player := owner.get_tree().get_first_node_in_group("player") as Player
	if player:
		player.stats.mana += 1
