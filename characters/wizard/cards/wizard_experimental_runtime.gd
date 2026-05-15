extends Card

const CURSE_BURN = preload("res://shared_cards/curses_corrupted_file.tres")

var draw := 2

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var player := targets[0].get_tree().get_nodes_in_group("player")[0] as Player
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = draw
	card_draw_effect.execute(targets)
	player.stats.draw_pile.add_card(CURSE_BURN.duplicate())
