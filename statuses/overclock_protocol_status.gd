extends Status

const MUSCLE_STATUS := preload("res://statuses/power_up.tres")

func initialize_status(target) -> void:
	Events.player_lose_life.connect(_on_player_lose_life.bind(target))

func _on_player_lose_life(target: Player) -> void:
	var status_effect := StatusEffect.new()
	var muscle := MUSCLE_STATUS.duplicate()
	muscle.stacks = stacks
	status_effect.status = muscle
	status_effect.execute([target])
	

func get_tooltip() -> String:
	return tooltip % stacks
