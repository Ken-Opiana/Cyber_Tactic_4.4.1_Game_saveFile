extends Card

const HELD_MANA_STATUS := preload("res://statuses/cached_energy.tres")

var base_damage := 6
var held_mana_stacks := 1

func apply_effects(targets: Array[Node], modifiers: ModifierHandler):
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)
	
	var player := targets[0].get_tree().get_nodes_in_group("player")
	var status_effect := StatusEffect.new()
	var held_mana := HELD_MANA_STATUS.duplicate()
	held_mana.stacks = held_mana_stacks
	status_effect.status = held_mana
	status_effect.execute(player)

func get_default_tooltip() -> String:
	return tooltip_text % base_damage

func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var modified_damage := player_modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		modified_damage = enemy_modifiers.get_modified_value(modified_damage, Modifier.Type.DMG_TAKEN)
	
	return tooltip_text % modified_damage
