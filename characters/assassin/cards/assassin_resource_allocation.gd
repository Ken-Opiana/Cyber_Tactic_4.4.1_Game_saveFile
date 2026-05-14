extends Card

const HELD_MANA_STATUS := preload("res://statuses/cached_energy.tres")

var held_mana_stacks := 2

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var held_mana := HELD_MANA_STATUS.duplicate()
	held_mana.stacks = held_mana_stacks
	status_effect.status = held_mana
	status_effect.execute(targets)
