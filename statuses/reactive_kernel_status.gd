extends Status


func initialize_status(target) -> void:
	Events.player_hit.connect(_on_player_hit.bind(target))

func _on_player_hit(target: Player) -> void:
	var gain_spell_effect := GainSpellEffect.new()
	gain_spell_effect.amount = stacks
	gain_spell_effect.execute([target])

func get_tooltip() -> String:
	return tooltip % stacks
