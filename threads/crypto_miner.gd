extends ThreadPassive

@export var amount := 7

var relic_ui: ThreadUI


func initialize_thread(owner: ThreadUI) -> void:
	relic_ui = owner
	Events.battle_won.connect(_on_battle_won)


func deactivate_thread(_owner: ThreadUI) -> void:
	Events.battle_won.disconnect(_on_battle_won)


func _on_battle_won() -> void:
	var run := relic_ui.get_tree().get_first_node_in_group("run") as Run
	run.stats.gold += amount
	relic_ui.flash()
