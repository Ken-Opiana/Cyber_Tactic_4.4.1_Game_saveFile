extends ThreadPassive

const MUSCLE_STATUS := preload("res://statuses/power_up.tres")

@export var skills_required := 3

var relic_ui: ThreadUI
var skills_this_turn: int
var muscle_stacks := 1


func initialize_thread(owner: ThreadUI) -> void:
	relic_ui = owner
	Events.start_of_turn_relics_activated.connect(_reset)
	Events.map_exited.connect(_reset.unbind(1))
	Events.card_played.connect(_on_card_played)


func deactivate_thread(_owner: ThreadUI) -> void:
	Events.start_of_turn_relics_activated.disconnect(_reset)
	Events.map_exited.disconnect(_reset)
	Events.card_played.disconnect(_on_card_played)


func _reset() -> void:
	skills_this_turn = 0


func _on_card_played(card: Card) -> void:
	if card.type != Card.Type.ATTACK:
		return

	skills_this_turn += 1

	if skills_this_turn % skills_required == 0:
		var player := relic_ui.get_tree().get_first_node_in_group("player")
		var status_effect := StatusEffect.new()
		var muscle := MUSCLE_STATUS.duplicate()
		muscle.stacks = muscle_stacks
		status_effect.status = muscle
		status_effect.execute([player])

		relic_ui.flash()
		skills_this_turn = 0
