extends Card

const WEAKENED_STATUS := preload("res://statuses/weakened.tres")

var weak_duration := 1

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	for target in targets:
		var status_effect := StatusEffect.new()
		var weak := WEAKENED_STATUS.duplicate()
		weak.duration = weak_duration
		status_effect.status = weak
		status_effect.execute([target])
	
	SFXPlayer.play(sound)
