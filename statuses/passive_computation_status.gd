extends Status

func apply_status(target: Node) -> void:
	var gain_spell_effect := GainSpellEffect.new()
	gain_spell_effect.amount = stacks
	gain_spell_effect.execute([target])

func get_tooltip() -> String:
	return tooltip % stacks
