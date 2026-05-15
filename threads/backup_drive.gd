extends ThreadPassive

var member_var := 0


@export var amount := 6

var relic_ui: ThreadUI


func initialize_thread(owner: ThreadUI) -> void:
	relic_ui = owner
	Events.drawpile_shuffled.connect(_on_drawpile_shuffled.bind(relic_ui))

func deactivate_thread(_owner: ThreadUI) -> void:
	Events.drawpile_shuffled.disconnect(_on_drawpile_shuffled)

func _on_drawpile_shuffled(owner: ThreadUI) -> void:
	var player := owner.get_tree().get_nodes_in_group("player")
	var block_effect := BlockEffect.new()
	block_effect.amount = amount
	block_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	block_effect.execute(player)
	relic_ui.flash()
