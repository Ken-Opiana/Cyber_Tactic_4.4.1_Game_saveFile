class_name PacketStormEngine
extends Status

func initialize_status(target) -> void:
	Events.card_played.connect(_on_card_played.bind(target))

func _on_card_played(_card: Card, target):
	var enemies = target.get_tree().get_nodes_in_group("enemies")
	var damage_effect := DamageEffect.new()
	damage_effect.amount = stacks
	# The damage is not affected by modifiers such as Exposed.
	damage_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	damage_effect.execute(enemies)

func get_tooltip() -> String:
	return tooltip % stacks
