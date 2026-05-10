extends Card

const NOTHING_TO_LOSE_STATUS := preload("res://statuses/system_override_status.tres")

var stacks := 1

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var nothing_to_lose := NOTHING_TO_LOSE_STATUS.duplicate()
	nothing_to_lose.stacks = stacks
	status_effect.status = nothing_to_lose
	status_effect.execute(targets)
