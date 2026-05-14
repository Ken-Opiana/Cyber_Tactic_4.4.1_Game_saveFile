class_name CachedEnergy
extends Status

func initialize_status(target) -> void:
	Events.player_hand_drawn.connect(_on_player_hand_drawn.bind(target))

func _on_player_hand_drawn(target: Player) -> void:
	target.stats.mana += stacks
	stacks = 0

func get_tooltip() -> String:
	return tooltip % stacks
