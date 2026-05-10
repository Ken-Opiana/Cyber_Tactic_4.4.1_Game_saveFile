class_name SystemOverrideStatus
extends Status

func apply_status(target):
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = stacks
	card_draw_effect.execute([target])
	
	var lose_health_effect := LoseHealthEffect.new()
	lose_health_effect.amount = stacks
	lose_health_effect.execute([target])

func get_tooltip() -> String:
	return tooltip % [stacks, stacks]
