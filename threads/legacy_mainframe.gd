extends ThreadPassive

const PRODIGY := preload("res://characters/wizard/cards/wizard_bootstrap.tres")

func activate_thread(owner: ThreadUI):
	# The CONNECT_ONE_SHOT argument has the connected function called once, then disconnects it.
	Events.player_hand_drawn.connect(_add_spell.bind(owner), CONNECT_ONE_SHOT)

func _add_spell(owner: ThreadUI) -> void:
	owner.flash()
	var player := owner.get_tree().get_first_node_in_group("player") as Player
	var hand := owner.get_tree().get_first_node_in_group("ui_layer").get_child(0)
	hand.add_card(PRODIGY.duplicate())
	if player:
		player.stats.spell += 1
