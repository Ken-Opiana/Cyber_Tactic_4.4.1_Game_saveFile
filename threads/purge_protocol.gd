extends ThreadPassive

@export var damage := 3

var relic_ui: ThreadUI

func initialize_thread(owner: ThreadUI) -> void:
	relic_ui = owner
	Events.card_exhausted.connect(_on_card_exhausted)


func deactivate_thread(_owner: ThreadUI) -> void:
	Events.card_exhausted.disconnect(_on_card_exhausted)

func _on_card_exhausted():
	var enemies := relic_ui.get_tree().get_nodes_in_group("enemies")
	var damage_effect := DamageEffect.new()
	damage_effect.amount = damage
	damage_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	damage_effect.execute(enemies)

	relic_ui.flash()
