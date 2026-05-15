extends ThreadPassive

const DEXTERITY_STATUS := preload("res://statuses/refine.tres")

var dex_stacks := 1

func activate_thread(owner: ThreadUI):
	# The CONNECT_ONE_SHOT argument has the connected function called once, then disconnects it.
	Events.player_hand_drawn.connect(_add_dex.bind(owner), CONNECT_ONE_SHOT)

func _add_dex(owner: ThreadUI) -> void:
	owner.flash()
	var player := owner.get_tree().get_first_node_in_group("player") as Player
	if not player:
		return
	
	var status_effect := StatusEffect.new()
	var dex := DEXTERITY_STATUS.duplicate()
	dex.stacks = dex_stacks
	status_effect.status = dex
	status_effect.execute([player])
