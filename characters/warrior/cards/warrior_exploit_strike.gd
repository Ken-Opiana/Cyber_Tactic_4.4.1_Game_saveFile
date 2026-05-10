extends Card

@export var element := Stats.Element.WATER

const VULNERABLE_STATUS = preload("res://statuses/vulnerable.tres")

var base_damage := 4
var vulnerable_duration := 2


func get_default_tooltip() -> String:
	return tooltip_text % base_damage


func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var modified_dmg := player_modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)

	if enemy_modifiers and enemy_modifiers.has_modifier(Modifier.Type.DMG_TAKEN):
		var enemy_stats = enemy_modifiers.get_parent().stats
		var elem_mult = enemy_stats.get_elemental_multiplier(element)
		modified_dmg = floor(modified_dmg * elem_mult)

	if enemy_modifiers:
		modified_dmg = enemy_modifiers.get_modified_value(modified_dmg, Modifier.Type.DMG_TAKEN)
		
	return tooltip_text % modified_dmg


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var raw = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	var damage_effect := DamageEffect.new()
	damage_effect.amount = raw
	damage_effect.element = element
	damage_effect.sound = sound
	damage_effect.execute(targets)
	
	var status_effect := StatusEffect.new()
	var vulnerable := VULNERABLE_STATUS.duplicate()
	vulnerable.duration = vulnerable_duration
	status_effect.status = vulnerable
	status_effect.execute(targets)
	
