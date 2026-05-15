extends ThreadPassive

const WEAKENED_STATUS := preload("res://statuses/weakened.tres")

var weakened_duration := 1

func activate_thread(owner: ThreadUI):
	# The CONNECT_ONE_SHOT argument has the connected function called once, then disconnects it.
	Events.player_hand_drawn.connect(_apply_weakened.bind(owner), CONNECT_ONE_SHOT)

func _apply_weakened(owner: ThreadUI) -> void:
	owner.flash()
	var enemies := owner.get_tree().get_nodes_in_group("enemies")
	if not enemies:
		return
	
	for enemy in enemies:
		var status_effect := StatusEffect.new()
		var weak := WEAKENED_STATUS.duplicate()
		weak.duration = weakened_duration
		status_effect.status = weak
		status_effect.execute([enemy])
