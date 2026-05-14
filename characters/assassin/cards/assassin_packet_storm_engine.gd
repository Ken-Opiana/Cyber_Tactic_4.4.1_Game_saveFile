extends Card

const THOUSAND_CUTS_STATUS := preload("res://statuses/packet_storm_engine_status.tres")

var stacks := 2

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var thousand_cuts := THOUSAND_CUTS_STATUS.duplicate()
	thousand_cuts.stacks = stacks
	status_effect.status = thousand_cuts
	status_effect.execute(targets)
