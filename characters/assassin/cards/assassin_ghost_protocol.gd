extends Card

const DEXTERITY_STATUS := preload("res://statuses/refine.tres")

var dex_stacks := 2

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var dexterity := DEXTERITY_STATUS.duplicate()
	dexterity.stacks = dex_stacks
	status_effect.status = dexterity
	status_effect.execute(targets)
