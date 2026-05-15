extends Card

var damage := 2

func end_of_turn_effects(targets: Array[Node], _modifiers: ModifierHandler):
	var damage_effect := DamageEffect.new()
	damage_effect.amount = damage
	damage_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	damage_effect.sound = sound
	damage_effect.execute(targets)
