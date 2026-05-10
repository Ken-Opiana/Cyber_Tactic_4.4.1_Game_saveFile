extends Card


var base_damage := 6

@export var element := Stats.Element.FIRE


func get_default_tooltip() -> String:
	return tooltip_text % base_damage


func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var dmg := player_modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)

	if enemy_modifiers and enemy_modifiers.has_modifier(Modifier.Type.DMG_TAKEN):
		var enemy_stats = enemy_modifiers.get_parent().stats
		var elem_mult = enemy_stats.get_elemental_multiplier(element)
		dmg = floor(dmg * elem_mult)
	
	if enemy_modifiers:
		dmg = enemy_modifiers.get_modified_value(dmg, Modifier.Type.DMG_TAKEN)
		
	return tooltip_text % dmg


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var raw = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	var damage_effect := DamageEffect.new()
	damage_effect.amount = raw
	damage_effect.element = element
	damage_effect.sound = sound
	damage_effect.execute(targets)
