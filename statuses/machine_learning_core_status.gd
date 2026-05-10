class_name MachineLearningCore
extends Status


func initialize_status(target) -> void:
	Events.card_exhausted.connect(_on_card_exhausted.bind(target))

func _on_card_exhausted(target):
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = stacks
	card_draw_effect.execute([target])

func get_tooltip() -> String:
	return tooltip % stacks
