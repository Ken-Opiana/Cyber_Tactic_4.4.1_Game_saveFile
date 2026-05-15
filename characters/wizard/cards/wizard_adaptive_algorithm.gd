extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var player := targets[0].get_tree().get_nodes_in_group("player")[0] as Player
	var char_stats = player.stats
	# Pick a Wizard power card at random
	var wizard_cards : Array[Card] = char_stats.draftable_cards.duplicate_cards()
	var available_cards : Array[Card] = wizard_cards.filter(
		func(card: Card):
			return card.type == Card.Type.POWER
	)
	RNG.array_shuffle(available_cards)
	var picked_card = available_cards[0]
	print("Card chosen: " + picked_card.name)
	
	# Add the card to the player's hand, change its cost to 0.
	var hand := targets[0].get_tree().get_first_node_in_group("ui_layer").get_child(0)
	picked_card.cost = 0
	hand.add_card(picked_card)
	
	SFXPlayer.play(sound)
