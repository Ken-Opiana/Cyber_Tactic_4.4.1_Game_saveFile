extends Card

const ENLIGHTENEMENT_STATUS := preload("res://statuses/neural_expansion_status.tres")

var stacks := 1

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var enlightenement := ENLIGHTENEMENT_STATUS.duplicate()
	enlightenement.stacks = stacks
	status_effect.status = enlightenement
	status_effect.execute(targets)
