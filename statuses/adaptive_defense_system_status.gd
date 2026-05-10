class_name AdaptiveDefenseSystem
extends Status

func initialize_status(target) -> void:
	Events.card_exhausted.connect(_on_card_exhausted.bind(target))

func _on_card_exhausted(target):
	var block_effect := BlockEffect.new()
	block_effect.amount = stacks
	block_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	block_effect.execute([target])

func get_tooltip() -> String:
	return tooltip % stacks
