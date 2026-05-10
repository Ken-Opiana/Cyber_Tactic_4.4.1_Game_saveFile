extends Card

const WEAKENED_STATUS := preload("res://statuses/weakened.tres")

@export var optional_sound: AudioStream

var base_damage := 6
var weakened_duration := 2

func apply_effects(targets: Array[Node], modifiers: ModifierHandler):
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)
	
	var status_effect := StatusEffect.new()
	var weakened := WEAKENED_STATUS.duplicate()
	weakened.duration = weakened_duration
	status_effect.status = weakened
	status_effect.execute(targets)

func get_default_tooltip() -> String:
	return tooltip_text % base_damage

func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var modified_damage := player_modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		modified_damage = enemy_modifiers.get_modified_value(modified_damage, Modifier.Type.DMG_TAKEN)
	
	return tooltip_text % modified_damage
