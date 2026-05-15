extends Card

const SPELL_SURGE_STATUS := preload("res://statuses/passive_computation_status.tres")

var stacks := 1

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var surge := SPELL_SURGE_STATUS.duplicate()
	surge.stacks = stacks
	status_effect.status = surge
	status_effect.execute(targets)
