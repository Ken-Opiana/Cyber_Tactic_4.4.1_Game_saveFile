extends Card

const WISE_VETERAN_STATUS := preload("res://statuses/machine_learning_core_status.tres")

var stacks := 1

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var veteran := WISE_VETERAN_STATUS.duplicate()
	veteran.stacks = stacks
	status_effect.status = veteran
	status_effect.execute(targets)
