extends ThreadPassive

func activate_thread(owner: ThreadUI):
	Events.player_hand_drawn.connect(_add_mana_at_third_turn.bind(owner))

func deactivate_thread(_owner: ThreadUI):
	Events.player_hand_drawn.disconnect(_add_mana_at_third_turn)

func _add_mana_at_third_turn(owner: ThreadUI) -> void:
	if GlobalTurnNumber.get_turn_number() % 3 == 0:
		owner.flash()
		var player := owner.get_tree().get_first_node_in_group("player") as Player
		if player:
			player.stats.mana += 1
