extends ThreadPassive

@export var damage := 3

var relic_ui: ThreadUI


func initialize_thread(owner: ThreadUI) -> void:
	relic_ui = owner
	Events.player_spend_spell.connect(_on_player_spend_spell.bind(relic_ui))

func deactivate_thread(_owner: ThreadUI) -> void:
	Events.player_spend_spell.disconnect(_on_player_spend_spell)

func _on_player_spend_spell(_owner: ThreadUI) -> void:
	var enemies := relic_ui.get_tree().get_nodes_in_group("enemies")
	var damage_effect := DamageEffect.new()
	damage_effect.amount = damage
	damage_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	damage_effect.execute(enemies)

	relic_ui.flash()
