extends ThreadPassive


func activate_relic(owner: ThreadUI):
	await Events.player_hand_drawn
	var player := owner.get_tree().get_first_node_in_group("player") as Player
	if player:
		var card_draw_effect := CardDrawEffect.new()
		card_draw_effect.cards_to_draw = 2
		card_draw_effect.execute([player])
		owner.flash()
