extends Card

var draw_amount := 2


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var exhaust_effect := ExhaustEffect.new()
	exhaust_effect.execute(targets)
	
	await Events.card_chosen #code doesn't work when you don't display the hand_choice_view
	
	# what if you don't have any cards to exhaust? you just draw two cards
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = draw_amount
	card_draw_effect.execute(targets)
