class_name Card
extends Resource

enum Type {ATTACK, SKILL, POWER, INFECTION}
enum Rarity {COMMON, UNCOMMON, RARE}
enum Target {SELF, SINGLE_ENEMY, ALL_ENEMIES, EVERYONE}

const RARITY_COLORS := {
	Card.Rarity.COMMON: Color.GRAY,
	Card.Rarity.UNCOMMON: Color.AQUA,
	Card.Rarity.RARE: Color.GOLD,
}


static func type_color(t: int) -> Color:
	match t:
		Type.ATTACK:
			return Color(0.545098, 0, 0, 1)   # red
		Type.POWER:
			return Color(0.15, 0.8, 0.15)   # green
		Type.SKILL:
			return Color(0.15, 0.15, 0.8)   # blue
		Type.INFECTION:
			return Color(0.707, 0.001, 0.773, 1.0)   # violet
		_:
			return Color(1,1,1)


@export_group("Card Attributes")
@export var name: String
@export var id: String
@export var type: Type
@export var rarity: Rarity
@export var target: Target
@export var cost: int
@export var spell_cost: int = 0
@export var remove: bool = false
@export var unplayable: bool = false

@export_group("Card Visuals")
@export var icon: Texture
@export_multiline var tooltip_text: String
@export_multiline var real_world_text: String
@export var sound: AudioStream

func is_single_targeted() -> bool:
	return target == Target.SINGLE_ENEMY


func _get_targets(targets: Array[Node]) -> Array[Node]:
	if not targets:
		return []
	
	var tree := targets[0].get_tree()
	
	match target:
		Target.SELF:
			return tree.get_nodes_in_group("player")
		Target.ALL_ENEMIES:
			return tree.get_nodes_in_group("enemies")
		Target.EVERYONE:
			return tree.get_nodes_in_group("player") + tree.get_nodes_in_group("enemies")
		_:
			return []


func play(targets: Array[Node], char_stats: CharacterStats, modifiers: ModifierHandler) -> void:
	Events.card_played.emit(self)
	char_stats.mana -= cost
	char_stats.spell -= spell_cost
	if spell_cost > 0:
		Events.player_spend_spell.emit()
	
	if is_single_targeted():
		apply_effects(targets, modifiers)
	else:
		apply_effects(_get_targets(targets), modifiers)


func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
	pass


func on_draw_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
	pass


func end_of_turn_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
	pass


func get_default_real_world_text() -> String:
	return real_world_text


func get_default_tooltip() -> String:
	return tooltip_text


func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	return tooltip_text
