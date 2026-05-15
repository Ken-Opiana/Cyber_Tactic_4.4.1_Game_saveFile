extends ThreadPassive

@export var skills_required := 3
@export var damage := 5

var relic_ui: ThreadUI
var skills_this_turn: int


func initialize_thread(owner: ThreadUI) -> void:
	relic_ui = owner
	Events.start_of_turn_relics_activated.connect(_reset)
	Events.map_exited.connect(_reset.unbind(1))
	Events.card_played.connect(_on_card_played)


func deactivate_thread(_owner: ThreadUI):
	Events.start_of_turn_relics_activated.disconnect(_reset)
	Events.map_exited.disconnect(_reset)
	Events.card_played.disconnect(_on_card_played)


func _reset() -> void:
	skills_this_turn = 0


func _on_card_played(card: Card) -> void:
	if card.type != Card.Type.SKILL:
		return

	skills_this_turn += 1

	if skills_this_turn % skills_required == 0:
		var enemies := relic_ui.get_tree().get_nodes_in_group("enemies")
		var damage_effect := DamageEffect.new()
		damage_effect.amount = damage
		damage_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
		damage_effect.execute(enemies)

		relic_ui.flash()
		skills_this_turn = 0
