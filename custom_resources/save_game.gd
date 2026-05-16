class_name SaveGame
extends Resource

const SAVE_PATH := "user://savegame.tres"

@export var rng_seed: int
@export var rng_state: int
@export var run_stats: RunStats
@export var char_stats: CharacterStats
@export var current_deck: CardPile
@export var current_library: CardPile
@export var discovered_cards: Array[String]
@export var current_health: int
@export var threads: Array[ThreadPassive]
@export var map_data: Array[Array]
@export var last_room: Room
@export var floors_climbed: int
@export var was_on_map: bool
@export var codex_discovered: Array[String] = []
@export var stats_tracker: RunStatsTracker
@export var was_in_hub: bool = false

# ── Existing shop fields ───────────────────────────────────────────────────────
@export var shop_card_ids: Array[String]        = []
@export var shop_card_prices: Array[int]        = []
@export var shop_sold_card_ids: Array[String]   = []
@export var shop_thread_ids: Array[String]      = []
@export var shop_thread_prices: Array[int]      = []
@export var shop_sold_thread_ids: Array[String] = []

# ── New vending machine shop fields ───────────────────────────────────────────
# Randomly generated AB12-style slot codes, one per item (cards first, then threads).
# Index order matches shop_card_ids + shop_thread_ids concatenated.
@export var shop_slot_codes: Array[String]      = []

# Items currently sitting in the PUSH tray (bought but not yet collected).
@export var shop_tray_card_ids: Array[String]   = []
@export var shop_tray_thread_ids: Array[String] = []

# Tracks whether the CouponsThread discount has already been applied to this
# shop visit's prices. Prevents re-applying the discount on every save/load.
@export var shop_coupon_applied: bool = false

# ── Boss cutscene one-shot flags ──────────────────────────────────────────────
# Once true, the corresponding cutscene will not play again, even after
# save/quit/reload within the same run.
@export var boss_intro_cutscene_played: bool = false
@export var boss_ending_cutscene_played: bool = false


func save_data() -> void:
	var err := ResourceSaver.save(self, SAVE_PATH)
	assert(err == OK, "Couldn't save the game!")


static func load_data() -> SaveGame:
	if FileAccess.file_exists(SAVE_PATH):
		return ResourceLoader.load(SAVE_PATH) as SaveGame
	
	return null


static func delete_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# Saves a minimal "player is in the Hub" record so the Continue button
# on the main menu stays active and routes to the Hub scene.
static func save_hub_state() -> void:
	var hub_save := SaveGame.new()
	hub_save.was_in_hub = true
	hub_save.save_data()
