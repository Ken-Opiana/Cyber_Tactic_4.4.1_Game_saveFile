extends ThreadPassive

var already_initialized := false

@export var amount := 7

func initialize_thread(owner: ThreadUI) -> void:
	# makes sure we don't have extra HP when we
	# keep saving and loading the game
	if already_initialized:
		print("raw steak already initialized")
		return

	var run := owner.get_tree().get_first_node_in_group("run") as Run
	run.character.max_health += amount
	already_initialized = true
	
	run.thread_handler.thread_state_dictionary[id] = {
		"already_initialized" : true
	}

func set_state_value(name: String, value: Variant) -> void:
	if name == "already_initialized":
		self.already_initialized = value
