## run.gd — CHANGES FROM ORIGINAL:
## 1. _on_shop_entered() passes new slot_codes, tray_card_ids, tray_thread_ids
##    to restore_from_save().
## 2. _save_run() captures get_slot_codes(), get_tray_card_ids(),
##    get_tray_thread_ids() from the shop node.
## 3. Clear new fields in the else branch of _save_run() so stale data is wiped.
##
## All other logic is UNCHANGED from your original run.gd.
## Replace your existing run.gd with this file.

class_name Run
extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const BATTLE_REWARD_SCENE := preload("res://scenes/battle_reward/battle_reward.tscn")
const CAMPFIRE_SCENE := preload("res://scenes/campfire/campfire.tscn")
const SHOP_SCENE := preload("res://scenes/shop/shop.tscn")
const TREASURE_SCENE := preload("res://scenes/treasure/treasure.tscn")
const BESTIARY_SCENE := preload("res://scenes/bestiary/bestiary.tscn")
const WIN_SCREEN_SCENE := preload("res://scenes/win_screen/win_screen.tscn")
const SUMMARY_SCENE := preload("res://scenes/ui/run_summary_screen.tscn")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"

@export var run_startup: RunStartup

@onready var map: Map = $Map
@onready var current_view: Node = $CurrentView
@onready var health_ui: HealthUI = %HealthUI
@onready var gold_ui: GoldUI = %GoldUI
@onready var thread_handler: ThreadHandler = %ThreadHandler
@onready var thread_tooltip: ThreadTooltip = %ThreadTooltip
@onready var deck_button: CardPileOpener = %DeckButton
@onready var deck_view: CardPileView = %DeckView
@onready var card_library_button: CardLibraryOpener = %CardLibraryButton
@onready var card_library_view: CardPileLibraryView = %CardLibraryView
@onready var bestiary_opener_button: TextureButton = %BestiaryOpenerButton
@onready var bestiary_view: BestiaryView = %BestiaryView
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var map_labels: VBoxContainer = %MapLabels
@onready var message_label: RichTextLabel = %MessageLabel


var stats: RunStats
var character: CharacterStats
var save_data: SaveGame
var stats_tracker: RunStatsTracker

var _is_on_map: bool = false

var _room_entry_rng_seed: int  = 0
var _room_entry_rng_state: int = 0


func _ready() -> void:
	if not run_startup:
		return
	
	pause_menu.save_and_quit.connect(
		func():
			_save_run(_is_on_map)
			get_tree().change_scene_to_file(MAIN_MENU_PATH)
	)
	
	match run_startup.type:
		RunStartup.Type.NEW_RUN:
			character = run_startup.picked_character.create_instance()
			_start_run()
		RunStartup.Type.CONTINUED_RUN:
			_load_run()
	
	if not DialogueState.has_shown("map_explain"):
		DialogueManager.start_dialogue_from_file("res://dialogues/map_explain.json", "map_explain")


func _start_run() -> void:
	stats         = RunStats.new()
	stats_tracker = RunStatsTracker.new()
	
	character = run_startup.picked_character.create_instance()
	for card in character.deck.cards:
		if not CardLibrary.is_discovered(card.id):
			CardLibrary.discovered_cards.append(card.id)
	
	_setup_event_connections()
	_setup_top_bar()
	
	MusicPlayer.play_track(MusicManager.Track.MAP)
	
	map.generate_new_map()
	map.unlock_floor(0)
	
	save_data  = SaveGame.new()
	_is_on_map = true
	_save_run(true)


func _save_run(was_on_map: bool) -> void:
	if was_on_map:
		save_data.rng_seed  = RNG.instance.seed
		save_data.rng_state = RNG.instance.state
	else:
		save_data.rng_seed  = _room_entry_rng_seed
		save_data.rng_state = _room_entry_rng_state

	save_data.run_stats        = stats
	save_data.char_stats       = character
	save_data.current_deck     = character.deck
	save_data.current_library  = character.card_library
	save_data.current_health   = character.health
	save_data.threads          = thread_handler.get_all_threads()
	save_data.last_room        = map.last_room
	save_data.map_data         = map.map_data.duplicate()
	save_data.floors_climbed   = map.floors_climbed
	save_data.was_on_map       = was_on_map
	save_data.discovered_cards = CardLibrary.discovered_cards
	save_data.stats_tracker    = stats_tracker

	var in_shop := (not was_on_map
			and map.last_room != null
			and map.last_room.type == Room.Type.SHOP)
	
	if in_shop and current_view.get_child_count() > 0:
		var shop := current_view.get_child(0) as Shop
		if shop:
			save_data.shop_card_ids        = shop.get_card_ids()
			save_data.shop_card_prices     = shop.get_card_prices()
			save_data.shop_sold_card_ids   = shop.get_sold_card_ids()
			save_data.shop_thread_ids      = shop.get_thread_ids()
			save_data.shop_thread_prices   = shop.get_thread_prices()
			save_data.shop_sold_thread_ids = shop.get_sold_thread_ids()
			# ── NEW: vending machine fields ───────────────────────────────────
			save_data.shop_slot_codes      = shop.get_slot_codes()
			save_data.shop_tray_card_ids   = shop.get_tray_card_ids()
			save_data.shop_tray_thread_ids = shop.get_tray_thread_ids()
			save_data.shop_coupon_applied  = shop.get_coupon_applied()
	else:
		# Not in a shop — clear stale data.
		save_data.shop_card_ids        = []
		save_data.shop_card_prices     = []
		save_data.shop_sold_card_ids   = []
		save_data.shop_thread_ids      = []
		save_data.shop_thread_prices   = []
		save_data.shop_sold_thread_ids = []
		# ── NEW: clear vending machine fields too ─────────────────────────────
		save_data.shop_slot_codes      = []
		save_data.shop_tray_card_ids   = []
		save_data.shop_tray_thread_ids = []

	save_data.save_data()


