extends ThreadPassive

const MUSCLE_STATUS := preload("res://statuses/power_up.tres")

var muscle_stacks := 1

func activate_thread(owner: ThreadUI):
	# The CONNECT_ONE_SHOT argument has the connected function called once, then disconnects it.
	Events.player_hand_drawn.connect(_add_muscle.bind(owner), CONNECT_ONE_SHOT)

func _add_muscle(owner: ThreadUI) -> void:
	owner.flash()
	var player := owner.get_tree().get_first_node_in_group("player") as Player
	if not player:
		return
	
	var status_effect := StatusEffect.new()
	var muscle := MUSCLE_STATUS.duplicate()
	muscle.stacks = muscle_stacks
	status_effect.status = muscle
	status_effect.execute([player])
