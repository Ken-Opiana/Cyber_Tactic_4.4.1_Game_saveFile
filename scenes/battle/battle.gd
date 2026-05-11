class_name Battle
extends Node2D

# Boss-tier 3D background. Loaded lazily so non-boss battles don't pay the cost.
const FINAL_BATTLE_BG: PackedScene = preload("res://art/3d_models/final_battle_background.tscn")

@export var battle_stats: BattleStats
@export var char_stats: CharacterStats
@export var threads: ThreadHandler

## Camera transform applied when the boss background loads.
## Tweak this in the Inspector after first running a boss battle and finding
## a position you like. Default (IDENTITY) means "don't touch the camera" —
## handy until you've dialed in the boss framing.
@export var boss_camera_transform: Transform3D = Transform3D.IDENTITY

@onready var battle_ui: BattleUI = $BattleUI
@onready var player_handler: PlayerHandler = $PlayerHandler 
@onready var enemy_handler: EnemyHandler = $EnemyHandler
@onready var player: Player = $Player
@onready var hand: HBoxContainer = %Hand
@onready var background_viewport: Battle3DBackground = %BackgroundViewport

var tutorial_manager: TutorialManager
var stats_tracker: RunStatsTracker
var starting_health: int = 0


func _ready() -> void:
	enemy_handler.child_order_changed.connect(_on_enemies_child_order_changed)
	Events.enemy_turn_ended.connect(_on_enemy_turn_ended)
	
	Events.player_press_end_turn_button.connect(player_handler.end_turn)
	Events.player_hand_discarded.connect(enemy_handler.start_turn)
	Events.player_died.connect(_on_player_died)


func start_battle() -> void:
	if not battle_stats:
		push_error("Battle.start_battle() called without battle_stats being set!")
		return
	
	get_tree().paused = false
	
	# Play the correct music + swap to boss background based on battle tier.
	# Tier 3 = boss fight, anything else = regular battle.
	if battle_stats.battle_tier == 3:
		MusicPlayer.play_track(MusicManager.Track.BOSS)
		_swap_to_boss_background()
	else:
		MusicPlayer.play_track(MusicManager.Track.BATTLE)
		# Default Main_1 background is already set in the scene; nothing to do.
	
	battle_ui.char_stats = char_stats
	player.stats = char_stats
	player_handler.threads = threads
	enemy_handler.setup_enemies(battle_stats)
	enemy_handler.reset_enemy_actions()
	
	threads.threads_activated.connect(_on_threads_activated)
	threads.activate_threads_by_type(ThreadPassive.Type.START_OF_COMBAT)
	
	# Check if tutorial should be shown (only for first non-tutorial battle).
	if not DialogueState.has_shown("battle_full_tutorial"):
		_setup_tutorial()


func _swap_to_boss_background() -> void:
	if not is_instance_valid(background_viewport):
		return
	
	# If boss_camera_transform was left at IDENTITY (the default), don't
	# touch the camera — keep whatever the editor set. Otherwise apply
	# the inspector-tuned transform so the boss GLB is framed correctly.
	if boss_camera_transform == Transform3D.IDENTITY:
		background_viewport.set_glb(FINAL_BATTLE_BG)
	else:
		background_viewport.set_glb(FINAL_BATTLE_BG, boss_camera_transform)


func _setup_tutorial() -> void:
	var BattleFullTutorialSteps = load("res://scenes/tutorial/battle_full_tutorial_steps.gd")
	var tutorial_steps: Array[TutorialStep] = BattleFullTutorialSteps.create_steps()
	
	tutorial_manager = TutorialManager.new()
	tutorial_manager.steps = tutorial_steps
	tutorial_manager.tutorial_key = "battle_full_tutorial"
	add_child(tutorial_manager)
	
	await Events.player_hand_drawn
	await get_tree().create_timer(0.5).timeout
	tutorial_manager.start_tutorial()


func _on_enemies_child_order_changed() -> void:
	if enemy_handler.get_child_count() == 0 and is_instance_valid(threads):
		threads.activate_threads_by_type(ThreadPassive.Type.END_OF_COMBAT)
	else:
		for enemy: Enemy in enemy_handler.get_children():
			enemy.update_action()


func _on_enemy_turn_ended() -> void:
	GlobalTurnNumber.turn_number_increase()
	player_handler.start_turn()
	enemy_handler.reset_enemy_actions()


func _on_player_died() -> void:
	# Play result music when the player dies.
	MusicPlayer.play_track(MusicManager.Track.RESULT)
	Events.player_died_run_over.emit()


func _on_threads_activated(type: ThreadPassive.Type) -> void:
	match type:
		ThreadPassive.Type.START_OF_COMBAT:
			player_handler.start_battle(char_stats)
			battle_ui.initialize_card_pile_ui()
		ThreadPassive.Type.END_OF_COMBAT:
			var was_perfect = (char_stats.health == starting_health)
			if is_instance_valid(stats_tracker):
				stats_tracker.record_battle_won(battle_stats.battle_tier, was_perfect)
			
			# Switch to battle result music on victory.
			MusicPlayer.play_track(MusicManager.Track.RESULT)
			Events.battle_over_screen_requested.emit("Victorious!", BattleOverPanel.Type.WIN)


# Debug: auto-win combat.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cheat"):
		for enemy: Enemy in enemy_handler.get_children():
			enemy.queue_free()
