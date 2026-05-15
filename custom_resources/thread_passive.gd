class_name ThreadPassive
extends Resource

enum Type {START_OF_TURN, START_OF_COMBAT, END_OF_TURN, END_OF_COMBAT, EVENT_BASED}
enum CharacterType {ALL, ASSASSIN, WARRIOR, WIZARD}

@export var thread_name: String
@export var id: String
@export var type: Type
@export var character_type: CharacterType
@export var starter_thread: bool = false
@export var icon: Texture
@export_multiline var tooltip: String


func initialize_thread(_owner: ThreadUI) -> void:
	pass


func activate_thread(_owner: ThreadUI) -> void:
	pass


# This method should be implemented by event-based relics
# which connect to the EventBus to make sure that they are
# disconnected when a relic gets removed.
func deactivate_thread(_owner: ThreadUI) -> void:
	pass


func get_tooltip() -> String:
	return tooltip


func can_appear_as_reward(character: CharacterStats) -> bool:
	if starter_thread:
		return false

	if character_type == CharacterType.ALL:
		return true
		
	var thread_char_name: String = CharacterType.keys()[character_type].to_lower()
	var char_name := character.character_name.to_lower()
	
	return thread_char_name == char_name

func set_state_value(_name: String, _value: Variant) -> void:
	pass
