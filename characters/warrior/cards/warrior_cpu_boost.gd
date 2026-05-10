extends Card

const POWER_UP_STATUS := preload("res://statuses/power_up.tres")

var power_stacks := 2

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var power_up := POWER_UP_STATUS.duplicate()
	power_up.stacks = power_stacks
	status_effect.status = power_up
	status_effect.execute(targets)