func _load_run() -> void:
	save_data = SaveGame.load_data()
	assert(save_data, "Couldn't load last save")
	
	RNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)
	
	_room_entry_rng_seed  = save_data.rng_seed
	_room_entry_rng_state = save_data.rng_state
	
	stats     = save_data.run_stats
	character = save_data.char_stats
	character.deck         = save_data.current_deck
	character.card_library = save_data.current_library
	character.health       = save_data.current_health
	thread_handler.add_threads(save_data.threads)
	
	CardLibrary.discovered_cards = save_data.discovered_cards.duplicate()
	for card in character.deck.cards:
		if not CardLibrary.is_discovered(card.id):
			CardLibrary.discovered_cards.append(card.id)
	
	if save_data.stats_tracker:
		stats_tracker = save_data.stats_tracker
	else:
		stats_tracker = RunStatsTracker.new()
	
	_setup_top_bar()
	_setup_event_connections()
	
	map.load_map(save_data.map_data, save_data.floors_climbed, save_data.last_room)
	
	if save_data.last_room and not save_data.was_on_map:
		match save_data.last_room.type:
			Room.Type.MONSTER, Room.Type.BOSS:
				if save_data.last_room.battle_stats:
					_on_battle_room_entered(save_data.last_room)
				else:
					push_warning("Cannot resume mid-battle (no battle_stats), returning to map")
					_restore_map_view()
			Room.Type.SHOP:
				_on_shop_entered()
			Room.Type.CAMPFIRE:
				_on_campfire_entered()
			Room.Type.TREASURE:
				_on_treasure_room_entered()
			Room.Type.EVENT:
				_on_event_room_entered(save_data.last_room)
	else:
		_restore_map_view()


func _restore_map_view() -> void:
	_is_on_map = true
	map.show_map()
	map_labels.show()
	message_label.show()
	MusicPlayer.play_track(MusicManager.Track.MAP)


func _change_view(scene: PackedScene) -> Node:
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()
	
	_is_on_map = false
	
	get_tree().paused = false
	var new_view := scene.instantiate()
	current_view.add_child(new_view)
	map.hide_map()
	map_labels.hide()
	message_label.hide()
	
	return new_view


func _show_map() -> void:
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()
	
	_is_on_map = true
	
	map.show_map()
	map.unlock_next_rooms()
	map_labels.show()
	message_label.show()
	
	MusicPlayer.play_track(MusicManager.Track.MAP)
	
	_save_run(true)


func _setup_event_connections() -> void:
	Events.battle_won.connect(_on_battle_won)
	Events.battle_reward_exited.connect(_on_battle_reward_exited_wrapper)
	Events.campfire_exited.connect(_show_map)
	Events.map_exited.connect(_on_map_exited)
	Events.shop_exited.connect(_on_shop_exited)
	Events.treasure_room_exited.connect(_on_treasure_room_exited)
	Events.event_room_exited.connect(_show_map)
	Events.bestiary_exited.connect(_show_map)
	Events.player_died_run_over.connect(_on_player_died_run_over)


func _setup_top_bar():
	character.stats_changed.connect(health_ui.update_stats.bind(character))
	health_ui.update_stats(character)
	gold_ui.run_stats = stats
	
	thread_handler.add_thread(character.starting_thread)
	Events.thread_tooltip_requested.connect(thread_tooltip.show_tooltip)
	
	deck_button.card_pile = character.deck
	deck_view.card_pile   = character.deck
	deck_button.pressed.connect(deck_view.show_current_view.bind("Deck"))
	
	card_library_button.card_library = character.card_library
	card_library_view.card_pile      = character.card_library
	card_library_button.pressed.connect(card_library_view.show_current_view.bind("Codex"))
	
	bestiary_opener_button.pressed.connect(bestiary_view.show)


