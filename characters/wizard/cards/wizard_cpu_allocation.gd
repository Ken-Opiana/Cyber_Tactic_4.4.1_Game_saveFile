extends Card

const MUSCLE_STATUS := preload("res://statuses/power_up.tres")
const DEXTERITY_STATUS := preload("res://statuses/refine.tres")

var new_stacks := 1

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var muscle := MUSCLE_STATUS.duplicate()
	muscle.stacks = new_stacks
	status_effect.status = muscle
	status_effect.execute(targets)
	
	var status_effect_02 := StatusEffect.new()
	var dexterity := DEXTERITY_STATUS.duplicate()
	dexterity.stacks = new_stacks
	status_effect_02.status = dexterity
	status_effect_02.execute(targets)
