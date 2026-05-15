extends ThreadPassive

@export var amount := 3

var relic_ui: ThreadUI


func initialize_thread(owner: ThreadUI) -> void:
	relic_ui = owner
	Events.card_discarded.connect(_on_card_discarded.bind(relic_ui))

func deactivate_thread(_owner: ThreadUI) -> void:
	Events.card_discarded.disconnect(_on_card_discarded)

func _on_card_discarded(owner: ThreadUI) -> void:
	var player := owner.get_tree().get_nodes_in_group("player")
	var block_effect := BlockEffect.new()
	block_effect.amount = amount
	block_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	block_effect.execute(player)
	relic_ui.flash()
