extends ThreadPassive

@export var block := 5

var relic_ui: ThreadUI

func initialize_thread(owner: ThreadUI) -> void:
	relic_ui = owner
	Events.player_press_end_turn_button.connect(_on_player_press_end_turn_button)


func deactivate_thread(_owner: ThreadUI) -> void:
	Events.player_press_end_turn_button.disconnect(_on_player_press_end_turn_button)

func _on_player_press_end_turn_button() -> void:
	var player := relic_ui.get_tree().get_first_node_in_group("player")
	if player.stats.block == 0:
		var block_effect := BlockEffect.new()
		block_effect.amount = block
		block_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
		block_effect.execute([player])
		
		relic_ui.flash()
