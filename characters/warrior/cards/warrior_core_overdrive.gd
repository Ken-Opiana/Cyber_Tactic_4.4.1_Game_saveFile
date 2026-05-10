extends Card

const POWERING_UP_STATUS = preload("res://statuses/powering_up.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var powering_up := POWERING_UP_STATUS.duplicate()
	status_effect.status = powering_up
	status_effect.execute(targets)
	
