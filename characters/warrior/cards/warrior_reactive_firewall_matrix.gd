extends Card

const REACTIVE_FIREWALL_STATUS := preload("res://statuses/warrior_reactive_firewall_matrix_status.tres")

var stacks := 4

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler):
	SFXPlayer.play(sound)
	var status_effect := StatusEffect.new()
	var iron_might := REACTIVE_FIREWALL_STATUS.duplicate()
	iron_might.stacks = stacks
	status_effect.status = iron_might
	status_effect.execute(targets)
