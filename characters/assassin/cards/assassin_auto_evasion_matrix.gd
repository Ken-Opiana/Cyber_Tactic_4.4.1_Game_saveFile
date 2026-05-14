extends Card

const NINE_LIVES_STATUS := preload("res://statuses/auto_evasion_matrix_status.tres")

var stacks := 1

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var nine_lives := NINE_LIVES_STATUS.duplicate()
	nine_lives.stacks = stacks
	status_effect.status = nine_lives
	status_effect.execute(targets)
