extends ThreadPassive

@export var damage := 1

var relic_ui: ThreadUI


func initialize_thread(owner: ThreadUI) -> void:
	relic_ui = owner
	Events.card_played.connect(_on_card_played)


func deactivate_thread(_owner: ThreadUI) -> void:
	Events.card_played.disconnect(_on_card_played)


func _on_card_played(card: Card) -> void:
	if card.cost == 0:
		var enemies := relic_ui.get_tree().get_nodes_in_group("enemies")
		var damage_effect := DamageEffect.new()
		damage_effect.amount = damage
		damage_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
		damage_effect.execute(enemies)

		relic_ui.flash()
