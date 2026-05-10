extends Card

const DETERMINATION_STATUS := preload("res://statuses/adaptive_defense_system_status.tres")

var stacks := 3

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var determination := DETERMINATION_STATUS.duplicate()
	determination.stacks = stacks
	status_effect.status = determination
	status_effect.execute(targets)
