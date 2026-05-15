class_name RunSummaryScreen
extends Control

const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
const HUB_PATH       := "res://scenes/hub/hub.tscn"

@onready var result_label: Label = %ResultLabel
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var kp_earned_label: Label = %KPEarnedLabel
@onready var rank_label: Label = %RankLabel
@onready var rank_title_label: Label = %RankTitleLabel
@onready var return_button: Button = %ReturnButton

# Unlock-notification overlay nodes (added in run_summary_screen.tscn).
@onready var unlock_overlay: Control = %UnlockOverlay
@onready var unlock_title: Label = %UnlockTitle
@onready var unlock_subtitle: Label = %UnlockSubtitle
@onready var unlock_portrait: TextureRect = %UnlockPortrait
@onready var unlock_continue_button: Button = %UnlockContinueButton

var stats_tracker: RunStatsTracker
var was_victory: bool = false


func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	# Wire the unlock overlay's button.
	if unlock_continue_button:
		unlock_continue_button.pressed.connect(_on_unlock_continue_pressed)
	if unlock_overlay:
		unlock_overlay.hide()


func show_summary(tracker: RunStatsTracker, victory: bool) -> void:
	stats_tracker = tracker
	was_victory = victory
	
	# Set result text
	if victory:
		result_label.text = "RUN COMPLETE!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
		return_button.text = "Return to Hub"
	else:
		result_label.text = "SECURITY BREACH"
		result_label.add_theme_color_override("font_color", Color.RED)
		return_button.text = "Return to Hub"
	
	# Display statistics
	_display_statistics()
	
	# Calculate and display Knowledge Points
	var kp_earned := tracker.calculate_knowledge_points()
	kp_earned_label.text = "Knowledge Points Earned: %d KP" % kp_earned
	
	# Display rank
	var rank_data := tracker.get_rank(kp_earned)
	
	# Award Knowledge Points and record run stats to meta progression
	var meta := MetaProgression.load_meta()
	meta.add_knowledge_points(kp_earned)
	meta.record_run_completion(tracker, rank_data)
	rank_label.text = rank_data["tier"]
	rank_title_label.text = rank_data["title"]
	
	# Color code rank
	match rank_data["tier"]:
		"Platinum":
			rank_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
		"Gold":
			rank_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		"Silver":
			rank_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		"Bronze":
			rank_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
	
	show()
	
	# After a victory, check if a new character was just unlocked and show
	# the popup over the summary. We don't acknowledge the unlock here —
	# the hub clears the "NEW!" badge the first time the player sees that
	# character highlighted, so the badge persists across the trip.
	if victory:
		_maybe_show_unlock_overlay(meta)


func _maybe_show_unlock_overlay(meta: MetaProgression) -> void:
	if unlock_overlay == null:
		return
	if meta.newly_unlocked_characters.is_empty():
		return
	
	# Show the most recently unlocked character (last in the list).
	var new_char_name: String = meta.newly_unlocked_characters[-1]
	var char_stats := _find_character_stats_by_name(new_char_name)
	
	unlock_title.text = "NEW CHARACTER UNLOCKED!"
	unlock_subtitle.text = new_char_name
	if char_stats and unlock_portrait:
		unlock_portrait.texture = char_stats.portrait
	
	unlock_overlay.show()


func _on_unlock_continue_pressed() -> void:
	unlock_overlay.hide()


# Looks up a CharacterStats resource by character_name.
# Update this if you add new characters later.
func _find_character_stats_by_name(name: String) -> CharacterStats:
	const WARRIOR := preload("res://characters/warrior/warrior.tres")
	const WIZARD := preload("res://characters/wizard/wizard.tres")
	const ASSASSIN := preload("res://characters/assassin/assassin.tres")
	var all: Array[CharacterStats] = [WARRIOR, WIZARD, ASSASSIN]
	for c in all:
		if c.character_name == name:
			return c
	return null


func _display_statistics() -> void:
	# Clear previous stats
	for child in stats_container.get_children():
		child.queue_free()
	
	# Only add stat labels if the value is greater than 0
	if stats_tracker.enemies_defeated > 0:
		_add_stat_label("Enemies Defeated: %d" % stats_tracker.enemies_defeated)
		
		# Show breakdown by tier (only if > 0)
		if stats_tracker.enemies_by_tier.get(0, 0) > 0:
			_add_stat_label("  - Easy: %d" % stats_tracker.enemies_by_tier.get(0, 0))
		if stats_tracker.enemies_by_tier.get(1, 0) > 0:
			_add_stat_label("  - Medium: %d" % stats_tracker.enemies_by_tier.get(1, 0))
		if stats_tracker.enemies_by_tier.get(2, 0) > 0:
			_add_stat_label("  - Hard: %d" % stats_tracker.enemies_by_tier.get(2, 0))
		if stats_tracker.enemies_by_tier.get(3, 0) > 0:
			_add_stat_label("  - Bosses: %d" % stats_tracker.enemies_by_tier.get(3, 0))
	
	if stats_tracker.floors_cleared > 0:
		_add_stat_label("Floors Cleared: %d" % stats_tracker.floors_cleared)
	
	if stats_tracker.perfect_battles > 0:
		_add_stat_label("Perfect Battles: %d" % stats_tracker.perfect_battles)
	
	# Show trivia stats if any questions were attempted
	if stats_tracker.trivia_total > 0:
		_add_stat_label("Trivia Questions: %d/%d correct" % [stats_tracker.trivia_correct, stats_tracker.trivia_total])


func _add_stat_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_font_override("font", load("res://art/Font Styles/Monocraft.ttc"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_container.add_child(label)


func _on_return_pressed() -> void:
	get_tree().paused = false
	# Both victory and defeat send the player to the Hub so they can see
	# any newly unlocked character right away.
	StaticTransition.transition_to_file(HUB_PATH)
