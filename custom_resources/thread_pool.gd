class_name ThreadPool
extends Resource

@export var pool: Array[ThreadPassive]

func get_available_threads(char_stats: CharacterStats, relic_handler: ThreadHandler) -> Array[ThreadPassive]:
	var available_relics := pool.filter(
		func(relic: ThreadPassive):
			var can_appear := relic.can_appear_as_reward(char_stats)
			var already_has_it := relic_handler.has_thread(relic.id)
			return can_appear and not already_has_it
	)
	return available_relics
