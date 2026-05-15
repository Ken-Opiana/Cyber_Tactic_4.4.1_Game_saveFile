extends Card

const CHAIN_REACTION_STATUS := preload("res://statuses/cascade_execution_status.tres")

var stacks := 3

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var chain_reaction := CHAIN_REACTION_STATUS.duplicate()
	chain_reaction.stacks = stacks
	status_effect.status = chain_reaction
	status_effect.execute(targets)