func _show_regular_battle_rewards() -> void:
	var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
	reward_scene.run_stats       = stats
	reward_scene.character_stats = character
	
	reward_scene.add_gold_reward(map.last_room.battle_stats.roll_gold_reward())
	reward_scene.add_card_reward()


func _on_battle_room_entered(room: Room) -> void:
	if not room.battle_stats:
		push_error("Room has no battle_stats! Cannot start battle.")
		_show_map()
		return
	
	var battle_scene: Battle = _change_view(BATTLE_SCENE) as Battle
	battle_scene.char_stats      = character
	battle_scene.battle_stats    = room.battle_stats
	battle_scene.threads         = thread_handler
	battle_scene.stats_tracker   = stats_tracker
	battle_scene.starting_health = character.health
	battle_scene.start_battle()


func _on_treasure_room_entered() -> void:
	var treasure_scene := _change_view(TREASURE_SCENE) as Treasure
	treasure_scene.thread_handler = thread_handler
	treasure_scene.char_stats     = character
	treasure_scene.generate_thread()


func _on_treasure_room_exited(thread: ThreadPassive) -> void:
	var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
	reward_scene.run_stats       = stats
	reward_scene.character_stats = character
	reward_scene.thread_handler  = thread_handler
	
	reward_scene.add_thread_award(thread)


func _on_campfire_entered() -> void:
	var campfire := _change_view(CAMPFIRE_SCENE) as Campfire
	campfire.char_stats = character


func _on_shop_entered() -> void:
	var shop := _change_view(SHOP_SCENE) as Shop
	shop.char_stats     = character
	shop.run_stats      = stats
	shop.thread_handler = thread_handler
	Events.shop_entered.emit(shop)
	
	MusicPlayer.play_track(MusicManager.Track.SHOP)
	
	if not save_data.shop_thread_ids.is_empty() or not save_data.shop_card_ids.is_empty():
		shop.restore_from_save(
			save_data.shop_card_ids,
			save_data.shop_card_prices,
			save_data.shop_sold_card_ids,
			save_data.shop_thread_ids,
			save_data.shop_thread_prices,
			save_data.shop_sold_thread_ids,
			save_data.shop_slot_codes,
			save_data.shop_tray_card_ids,
			save_data.shop_tray_thread_ids,
			save_data.shop_coupon_applied
		)
	else:
		shop.populate_shop()


func _on_shop_exited() -> void:
	_show_map()


func _on_event_room_entered(room: Room) -> void:
	var event_room := _change_view(room.event_scene) as EventRoom
	event_room.character_stats = character
	event_room.run_stats       = stats
	event_room.thread_handler  = thread_handler
	event_room.stats_tracker   = stats_tracker
	event_room.setup()


func _on_battle_won() -> void:
	if map.floors_climbed == MapGenerator.FLOORS:
		var meta = MetaProgression.load_meta()
		meta.increment_runs_won()
		SaveGame.delete_data()
		_show_run_summary(true)
	else:
		_show_regular_battle_rewards()


func _on_map_exited(room: Room) -> void:
	_room_entry_rng_seed  = RNG.instance.seed
	_room_entry_rng_state = RNG.instance.state
	
	_save_run(false)
	
	stats_tracker.record_floor_cleared()
	
	var meta = MetaProgression.load_meta()
	meta.increment_floors_climbed()
	
	match room.type:
		Room.Type.MONSTER:
			_on_battle_room_entered(room)
		Room.Type.TREASURE:
			_on_treasure_room_entered()
		Room.Type.CAMPFIRE:
			_on_campfire_entered()
		Room.Type.SHOP:
			_on_shop_entered()
		Room.Type.EVENT:
			_on_event_room_entered(room)
		Room.Type.BOSS:
			_on_battle_room_entered(room)


func _on_battle_reward_exited_wrapper() -> void:
	_show_map_after_battle()
	if not DialogueState.has_shown("post_battle_shown"):
		DialogueManager.start_dialogue_from_file("res://dialogues/post_battle_congrats.json", "post_battle_shown")


func _show_map_after_battle() -> void:
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()
	
	_is_on_map = true
	
	map.show_map()
	map.unlock_next_rooms()
	map_labels.show()
	message_label.show()
	
	MusicPlayer.play_track(MusicManager.Track.MAP, true)
	
	_save_run(true)


func _on_player_died_run_over() -> void:
	var meta = MetaProgression.load_meta()
	meta.increment_runs_lost()
	SaveGame.delete_data()
	SaveGame.save_hub_state()
	_show_run_summary(false)


func _show_run_summary(victory: bool) -> void:
	var summary := _change_view(SUMMARY_SCENE) as RunSummaryScreen
	summary.show_summary(stats_tracker, victory)
	get_tree().paused = true
