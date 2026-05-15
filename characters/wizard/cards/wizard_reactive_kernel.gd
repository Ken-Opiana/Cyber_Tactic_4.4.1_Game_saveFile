extends Card

const MAGIC_BLOOD_STATUS := preload("res://statuses/reactive_kernel_status.tres")

var stacks := 1

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var magic_blood := MAGIC_BLOOD_STATUS.duplicate()
	magic_blood.stacks = stacks
	status_effect.status = magic_blood
	status_effect.execute(targets)
