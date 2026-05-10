extends Card

const OVERCLOCK_STATUS := preload("res://statuses/warrior_overclock_protocol_status.tres")

var stacks := 1

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var frenzy := OVERCLOCK_STATUS.duplicate()
	frenzy.stacks = stacks
	status_effect.status = frenzy
	status_effect.execute(targets)
